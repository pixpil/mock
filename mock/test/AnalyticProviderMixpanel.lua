module 'mock'

CLASS: AnalyticProviderMixpanel ( AnalyticProvider )
:register( 'mixpanel' )

function AnalyticProviderMixpanel:__init()
end

function AnalyticProviderMixpanel:affirmDeviceID()
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


function AnalyticProviderMixpanel:onInit()
	if not game:getConfig( 'mixpanel_enabled' ) then
		return false
	end
	self.apiKey = game:getConfig( 'mixpanel_api_key' )
	if not self.apiKey then
		_warn( 'api_key_mixpanel API key not defined' )
		return false
	end
	self.apiUrl = string.format( 'http://api.mixpanel.com/track/' )
	self.client = HTTPClient()

	self.httpOptions = {
		onResponse  = self:methodPointer( 'onHttpResponse' ),
		contentType = 'application/x-www-form-urlencoded',
	}

	_log( 'Mixpanel initialized' )
	--TODO: validation?
end

function AnalyticProviderMixpanel:onHttpResponse( task, code )
	--TODO: keep unsent events?
	print( task, code )
end

function AnalyticProviderMixpanel:onSessionStart()
end

function AnalyticProviderMixpanel:onSessionStop()
end

local simplecopy = table.simplecopy
local insert = table.insert
local base64 = MOAIDataBuffer.base64Encode
function AnalyticProviderMixpanel:onRecord( events )
	-- body
	local url = self.apiUrl
	local options = self.httpOptions
	local deviceId = self.deviceId
	local batchSize = 0 --TODO: batch size
	local outputList = {}
	for _, e in ipairs( events ) do
		local properties = e.data and simplecopy( e.data ) or {}
		--fill required data
		properties.token = self.apiKey
		local rawData = {
			event = e.type,
			distinct_id = deviceId,
			properties = properties
		}
		insert( outputList, rawData )
	end
	
	local method = 'get'

	if method == 'get' then
		for i, rawData in ipairs( outputList ) do
			local outputString = encodeJSON( outputList, true ) --no indent
			local output64 = base64( outputString )
			local dataUrl = url .. '?data=' .. output64
			self.client:get( dataUrl, nil, options )
		end
	elseif method == 'post' then
		local outputString = encodeJSON( outputList, true ) --no indent
		local output64 = base64( outputString )
		self.client:post( url, output64, options )
	end

end
