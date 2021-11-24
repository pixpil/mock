module 'mock'

local _SQDebugFrameStateLoaders = {}
function registerSQDebugFrameStateLoader( key, clas )
	_SQDebugFrameStateLoaders[ key ] = clas
end

--------------------------------------------------------------------
CLASS: SQDebugFrameStateLoader ()

function SQDebugFrameStateLoader.register( clas, key )
	registerSQDebugFrameStateLoader( key, clas )
end

function SQDebugFrameStateLoader:load( data )
end

function SQDebugFrameStateLoader:save()
	return nil
end


--------------------------------------------------------------------
CLASS: SQDebugHelper ()
	:MODEL{}

function SQDebugHelper:__init()
	self.checkpoints = {}
	self.checkpointCount = 0

	self.pendingCheckpoint = false
	self.prevCheckpoint = false

	self.recordingSessions = {}
	self.session = false
	self.frameStateLoaders = {}

end

function SQDebugHelper:init()
	if mock.__nodebug then return end
	connectGlobalSignal( 'sq.start', self:methodPointer( 'onSQActorStart' ) )
	connectGlobalSignal( 'sq.stop',  self:methodPointer( 'onSQActorStop'  ) )

	connectGlobalSignal( 'sq.system.pause', self:methodPointer( 'onSQPause' ) )
	connectGlobalSignal( 'sq.system.resume',  self:methodPointer( 'onSQResume'  ) )
	
	connectGlobalSignalFunc( 'mainscene.start', function()
		self:onMainSceneStart()
	end )

	registerSyncQueryHandler( function( key, context )
		if key == 'sq.checkpoints' then
			return self:onQueryCheckpoints()

		elseif key == 'cmd.sq.run_checkpoint' then
			local name = context[ 'checkpoint' ]
			assert( name )
			self:startCheckpointByName( name )

		elseif key == 'cmd.sq.run_previous_checkpoint' then
			local name = game:getUserObject( 'previous_sq_checkpoint' )
			if name then
				self:startCheckpointByName( name )
			else
				_warn( 'no previous checkpoint.' )
			end

		elseif key == 'cmd.sq.run_from_line' then
			local assetPath = context[ 'path' ]
			local line      = context[ 'line' ]
			self:startFromLine( assetPath, line )
		end
	end )

	
	for key, clas in pairs( _SQDebugFrameStateLoaders ) do
		local loader = clas()
		self.frameStateLoaders[ key ] = assert( loader )
	end

end

function SQDebugHelper:getSession()
	return self.session
end

function SQDebugHelper:setBreakpoint( node )
	self.breakpointNode = node
end

-- function SQDebugHelper:setBreakpoint( path, line )
-- 	self.breakpointPath = path or false
-- 	self.breakpointLine = line or false
-- end

function SQDebugHelper:hasPrevCheckpoint()
	return self.prevCheckpoint and true or false
end

function SQDebugHelper:startPrevCheckpoint()
	if not self.prevCheckpoint then return false end
	self:startCheckpointByName( self.prevCheckpoint )
	return true
end

function SQDebugHelper:startCheckpointByName( name, looseMatch )
	for i, entry in ipairs( self.checkpoints ) do
		local match
		local entryName = entry[1]
		if looseMatch then --ignore sqactor
			match = entryName:startwith( name ) 
		else
			match = entryName == name
		end
		if match then
			return self:startCheckpoint( entry )
		end
	end
	return _warn( 'no checkpoint found', name )
end

