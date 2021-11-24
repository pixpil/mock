module 'mock'

--------------------------------------------------------------------
registerGlobalSignals{
	'app.wegame.achievement_stored',
	'app.wegame.achievement_received',
}


local _WegameSupport = false

--------------------------------------------------------------------
CLASS: WegameSupport ( GlobalManager )
	:MODEL{}

function WegameSupport:__init()
	self.enabled = false	
end

function WegameSupport:isEnabled()
	return self.enabled
end

function WegameSupport:preInit()
	if not getG( 'MOAIRail' ) then
		self.enabled = false
		return
	end

	if not MOAIRail.isInitialized() then
		self.enabled = false
		_log( 'no wegame.' )
		return
	end

	AchievementManager:get():setService( WegameAchievementService() )

	_log( 'detected wegame...')

	self.enabled = true
	game.userId = 'wegame_'..MOAIRail.getPlayerID()

end

function WegameSupport:onInit()
	if not self.enabled then return end
	
	MOAIRail.setAchievementStoredCallback( function( succ )
		return self:onAchievementStored( succ )
	end)

	MOAIRail.setAchievementReceivedCallback( function( succ )
		return self:onAchievementReceived( succ )
	end)

	MOAIRail.requestAchievement()

	print( self:getCurrentLanguage() )
end

function WegameSupport:getAvailableLanguages()
	--todo
end

function WegameSupport:getAvailableLocales()
	--todo
end


function WegameSupport:getCurrentLanguage()
	return MOAIRail.getCurrentGameLanguage()
end

function WegameSupport:getCurrentLocale()
	return self:languageToLocale( MOAIRail.getCurrentGameLanguage() )
end

-- function WegameSupport:onUpdate( ... )
-- 	-- body
-- end

function WegameSupport:isStatReady()
	return self.statReady
end

function WegameSupport:onAchievementStored( succ )
	_log( 'wegame achievements stored:', succ )
	if not succ then return end

	emitGlobalSignal( 'app.wegame.achievement_stored', succ )
end

function WegameSupport:onAchievementReceived( succ )
	_log( 'wegame achievements received:', succ )
	if not succ then return end

	self.statReady = succ
	emitGlobalSignal( 'app.wegame.achievement_received', succ )
end

local _wegameLanguageTable = {
	[ "zh-CN"   	 ] = "zh-CN",
	[ "zh-HK"   	 ] = "zh-TW",
	[ "en_US"  		 ] = "en",
}

function WegameSupport:languageToLocale( languageName )
	return _wegameLanguageTable[ languageName ] or "zh-CN"
end


--------------------------------------------------------------------
CLASS: WegameAchievementService ( AchievementService )

function WegameAchievementService:onAchievementUnlock( ach )
	MOAIRail.unlockAchievement( ach:getId() )	
end

function WegameAchievementService:onAchievementProgress( ach )
	local progress, progressMax = ach:getProgress()
	MOAIRail.unlockAchievement( ach:getId(), progress, progressMax )	
end

function WegameAchievementService:onReset()
	MOAIRail.resetAllAchievements()
end

function WegameAchievementService:onRequestAcheviementState( ach )
	local id = ach:getId()
	local unlocked, percent, unlockTime = MOAIRail.getAchievementState( id )
	return unlocked, percent, unlockTime
end

function WegameAchievementService:isStateReady()
	return _WegameSupport.statReady
end



---------------------------------------------------------------------
_WegameSupport = WegameSupport()

function getWegameSupport()
	return _WegameSupport
end
