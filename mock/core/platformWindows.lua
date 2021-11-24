module 'mock'

if MOAIEnvironment.osBrand ~= 'Windows' then return end

--------------------------------------------------------------------
CLASS: PlatformSupportWindows ( PlatformSupportDesktop )

function PlatformSupportWindows:getName()
	return 'Windows'
end

function PlatformSupportWindows:getHomeDir()
	return os.getenv( 'UserProfile' )
end

function PlatformSupportWindows:getAppDir( name, vendor, userId )
	local base = MOCKHelper.getWindowsAppDir( false )
	local path = base
	if vendor then
		path = path .. '\\' .. vendor
	end
	if name then
		path = path .. '\\' .. name
	end
	if userId then
		path = path .. '\\' .. userId
	end
	return path
end

function PlatformSupportWindows:openURLInBrowser( url )
	return os.execute( string.format( 'start "" %q', url ))
end

PlatformSupportWindows()
