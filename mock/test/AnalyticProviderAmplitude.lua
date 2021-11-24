module 'mock'

CLASS: AnalyticProviderAmplitude ( AnalyticProvider )
:register( 'amplitude' )

function AnalyticProviderAmplitude:__init()
end

function AnalyticProviderAmplitude:affirmDeviceID()
	local id = game:getSetting( 'analytic_device_id' )
	if not id then
		id = MOAIEnvironment.generateGUID()
		game:updateSetting( 'analytic_device_id', id )
		-- print( 'generate device id')
	else
		-- print( 'device id found')
	end
	self.deviceId = id
end


function AnalyticProviderAmplitude:onInit()
	if not game:getConfig( 'amplitude_enabled' ) then
		return false
	end
	self.apiKey = game:getConfig( 'amplitude_api_key' )
	if not self.apiKey then
		_warn( 'api_key_amplitude API key not defined' )
		return false
	end
	self.urlBase = string.format( 'https://api.amplitude.com/httpapi?api_key=' .. self.apiKey )
	self.client = HTTPClient()

	self.httpOptions = {
		onResponse  = self:methodPointer( 'onHttpResponse' ),
		contentType = 'application/x-www-form-urlencoded',
	}

	_log( 'amplitude initialized' )
	--TODO: validation?
end

function AnalyticProviderAmplitude:onHttpResponse( task, code )
	--TODO: keep unsent events?
	-- print( task, code )
end

function AnalyticProviderAmplitude:onSessionStart()
	self:affirmDeviceID()
end

function AnalyticProviderAmplitude:onSessionStop()
end

local simplecopy = table.simplecopy
local insert = table.insert
local base64 = MOAIDataBuffer.base64Encode
function AnalyticProviderAmplitude:onRecord( events )
	-- body
	local options = self.httpOptions
	local deviceId = self.deviceId
	local batchSize = 0 --TODO: batch size
	local outputList = {}
	for _, e in ipairs( events ) do
		local properties = e.data and simplecopy( e.data ) or {}
		--fill required data
		properties.token = self.apiKey
		local rawData = {
			event_type = e.type,
			device_id = deviceId,
			event_properties = properties
		}
		insert( outputList, rawData )
	end
	
	local method = 'get'

	if method == 'get' then
		local query = url.buildQuery{ event = encodeJSON( outputList, true ) }
		local dataUrl = self.urlBase .. '&' .. query
		self.client:get( dataUrl )

		-- for i, rawData in ipairs( outputList ) do
		-- 	local outputString = encodeJSON( outputList, true ) --no indent
		-- 	local output64 = base64( outputString )
		-- 	local dataUrl = url .. '?data=' .. output64
		-- 	self.client:get( dataUrl, nil, options )
		-- end
	elseif method == 'post' then
		-- local outputString = encodeJSON( outputList, true ) --no indent
		-- local output64 = base64( outputString )
		-- self.client:post( url, output64, options )
	end

end
