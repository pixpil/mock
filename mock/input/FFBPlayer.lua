module 'mock'
--------------------------------------------------------------------
CLASS: FFBEventType ()

function FFBEventType:__init()
	self.attenuationMin = 0
	self.attenuationMax = 200
	self.strengthMin = 0
	self.strengthMax = 1
end

function FFBEventType:getLength()
	return 0
end

function FFBEventType:onInit( instance, option )
end

function FFBEventType:onUpdate( instance, elapsed )
end

function FFBEventType:onStart( instance )
end

function FFBEventType:onStop( instance )
end

--------------------------------------------------------------------
local _FFBPlayer
--------------------------------------------------------------------
CLASS: FFBEventInstance ()
	:MODEL{}

function FFBEventInstance:__init( eventType, targetGroup, option, looping )
	self.targetGroup = targetGroup
	self.eventType = eventType
	self.playing = true
	self.elapsed = false
	self.vibA = 0 
	self.vibB = 0
	self.strength = 1
	self.volume = 1
	self.looping = looping or false
	self.loopDuration = false
	eventType:onInit( self, option )
end

function FFBEventInstance:getId()
	local t = self.eventType
	return t and t.__eventId or false
end

function FFBEventInstance:setLooping( looping )
	self.looping = looping ~= false
end

function FFBEventInstance:setLoopDuration( d )
	self.loopDuration = d or false
end

function FFBEventInstance:getStrength()
	return self.strength
end

function FFBEventInstance:setStrength( s )
	self.strength = math.clamp( s, 0, 1 )
end

function FFBEventInstance:setVolume( s )
	self.volume = s or 1
end

function FFBEventInstance:getVolume()
	return self.volume
end

function FFBEventInstance:stop()
	self.playing = false
end

function FFBEventInstance:sendData( a, b )
	if a then self.vibA = a end
	if b then self.vibB = b end
end

function FFBEventInstance:onUpdate( dt )
	local eventType = self.eventType
	local elapsed = self.elapsed
	if not elapsed then
		eventType:onStart( self )
		elapsed = 0
	else
		elapsed = elapsed + dt
	end
	if self.looping then
		if self.loopDuration then
			self.loopDuration = self.loopDuration - dt
			if self.loopDuration <= 0 then
				return false
			end
		end
		
		local l = eventType:getLength()
		if l > 0 then
			while elapsed >= l do
				elapsed = elapsed - l
			end
		end
	end
	self.elapsed = elapsed
	return eventType:onUpdate( self, elapsed )
end

--------------------------------------------------------------------
CLASS: FFBEventInstanceDynamic ( FFBEventInstance )
	:MODEL{}

function FFBEventInstanceDynamic:__init()
	self.transform = MOAITransform.new()
	self.attenuationMin = false
	self.attenuationMax = false
end

function FFBEventInstanceDynamic:getLoc()
	return self.transform:getLoc()
end

function FFBEventInstanceDynamic:setLoc( x, y, z )
	self.transform:setLoc( x, y, z )
end

function FFBEventInstanceDynamic:getTransform()
	return self.transform
end

function FFBEventInstanceDynamic:linkTransform( transform )
	if transform then
		inheritLoc( self.transform, transform )
	else
		clearInheritLoc( self.transform )
	end
end

function FFBEventInstanceDynamic:setAttenuation( min, max )
	self.attenuationMin = min
	self.attenuationMax = max
end

local _dist = MOCKHelper.worldDistanceBetweenTransform
function FFBEventInstanceDynamic:onUpdate( dt )
	--update strength
	local attMin, attMax
	attMin = self.attenuationMin or self.eventType.attenuationMin
	attMax = self.attenuationMax or self.eventType.attenuationMax or attMin
	local strMin, strMax
	strMin = self.eventType.strengthMin or 0
	strMax = self.eventType.strengthMax or 1

	if not attMin or attMin < 0 then
		self.strength = 1
	else
		local distance = _dist( self.transform, _FFBPlayer.listenerTransform )
		self.strength = attenuation( distance, attMin, attMax, 2, strMin, strMax )
	end
	return FFBEventInstanceDynamic.__super.onUpdate( self, dt )
end

--------------------------------------------------------------------
CLASS: FFBPlayer ( GlobalManager )
	:MODEL{}

function FFBPlayer:__init()
	self.paused = false
	self.eventTypeClasses = {}
	self.eventTypes = {}
	self.instances = {}
	self.vibrationData = {}

	self.listenerTransform = MOAITransform.new()

	-- local controlNode = MOAIScriptNode.new() 
	-- self.controlNode = controlNode
	-- self.controlNode:reserveAttrs( 1 )
	-- self.controlNode:setAttr( 1, 1 ) --global scale
	self.globalScl = 1
end

function FFBPlayer:registerEventType( id, eventType )
	eventType.__eventId = id
	self.eventTypes[ id ] = eventType
end

function FFBPlayer:getScl()
	return self.globalScl
	-- return self.controlNode:getAttr( 1 )
end

function FFBPlayer:setScl( scl )
	self.globalScl = scl or 1
	-- self.controlNode:setAttr( 1, scl or 1 )
end

