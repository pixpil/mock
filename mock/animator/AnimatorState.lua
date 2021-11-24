module 'mock'

local insert, remove = table.insert, table.remove

local MOAIActionIT = MOAIAction.getInterfaceTable ()
local MOAIActionIsBusy = MOAIActionIT.isBusy
local MOAIActionIsDone = MOAIActionIT.isDone

local MOAITimerIT = MOAITimer.getInterfaceTable ()
local MOAITimerGetTime = MOAITimerIT.getTime

local function _onAnimUpdate( anim )
	local t = MOAITimerGetTime( anim )
	local state = anim.source
	return state:onUpdate( t )
end

local function _isFinite( mode )
	if mode == MOAITimer.NORMAL then return true end
	if mode == MOAITimer.REVERSE then return true end
	return false
end

local function _onAnimStop( anim )
	local state = anim.source
	return state:tryAutoStop( anim )
end

local function _onAnimKeyFrame( timer, keyId, timesExecuted, time, value )
	local state  = timer.source
	local keys   = state.keyEventMap[ keyId ]
	local time   = MOAITimerGetTime( timer )
	for i = 1, #keys do
		keys[ i ]:executeEvent( state, time )
	end
end


local animPool = {}
local newAnim = function()
	local anim = remove( animPool, 1 )
	if not anim then
		return MOAIAnim.new()
	end
	return anim
end
--------------------------------------------------------------------
CLASS: AnimatorState ()
	:MODEL{}

function AnimatorState:__init()
	self.seq = 0
	self.animator = false	
	self.autostop = true
	-- self.anim = newAnim()
	self.anim = MOAIAnim.new()
	self.anim.source = self
	self.updateListenerTracks = {}
	self.attrLinks = {}
	self.attrLinkCount = 0
	self.parentThrottle = 1
	self.throttle = 1
	self.clipSpeed = 1
	self.actualThrottle = 1
	self.trackTargets = {}
	
	self.stopping = false
	self.previewing = false
	self.previewRunning = false
	
	self.length = 0
	self.clip   = false
	self.clipMode = 'clip'
	self.mode = false

	self.defaultMode = false
	
	self.startPos = 0
	self.endPos   = 0

	self.duration = 0

	self.vars = {}
	self.fixedMode = false

	self.elapsedTimer = MOAITimer.new()
	self.elapsedTimer:setMode( MOAITimer.CONTINUE )
	self.elapsedTimer:attach( self.anim )
	self.elapsedTimer:setListener(
		MOAIAnim.EVENT_TIMER_END_SPAN, 
		function()
			return self:stop()
		end
	)

	self.onVarChanged = false
	self.roughness = false

	--lift method
	self.onUpdate = self.onUpdate
	self.isBusy = self.isBusy
	self.apply = self.apply

	self._updating = false

end

function AnimatorState:setRoughness( r )
	self.roughness = r
end

function AnimatorState:getClipName()
	if not self.clip then return nil end
	return self.clip:getName()
end

function AnimatorState:getClipLength()
	return self.clipLength
end

function AnimatorState:__tostring()
	return string.format( '%s(%s)', self:__repr(), self:getClipName() or '<nil>' )
end

function AnimatorState:getMoaiAction()
	return self.anim
end
---
function AnimatorState:isActive()
	if not self.anim then return false end --cleared
	return self.anim:isActive()
end

function AnimatorState:setParentThrottle( t )
	self.parentThrottle = t or 1
	return self:updateThrottle()
end

function AnimatorState:setThrottle( t )
	self.throttle = t or 1
	return self:updateThrottle()
end

function AnimatorState:getThrottle()
	return self.throttle
end

function AnimatorState:setClipSpeed( speed )
	self.clipSpeed = speed
	return self:updateThrottle()
end

function AnimatorState:updateThrottle()
	local t = self.throttle * self.clipSpeed * self.parentThrottle
	self.actualThrottle = t
	self.anim:throttle( t )
	return self.elapsedTimer:throttle( 1 / t )
end

function AnimatorState:resetRange()
	self:setRange( 0, self.length )
end

function AnimatorState:setRange( startPos, endPos )
	local p0, p1
	
	if not startPos then --current time
		p0 = self:getTime()
	else
		p0 = self:affirmPos( startPos )
	end
	
	if not endPos then --end time
		p1 = self.clipLength
	else
		p1 = self:affirmPos( endPos )
	end

	self.startPos = p0
	self.endPos   = p1
	self.anim:setSpan( p0, p1 )
	
end

function AnimatorState:affirmInRange()
	local current = self:getTime()
	--confine current time
	local p0, p1 = self.startPos, self.endPos
	local p = math.clamp( current, p0, p1 )
	-- print( 'range:', current, p, p0, p1 )
	return self:seek( p )
