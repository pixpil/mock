-- module 'mock'

-- CLASS: AnalyticProviderCountly ( AnalyticProvider )
-- :register( 'countly' )

-- function AnalyticProviderCountly:__init()
-- end

-- function AnalyticProviderCountly:onInit()
-- 	if not ( getG( 'MOAICountly' ) and game:getConfig( 'countly_enabled' )) then
-- 		return false
-- 	end
-- 	self.apiKey = game:getConfig( 'countly_api_key' )
-- 	if not self.apiKey then
-- 		_warn( 'countly API key not defined' )
-- 		return false
-- 	end
-- 	self.serverAddress = game:getConfig( 'countly_server')
-- 	self.serverPort = game:getConfig( 'countly_port' )
	
	
-- 	_log( 'countly initialized' )
-- 	--TODO: validation?
-- end

-- function AnalyticProviderCountly:onSessionStart()
-- 	--TODO: metrics
-- 	local osName = 'MacOS X'
-- 	local osVersion = '10.13.6'
-- 	local deviceName = 'MacBook Pro'
-- 	local deviceResolution = '1440x900'
-- 	local carrierName = ''
-- 	local appVersion = '1.0'
	
-- 	MOAICountly.setMetrics(
-- 		osName,
-- 		osVersion,
-- 		deviceName,
-- 		deviceResolution,
-- 		carrierName,
-- 		appVersion
-- 	)
-- 	MOAICountly.setPath( '.' )
-- 	print( 'start countly:', self.apiKey, self.serverAddress, self.serverPort )
-- 	MOAICountly.start( self.apiKey, self.serverAddress, self.serverPort )
-- 	MOAICountly.setMaxEventsPerMessage( 32 )
-- 	MOAICountly.setMinUpdatePeriod( 4 )
-- end

-- function AnalyticProviderCountly:onSessionStop()
-- 	print 'stop countly'
-- 	MOAICountly.stop()
-- end

-- function AnalyticProviderCountly:onRecord( events )
-- 	local countly = self.countly
-- 	for _, e in ipairs( events ) do
-- 		local data = e.data
-- 		local count = data and data.count or 1
-- 		local sum = data and data.sum
-- 		if data then
-- 			data = table.simplecopy( data )
-- 			data.count = nil
-- 			data.sum = nil
-- 		end
-- 		if data then
-- 			if sum then
-- 				MOAICountly.recordEvent( e.type, count, sum, data )
-- 			else
-- 				MOAICountly.recordEvent( e.type, count, data )
-- 			end
-- 		else
-- 			if sum then
-- 				MOAICountly.recordEvent( e.type, count, sum )
-- 			else
-- 				MOAICountly.recordEvent( e.type, count )
-- 			end
-- 		end
-- 	end
-- end