function SQDebugHelper:startCheckpoint( entry, checkGroup )
	local name, node, actor = unpack( entry )
	self.prevCheckpoint = name
	--check group
	if checkGroup ~= false then
		local overrideGroupConfig = false
		if node.groupsOnly then
			if node.groupsOff or node.groupsOn then
				node:_warn( 'group_only will overwrite group_on/group_off' )
			end
			overrideGroupConfig = overrideGroupConfig or {}
			overrideGroupConfig[ '*' ] = 'OFF'
			for _, path in pairs( node.groupsOnly ) do
				path = path:trim()
				while true do
					overrideGroupConfig[ path ] = 'ON'
					path = dirname( path )
					if path == '' then break end
				end
			end
		else
			if node.groupsOff then
				overrideGroupConfig = overrideGroupConfig or {}
				for _, path in pairs( node.groupsOff ) do
					overrideGroupConfig[ path:trim() ] = 'OFF'
				end
			end
			if node.groupsOn then
				overrideGroupConfig = overrideGroupConfig or {}
				for _, path in pairs( node.groupsOn ) do
					path = path:trim()
					while true do
						overrideGroupConfig[ path ] = 'ON'
						path = dirname( path )
						if path == '' then break end
					end
				end
			end
		end

		game:setUserObject( 'conditional_group_override', overrideGroupConfig )
		game:setUserObject( 'running_sq_checkpoint', true )
		self:getSession():clear()
		pauseSQSystem( false )
		if overrideGroupConfig then
			game:scheduleReopenMainScene()
			self.pendingCheckpoint = name
			return 'pending'
		end
		
	end

	--check group state
	local state = actor:getState()
	if state then
		local routineState = state:addRoutineState( node, true ) --enter entry node
		if routineState then 
			_log( 'running into checkpoint', name )
			routineState:start()
			self.runningRoutineState = routineState
		else
			_warn( 'failed create routine state' )
		end
	else
		_warn( 'sq actor not active' )
	end
	game:setUserObject( 'previous_sq_checkpoint', name )
	game:setDebugUIEnabled( false )
	MOAISim.raiseWindow()
end

local function _sortFunc( a, b )
	return a[1] < b[1]
end

function SQDebugHelper:scanCheckpoints()
	local scene = game:getMainScene()
	local actors = getSQActorsInScene( scene )
	local result = {}
	for actor in pairs( actors ) do
		local script = actor.script
		if script then
			local checkpoints = script:getCheckpoints()
			for point in pairs( checkpoints	) do
				local name = point:getRepr()
				local entry = { name, point, actor }
				table.insert( result, entry )
			end
		end
	end
	table.sort( result, _sortFunc )
	self.checkpoints = result
	self.checkpointCount = #result
end

function SQDebugHelper:getCheckpoints()
	return self.checkpoints
end

function SQDebugHelper:getCheckpointCount()
	return self.checkpointCount
end


function SQDebugHelper:findNearestCheckpoint( path, line )
	local nearestCheckpoint, nearestDiff = false, false
	
	local node = self:findSQScriptNode( path, line )
	if not node then return false end
	local depth = node.depth
	for i, entry in ipairs( self.checkpoints ) do
		local name, cpNode, actor = unpack( entry )
		local script = cpNode:getScript()
		local sourcePath = script:getSourcePath()
		if sourcePath == path then
			local cdepth = cpNode.depth
			local sourceLine = cpNode.lineNumber
			if sourceLine <= line and cdepth <= depth then
				--check structure
				local p = node
				for i = 1, depth - cdepth do
					p = p.parentNode
				end
				if p == cpNode or p.parentNode == cpNode.parentNode then
					local diff = line - sourceLine
					if ( not nearestCheckpoint ) or nearestDiff > diff then
						nearestCheckpoint = entry
						nearestDiff = diff
					end
				end
			end
		end
	end

	return nearestCheckpoint, node
end

function SQDebugHelper:findSQScriptNode( file, line )
	local script = getCachedAsset( file )
	if not script then return false end
	local node = script:findNodeByLine( line )
	return node
end

function SQDebugHelper:startFromLine( path, line )
	local nearestCheckpoint, node = self:findNearestCheckpoint( path, line )	
	if not nearestCheckpoint then
		_warn( 'no near Checkpoint found' )
		return false
	end

	self:setBreakpoint( node )
	startSQFastForward( 'default', 10 )
	return self:startCheckpoint( nearestCheckpoint )
end

function SQDebugHelper:onQueryCheckpoints()
	local output  = {}
	for i, entry in ipairs( self.checkpoints ) do
		output[ i ] = entry[1]
	end
	return output
end

function SQDebugHelper:onSQActorStart( actor, state )
	if not actor.allowRecording then return end
	state:setNodeListener( self:methodPointer( 'onNodeEvent' )  )
end

