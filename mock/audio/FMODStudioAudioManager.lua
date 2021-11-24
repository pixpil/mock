module 'mock'
if not MOAIFMODStudioMgr then return end

local _mgr = false

--------------------------------------------------------------------
injectMoaiClass( MOAIFMODStudioEventInstance, {
	isValid = function( self )
		return self:getPlaybackState() ~= MOAIFMODStudioEventInstance.PLAYBACK_STOPPED
	end
} )

--------------------------------------------------------------------

local function createFMODStudioSystem()
	if not MOAIFMODStudioMgr then return end
	_stat('init FMODStudio')
	
	local option = {
		['MaxChannelCount']            = nil;
		['SoundMemoryMB']              = nil;
		['RsxMemoryMB']                = nil;
		['VoiceLRUMaxMB']              = nil;
		['VoiceLRUBufferMB']           = nil;
		['RealChannelCount']           = nil;
		['PCMCodecCount']              = nil;
		['ADPCMCodecCount']            = nil;
		['CompressedCodecCount']       = nil;
		['MaxInputChannelCount']       = nil;
		['DSPBufferSize']              = nil;
		['DSPBufferCount']             = nil;
		['SoundSystemEnabled']         = nil;
		['DistantLowpassEnabled']      = nil;
		['EnvironmentalReverbEnabled'] = nil;
		['Near2DBlendEnabled']         = nil;
		['AuditioningEnabled']         = nil;
		['ProfilingEnabled']           = true;
		['ProfilingPort']              = nil;
		['FsCallbacksEnabled']         = nil;
		['SoundDisabled']              = nil;
		['DopplerScale']               = nil;
	}

	if game:isEditorMode() then
		option[ 'ProfilingEnabled' ] = false
	end
	if MOAIEnvironment.connectionType == MOAIEnvironment.CONNECTION_TYPE_NONE then
		option[ 'ProfilingEnabled' ] = false
	end
	if mock.__nodebug then
		option[ 'ProfilingEnabled' ] = false
	end

	local system = MOAIFMODStudioMgr.createSystem( option )
	if not system then
		_error('FMODStudio not initialized...')
		return false
	else
		_stat('FMODStudio ready...')
		return system
	end

end


local event2IDCache = table.weak_k()

local function _affirmFmodEvent( event )
	if not event then return nil end
	local id = event2IDCache[ event ]
	if id ~= nil then return id end
	if type( event ) == 'string' then
		event, node = tryLoadAsset( event ) 
		if event then
			id = event:getSystemID()
		else
			return nil
		end
	else
		id = event:getSystemID()
	end
	event2IDCache[ event ] = id or false
	return id
end

--------------------------------------------------------------------
CLASS: FMODStudioAudioManager ( AudioManager )
	:MODEL{}

function FMODStudioAudioManager:__init()
	self.system = false
	if getG( 'socket' ) then
		self.comm = FMODStudioCommunicationHelper()
	else
		self.comm = false
	end
	self.unitsToMeters = 1
	self.listeners = {}
	_mgr = self
end

function FMODStudioAudioManager:init( option )
	local system = createFMODStudioSystem()
	if not system then return false end
	self.system = system
	
	--apply options
	local u2m = option[ 'unitsToMeters' ] or 1
	self.unitsToMeters = u2m
	self.system:setUnitsToMeters( u2m )

	self.default3DSpread = option[ '3DSpread' ] or 360
	self.default3DLevel  = option[ '3DLevel' ] or 1

	self:initListeners()
	self:clearCaches()

	return true
end

function FMODStudioAudioManager:initListeners()
	local count = 4
	local system = self.system
	system:setNumListeners( count )
	for i = 1, count do
		local l = system:getListener( i )
		self.listeners[ i ] = l
		l:setWeight( 0 )
	end
end

function FMODStudioAudioManager:stop()
	
end

function FMODStudioAudioManager:getUnitToMeters()
	return self.unitsToMeters
end

function FMODStudioAudioManager:getSystem()
	return self.system
