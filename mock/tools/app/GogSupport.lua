module 'mock'

--------------------------------------------------------------------
registerGlobalSignals{
	'app.gog.achievement_stored',
	'app.gog.achievement_received',
}


local _GOGSupport = false

--------------------------------------------------------------------
CLASS: GOGSupport ( GlobalManager )
	:MODEL{}

function GOGSupport:__init()
	self.enabled = false	
end

function GOGSupport:isEnabled()
	return self.enabled
end

function GOGSupport:preInit()
	if not getG( 'MOAIGalaxy' ) then
		self.enabled = false
		return
	end

	if not MOAIGalaxy.isInitialized() then
		self.enabled = false
		_log( 'no GOG.' )
		return
	end

	AchievementManager:get():setService( GOGAchievementService() )

	_log( 'detected GOG...')

	self.enabled = true
	game.userId = false

end

function GOGSupport:onInit()
	-- if not self.enabled then return end
	if not getG( 'MOAIGalaxy' ) then
		return 
	end
	
	MOAIGalaxy.setAchievementStoredCallback( function( succ )
		return self:onAchievementStored( succ )
	end)

	MOAIGalaxy.setAchievementReceivedCallback( function( succ )
		return self:onAchievementReceived( succ )
	end)

	-- MOAIGalaxy.requestAchievement()

	-- print( self:getCurrentLanguage() )
end

function GOGSupport:getAvailableLanguages()
	--todo
end

function GOGSupport:getAvailableLocales()
	--todo
end


function GOGSupport:getCurrentLanguage()
	return MOAIGalaxy.getCurrentGameLanguage()
end

function GOGSupport:getCurrentLocale()
	return self:languageToLocale( MOAIGalaxy.getCurrentGameLanguage() )
end

-- function GOGSupport:onUpdate( ... )
-- 	-- body
-- end

function GOGSupport:isStatReady()
	return self.statReady
end

function GOGSupport:onAchievementStored( succ )
	_log( 'GOG achievements stored:', succ )
	if not succ then return end

	emitGlobalSignal( 'app.gog.achievement_stored', succ )
end

function GOGSupport:onAchievementReceived( succ )
	_log( 'GOG achievements received:', succ )
	if not succ then return end

	AchievementManager:get():setService( GOGAchievementService() )
	self.enabled = true

	self.statReady = succ

	local achList = AchievementManager:get():getAchievementList()
	if achList then
		for i, ach in ipairs( achList ) do
			ach:refreshAchState( succ )
		end
	end

	emitGlobalSignal( 'app.gog.achievement_received', succ )
end

local _GOGLanguageTable = {
	[ "zh-CN"   	 ] = "zh-CN",
	[ "zh-HK"   	 ] = "zh-TW",
	[ "en_US"  		 ] = "en",
}

function GOGSupport:languageToLocale( languageName )
	return _GOGLanguageTable[ languageName ] or "zh-CN"
end


--------------------------------------------------------------------
CLASS: GOGAchievementService ( AchievementService )

function GOGAchievementService:onAchievementUnlock( ach )
	MOAIGalaxy.unlockAchievement( ach:getId() )	
end

function GOGAchievementService:onAchievementProgress( ach )
	-- local progress, progressMax = ach:getProgress()
	-- MOAIGalaxy.unlockAchievement( ach:getId(), progress, progressMax )	
end

function GOGAchievementService:onReset()
	MOAIGalaxy.resetAllAchievements()
end

function GOGAchievementService:onRequestAcheviementState( ach )
	local id = ach:getId()
	local unlocked, percent, unlockTime = MOAIGalaxy.getAchievementState( id )
	return unlocked, percent, unlockTime
end

function GOGAchievementService:isStateReady()
	return _GOGSupport.statReady
end



---------------------------------------------------------------------
_GOGSupport = GOGSupport()

function getGOGSupport()
	return _GOGSupport
end
