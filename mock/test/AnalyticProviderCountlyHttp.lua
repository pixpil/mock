module 'mock'

CLASS: AnalyticProviderCountlyHttp ( AnalyticProvider )
:register( 'countly_http' )

function AnalyticProviderCountlyHttp:__init()
end

function AnalyticProviderCountlyHttp:affirmDeviceID()
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

function AnalyticProviderCountlyHttp:onInit()
	if not game:getConfig( 'countly_enabled' ) then
		return false
	end
	self.apiKey = game:getConfig( 'countly_api_key' )
	if not self.apiKey then
		_warn( 'countly API key not defined' )
		return false
	end

	self.serverAddress = game:getConfig( 'countly_server')
	self.serverPort = game:getConfig( 'countly_port' )
	
	self.client = HTTPClient()

	self.httpOptions = {
		onResponse  = self:methodPointer( 'onHttpResponse' ),
		contentType = 'application/x-www-form-urlencoded',
	}
	
	_log( 'countly initialized' )
end

function AnalyticProviderCountlyHttp:makeQueryURL( ... )
	local out = self.urlBase
	for i, entry in ipairs( {...} ) do
		local query = url.buildQuery( entry )
		out = out .. '&' .. query
	end
	return out
end

function AnalyticProviderCountlyHttp:onHttpResponse( task, code )
	--TODO: keep unsent events?
	-- print( task, code )
end

function AnalyticProviderCountlyHttp:onPulse()
	local t1 = game:getTime()
	local delta = t1 - self.prevPulse
	self.prevPulse = t1
	self.client:get( 
		self:makeQueryURL{ session_duration = delta }
	)
end

function AnalyticProviderCountlyHttp:onSessionStart()
	self.prevPulse = game:getTime()
	self:affirmDeviceID()
	self.queryHeader = url.buildQuery{
		app_key = self.apiKey,
		device_id = self.deviceId,
	}
	self.urlBase = self.serverAddress .. ':' .. self.serverPort .. '/i?' .. self.queryHeader

	--TODO: metrics
	local osName = 'MacOS X'
	local osVersion = '10.13.6'
	local deviceName = 'MacBook Pro'
	local deviceResolution = '1440x900'
	local carrierName = ''
	local appVersion = '1.0'
	
	metrics ={
		_os = osName,
		_os_version = osVersion,
		_device = deviceName,
		_resolution = deviceResolution,
		_carrier = carrierName,
		_app_version = appVersion
	}

	local query = self:makeQueryURL(
			{ begin_session = 1 },
			{ metrics = encodeJSON( metrics, true ) }
	)
	-- print( query )
	self.client:get( query )
end

function AnalyticProviderCountlyHttp:onSessionStop()
	self.client:get( 
		self:makeQueryURL{ end_session = 1 }
	)
end

function AnalyticProviderCountlyHttp:onRecord( events )
	-- local countly = self.countly
	local eventQuery = {}
	for i, e in ipairs( events ) do
		local data = e.data
		local count = data and data.count or 1
		local sum = data and data.sum or nil
		eventBody = {
			key = e.type,
			count = count
		}
		if sum then
			eventBody.sum = sum
		end
		
		if data then
			data.count = nil
			data.sum = nil
			eventBody.segmentation = data
		end
		eventQuery[ i ] = eventBody
	end

	self.client:get(
		self:makeQueryURL{
			events = encodeJSON( eventQuery, true )
		}
	)
end
