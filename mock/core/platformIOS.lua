module 'mock'

if MOAIEnvironment.osBrand ~= 'iOS' then return end

--------------------------------------------------------------------
CLASS: PlatformSupportIOS ( PlatformSupportMobile )

function PlatformSupportIOS:getAppDir( name )
	return MOAIEnvironment.documentDirectory	
end

function PlatformSupportIOS:openURLInBrowser( url )
	return MOAIAppIOS.openURL( url )
end

PlatformSupportIOS()

