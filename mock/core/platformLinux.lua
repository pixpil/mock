module 'mock'

if MOAIEnvironment.osBrand ~= 'Linux' then return end

--------------------------------------------------------------------
CLASS: PlatformSupportLinux ( PlatformSupportDesktop )

function PlatformSupportLinux:getName()
	return 'Linux'
end

function PlatformSupportLinux:getHomeDir()
	return os.getenv('HOME')
end

function PlatformSupportLinux:getAppDir( name, vendor, userId )
	local home = os.getenv( 'HOME' )
	local base = home
	local path = base
	if vendor then
		path = path .. '/.' .. vendor
	end
	if name then
		path = path .. '/' .. name
	end
	if userId then
		path = path .. '/' .. userId
	end
	return path
end

function PlatformSupportLinux:openURLInBrowser( url )
	return os.execute( string.format( 'sensible-browser "" %s', url ))
end

PlatformSupportLinux()