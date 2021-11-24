module 'mock'

--------------------------------------------------------------------
CLASS:  AsyncDataLoadTask ( Task )
	:MODEL{}

function AsyncDataLoadTask:__init( filename )
	self.filename = filename
end

function AsyncDataLoadTask:onExec( queue )
	if not self.filename then return false end
	local buffer = MOAIDataBuffer.new()
	buffer:loadAsync(
		self.filename,
		self:requestThreadTaskQueue(),
		function( result )
			return self:complete( result )
		end
	)
	return 'running'
end

--------------------------------------------------------------------
CLASS:  AsyncDataSaveTask ( Task )
	:MODEL{}

function AsyncDataSaveTask:__init( data, filename )
	local tt = type( data )
	if tt == 'string' then
		local buffer = MOAIDataBuffer.new()
		buffer:setString( data )
		self.buffer = buffer

	elseif isMOAIObject( data, MOAIDataBuffer ) then
		self.buffer = data

	else
		self.buffer = false

	end
	self.filename = filename
end

function AsyncDataSaveTask:getDefaultGroupId()
	return 'save_data'
end

function AsyncDataSaveTask:onExec( queue )
	if not self.buffer then return false end
	if not self.filename then return false end
	
	self.buffer:saveAsync(
		self.filename,
		self:requestThreadTaskQueue(),
		function( result )
			return self:complete( result )
		end
	)
	return 'running'
end

