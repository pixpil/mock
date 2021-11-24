module 'mock'
if getAudioManager() then return end
local _mgr = false
--------------------------------------------------------------------
CLASS: NullStudioAudioManager ( AudioManager )
	:MODEL{}

function NullStudioAudioManager:__init()
	_mgr = self
	self.unitsToMeters = 1
end

function NullStudioAudioManager:init( option )
	return true
end

function NullStudioAudioManager:stop()	
end

function NullStudioAudioManager:getUnitToMeters()
	return self.unitsToMeters
end

function NullStudioAudioManager:getSystem()
end

function NullStudioAudioManager:forceUpdate()
end

function NullStudioAudioManager:clearCaches()
end

function NullStudioAudioManager:getListener( idx )
	return self.system:getListener( idx or 1 )
end

function NullStudioAudioManager:getEventById( id )
	return false
end

function NullStudioAudioManager:getBus( path )
	return false
end

function NullStudioAudioManager:getCategoryVolume( category )
	return 0
end

function NullStudioAudioManager:setCategoryVolume( category, volume )
	return
end

function NullStudioAudioManager:seekCategoryVolume( category, v, delta, easeType )
	return
end

function NullStudioAudioManager:moveCategoryVolume( category, dv, delta, easeType )
	return
end

function NullStudioAudioManager:pauseCategory( category, paused )
	return
end

function NullStudioAudioManager:setCategoryMuted( category, muted )
	return
end

function NullStudioAudioManager:isCategoryMuted( category )
	return false
end

function NullStudioAudioManager:isCategoryPaused( category )
	return false
end

function NullStudioAudioManager:getEventDescription( eventPath )
	return false
end

function NullStudioAudioManager:createEventInstance( eventPath )
	return false
end

function NullStudioAudioManager:playEvent3D( eventPath, x, y, z )
	return false
end

function NullStudioAudioManager:playEvent2D( eventPath )
	return false
end

function NullStudioAudioManager:isEventInstancePlaying( sound )
	return false
end

function NullStudioAudioManager:triggerEventInstanceCue( eventInstance )
	return false
end


function NullStudioAudioManager:getEventSetting( path, key )
	return nil
end

function NullStudioAudioManager:setEventSetting( path, key, value )
	--do nothing
	return	
end

function NullStudioAudioManager:getEventInstanceSetting( eventInstance, key )
	return nil
end


function NullStudioAudioManager:setEventInstanceSetting( eventInstance, key, value )
	return nil
end

function NullStudioAudioManager:getEventInstanceTime( eventInstance )
	return 0
end

function NullStudioAudioManager:setEventInstanceTime( eventInstance, time )
	return
end

function NullStudioAudioManager:getEventInstanceVolume( eventInstance )
	return 0
end

function NullStudioAudioManager:setEventInstanceVolume( eventInstance, volume )
	return
end

function NullStudioAudioManager:getEventInstanceParameter( eventInstance, key )
	return nil
end

function NullStudioAudioManager:setEventInstanceParameter( eventInstance, key, value )
	return
end

function NullStudioAudioManager:sendEditCommand( cmd, data )
	return
end

--------------------------------------------------------------------
_log( 'using NULL Studio audio manager' )
NullStudioAudioManager()

 