function FFBPlayer:pause( paused )
	self.paused = paused ~= false
end

function FFBPlayer:linkListenerTransform( transform )
	if transform then
		inheritLoc( self.listenerTransform, transform )
	else
		clearInheritLoc( self.listenerTransform )
	end
end


function FFBPlayer:playEvent( id, groupId, dynamic, option )
	--TODO
	-- _log( 'FFBEvent:', id , '@Group:', groupId )
	local eventType = self.eventTypes[ id ]
	if not eventType then
		_warn( 'no FFBEventType defined:', id )
		return false
	end
	local group = getFFBControllerGroup( groupId or '__root' )
	local instance
	if dynamic then
		instance = FFBEventInstanceDynamic( eventType, group, option )
	else
		instance = FFBEventInstance( eventType, group, option )
	end
	self.instances[ instance ] = true
	return instance
end

function FFBPlayer:loopEvent( id, groupId, dynamic, option )
	local instance = self:playEvent( id, groupId, dynamic, option )
	if instance then
		instance:setLooping( true )
	end
	return instance
end

local max, min = math.max, math.min
local testVibA, testVibB = 0, 0

local ambientVibA, ambientVibB = 0, 0
function FFBPlayer:onUpdate( game, dt )
	local allControllers = getRootFFBControllerGroup():affirmControllerCache()
	if self.paused then
		for controller in pairs( allControllers ) do
			controller:setVibration( 0, 0 )
		end
		return
	end
	local toremove = false
	local instances = self.instances
	
	local totalVibA = {}
	local totalVibB = {}
	local maxVibA = {}
	local maxVibB = {}

	local count = 0
	ambientVibA = ambientVibA * 0.5
	ambientVibB = ambientVibB * 0.5
	for instance in pairs( instances ) do
		if not instance.playing then --toremove
			if not toremove then
				toremove = {}
			end
			toremove[ instance ] = true
		else
			local result = instance:onUpdate( dt )
			if result == false then
				instance:stop()
			else
				count = count + 1
				local str = instance.strength * instance.volume
				local group = instance.targetGroup
				local va = instance.vibA * str
				local vb = instance.vibB * str
				for controller in pairs( group:affirmControllerCache() ) do
					totalVibA[ controller ] = ( totalVibA[ controller ] or 0 ) + va
					totalVibB[ controller ] = ( totalVibB[ controller ] or 0 ) + vb
					maxVibA[ controller ] = max( maxVibA[ controller ] or 0, va )
					maxVibB[ controller ] = max( maxVibB[ controller ] or 0, vb )
				end
			end
		end
	end
	if toremove then
		for instance in pairs( toremove ) do
			instance.eventType:onStop( instance )
			instances[ instance ] = nil
		end
	end

	local scl = self.globalScl
	--flush
	for controller in pairs( allControllers ) do
		local vibA = totalVibA[ controller ] or 0
		local vibB = totalVibB[ controller ] or 0
		local maxVibA = maxVibA[ controller ] or vibA
		local maxVibB = maxVibB[ controller ] or vibB
		controller:setVibration( 
			scl * ( min( vibA, maxVibA * 1.2 ) + ambientVibA + testVibA ), 
			scl * ( min( vibB, maxVibB * 1.2 ) + ambientVibB + testVibB )
		)
	end

end

function FFBPlayer:findEventInstance( id )
	for instance in pairs( self.instances ) do
		if instance:getId() == id then return instance end
	end
	return nil
end

function FFBPlayer:findAndStopEvent( id )
	for instance in pairs( self.instances ) do
		if instance:getId() == id then 
			instance:stop()
		end
	end
end

function FFBPlayer:stopAllEvents( groupId )
	if not groupId then
		for instance in pairs( self.instances ) do
			instance.eventType:onStop( instance )
		end
		self.instances = {}
		local allControllers = getRootFFBControllerGroup():affirmControllerCache()
		for controller in pairs( allControllers ) do
			controller:setVibration( 0, 0 )
		end

	end

	--TODO
	-- _log( 'stop FFBEvents', groupId or '__root' )
end


_FFBPlayer = FFBPlayer()
--------------------------------------------------------------------
function getFFBPlayer()
	return _FFBPlayer
end

function playDynamicFFBEvent( id, group, option  )
	return _FFBPlayer:playEvent( id, group, true, option )
end

function playStaticFFBEvent( id, group, option )
	return _FFBPlayer:playEvent( id, group, false, option )
end

function loopDynamicFFBEvent( id, group, option  )
	return _FFBPlayer:loopEvent( id, group, true, option )
end

function loopStaticFFBEventTimed( id, duration )
	local instance = _FFBPlayer:loopEvent( id, nil, false, nil )
	if instance then
		instance:setLoopDuration( duration or 5 )
	end
	return instance
end

function loopStaticFFBEvent( id, group, option )
	return _FFBPlayer:loopEvent( id, group, false, option )
end

function stopAllFFBEvents( group )
	return _FFBPlayer:stopAllEvents( group )
end

function _sendVibEvent( a, b ) --for remote vibration test
	testVibA = a
	testVibB = b
	-- print( 'vib', a, b )
end
