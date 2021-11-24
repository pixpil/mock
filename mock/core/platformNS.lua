module 'mock'

if MOAIEnvironment.osBrand ~= 'NS' then return end

registerGlobalSignals{
	'platform.ns.performance_mode_change',
	'platform.ns.operation_mode_change',
}

local opModeMap = {
	[MOAIAppNX.OPERATION_MODE_HANDHELD] = 'handheld';
	[MOAIAppNX.OPERATION_MODE_CONSOLE]  = 'console';
}

local perfModeMap = {
	[MOAIAppNX.PERFORMANCE_MODE_INVALID] = 'invalid';
	[MOAIAppNX.PERFORMANCE_MODE_NORMAL]  = 'normal';
	[MOAIAppNX.PERFORMANCE_MODE_BOOST]   = 'boost';
}

--------------------------------------------------------------------
CLASS: PlatformSupportNS ( PlatformSupportConsole )

function PlatformSupportNS:getName()
	return 'NS'
end

function PlatformSupportNS:onInit()
	
	MOAIAppNX.setListener( MOAIAppNX.EVENT_PERFORMANCE_MODE_CHANGE, function()
		local modeName = self:getPerformanceMode()
		emitGlobalSignal( 'platform.ns.performance_mode_change',  modeName )
	end )

	MOAIAppNX.setListener( MOAIAppNX.EVENT_OPERATION_MODE_CHANGE, function()
		local modeName = self:getOperationMode()
		emitGlobalSignal( 'platform.ns.operation_mode_change',  modeName )
		getJoystickManager():affirmJoysticks( true )
	end )
end

function PlatformSupportNS:getPerformanceMode()
	local mode = MOAIAppNX.getPerformanceMode()
	local modeName = perfModeMap[ mode ] or false
	return modeName
end

function PlatformSupportNS:getOperationMode()
	local mode = MOAIAppNX.getOperationMode()
	local modeName = opModeMap[ mode ] or false
	return modeName
end

function PlatformSupportNS:getAppDir( name, vendor, userId )
	local devPlatform = MOAIEnvironment.devPlatform
	if devPlatform == 'NX' then
		return 'save:'
	elseif devPlatform == 'windows' then
		--TODO: for ns win
		return '.'
	else
		error( 'WTF?' )
	end

end

function PlatformSupportNS:commitSaveData()
	return MOAIAppNX.commitSaveData()
end

function PlatformSupportNS:getCap( key )
	if key == 'allow_fullscreen' then
		return false
	end
	return nil
end

function PlatformSupportNS:getNetworkState()
	if MOAIAppNX.isNetworkAvailable() then
		return true
	else
		return false
	end
end

local LanguageToLocale = {
	[ 'en-US'   ] = 'en';
	[ 'en-GB'   ] = 'en';
	[ 'zh-CN'   ] = 'zh-CN';
	[ 'zh-Hans' ] = 'zh-CN';
	[ 'zh-Hant' ] = 'zh-TW';
	[ 'zh-TW'   ] = 'zh-TW';
	[ 'ja'      ] = 'ja';
	[ 'fr'      ] = 'fr';
	[ 'fr-CA'   ] = 'fr';
	[ 'de'      ] = 'de';
	[ 'it'      ] = 'it';
	[ 'es'      ] = 'es';
	[ 'es-419'  ] = 'es';
	[ 'ko'      ] = 'ko';
	[ 'nl'      ] = 'nl';
	[ 'pt'      ] = 'pt';
	[ 'ru'      ] = 'ru';
}

function PlatformSupportNS:getDefaultLocale()
	local language = MOAIAppNX.getDesiredLanguage()
	local locale = LanguageToLocale[ language ]
	return locale
end

PlatformSupportNS()

-- replace default os.time() to ns time library version
-- os.time = MOAIAppNX.getNetworkClockTimeStamp
os.time = MOAIAppNX.getUserClockTimeStamp
print( 'replaced lua os.time() with ns time lib impl' )
