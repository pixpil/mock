module 'mock'

local _globalSoundPlayer
function getGlobalSoundPlayer()
	return _globalSoundPlayer
end

function getGlobalSoundSession( name )
	return _globalSoundPlayer:getSession( name )
end

function getGlobalSoundGroup( name )
	return _globalSoundPlayer:getGroup( name )
end


--------------------------------------------------------------------
local function _actionSeekInstanceVolume( instance, volume, duration, delay, actionOnFinish )
	local v0 = instance:getVolume()
	
	if delay and delay > 0 then
		local elapsed = 0
		while elapsed < delay do
			elapsed = elapsed + coroutine.yield()
		end
	end
	
	instance:pause( false )
	if duration and duration > 0 then
		local elapsed = 0
		local t = os.clock()
		while true do
			coroutine.yield()
			t1 = os.clock()
			local dt = math.min( t1 - t, 1/60 )
			t = t1
			elapsed = elapsed + dt
			local k = math.min( elapsed / duration, 1 )
			if not instance:isValid() then
				return
			end
			local v = lerp( v0, volume, k )
			instance:setVolume( v )
			if k >= 1 then break end
		end
	else
		instance:setVolume( volume )
	end

	if actionOnFinish == 'stop' then
		instance:stop()
	elseif actionOnFinish == 'pause' then
		instance:pause()
	end

end

--------------------------------------------------------------------
CLASS: GlobalSoundPlayerSession ( Actor )
	:MODEL{}

function GlobalSoundPlayerSession:__init( name )
	self.name = name
	self.currentEvent = false
	self.soundInstance = false
	self.eventQueue = {}
	self.fadingInstance = false
	self.volume = 1

	self.mainCoro = false
	self.changeSeq = 0
	self.paused = false

end

function GlobalSoundPlayerSession:isRunning()
	return self.soundInstance
end

function GlobalSoundPlayerSession:stop( fadeDuration )
	self:stopEvent( fadeDuration )
end

function GlobalSoundPlayerSession:pause( fadeDuration )
	self.paused = true
	self:stopMainCoroutine()
	self.changeSeq = self.changeSeq + 1
	if self.soundInstance then
		if fadeDuration and fadeDuration > 0 then
			local coro = self:addMainCoroutine( _actionSeekInstanceVolume, self.soundInstance, 0, fadeDuration, false , 'pause')
			return coro
		else
			self.soundInstance:pause()
		end
	end
end

function GlobalSoundPlayerSession:resume( fadeDuration, delay )
	self:stopMainCoroutine()
	if self.soundInstance then
		self.paused = false
		_log( 'resuming sound', self, self.currentEvent )
		if fadeDuration and fadeDuration > 0 then
			-- self.soundInstance:setVolume( 0 )
			self:seekVolume( self.volume, fadeDuration, delay )
		else
			self.soundInstance:pause( false )
			self.soundInstance:setVolume( self.volume )
		end
	else
		_log( 'no sound to resume' )
	end
end

function GlobalSoundPlayerSession:getCurrentEvent()
	return self.currentEvent
end



function GlobalSoundPlayerSession:isPlaying()
	local instance = self.soundInstance
	if not instance then return false end
	return AudioManager.get():isEventInstancePlaying( instance )
end

function GlobalSoundPlayerSession:stopEvent( fadeDuration )
	self:stopMainCoroutine()
	local instance = self.soundInstance
	if not instance then return false end
	if fadeDuration and fadeDuration > 0 then
		game:addCoroutine( _actionSeekInstanceVolume, instance, 0, fadeDuration, false, 'stop' )
	else
		instance:stop()
	end
	self.soundInstance = false
	self.currentEvent  = false
	self.changeSeq = self.changeSeq + 1
	return true
end

function GlobalSoundPlayerSession:changeEvent( eventPath, delay, fadeInDuration, fadeOutDuration, restartIfPaused )
	restartIfPaused = restartIfPaused ~= false
	self.changeSeq = self.changeSeq + 1
	local allowRestart = restartIfPaused and self:isPaused()
	if self.currentEvent == eventPath and ( not allowRestart )  then 
		_log( 'same event, ignore' )
		return
	end
	self.currentEvent = eventPath
	return self:playEvent( eventPath, delay, fadeInDuration, fadeOutDuration )
end

function GlobalSoundPlayerSession:stopMainCoroutine()
	if self.mainCoro then
		self.mainCoro:stop()
		self.mainCoro = false
	end
end

function GlobalSoundPlayerSession:addMainCoroutine( func, ... )
	self:stopMainCoroutine()
	local coro = game:addCoroutine( func, ... )
	self.mainCoro = coro
	return coro
end

function GlobalSoundPlayerSession:playEvent( eventPath, delay, fadeInDuration, fadeOutDuration )
	fadeOutDuration = fadeOutDuration or fadeInDuration or 0
	self:stopEvent( fadeOutDuration )
	local instance = AudioManager.get():playEvent2D( eventPath )
	self.currentEvent = eventPath
	self.soundInstance = instance
	self.changeSeq = self.changeSeq + 1
	self.paused = false
	_log( 'start playing', eventPath, self )

	if instance then
		instance.session  = self
		if fadeInDuration or delay then
			instance:setVolume( 0 )
			instance:pause()
			local coro = self:addMainCoroutine( _actionSeekInstanceVolume, instance, self.volume, fadeInDuration, delay )
			self.mainCoro = coro
			return coro
		else
			instance:setVolume( self.volume )
		end
	end
