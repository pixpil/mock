module 'mock'

--------------------------------------------------------------------
registerGlobalSignals{
	'app.eos.achievement_stored',
	'app.eos.achievement_received',
}


local _EosSupport = false

--------------------------------------------------------------------
CLASS: EosSupport ( GlobalManager )
	:MODEL{}

function EosSupport:__init()
	self.enabled = false	
end

function EosSupport:isEnabled()
	return self.enabled
end

function EosSupport:preInit()
	if not getG( 'MOAIEos' ) then
		self.enabled = false
		return
	end

	if not MOAIEos.isInitialized() then
		self.enabled = false
		_log( 'no eos.' )
		return
	end

	AchievementManager:get():setService( EosAchievementService() )

	_log( 'detected eos...')

	self.enabled = true
	game.userId = false

end

function EosSupport:onInit()
	if not self.enabled then return end
	
	MOAIEos.setAchievementStoredCallback( function( succ )
		return self:onAchievementStored( succ )
	end)

	-- MOAIEos.setAchievementReceivedCallback( function( succ )
	-- 	return self:onAchievementReceived( succ )
	-- end)

	-- MOAIEos.requestAchievement()

	print( self:getCurrentLanguage() )
end

function EosSupport:getAvailableLanguages()
	--todo
end

function EosSupport:getAvailableLocales()
	--todo
end


function EosSupport:getCurrentLanguage()
	return MOAIEos.getCurrentGameLanguage()
end

function EosSupport:getCurrentLocale()
	return self:languageToLocale( MOAIEos.getCurrentGameLanguage() )
end

-- function EosSupport:onUpdate( ... )
-- 	-- body
-- end

function EosSupport:isStatReady()
	return self.statReady
end

function EosSupport:onAchievementStored( succ )
	_log( 'eos achievements stored:', succ )
	if not succ then return end

	emitGlobalSignal( 'app.eos.achievement_stored', succ )
end

function EosSupport:onAchievementReceived( succ )
	_log( 'eos achievements received:', succ )
	if not succ then return end

	self.statReady = succ
	emitGlobalSignal( 'app.eos.achievement_received', succ )
end

local _eosLanguageTable = {
	[ "zh-CN"   	 ] = "zh-CN",
	[ "zh-HK"   	 ] = "zh-TW",
	[ "en_US"  		 ] = "en",
}

function EosSupport:languageToLocale( languageName )
	return _eosLanguageTable[ languageName ] or "zh-CN"
end


--------------------------------------------------------------------
CLASS: EosAchievementService ( AchievementService )

function EosAchievementService:onAchievementUnlock( ach )
	MOAIEos.unlockAchievement( ach:getId() )	
end

function EosAchievementService:onAchievementProgress( ach )
	local progress, progressMax = ach:getProgress()
	MOAIEos.unlockAchievement( ach:getId(), progress, progressMax )	
end

function EosAchievementService:onReset()
	MOAIEos.resetAllAchievements()
end

function EosAchievementService:onRequestAcheviementState( ach )
	local id = ach:getId()
	local unlocked, percent, unlockTime = MOAIEos.getAchievementState( id )
	return unlocked, percent, unlockTime
end

function EosAchievementService:isStateReady()
	return _EosSupport.statReady
end



---------------------------------------------------------------------
_EosSupport = EosSupport()

function getEosSupport()
	return _EosSupport
end