function SQDebugHelper:onSQActorStop( actor, state )
	if not actor.allowRecording then return end
	state:setNodeListener( nil )
end

function SQDebugHelper:onSQPause()
	local session = self:getSession()
	session.lastFrameData = session:saveFrameState()
end

function SQDebugHelper:onSQResume()
	local session = self:getSession()
	local frameData = session.lastFrameData
	session.lastFrameData = nil
	session:loadFrameState( frameData, true )
	session.played = false
end

function SQDebugHelper:onMainSceneStart()
	self:scanCheckpoints()
	local pending = self.pendingCheckpoint
	self.pendingCheckpoint = false
	if pending then
		for i, entry in ipairs( self.checkpoints ) do
			if entry[1] == pending then
				game:setUserObject( 'conditional_group_override', false )
				game:getMainScene():callNextFrame(
					function()
						self:startCheckpoint( entry, false )
					end
				)
				-- 		game:getMainScene():callNextFrame(
				-- 			function()
				-- 				game:setUserObject( 'running_sq_checkpoint', nil )
				-- 			end
				-- 		)
				-- 	end
				-- )
				break
			end
		end
	else
		game:setUserObject( 'running_sq_checkpoint', nil )
	end
	self:getSession():clear()
	self.selectedStep = false
end

function SQDebugHelper:reloadSQ()
	local scene = game:getMainScene()
	local actors = getSQActorsInScene( scene )
	for actor in pairs( actors ) do
		if actor.script then
			actor:stopScript()
		end
		local scriptPath = actor:getScript()
		if scriptPath then
			actor:loadScript()
			if actor.autoStart then
				actor:startScript()
			end
		end
	end
end


function SQDebugHelper:createRecordSession()
	return SQRecordSession()
end

function SQDebugHelper:startRecording()
	self.recording = true
	self.session = self:createRecordSession()
	self.session.owner = self
end

function SQDebugHelper:onUpdate( dt )
	self.session:update( dt )
end

function SQDebugHelper:onNodeEvent( ev, node, state, env )
	local canRecord
	if node:isReplayable()  then
		canRecord = true
	else	
		canRecord = 
			node:isInstance( SQNodeLabel )
			or node:isInstance( SQNodeCheckpoint )
			or node:isInstance( SQNodeGoto )
			or false
	end
	local breakpointNode = self.breakpointNode
	if ev == 'enter' and breakpointNode then
		if node == breakpointNode then
		-- local scriptPath = node:getScript():getSourcePath()
		-- if scriptPath == breakpointPath and node.lineNumber == self.breakpointLine then
		-- 	--exit fastforward
			stopSQFastForward( 'default' )
		end
	end
	if canRecord then
		self.session:recordStep( ev, node, state, env )
	end
end


--------------------------------------------------------------------
CLASS: SQRecordSession ()
	:MODEL{}

function SQRecordSession:__init()
	self.steps = {}
	self.recorded = 0
	self.maxLength = 400
	self.currentEnterStep = false
	self.currentStep = false
	self.currentStepId = false
	self.elapsed = 0
	self.nextStepTime = 0
	self.nextTimestamp = 0
	self.runningNodes = {} 
	self.paused = true
	self.pauseOnNewFrame = false
	self.hardResetting = false
	self.played = false
end

local insert = table.insert
local remove = table.remove
local stepId = 0
function SQRecordSession:recordStep( ev, node, state, env )
	env = env and table.simplecopy( env ) or false
	local timestamp = game:getTime()
	stepId = stepId + 1
	local step = {
		stepId, ev, node, state, env, timestamp
	}
	insert( self.steps, step )
	local recorded = self.recorded
	if recorded > self.maxLength then
		remove( self.steps, 1 )
	else
		self.recorded = recorded + 1
	end
	self.currentStep = step
	if ev == 'enter' then
		self.currentEnterStep = step
		-- local contextStates = {}
		-- for i, target in ipairs( node:getContextEntities( state ) ) do
		-- 	if target then
		-- 		local s = self:saveContextEntityState( target, node, state, env )
		-- 		contextStates[ target ] = s
		-- 	end
		-- end
		-- step.contextStates = contextStates
		step.frameState = self:saveFrameState()
	end
	return step