end

function GlobalSoundPlayerSession:seekVolume( vol, duration, delay, actionOnFinish )
	local v0 = self.volume
	local instance = self.soundInstance
	if not instance then 
		_warn( 'no sound instance' )
		return nil
	end
	local coro = self:addMainCoroutine( _actionSeekInstanceVolume, instance, vol, duration, delay, actionOnFinish )
	self.volume = vol
	return coro
end

function GlobalSoundPlayerSession:setVolume( vol )	
	self.volume = vol or 1
	if self.soundInstance then
		self.soundInstance:setVolume( self.volume )
	end
end

function GlobalSoundPlayerSession:getEventInstanceVolume()
	return self.soundInstance and self.soundInstance:getVolume() or 0
end

function GlobalSoundPlayerSession:resetChangeSeq()
	self.changeSeq = 0
end

function GlobalSoundPlayerSession:getChangeSeq()
	return self.changeSeq
end

function GlobalSoundPlayerSession:isPaused()
	return self.paused
end

function GlobalSoundPlayerSession:isChanged()
	return self.changeSeq > 0
end

function GlobalSoundPlayerSession:getVolume()
	return self.volume
end

function GlobalSoundPlayerSession:getEventInstance()
	return self.soundInstance
end

function GlobalSoundPlayerSession:setParam( key, value )
	if self.soundInstance then
		return getAudioManager():setEventInstanceParameter( self.soundInstance, key, value )
	else
		_error( 'no event instance for setParam' )
	end
end


--------------------------------------------------------------------
CLASS: GlobalSoundGroup ()

function GlobalSoundGroup:__init()
	self.eventInstances = {}
end

function GlobalSoundGroup:getEventInstances()
	return self.eventInstances
end

function GlobalSoundGroup:playEvent( eventPath, category )
	local mgr = getAudioManager()
	local instance = AudioManager.get():playEvent2D( eventPath )
	if instance then
		self.eventInstances[ instance ] = true
	end
	self:clearStoppedInstances()
	return instance
end

function GlobalSoundGroup:clearStoppedInstances()
	local instances = self.eventInstances
	local dead = {}
	for instance, k in pairs( instances ) do
		if not instance:isValid() then dead[ instance ] = true end
	end
	for instance in pairs( dead ) do
		instances[ instance ] = nil
	end
end

function GlobalSoundGroup:stop()
	local mgr = getAudioManager()
	for instance in pairs( self.eventInstances ) do
		instance:stop()
	end
	self.eventInstances = {}
end


--------------------------------------------------------------------
CLASS: GlobalSoundPlayer ( GlobalManager )
	:MODEL{}

function GlobalSoundPlayer:__init()
	self.sessions = {}
	self.groups = {}
	self.sortedSessionList = false
	self.changeSeq = 0
end

function GlobalSoundPlayer:getKey()
	return 'GlobalSoundPlayer'
end

function GlobalSoundPlayer:stop()
	self:stopAllSessions()
	self:stopAllGroups()
end

function GlobalSoundPlayer:affirmGroup( name )
	local group = self.groups[ name ]
	if not group then
		return self:addGroup( name )
	end
	return group
end

function GlobalSoundPlayer:addGroup( name )
	if self.groups[ name ] then
		_warn( 'duplicated global sound group', name )
		return self.groups[ name ]
	end
	group = GlobalSoundGroup()
	self.groups[ name ] = group
	return group
end

function GlobalSoundPlayer:getGroup( name )
	return self.groups[ name ]
end

function GlobalSoundPlayer:stopGroup( name )
	local group = self:getGroup( name )
	if group then
		return group:stop()
	end
end

function GlobalSoundPlayer:affirmSession( name )
	local session = self.sessions[ name ]
	if session then return session end
	return self:addSession( name )
end

function GlobalSoundPlayer:stopSession( name )
	local session = self:getSession( name )
	if session then session:stop() end
end

function GlobalSoundPlayer:stopSessionEvent( ... )
	local session = self:getSession( name )
	if session then session:stopEvent( ... ) end
end

function GlobalSoundPlayer:stopAllSessions()
	for name, session in pairs( self.sessions ) do
		session:stop()
	end
end

function GlobalSoundPlayer:clearSessions()
	self:stopAllSessions()
	self.sessions = {}
end

function GlobalSoundPlayer:addSession( name )
	local session = GlobalSoundPlayerSession( name )
	if not self.sessions[ name ] then
		self.sessions[ name ] = session
		self.sortedSessionList = false
		return session
	else
		_warn( 'duplicated global sound session', name )
		return false
	end
end

function GlobalSoundPlayer:getSession( name )
	return self.sessions[ name ]
end

function GlobalSoundPlayer:getSessions()
	return self.sessions
end

function GlobalSoundPlayer:getSessionList()
	local list = self.sortedSessionList
	if not list then 
		list = table.values( self.sessions )
		table.sort( list, function(a,b) return a.name < b.name end )
		self.sortedSessionList = list
	end
	return list
end


_globalSoundPlayer = GlobalSoundPlayer()