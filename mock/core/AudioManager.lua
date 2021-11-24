module 'mock'

DefaultAudioOption = {
	unitsToMeters = 1.0,
}

--------------------------------------------------------------------
CLASS: AudioManager ()
	:MODEL{}

local _audioManagerSingleton = false
function AudioManager.get()
	return _audioManagerSingleton
end

function AudioManager:__init()
	assert( not _audioManagerSingleton, 'duplicated AudioManager registration' )
	_audioManagerSingleton = self	
	self.eventLogs = WrapList( 8 )
end

function AudioManager:init( option )
	initFmodDesigner()
end

function AudioManager:getListener()
	return nil
end

function AudioManager:getUnitToMeters()
	return 1
end

function AudioManager:stop()
end

function AudioManager:getMasterVolume()
	return self:getCategoryVolume( 'master' )
end

function AudioManager:setMasterVolume( v )
	return self:setCategoryVolume( 'master', v )
end

function AudioManager:seekMasterVolume( v, delta, easeType )
	return self:seekCategoryVolume( 'master', v, delta, easeType )
end

function AudioManager:moveMasterVolume( dv, delta, easeType )
	return self:moveCategoryVolume( 'master', dv, delta, easeType )
end

function AudioManager:getCategoryVolume( category )
	_error( 'need implementation' )
end

function AudioManager:setCategoryVolume( category, volume )
	_error( 'need implementation' )
end

function AudioManager:seekCategoryVolume( category, v, delta, easeType )
	_error( 'need implementation' )
end

function AudioManager:moveCategoryVolume( category, dv, delta, easeType )
	_error( 'need implementation' )
end

function AudioManager:pauseCategory( category, paused )
	_error( 'need implementation' )
end

function AudioManager:isCategoryPaused( category )
	_error( 'need implementation' )
end

function AudioManager:setCategoryMuted( category, muted )
	_error( 'need implementation' )
end

function AudioManager:isCategoryMuted( category )
	_error( 'need implementation' )
end

function AudioManager:playEvent3D( eventPath, x, y, z )
	_error( 'need implementation' )
end

--RETURN event instance
function AudioManager:playEvent2D( eventPath, looped )
	_error( 'need implementation' )
end

function AudioManager:logEvent( event, info )
	self.eventLogs:push( { event, info } )
end

function AudioManager:getLogs()
	return self.eventLogs
end

function AudioManager:clearLog()
	self.eventLogs:clear()
end


function AudioManager:isEventInstance( sound )
	_error( 'need implementation' )
end

function AudioManager:isEventInstancePlaying( sound )
	_error( 'need implementation' )
end

function AudioManager:setEventSetting( eventInstance, id, value )
	_error( 'need implementation' )
end

function AudioManager:getEventSetting( eventInstance, id )
	_error( 'need implementation' )
end

function AudioManager:setEventInstanceSetting( eventInstance, id, value )
	_error( 'need implementation' )
end

function AudioManager:getEventInstanceSetting( eventInstance, id )
	_error( 'need implementation' )
end

function AudioManager:triggerEventInstanceCue( eventInstance )
	_error( 'need implementation' )
end

function AudioManager:getEventInstanceTime( eventInstance )
	_error( 'need implementation' )
end

function AudioManager:setEventInstanceTime( eventInstance, time )
	_error( 'need implementation' )
end

function AudioManager:getEventInstanceVolume( eventInstance )
	_error( 'need implementation' )
end

function AudioManager:setEventInstanceVolume( eventInstance, volume )
	_error( 'need implementation' )
end


function AudioManager:setEventInstanceParameter( eventInstance, id, value )
	_error( 'need implementation' )
end

function AudioManager:getEventInstanceParameter( eventInstance, id )
	_error( 'need implementation' )
end

function AudioManager:forceUpdate()
	_error( 'need implementation' )
end

--------------------------------------------------------------------
function AudioManager:sendEditCommand( cmd, data )
	return false
end

--------------------------------------------------------------------
function getAudioManager()
	return AudioManager.get()
end

function setAudioEventInstanceParameter( instance, id, value )
	return _audioManagerSingleton:setEventInstanceParameter( instance, id, value )
end

function getAudioEventInstanceParameter( instance, id, value )
	return _audioManagerSingleton:getEventInstanceParameter( instance, id, value )
end