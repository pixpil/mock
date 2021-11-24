module 'mock'

--------------------------------------------------------------------
CLASS: BTActionReset ( mock.BTAction )
:register( 'bt_reset' )

function BTActionReset:start( context )
	context:getController():resetEvaluate()
end

--------------------------------------------------------------------
CLASS: BTActionStop ( mock.BTAction )
:register( 'bt_stop' )

function BTActionStop:start( context )
	context:getController():stop()
end


--------------------------------------------------------------------
CLASS: BTActionCoroutine ( mock.BTAction )
	:MODEL{}

BTActionCoroutine:register( 'coroutine' )

function BTActionCoroutine:start( context )
	local ent = context:getControllerEntity()
	local coroutineName = self:getArgS( 'method' )
	local target = false
	local targetName = self:getArgS( 'target', false )
	if not targetName then
		target = ent
	else
		target = ent:com( targetName )
	end
	if not target then
		_error( 'no coroutine target', targetName, ent )
	end
	local coro = target:addCoroutine( coroutineName )
	self.coroutine = coro
end

function BTActionCoroutine:step( context, dt )
	if self.coroutine:isBusy() then
		return 'running'
	else
		return 'ok'
	end
end

function BTActionCoroutine:stop( context )
	self.coroutine:stop()
end