end

function AnimatorState:getRange()
	return self.startPos, self.endPos
end

function AnimatorState:setDuration( duration )
	self.duration = duration or 0
	self:updateDuration()
end

function AnimatorState:getDuration()
	return self.duration
end

function AnimatorState:setFixedMode( mode )
	self.fixedMode = true
	self.mode = mode
	self.anim:setMode( mode or self.defaultMode or MOAITimer.NORMAL )
end

function AnimatorState:setMode( mode )
	if self.fixedMode then return end
	self.mode = mode
	self.anim:setMode( mode or self.defaultMode or MOAITimer.NORMAL )
end

function AnimatorState:getMode()
	return self.mode
end 	

function AnimatorState:play( mode )
	if mode then
		self:setMode( mode )
	end
	return self:start()
end

function AnimatorState:playRange( startPos, endPos, mode )
	self:setRange( startPos, endPos )
	return self:resetAndPlay( mode )
end

function AnimatorState:playUntil( endPos )
	self:setRange( nil, endPos )
	return self:start()
end

function AnimatorState:seek( pos )
	local t = self:affirmPos( pos )
	return self:apply( t )
end

function AnimatorState:start()
	self.anim:start()
	local p0, p1 = self:getRange()
	self:apply( p0 )
	self.anim:pause( false )
	if self.animator then
		self.animator:onStateStart( self )
	end
	return self.anim
end

function AnimatorState:isAutostop()
	return self.autostop
end

function AnimatorState:setAutostop( s )
	self.autostop = s~=false
end

function AnimatorState:tryAutoStop( anim )
	if not self.autostop then return end
	if _isFinite( self.mode ) then
		local seq = self.seq
		_onAnimUpdate( anim )
		if self.seq == seq then --current state is not reused during last update
			return self:stop()
		end
	end
end

function AnimatorState:stop()
	if not self.anim then return end --cleared
	if self.stopping then return end
	self.stopping = true
	self.anim:stop()
	self.elapsedTimer:stop()
	if self.animator then
		self.animator:onStateStop( self )
	end
end

function AnimatorState:reset()
	self.seq = self.seq + 1
	self:resetContext()
	self.elapsedTimer:setTime( 0 )
	self.elapsedTimer:attach( self.anim )
	self:seek( 0 )
end

function AnimatorState:clear()
	local anim = self.anim
	anim:clear()
	anim.source = false
	anim:setListener( MOAIAnim.EVENT_TIMER_KEYFRAME, nil )
	anim:setListener( MOAIAnim.EVENT_NODE_POST_UPDATE, nil )
	anim:setListener( MOAIAnim.EVENT_TIMER_END_SPAN, nil )
	self:clearContext()
	self.anim = false
	-- insert( animPool, anim )
end

function AnimatorState:resetAndPlay( mode )
	self:reset()
	return self:play( mode )
end

function AnimatorState:isPaused()
	return self.anim:isPaused()
end 

function AnimatorState:isBusy()
	if not self.anim then return false end --cleared
	return MOAIActionIsBusy( self.anim )
end 

function AnimatorState:isDone()
	if not self.anim then return false end --cleared
	return MOAIActionIsDone( self.anim )
end 

function AnimatorState:pause( paused )
	if not self.anim then return false end --cleared
	self.anim:pause( paused )
end

function AnimatorState:resume()
	if not self.anim then return false end --cleared
	local anim = self.anim
	self:affirmInRange()
	if not MOAIActionIsBusy( anim ) then
		anim:start()
	end
	anim:pause( false )
end

function AnimatorState:isPreviewing()
	return self.previewing
end

function AnimatorState:isPlaying()
	return  ( self.anim and self.anim:isBusy() ) or self.previewRunning
end

function AnimatorState:getTime()
	return MOAITimerGetTime( self.anim )
end

function AnimatorState:getElapsed()
	return MOAITimerGetTime( self.elapsedTimer )
end

function AnimatorState:apply( t, flush )
	local anim = self.anim
	local t0 = MOAITimerGetTime( anim )
	anim:apply( t0, t )
	anim:setTime( t )
	if flush ~= false then
		return anim:flushUpdate()
	end
end


function AnimatorState:findMarker( id )
	return self.clip:findMarker( id )
end

function AnimatorState:affirmPos( pos )
	local tt = type( pos )
	if tt == 'string' then
		local posName = pos
		local marker = self:findMarker( posName )
		pos = marker and marker:getPos()
		if not pos then
			_warn( 'no marker found', posName, self, self:getAnimator() )
			pos = 0
		end
	elseif tt == 'nil' then
		return 0
	end
	return clamp( pos, 0, self.clipLength )