end

function FMODStudioAudioManager:forceUpdate()
	if self.system then
		self.system:flushCommands()
	end
end


function FMODStudioAudioManager:clearCaches()
	self.cacheVCA = {}
	self.cacheBus = {}
	self.cacheSnapshot = {}
	self.cacheEventDescription = {}
end

function FMODStudioAudioManager:getListener( idx )
	return self.listeners[ idx or 1 ]
end

function FMODStudioAudioManager:getEventById( id )
	local ed = self.cacheEventDescription[ id ]
	if ed == nil then
		ed = self.system:getEventByID( id ) or false
		self.cacheEventDescription[ id ] = ed
	end
	return ed
end

function FMODStudioAudioManager:getBus( path )
	if path == 'master' then path = '' end
	local bus = self.cacheBus[ path ]
	if bus == nil then
		local fullpath = 'bus:/' .. path
		bus = self.system:getBus( fullpath ) or false
		self.cacheBus[ path ] = bus
	end
	return bus
end


function FMODStudioAudioManager:getVCA( path )
	if path == 'master' then path = '' end
	local vca = self.cacheVCA[ path ]
	if vca == nil then
		local fullpath = 'vca:/' .. path
		vca = self.system:getVCA( fullpath ) or false
		self.cacheVCA[ path ] = vca
	end
	return vca
end

function FMODStudioAudioManager:setVCAFaderLevel( name, level )
	local vca = self:getVCA( name )
	if not vca then 
		_warn( 'vca not found', name )
		return false
	end
	vca:setFaderLevel( level ) 
	return true
end

function FMODStudioAudioManager:setBusFaderLevel( name, level )
	local bus = self:getBus( name )
	if not bus then return false end
	bus:setFaderLevel( level )
	return true
end

function FMODStudioAudioManager:getVCAFaderLevel( name, level )
	local vca = self:getVCA( name )
	if not vca then return false end
	return vca:getFaderLevel( level ) 
end

function FMODStudioAudioManager:getBusFaderLevel( name, level )
	local bus = self:getBus( name )
	if not bus then return false end
	return bus:getFaderLevel( level )
end

function FMODStudioAudioManager:getCategoryVolume( category )
	if category == 'master' then
		if self.system.getMasterVolume then
			return self.system:getMasterVolume( 1 )
		end
	end
	local bus = self:getBus( category )
	if not bus then return false end
	return bus:getFaderLevel()
end

function FMODStudioAudioManager:setCategoryVolume( category, volume )
	if category == 'master' then
		if self.system.setMasterVolume then
			return self.system:setMasterVolume( volume )
		end
	end
	local bus = self:getBus( category )
	if not bus then 
		_warn( 'audio bus not found', category )
		return false
	end
	return bus:setFaderLevel( volume or 1 )
end

function FMODStudioAudioManager:seekCategoryVolume( category, v, delta, easeType )
	category = category or 'master'
	delta = delta or 0
	if delta <= 0 then return self:setCategoryVolume( category, v ) end
	local bus = self:getBus( category )
	if not bus then return nil end

	local v0 = bus:getFaderLevel()
	v = clamp( v, 0, 1 )
	easeType = easeType or MOAIEaseType.EASE_OUT
	local tmpNode = MOAIScriptNode.new()
	tmpNode:reserveAttrs( 1 )
	tmpNode:setCallback( function( node )
		local value = node:getAttr( 1 )
		return bus:setFaderLevel( value )
	end )
	tmpNode:setAttr( 1, v0 )
	return tmpNode:seekAttr( 1, v, delta, easeType )
end

function FMODStudioAudioManager:moveCategoryVolume( category, dv, delta, easeType )
	category = category or 'master'
	local v0 = self:getCategoryVolume( category )
	if not v0 then return nil end
	return self:seekCategoryVolume( category, v0 + dv, delta, easeType )
end

function FMODStudioAudioManager:pauseCategory( category, paused )
	local bus = self:getBus( category )
	if bus then 
		bus:setPaused( paused ~= false )
	else
		_warn( 'no audio bus found', category )
	end
