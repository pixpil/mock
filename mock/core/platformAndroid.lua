module 'mock'

if MOAIEnvironment.osBrand ~= 'Android' then return end
--------------------------------------------------------------------
CLASS: PlatformSupportAndroid ( PlatformSupportMobile )

function PlatformSupportAndroid:onInit()
	local _log = MOAILogMgr.log

	local function logger( token, s, outputLine  )
		return _log( 1, outputLine )
	end

	_G.print = function ( a, ... )
		local out

		if a == nil then
			out = ''
		else
			out = tostring( a )
		end
		
		for i = 1, select( '#', ... ) do
			out = out .. '\t' .. tostring( select( i, ... ))
		end
		return _log( out )
	end

	addLogListener( logger )
end

function PlatformSupportAndroid:getAppDir( name )
	return MOAIEnvironment.documentDirectory
end

function PlatformSupportAndroid:openURLInBrowser( url )
	return MOAIAppAnadroid.openURL( url )
end

PlatformSupportAndroid()

