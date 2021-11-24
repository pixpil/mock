module 'mock'

if MOAIEnvironment.osBrand ~= 'OSX' then return end

--------------------------------------------------------------------
CLASS: PlatformSupportOSX ( PlatformSupportDesktop )

function PlatformSupportOSX:getName()
	return 'OSX'
end

function PlatformSupportOSX:getHomeDir()
	return os.getenv('HOME')
end

function PlatformSupportOSX:getAppDir( name, vendor, userId )
	local home = os.getenv( 'HOME' )
	local base = home .. '/Library/Application Support'
	local path = base
	if vendor then
		path = path .. '/' .. vendor
	end
	if name then
		path = path .. '/' .. name
	end
	if userId then
		path = path .. '/' .. userId
	end
	return path
end

function PlatformSupportOSX:openURLInBrowser( url )
	return os.execute( string.format( 'open "" %q', url ))
end

function PlatformSupportOSX:onInit()
	if getG( 'MOCKSDLHelper' ) then
		local displayCount = MOCKSDLHelper.getNumVideoDisplays()
		local touchScreenIdx
		for i = 0, displayCount-1 do
			local name = MOCKSDLHelper.getDisplayName( i )
			if name and name:find( 'T779' ) then
				touchScreenIdx = i
			end
		end

		if touchScreenIdx then
			local scrx, scry, scrw, scrh = MOCKSDLHelper.getDisplayBounds( touchScreenIdx )
			MOCKSDLHelper.setWindowPosition( scrx, scry )
			game:enterFullscreenMode()
		end
	end
end

PlatformSupportOSX()

