module 'mock'

local NameToAnimMode = {
	['normal']           = MOAITimer.NORMAL;
	['reverse']          = MOAITimer.REVERSE;
	['continue']         = MOAITimer.CONTINUE;
	['continue_reverse'] = MOAITimer.CONTINUE_REVERSE;
	['loop']             = MOAITimer.LOOP;
	['loop_reverse']     = MOAITimer.LOOP_REVERSE;
	['ping_pong']        = MOAITimer.PING_PONG;
}

local AnimModeToName = table.swapkv( NameToAnimMode )

--------------------------------------------------------------------
CLASS: SQNodeAnimator ( SQNode )
	:MODEL{

	}

function SQNodeAnimator:__init()
	self.cmd = 'play'
	self.blocking  = false
end

function SQNodeAnimator:isReplayable()
	return true
end

function SQNodeAnimator:playClip( state, env, clipName, mode )
	local animator = self:checkAndGetAnimator( state )
	local animState = animator:playClip( clipName, mode, self:hasTag( 'retain_current' ) )
	return animState
end

function SQNodeAnimator:enter( state, env )
	local animator = self:checkAndGetAnimator( state )
	if not animator then return false end

	local cmd = self.cmd
	if cmd == 'play' then
		if not self.argClipName then return false end
		local animState = self:playClip( state, env, self.argClipName, self.argMode )
		if not animState then 
			self:_warn( 'no animator clip found:', animator:getEntity():getName(), self.argClipName )
			return false
		end
		local duration = self.argDuration
		if duration > 0 then
			animState:setDuration( duration )
		else
			animState:setDuration( 0 )
			duration = animState.clipLength
		end
		if self.argMode == MOAITimer.REVERSE then
			animState.anim:setTime( duration )
		end
		env.animState = animState
		return true 

	elseif cmd == 'load' then
		if not self.argClipName then return false end
		local animState = self:playClip( state, env, self.argClipName, self.argMode )
		if not animState then 
			self:_warn( 'no animator clip found:', animator:getEntity():getName(), self.argClipName )
			return false
		end
		animState:setAutostop( false )
		animState:pause()
		return false

	elseif cmd == 'stop' then
		animator:stop()
		return false

	elseif cmd == 'pause' then
		animator:pause()
		return false

	elseif cmd == 'resume' then
		local state = animator:getActiveState()
		if not state then
			self:_warn( 'no anim clip loaded' )
			return false
		end
		animator:resume()
		env.animState = state
		return true

	elseif cmd == 'throttle' then
		animator:setThrottle( self.argThrottle )
		return false

	elseif cmd == 'seek' then
		local state = animator:getActiveState()
		if not state then
			self:_warn( 'no anim clip loaded' )
			return false
		end
		state:seek( self.argPosFrom )

	elseif cmd == 'to' then
		local state = animator:getActiveState()
		if not state then
			self:_warn( 'no anim clip loaded' )
			return false
		end
		state:setRange( nil, self.argPosTo )
		state:resume()
		env.animState = state
		return true

	elseif cmd == 'range' then
		local state = animator:getActiveState()
		if not state then
			self:_warn( 'no anim clip loaded' )
			return false
		end
		state:seek( self.argPosFrom )
		state:setRange( self.argPosFrom, self.argPosTo )
		state:resume()
		env.animState = state
		return true

	elseif cmd == 'set_var' then
		if self.argVarName then
			animator:setVar( self.argVarName, self.argVarValue )
		end
		return false

	else
		return false
	end
end

function SQNodeAnimator:step( state, env, dt )
	if self.blocking then
		local animState = env.animState
		if animState:isBusy() then
			return false
		end

		if animState:isDone() then
			return true
		end

		if not animState:isActive() then
			return true
		end

	else
		return true
	end
end

function SQNodeAnimator:checkAndGetAnimator( state )
	local target = self:getContextEntity( state )
	local animator = target:getComponent( Animator )
	if not animator then
		self:_warn( 'no animator for target:', target:getName() )
	end
	return animator
end

function SQNodeAnimator:getIcon()
	return 'sq_node_animator'
end

local function toValue( d )
	local n = tonumber( d )
	if n then return n end
	if d =='true' then return true end
	if d =='false' then return false end
	return d
end

function SQNodeAnimator:load( data )
	local args = data.args
	local cmd = args[1]
	if not cmd then return end
	self.cmd = cmd
	if cmd == 'play' then
		--
		self.argClipName = args[2] or false
		self.argMode = NameToAnimMode[ args[3] or 'normal' ] or 0
		self.argDuration = tonumber( args[4] ) or 0
		self.blocking = self:checkBlockTag( true )

	elseif cmd == 'load' then
		self.argClipName = args[2] or false
		self.argMode = NameToAnimMode[ args[3] or 'normal' ] or 0
		self.blocking  = false

	elseif cmd == 'loop' then
		self.cmd = 'play'
		self.argClipName = args[2] or false
		self.argDuration = tonumber( args[3] ) or 0
		self.argMode = NameToAnimMode[ 'loop' ]
		self.blocking = self:checkBlockTag( false )

	elseif cmd == 'stop' then
		--no args
		
	elseif cmd == 'pause' then
		--self.argPause = paused
		--no args

	elseif cmd == 'resume' then
		--no args

	elseif cmd == 'throttle' then
		self.argThrottle = tonumber( args[2] ) or 1

	elseif cmd == 'seek' then
		self.argPosFrom = tonumber( args[2] ) or args[2]

	elseif cmd == 'to' then
		self.argPosTo = tonumber( args[2] ) or args[2]
		self.blocking = self:checkBlockTag( true )

	elseif cmd == 'range' then
		self.argPosFrom = tonumber( args[2] ) or args[2]
		self.argPosTo = tonumber( args[3] ) or args[3]
		self.blocking = self:checkBlockTag( true )

	elseif cmd == 'set_var' then
		self.argVarName  = args[2] or false
		self.argVarValue = toValue( args[3] )
		self.blocking = false

	else
		self:_warn( 'unkown animator command', tostring(cmd) )
		return false

	end
end

function SQNodeAnimator:getDebugRepr()
	local cmd = self.cmd
	local argPart = cmd
	if cmd == 'play' or cmd == 'loop' then
		argPart = argPart .. ' ' .. self.argClipName .. ' ' .. AnimModeToName[ self.argMode ]
	end
	return 'anim', argPart
end

--------------------------------------------------------------------
registerSQNode( 'anim', SQNodeAnimator   )
