module 'mock'

local _platformSupport = false

function getPlatformSupport()
	return _platformSupport
end

--------------------------------------------------------------------
CLASS: PlatformSupportBase ()

function PlatformSupportBase:__init()
	_platformSupport = self
end

function PlatformSupportBase:getName()
	return 'unknown'
end

function PlatformSupportBase:getType()
	return 'unknown'
end

function PlatformSupportBase:onInit()
end

function PlatformSupportBase:getAppDir( name, vendor, userId )
	error( 'no impl')
end

function PlatformSupportBase:getHomeDir()
	error( 'no impl')
end

function PlatformSupportBase:affirmAppDir( name, vendor, userId )
	local path = self:getAppDir( name, vendor, userId )
	if MOAIFileSystem.checkPathExists( path ) then
		return path
	end
	
	MOAIFileSystem.affirmPath( path )
	if MOAIFileSystem.checkPathExists( path ) then
		return path
	end
	return false
end

function PlatformSupportBase:commitSaveData()
	
end

function PlatformSupportBase:openURLInBrowser( url )
	error( 'no impl' )
end

function PlatformSupportBase:getCap( key )
	return nil
end

function PlatformSupportBase:getDefaultLocale()
	return 'en'
end

function PlatformSupportBase:getNetworkState()
	return true
end

function PlatformSupportBase:getResolutions()
	return {}
end

function PlatformSupportBase:getDisplayResolution()
	return {}
end

--------------------------------------------------------------------
CLASS: PlatformSupportMobile ( PlatformSupportBase )

function PlatformSupportMobile:getType()
	return 'mobile'
end

function PlatformSupportMobile:getCap( key )
	if key == 'allow_fullscreen' then
		return false
	end
	return nil
end

--------------------------------------------------------------------
CLASS: PlatformSupportDesktop ( PlatformSupportBase )

function PlatformSupportDesktop:getType()
	return 'desktop'
end

function PlatformSupportDesktop:getCap( key )
	if key == 'allow_fullscreen' then
		return true
	elseif key == 'input_keyboard' then
		return true
	elseif key == 'input_mouse' then
		return true
	end
	return nil
end

function PlatformSupportDesktop:getResolutions()
	local function parseModes( s )
		if type(s) ~= 'string' then return {} end
		local result = {}
		local i = 1
		for line in s:gsplit( "\n", true ) do
			local w, h = line:match( "(%d+)%*(%d+)")
			result[ i ] = { tonumber(w), tonumber(h) }
			i = i + 1
		end
		return result
	end
	return parseModes( MOAIEnvironment.displayModes )
end

function PlatformSupportDesktop:getDisplayResolution()
	local mode = MOAIEnvironment.currentDisplayMode
	local w, h = mode:match( "(%d+)%*(%d+)")
	return { tonumber(w), tonumber(h) }
end

--------------------------------------------------------------------
CLASS: PlatformSupportConsole ( PlatformSupportBase )

function PlatformSupportConsole:getType()
	return 'console'
end

function PlatformSupportConsole:getCap( key )
	if key == 'allow_fullscreen' then
		return false
	elseif key == 'input_keyboard' then
		return false
	elseif key == 'input_mouse' then
		return false
	end
	return nil
end
--------------------------------------------------------------------
require 'mock.core.platformOSX'
require 'mock.core.platformLinux'
require 'mock.core.platformWindows'
require 'mock.core.platformNS'
require 'mock.core.platformIOS'
require 'mock.core.platformAndroid'
--------------------------------------------------------------------


