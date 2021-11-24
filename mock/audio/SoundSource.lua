module 'mock'
--------------------------------------------------------------------
--SOUND SOURCE
--------------------------------------------------------------------
CLASS: SoundSource ( Component )
	:MODEL{
		Field 'defaultEvent' :asset( getSupportedSoundAssetTypes() )  :getset('DefaultEvent');
		Field 'autoPlay'    :boolean();
		'----';
		Field 'singleInstance' :boolean();
		Field 'initialVolume' :number();
		'----';
		Field 'is3D' :boolean();
		Field 'following' :boolean();
		Field 'minDistance' :getset( 'MinDistance' );
		Field 'maxDistance' :getset( 'MaxDistance' );
	}

	:META{
		category = 'audio'
	}


function SoundSource:__init()
	self.eventInstances = {}
	self.eventNamePrefix = false
	self.autoPlay = true
	self.loopSound = true
	self.defaultEventPath = false
	self.singleInstance = false
	self.initialVolume = -1
	self.is3D = true
	self.following = false
	self.minDistance = -1
	self.maxDistance = -1
	self._defaultInstance = false
end

function SoundSource:onAttach( entity )
end

function SoundSource:onDetach( entity )
	self:stop()
	self.eventInstances = nil
end

function SoundSource:setDefaultEvent( path )
	self.defaultEventPath = path
	local scene = self:getScene()
	if not ( scene and scene:isRunning() ) then return end
	if self.autoPlay then --already playing
		self:start()
	end
end

function SoundSource:getDefaultEvent()
	return self.defaultEventPath
end

function SoundSource:onStart()
	if self.autoPlay then self:start() end	
end

function SoundSource:setEventPrefix( prefix )
	self.eventNamePrefix = prefix or false
end

function SoundSource:start()
	if self._defaultInstance then
		self._defaultInstance:stop()
		self._defaultInstance = false
	end
	if self.defaultEventPath then
		if self.is3D then
			self._defaultInstance = self:playEvent3D( self.defaultEventPath )
			return self._defaultInstance
		else
			self._defaultInstance = self:playEvent2D( self.defaultEventPath )
			return self._defaultInstance
		end
	end
end

function SoundSource:playOrResume()
	if self._defaultInstance and self._defaultInstance:isValid() then
		return self:pause( false )
	else
		return self:play()
	end
end

function SoundSource:pause( paused )
	if self._defaultInstance and self._defaultInstance:isValid() then
		return self._defaultInstance:pause( paused ~= false )
	end
end

function SoundSource:play()
	return self:start()
end

function SoundSource:stop( allowFadeOut )
	allowFadeOut = allowFadeOut ~= false
	for instance, k in pairs( self.eventInstances ) do
		instance:stop( allowFadeOut )
	end
	self.eventInstances = {}
end

function SoundSource:setVolume( v )
	v = v or 1
	for instance in pairs( self.eventInstances ) do
		instance:setVolume( v )
	end
end

--------------------------------------------------------------------
function SoundSource:_addInstance( instance )
	if not self.eventInstances then  return end
	local mgr = AudioManager.get()
	if self.singleInstance then
		self:stop()
	end
	self:clearStoppedInstances()
	self.eventInstances[ instance ] = true
	if self.initialVolume >= 0 then
		instance:setVolume( self.initialVolume )
	end
	local d0, d1 = self.minDistance, self.maxDistance
	local u2m = mgr:getUnitToMeters()
	if d0 >= 0 then
		mgr:setEventInstanceSetting( instance, 'min_distance', d0 * u2m )
	end
	if d1 >= 0 then
		mgr:setEventInstanceSetting( instance, 'max_distance', d1 * u2m )
	end
	
	return instance
end

function SoundSource:_playEvent3DAt( event, x,y,z, follow, followTarget )
	local instance	
	instance = AudioManager.get():playEvent3D( event, x,y,z )

	if instance then
		if follow then
			followTarget = followTarget or self._entity
			inheritTransform( instance, followTarget:getProp( 'physics' ) )
			instance:setLoc( 0,0,0 )
			instance:forceUpdate()
		end
		return self:_addInstance( instance )
	else
		_error( 'sound event not found:', event )
		return false
	end
end

function SoundSource:_playEvent2D( event, looped )
	local instance = AudioManager.get():playEvent2D( event, looped )
	if instance then
		return self:_addInstance( instance, false )
	else
		_error( 'sound event not found:', event )
		return false
	end
end

