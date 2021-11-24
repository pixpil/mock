module 'mock'

--------------------------------------------------------------------
CLASS: TaskManager ()
	:MODEL{}

local _mgr = false
function getTaskManager()
	if _mgr then return _mgr end
	_mgr = TaskManager()
	return _mgr
end

function isTaskGroupBusy( groupId )
	return getTaskManager():isBusy( groupId )
end

function getTaskGroup( groupId )
	groupId = groupId or getTaskManager().defaultGroupId
	return getTaskManager():getGroup( groupId )
end

function getTaskProgress( groupId )
	groupId = groupId or getTaskManager().defaultGroupId
	local group = getTaskManager():getGroup( groupId, false )
	if not group then return 1 end
	return group:getProgress()
end

--------------------------------------------------------------------
--------------------------------------------------------------------
function TaskManager:__init()
	self.groups = {}
	self.defaultGroupId = 'main'
	self.moaiTaskQueues = {}
	self.activeCoroutines = {}

	self.taskQueueCount = 4
	self.moaiTaskQueues = {}

	for i = 1, self.taskQueueCount do
		self.moaiTaskQueues[ i ] = MOAITaskQueue.new()
	end

end

function TaskManager:getGroup( name, createIfNotExist )
	local group = self.groups[ name ]
	if not group and ( createIfNotExist ~= false ) then
		group = TaskGroup()
		self.groups[ name ] = group
		group.manager = self
	end
	return group
end

function TaskManager:setGroupSize( name, size )
	local group = self:getGroup( name, true )
	group:setSize( size )
end

function TaskManager:getDefaultGroupId()
	return self.defaultGroupId
end

function TaskManager:getDefaultGroup()
	return self:affirmGroup( self.defaultGroupId )
end
	
function TaskManager:setDefaultGroup( name )
	self.defaultGroupId = name or 'main'
end

function TaskManager:pushActiveTaskCoroutine( coro )
	self.activeCoroutines[ coro ] = true
end

function TaskManager:removeActiveTaskCoroutine( coro )
	self.activeCoroutines[ coro ] = false
end

function TaskManager:pushTask( groupId, t )
	groupId = groupId or self.defaultGroupId
	local group = self:getGroup( groupId )
	t.groupId = groupId
	group:pushTask( t )
	return t
end

function TaskManager:isBusy( groupId )
	local group = self:getGroup( groupId or self.defaultGroupId, false )
	if not group then return false end
	return group:isBusy()
end

function TaskManager:isAnyBusy()
	return self.busy
end

local qid = 0
function TaskManager:requestThreadTaskQueue( queue )
	--TODO:allocation taskqueue
	qid = ( qid + 1 ) % self.taskQueueCount
	return self.moaiTaskQueues[ qid + 1 ]
end

local resume = coroutine.resume
function TaskManager:updateCoroutines()
	for coro, active in pairs( self.activeCoroutines ) do
		if active then 
			local stat, result = resume( coro )
			if not stat then
				print( result )
				error( 'task coroutine crash' )
			end
		end
	end
end

function TaskManager:update()
	return self:onUpdate()
end

function TaskManager:onUpdate()
	MOCKHelper.updateTaskSubscriber()
	self:updateCoroutines()
end

---------------------------------------------------------------------
CLASS: TaskGroup ()
	:MODEL{}

function TaskGroup:__init()
	self.size = 0
	self.queues = {}
	self:setSize( 1 )
end

function TaskGroup:setSize( size )
	size = math.max( size, 1 )
	self.size = size or 1
	for i = 1, size do
		local q = self.queues[ i ]
		if not q then
			q = TaskQueue()
			self.queues[ i ] = q
		end
	end
end

function TaskGroup:getSize()
	return self.size
end

function TaskGroup:isIdle()
	return not self:isBusy()
end

function TaskGroup:isBusy()
	for i, queue in ipairs( self.queues ) do
		if queue:isBusy() then 
			return true 
		end
	end
	return false
end

function TaskGroup:getTotalTaskSize()
	local size = 0
	for i, queue in ipairs( self.queues ) do
		size = size + queue.totalTaskSize
	end
	return size
end

function TaskGroup:getTaskSize()
	local size = 0
	for i, queue in ipairs( self.queues ) do
		size = size + queue.taskSize
	end
	return size
end

function TaskGroup:getProgress()
	local totalSize = self:getTotalTaskSize()
	if totalSize <= 0 then return 1 end
	local taskSize = self:getTaskSize()
	return 1 - ( taskSize/totalSize )
end

function TaskGroup:pushTask( task )
	--find empty queue
	local minQSize = false
	local selectedQueue = false
	for i, queue in ipairs( self.queues ) do
		if not queue:isBusy() then
			selectedQueue = queue
			break
		end
		local qsize = queue.taskCount
		if ( not minQSize ) or qsize < minQSize then
			minQSize = qsize
			selectedQueue = queue
		end
	end
	assert( selectedQueue )
	return selectedQueue:pushTask( task )

end

--------------------------------------------------------------------
CLASS: TaskQueue ()
	:MODEL{}
function TaskQueue:__init()
	
	self.pending = {}
	self.activeTask = false
	self.taskSize  = 0
	self.taskCount = 0
	self.totalTaskSize  = 0
	self.totalTaskCount = 0
	
	self.coroutine = coroutine.create( function()
		return self:threadMain()
	end )