end

function FMODStudioAudioManager:setCategoryMuted( category, muted )
	local bus = self:getBus( category )
	if bus then
		bus:setMute( muted ~= false )
	else
		_warn( 'no audio bus found', category )
	end
end

function FMODStudioAudioManager:isCategoryMuted( category )
	local bus = self:getBus( category )
	if not bus then return nil end
	return bus:isMute()
end

function FMODStudioAudioManager:isCategoryPaused( category )
	local bus = self:getBus( category )
	if not bus then return nil end
	return bus:isPaused()
end

function FMODStudioAudioManager:getEventDescription( eventPath )
	local eventId = _affirmFmodEvent( eventPath )
	if not eventId then
		-- _warn( 'no audio event found', eventPath )
		return false
	end
	local eventDescription = self:getEventById( eventId )
	if not eventDescription then
		-- _warn( 'no event found', eventId )
		return false
	end
	return eventDescription
end

local EVENT_CREATE = MOAIFMODStudioEventInstance.EVENT_CREATE
local function _CallbackOnCreate3DEvent( this )
	-- this:set3DLevel( _mgr.default3DLevel )
end

local function _CallbackOnCreate2DEvent( this )
end

function FMODStudioAudioManager:createEventInstance( eventPath )
	local eventDescription = self:getEventDescription( eventPath )
	if not eventDescription then return false end
	local instance = eventDescription:createInstance()
	instance:setLoc( 0,0,0 )
	-- if eventDescription:is3D() then
	-- 	instance:setListener( EVENT_CREATE, _CallbackOnCreate3DEvent )
	-- else
	-- 	instance:setListener( EVENT_CREATE, _CallbackOnCreate2DEvent )
	-- end
	return instance, eventDescription
end

function FMODStudioAudioManager:playEvent3D( eventPath, x, y, z )
	local instance, ed = self:createEventInstance( eventPath )
	if not instance then return false end
	instance:start()
	instance:setLoc( x, y, z )
	local id = ed:getID() 
	if self.prevId ~= id then
		self.prevId = id
		self:logEvent( ed:getPath(), { id = id } )
	end
	return instance
end

function FMODStudioAudioManager:playEvent2D( eventPath )
	local instance, ed = self:createEventInstance( eventPath )
	if not instance then return false end
	instance:start()
	local id = ed:getID() 
	if self.prevId ~= id then
		self.prevId = id
		self:logEvent( ed:getPath(), { id = id } )
	end
	return instance
end

function FMODStudioAudioManager:isEventInstancePlaying( sound )
	return sound:getPlaybackState() ~= MOAIFMODStudioEventInstance.PLAYBACK_STOPPED
end

function FMODStudioAudioManager:triggerEventInstanceCue( eventInstance )
	return eventInstance:triggerCue()
end

local FMODStudioEventSettingNames = {
	[ 'min_distance' ] = MOAIFMODStudioEventInstance.PROPERTY_MINIMUM_DISTANCE,
	[ 'max_distance' ] = MOAIFMODStudioEventInstance.PROPERTY_MAXIMUM_DISTANCE,
}

function FMODStudioAudioManager:getEventSetting( path, key )
	local ed = self:getEventDescription( path )
	if not ed then return nil end
	if key == 'min_distance' then
		return ed:getMinimumDistance()
	elseif key == 'max_distance' then
		return ed:getMaximumDistance()
	elseif key == 'length' then
		return ( ed:getLength() or 0 ) * 0.001 --to seconds
	else
		return nil
	end
end

function FMODStudioAudioManager:setEventSetting( path, key, value )
	--do nothing
	return	
end

function FMODStudioAudioManager:getEventInstanceSetting( eventInstance, key )
	local id
	if type( key ) == 'number' then
		id = key
	else
		id = FMODStudioEventSettingNames[ key ]
	end
	return id and eventInstance:getProperty( id )
end


