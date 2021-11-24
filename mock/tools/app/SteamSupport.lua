module 'mock'

--------------------------------------------------------------------
registerGlobalSignals{
	'app.steam.game_overlay',
	'app.steam.achievement_stored',
	'app.steam.userstats_stored',
	'app.steam.userstats_received',

}


local STEAM_CLOUD_DATA_PATH = '.steamcloud'
local _SteamSupport = false

--------------------------------------------------------------------
CLASS: SteamSupport ( GlobalManager )
	:MODEL{}

function SteamSupport:__init()
	self.enabled = false
	self.cloudDataPath = false
	self.cloudDataState = false
end

function SteamSupport:isEnabled()
	return self.enabled
end

function SteamSupport:preInit()
	if not getG( 'MOAISteamworks' ) then
		self.enabled = false
		return
	end

	if not game:isDeveloperMode() then 
		if MOAIEnvironment.STEAM_IS_ONLINE ~= "online" then
			os.exit()
		end
	end
	
	if not MOAISteamworks.isInitialized() then
		self.enabled = false
		_log( 'no steamworks.' )
		return
	end

	

	AchievementManager:get():setService( SteamAchievementService() )

	_log( 'detected steamworks...')

	self.enabled = true
	game.userId = 'steam_' .. MOAISteamworks.getSteamID()

end

function SteamSupport:onInit()
	if not self.enabled then return end
	--callbacks
	MOAISteamworks.setGameOverlayCallback( function( active )
		return self:onGameOverlay( active )
	end)
	
	MOAISteamworks.setAchievementStoredCallback( function( succ )
		return self:onAchievementStored( succ )
	end)

	MOAISteamworks.setUserStatsStoredCallback( function( succ )
		return self:onUserStatsStored( succ )
	end)

	MOAISteamworks.setUserStatsReceivedCallback( function( succ )
		return self:onUserStatsReceived( succ )
	end)

	MOAISteamworks.setCloudFileReadCallback( function( succ )
		print( 'cloud read', succ )
		self.cloudDataState = false
	end )

	MOAISteamworks.setCloudFileWriteCallback( function( succ )
		print( 'cloud write', succ )
		self.cloudDataState = false
	end)

	MOAISteamworks.requestStats()
	--we map cloud savedata to the "$USERDATA/_steamcloud" folder
	
	self:initCloudSaveData()
end

function SteamSupport:initCloudSaveData()
	self.cloudDataPath = game:affirmUserDataPath( STEAM_CLOUD_DATA_PATH )
	MOAISteamworks.setRemoteStorageParams( self.cloudDataPath, 'userdata' )
	self.cloudDataState = false
end

function SteamSupport:pullSaveData()
	if self.cloudDataState then return false end
	_log( 'pulling steam savedata')
	self.cloudDataState = 'pull'
	MOAISteamworks.pullSaveData()
	return true
end

function SteamSupport:pushSaveData()
	if self.cloudDataState then return false end
	_log( 'pushing steam savedata')
	self.cloudDataState = 'push'
	MOAISteamworks.pushSaveData()
	return true
end

function SteamSupport:getAvailableLanguages()
	--todo
end

function SteamSupport:getAvailableLocales()
	--todo
end


function SteamSupport:getCurrentUILanguage()
	return MOAISteamworks.getCurrentUILanguage()
end

function SteamSupport:getCurrentLanguage()
	return MOAISteamworks.getCurrentGameLanguage()
end

function SteamSupport:getCurrentBetaName()
	return MOAISteamworks.getCurrentBetaName()
end

function SteamSupport:getCurrentLocale()
	return self:languageToLocale( MOAISteamworks.getCurrentUILanguage() )
	-- return self:languageToLocale( MOAISteamworks.getCurrentGameLanguage() )
end

-- function SteamSupport:onUpdate( ... )
-- 	-- body
-- end

function SteamSupport:isStatReady()
	return self.statReady
end

function SteamSupport:onGameOverlay( active )
	_log( 'steam game overlay activated:', active )
	emitGlobalSignal( 'app.steam.game_overlay', active )
end


function SteamSupport:onAchievementStored( succ )
	_log( 'steam achievements stored:', succ )
	emitGlobalSignal( 'app.steam.achievement_stored', succ )
end


function SteamSupport:onUserStatsStored( succ )
	_log( 'steam stats stored:', succ )
	emitGlobalSignal( 'app.steam.userstats_stored', succ )
end

function SteamSupport:onUserStatsReceived( succ )
	_log( 'steam stats stored:', succ )
	if not succ then return end
	self.statReady = true
	
	print( 'achievements:', MOAISteamworks.getAchievementCount() )
	local count = MOAISteamworks.getAchievementCount()
	for i = 1, count do
		local id = MOAISteamworks.getAchievementID( i )
		local name, desc, hidden = MOAISteamworks.getAchievementDisplayAttributes( i )
		print( i, id, name, desc, hidden )
	end

	emitGlobalSignal( 'app.steam.userstats_received', succ )
end


local _steamLanguageTable = {
	[ "arabic"     ] = "ar",
	[ "bulgarian"  ] = "bg",
	[ "schinese"   ] = "zh-CN",
	[ "tchinese"   ] = "zh-TW",
	[ "czech"      ] = "cs",
	[ "danish"     ] = "da",
	[ "dutch"      ] = "nl",
	[ "english"    ] = "en",
	[ "finnish"    ] = "fi",
	[ "french"     ] = "fr",
	[ "german"     ] = "de",
	[ "greek"      ] = "el",
	[ "hungarian"  ] = "hu",
	[ "italian"    ] = "it",
	[ "japanese"   ] = "ja",
	[ "koreana"    ] = "ko",
	[ "norwegian"  ] = "no",
	[ "polish"     ] = "pl",
	[ "portuguese" ] = "pt",
	[ "brazilian"  ] = "pt-BR",
	[ "romanian"   ] = "ro",
	[ "russian"    ] = "ru",
	[ "spanish"    ] = "es",
	[ "latam"      ] = "es-419",
	[ "swedish"    ] = "sv",
	[ "thai"       ] = "th",
	[ "turkish"    ] = "tr",
	[ "ukrainian"  ] = "uk",
	[ "vietnamese" ] = "vn",
}

function SteamSupport:languageToLocale( languageName )
	return _steamLanguageTable[ languageName ]
end


--------------------------------------------------------------------
CLASS: SteamAchievementService ( AchievementService )

function SteamAchievementService:onAchievementUnlock( ach )
	MOAISteamworks.unlockAchievement( ach:getId() )	
end

function SteamAchievementService:onAchievementProgress( ach )
	local progress, progressMax = ach:getProgress()
	MOAISteamworks.unlockAchievement( ach:getId(), progress, progressMax )	
end

function SteamAchievementService:onReset()
	MOAISteamworks.resetAllStats()
end

function SteamAchievementService:onRequestAcheviementState( ach )
	local id = ach:getId()
	local unlocked, percent, unlockTime = MOAISteamworks.getAchievementState( id )
	return unlocked, percent, unlockTime
end

function SteamAchievementService:isStateReady()
	return _SteamSupport.statReady
end



---------------------------------------------------------------------
_SteamSupport = SteamSupport()

function getSteamSupport()
	return _SteamSupport
end