end

function TaskQueue:requestThreadTaskQueue()
	return _mgr:requestThreadTaskQueue( self )
end

--LAZY queue processing corouinte
function TaskQueue:threadMain()
	local coro = self.coroutine
	local remove = table.remove
	local clock = os.clock
	while true do
		--in active queue now
		local task = remove( self.pending, 1 )
		if task then
			_stat( 'Processing task', self, task )
			self.activeTask = task
			task.execTime0 = clock()
			task.state = 'busy'
			task:_exec( self )
			_stat( 'task in execution now', self, task )
			if task.state == 'busy' then
				self:_deactivate() --will resume from notify function
				coroutine.yield()
			end
			self.taskSize = self.taskSize - task:getTaskSize()
			self.taskCount = self.taskCount - 1
			task.execTime1 = clock()
		else
			self.activeTask = false
			self:_deactivate()
			coroutine.yield()
		end
	end
end

function TaskQueue:_activate()
	return _mgr:pushActiveTaskCoroutine( self.coroutine )
end

function TaskQueue:_deactivate()
	return _mgr:removeActiveTaskCoroutine( self.coroutine )
end

function TaskQueue:resetProgress()
	self.totalTaskSize  = self.taskSize
	self.totalTaskCount = self.taskCount
end

function TaskQueue:getProgress()
	if self.totalTaskSize <= 0 then return 1 end
	return 1 - ( self.taskSize / self.totalTaskSize )
end

function TaskQueue:pushTask( task )
	table.insert( self.pending, task )
	self.taskSize  = self.taskSize + task:getTaskSize()
	self.taskCount = self.taskCount + 1
	self.totalTaskSize  = self.totalTaskSize + task:getTaskSize()
	self.totalTaskCount = self.totalTaskCount + 1
	task.queue = self

	if not self.activeTask then
		return self:_activate()
	end
end

function TaskQueue:isBusy()
	if self.activeTask then return true end
	if next( self.pending ) then return true end
	return false
end

function TaskQueue:notifyCompletion( task )
	assert( self.activeTask == task )
	_stat( 'Task completed', task:toString() )
	return self:_activate()
end

function TaskQueue:notifyFail( task ) --TODO: allow interrupt on error?
	assert( self.activeTask == task )
	_warn( 'Task failed', task:toString() )
	return self:_activate()
end

--------------------------------------------------------------------
--------------------------------------------------------------------
CLASS: Task ()
	:MODEL{}

function Task:getDefaultGroupId()
	return nil
end


function Task:__init()
	self.state = 'idle'
	self.groupId = false
	self.depedencies = false
	self.retryCount = 3
end

function Task:setRetryCount( r )
	self.retryCount = r
end

function Task:init( ... )
	self:onInit( ... )
	return self
end

function Task:setDependency( task )
	local state = self.state
	assert( state == 'idle' or state == 'waiting' )
	if not self.depedencies then
		self.depedencies = {}
	end
	self.depedencies[ task ] = true
end

function Task:next( task )
	task:setDependency( self )
	return task
end

function Task:requestThreadTaskQueue()
	return assert( self.queue:requestThreadTaskQueue() )
end

function Task:start( groupId )
	groupId = groupId or self:getDefaultGroupId()
	self.groupId = groupId
	self.state = 'waiting'
	getTaskManager():pushTask( groupId, self )
end

function Task:_retry()
	_log( 'Task retrying', self:toString() )
	self.state = 'waiting'
	getTaskManager():pushTask( self.groupId, self )
end

function Task:__tostring()
	return string.format( '%s:%s', self:__repr(), self:toString() )
end

function Task:toString()
	return '<unknown>'
end

function Task:getGroupId()
	return self.groupId
end

function Task:isIdle()
	return self.state == 'idle'
end

function Task:isWaiting()
	return self.state == 'waiting'
end

function Task:isBusy()
	return self.state == 'busy'
end

function Task:isDone()
	return self.state == 'done'
end

function Task:isFailed()
	return self.state == 'fail'
end

function Task:complete( ... )
	self.state = 'done'
	self.queue:notifyCompletion( self )
	return self:onComplete( ... )
end

function Task:fail( ... )
	self.state = 'fail'
	if self.retryCount > 0 then
		self.retryCount = self.retryCount - 1
		return self:_retry()
	end
	self.queue:notifyFail( self )		
	return self:onFail( ... )
end

function Task:yield()
	coroutine.yield()
end

function Task:_exec( queue )
	local deps = self.depedencies
	if deps then
		while true do
			local done = true
			for dep in pairs( deps ) do
				local state = dep.state
				if state == 'fail' then
					return self:fail()
				elseif state ~= 'done' then
					done = false
					break
				end
			end
			if done then break end
			self:yield()
		end
	end
	return self:onExec( queue )
end

function Task:onInit()
end

function Task:onExec( queue )
end

function Task:onComplete( ... )
end

function Task:onFail( ... )
end

function Task:getTaskSize() --for progress calculation
	return 1
end

function Task:getTimeElapsed()	
	local t0 = self.execTime0 or 0
	local t1 = self.execTime1 or os.clock()
	return t1 - t0
end