function FMODStudioAudioManager:setEventInstanceSetting( eventInstance, key, value )
	local id
	if type( key ) == 'number' then
		id = key
	else
		id = FMODStudioEventSettingNames[ key ]
	end
	if not id then
		_warn( 'no valid event property', key )
	end
	return eventInstance:setProperty( id, value )
end


local function _getEventInstanceParameterID( eventInstance, key )
	local desc = eventInstance:getDescription()
	if not desc then return nil end
	local parameterIDCache = desc.parameterIDCache
	if not parameterIDCache then
		parameterIDCache = {}
		desc.parameterIDCache = parameterIDCache
	end
	local id = parameterIDCache[ key ]
	if id == false then 
		return false

	elseif id == nil then
		local data1, data2 = desc:getParameterID( key )
		if data1 then
			id = { data1, data2 }
		else
			parameterIDCache[ key ] = false
			return false
		end

	end
	parameterIDCache[ key ] = id
	return id[1], id[2]
end

function FMODStudioAudioManager:getEventInstanceTime( eventInstance )
	return ( eventInstance:getTimelinePosition() or 0 ) / 1000 --to sec
end

function FMODStudioAudioManager:setEventInstanceTime( eventInstance, time )
	return eventInstance:setTimelinePosition( ( time or 0 )*1000 ) --to ms
end

function FMODStudioAudioManager:getEventInstanceVolume( eventInstance )
	return eventInstance:getVolume()
end

function FMODStudioAudioManager:setEventInstanceVolume( eventInstance, volume )
	return eventInstance:setVolume( volume )
end

function FMODStudioAudioManager:getEventInstanceParameter( eventInstance, key )
	local id1, id2 = _getEventInstanceParameterID( eventInstance, key )
	if id1 then
		return eventInstance:getParameterByID( id1, id2 )
	else
		_warn( 'event parameter not found', key )
		return 0
	end
end

function FMODStudioAudioManager:setEventInstanceParameter( eventInstance, key, value, ignoreSeek )
	local id1, id2 = _getEventInstanceParameterID( eventInstance, key )
	if id1 then
		return eventInstance:setParameterByID( id1, id2, value, true )
	else
		_warn( 'event parameter not found', key )
	end
end

function FMODStudioAudioManager:sendEditCommand( cmd, data )
	if not self.comm then return end
	if cmd == 'locate' then
		local id = data.id
		return self.comm:sendf(
			"studio.window.navigateTo( studio.project.lookup(%q))",
			id
		)
	elseif cmd == 'get_project_path' then
		return self.comm:send(
			"studio.project.filePath"
			)

	elseif cmd == 'command' then
		local command = data.command
		return self.comm:send( command )
	end
end

--------------------------------------------------------------------
CLASS: FMODStudioCommunicationHelper()

function FMODStudioCommunicationHelper:__init()
	-- body
	self.host   = '127.0.0.1'
	self.port = 3663
	self.conn = false
end

function FMODStudioCommunicationHelper:getConnection()
	if not game:getPlatformSupport():getNetworkState() then return false end
	if not self.conn then
		local socket = require 'socket'
		self.conn = socket.connect( self.host, self.port )
		if not self.conn then return false end
		self.conn:settimeout( 0.1 )
		while self.conn:receive() do 
		end
		if self.conn then
			_log( 'connected to FmodStudio' )
		end
	end
	return self.conn
end


function FMODStudioCommunicationHelper:send( data )
	local conn = self:getConnection()
	if conn then
		conn:send( data )
		local result = {}
		while true do
			local l, e = conn:receive()
			if not l then break end
			local out = l:match( 'out%(%): (.*)')
			-- local log = l:match( 'log%(%): (.*)')
			if out then
				table.insert( result, out )
			end
		end
		return result
	end
end

function FMODStudioCommunicationHelper:sendf( pattern, ... )
	local data = string.format( pattern, ... )
	return self:send( data )
end


--------------------------------------------------------------------
_stat( 'using FMOD Studio audio manager' )
FMODStudioAudioManager()

 