end

function SQRecordSession:saveFrameState()
	local dataset = {}
	for key, loader in pairs( self.owner.frameStateLoaders ) do
		local data = loader:save()
		dataset[ key ] = data
	end
	return dataset
end

function SQRecordSession:loadFrameState( dataset, hardReset )
	for key, loader in pairs( self.owner.frameStateLoaders ) do
		local data = dataset[ key ]
		if data then
			loader:load( data, hardReset )
		end
	end
end

-- function SQRecordSession:saveContextEntityState( entity, node, state, env )
-- 	local data = {}
-- 	data.transform = entity:saveTransform()
-- 	data.color = { entity:getColor() }
-- 	data.visible = entity:isLocalVisible()
-- 	return data
-- end

-- function SQRecordSession:loadContextEntityState( entity, data, node, state, env )
-- 	entity:loadTransform( data.transform )
-- 	entity:setColor( unpack( data.color ) )
-- 	entity:setVisible( data.visible )
-- end

function SQRecordSession:findStepIndex( step )
	if not step then return false end
	local i = table.index( self.steps, step )
	return i
end

function SQRecordSession:findPrevStep()
	local i = self:findStepIndex( self.currentStep )
	if not i then return false end
	return self.steps[ i + 1 ]
end

function SQRecordSession:findNextStep()
	local i = self:findStepIndex( self.currentStep )
	if not i then return false end
	return self.steps[ i + 1 ]
end

function SQRecordSession:next()
	local nextStep = self:findNextStep()
	if nextStep then
		return self:startStep( nextStep )
	end
end

function SQRecordSession:resetPlayback()
	self.elapsed = 0
	self.nextStep = false
	self.currentStep = false
	self.currentEnterStep = false
	self.nextStepTime = 0
	self.runningNodes = {}
	self.paused = true
end

function SQRecordSession:pause( paused )
	self.paused = paused ~= false
end

function SQRecordSession:startStep( step )
	local id, ev, node, state, env, ts0 = unpack( step )
	self.currentStep = step
	self.currentStepId = step[1]
	self.currentStepExecuted = false
	if ev == 'enter' then
		self.currentEnterStep = step
	end

	local nextStep = self:findNextStep()
	self.nextStep = nextStep

	if not nextStep then return end
	local ts1 = nextStep[ 6 ]
	local interval = ts1 - ts0
	self.nextStepTime = self.nextStepTime + interval
end

function SQRecordSession:updateNext()
	if not self.nextStep then return end
	if self.elapsed >= self.nextStepTime then
		return self:startStep( self.nextStep )
	end
end

function SQRecordSession:update( dt )
	if self.paused then return end
	
	for node, data in pairs( self.runningNodes ) do
		local state, env = unpack( data )
		node:step( state, env, dt )
	end
	self.elapsed = self.elapsed + dt
	--apply the step
	local step = self.currentStep
	if step and ( not self.currentStepExecuted ) then
		local id, ev, node, state, env, ts0 = unpack( step )
		self.currentStepExecuted = true
		local hardReset = self.hardResetting
		self.hardResetting = false
		if node:isReplayable() then
			if ev == 'enter' then
				local frameState = step.frameState
				if frameState then
					self:loadFrameState( frameState, hardReset )
					self.played = true
				end
				if node:isReplayable() ~= 'noplay' then
					if node:enter( state, env ) ~= false then
						self.runningNodes[ node ] = { state, env }
					end
				end
				if self.pauseOnNewFrame then
					self.paused = true
					return
				end
			elseif ev == 'exit' then
				node:exit( state, env )
				self.runningNodes[ node ] = nil
			end
		end
	end
	return self:updateNext()
end

function SQRecordSession:seekAndPlay( step )
	self:seek( step )
	self:pause( false )
end

function SQRecordSession:seek( step )
	pauseSQSystem()
	emitGlobalSignal( 'sq.debug.seek' )
	self:resetPlayback()
	self.hardResetting = true
	self:startStep( step )
end

function SQRecordSession:clear()
	self:resetPlayback()
	self.steps = {}
	self.recorded = 0
end
---------------------------------------------------------------------