end

--
local noise = noise
function AnimatorState:onUpdate( t, t0 )
	self._updating = true
	local roughness = self.roughness
	if roughness then
		t = t + noise( roughness )
	end

	local tracks = self.updateListenerTracks
	-- for i = 1, self.updateListenerTracksCount do		
	for i = 1, #tracks do
		if self.stopping then break end --edge case: new clip started in apply
		local entry = tracks[ i ]
		local track   = entry[1]
		local context = entry[2]
		local apply = entry[3]
		apply( track, self, context, t, t0 )
	end
	self._updating = false
end

function AnimatorState:resetContext()
	for i, entry in ipairs( self.updateListenerTracks ) do
		local track = entry[1]
		local context = entry[2]
		track:reset( self, context )
	end
end

function AnimatorState:clearContext()
	for i, entry in ipairs( self.updateListenerTracks ) do
		local track = entry[1]
		local context = entry[2]
		track:clear( self, context )
	end
end

function AnimatorState:getAnimator()
	return self.animator
end

function AnimatorState:loadClip( animator, clip )
	self.animator    = animator
	self.targetRoot  = animator._entity
	self.targetScene = self.targetRoot.scene

	local context = clip:getBuiltContext()
	self.clip        = clip
	self.clipLength  = context.length
	self.defaultMode = clip.defaultMode
	self.startPos    = 0
	self.endPos      = self.clipLength

	local anim = self.anim
	
	local previewing = self.previewing
	for track in pairs( context.playableTracks ) do
		if track:isLoadable( self ) then
			if ( not previewing ) or track:isPreviewable() then
				track:onStateLoad( self )
			end
		end
	end

	anim:reserveLinks( self.attrLinkCount )
	for i, linkInfo in ipairs( self.attrLinks ) do
		local track, curve, target, attrId, asDelta  = unpack( linkInfo )
		if target then
			if ( not previewing ) or track:isPreviewable() then
				anim:setLink( i, curve, target, attrId, asDelta )
			end
		end
	end

	--event key
	anim:setCurve( context.eventCurve )
	self.keyEventMap = context.keyEventMap
	
	--range init
	anim:setSpan( self.clipLength )
	self.elapsedTimer:setTime( 0 )
	self:updateDuration()

	anim:flushUpdate()
	anim:setListener( MOAIAnim.EVENT_TIMER_KEYFRAME, _onAnimKeyFrame )
	anim:setListener( MOAIAnim.EVENT_NODE_POST_UPDATE, _onAnimUpdate )
	anim:setListener( MOAIAnim.EVENT_TIMER_END_SPAN, _onAnimStop )
		
	--sort update listeners
	table.sort(
		self.updateListenerTracks, 
		function(lhs, rhs)
			local t1 = lhs[1]
			local t2 = rhs[1]
			return t1:getPriority() < t2:getPriority()
		end
	)

	self.updateListenerTracksCount = #self.updateListenerTracks
end

function AnimatorState:updateDuration()
	local duration = self.duration
	if duration > 0 then
		self.elapsedTimer:setSpan( duration )
		self.elapsedTimer:pause( false )
	else
		self.elapsedTimer:setSpan( 0 )
		self.elapsedTimer:pause( true )
	end
end

function AnimatorState:addUpdateListenerTrack( track, context )
	local apply = track.apply
	table.insert( self.updateListenerTracks, { track, context, apply } )
end

function AnimatorState:addAttrLink( track, curve, target, id, asDelta )
	self.attrLinkCount = self.attrLinkCount + 1
	self.attrLinks[ self.attrLinkCount ] = { track, curve, target, id, asDelta or false }
end

function AnimatorState:findTarget( targetPath )
	local obj = targetPath:get( self.targetRoot, self.targetScene )
	return obj
end

function AnimatorState:getTargetRoot()
	return self.targetRoot, self.targetScene
end

function AnimatorState:setTrackTarget( track, target )
	self.trackTargets[ track ] = target
end

function AnimatorState:getTrackTarget( track )
	return self.trackTargets[ track ]
end

function AnimatorState:setListener( evId, func )
	self.anim:setListener( evId, func )
end

function AnimatorState:onPreviewStart()
	for i, entry in ipairs( self.updateListenerTracks ) do
		local track = entry[1]
		local context = entry[2]
		track:onPreviewStart( self, context )
	end
end

function AnimatorState:onPreviewStop()
	for i, entry in ipairs( self.updateListenerTracks ) do
		local track = entry[1]
		local context = entry[2]
		track:onPreviewStop( self, context )
	end
end