--------------------------------------------------------------------
function SoundSource:playEvent3DFor( target, event, follow )
	local x,y,z
	target:forceUpdate()
	local prop = target:getProp( 'physics' )
	x,y,z = prop:getWorldLoc()
	return self:_playEvent3DAt( event, x,y,z, follow, target )
end

function SoundSource:playEvent3DAt( event, x,y,z )
	return self:_playEvent3DAt( event, x,y,z, false )
end

function SoundSource:playEvent3D( event, follow )
	if follow == nil then follow = self.following end
	return self:playEvent3DFor( self._entity, event, follow )
end

function SoundSource:playEvent2D( event )
	return self:_playEvent2D( event, nil )
end

function SoundSource:playEvent( event )
	if self.is3D then
		return self:playEvent3D( event )
	else
		return self:playEvent2D( event )
	end
end

function SoundSource:loopEvent3DAt( event, x,y,z, follow )
	return self:_playEvent3DAt( event, x,y,z, follow, true )
end

function SoundSource:loopEvent3D( event, follow )
	local x,y,z
	x,y,z = self._entity:getWorldLoc()
	return self:loopEvent3DAt( event, x,y,z, follow )
end

function SoundSource:loopEvent2D( event )
	return self:_playEvent2D( event, true )
end

--------------------------------------------------------------------
function SoundSource:isBusy()
	self:clearStoppedInstances()
	return next(self.eventInstances) ~= nil
end
	
function SoundSource:clearStoppedInstances()
	if not self.eventInstances then return end
	local t1 = {}
	for instance, k in pairs( self.eventInstances ) do
		if instance:isValid() then
			t1[ instance ] = k
		end
	end
	self.eventInstances = t1
end

function SoundSource:pauseInstances( paused )
	if not self.eventInstances then return end
	for instance in pairs( self.eventInstances ) do
		instance:pause( paused ~= false )
	end
end

function SoundSource:resumeInstances()
	if not self.eventInstances then return end
	for instance in pairs( self.eventInstances ) do
		instance:pause( false )
	end
end

function SoundSource:getMinDistance()
	return self.minDistance
end

function SoundSource:getMaxDistance()
	return self.maxDistance
end

function SoundSource:setMinDistance( d )
	self.minDistance = d
	if self._entity then self:updateDistance() end
end

function SoundSource:setMaxDistance( d )
	self.maxDistance = d
	if self._entity then self:updateDistance() end
end

function SoundSource:updateDistance()
	local d0, d1 = self.minDistance, self.maxDistance
	local mgr = AudioManager.get()
	local u2m = mgr:getUnitToMeters()
	for instance in pairs( self.eventInstances ) do
		if d0 >= 0 then
			mgr:setEventInstanceSetting( instance, 'min_distance', d0 * u2m )
		end
		if d1 >= 0 then
			mgr:setEventInstanceSetting( instance, 'max_distance', d1 * u2m )
		end
	end
end

function SoundSource:getDefaultEventSetting( key )
	local ev = self.defaultEventPath
	if not ev then return nil end
	return AudioManager.get():getEventSetting( ev, key )
end

function SoundSource:getDefaultEventDistanceSetting()
	if not self.defaultEventPath then return nil end
	local d0, d1 = self.minDistance, self.maxDistance
	local mgr = AudioManager.get()
	local u2m = mgr:getUnitToMeters()
	if d0 < 0 then
		d0 = ( self:getDefaultEventSetting( 'min_distance' ) or 0 ) / u2m
	end
	if d1 < 0  then
		d1 = ( self:getDefaultEventSetting( 'max_distance' ) or 0 ) / u2m
	end
	return d0, d1
end
--------------------------------------------------------------------
function SoundSource:onDrawGizmo( selected )
	if not self.defaultEventPath then return end
	local mgr = AudioManager.get()
	GIIHelper.setVertexTransform( self._entity:getProp( 'render' ) )
	local d0, d1 = self:getDefaultEventDistanceSetting()
	mock_edit.applyColor( 'range-min' )
	MOAIDraw.drawCircle( 0, 0, d0 )
	mock_edit.applyColor( 'range-max' )
	MOAIDraw.drawCircle( 0, 0, d1 )
end

--------------------------------------------------------------------
function SoundSource:onBuildGizmo()
	local icon = mock_edit.IconGizmo( 'sound.png' )
	local draw = mock_edit.DrawScriptGizmo()
	return icon, draw
end


registerComponent( 'SoundSource', SoundSource )
--------------------------------------------------------------------
