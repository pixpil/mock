module 'mock'

local insert = table.insert

--------------------------------------------------------------------
local _analyticProviders = {}
local _analyticEventTypes = {}
local _analyticManager = false

function registerAnalyticEvent( etype, clas )
	if _analyticEventTypes[ etype ] then
		_warn( 'duplicated event type', etype )
	end
	_analyticEventTypes[ etype ] = clas or AnalyticEvent
end

function registerAnalyticEvents( t )
	for _, entry in pairs( t ) do
		if type( entry ) == 'table' then
			etype, eclas = unpack( entry )
			registerAnalyticEvent( etype, eclas )
		elseif type( entry ) == 'string' then
			registerAnalyticEvent( entry )
		end
	end
end

---------------------------------------------------------------------
CLASS: AnalyticEvent ()
	:MODEL{}

function AnalyticEvent.register( clas, name )
	registerAnalyticEventType( name, clas )
end

function AnalyticEvent:__init( type, data )
	self.type = type
	self.data = data or false
	self.time = os.time()
	self.level = false
end

function AnalyticEvent:setData( key, value )
	self.data[ key ] = value
end

function AnalyticEvent:getData( key )
	return self.data[ key ]
end


--------------------------------------------------------------------
CLASS: AnalyticProvider ()

function AnalyticProvider.register( clas, name )
	_analyticProviders[ name ] = clas
end

function AnalyticProvider:__init()
end

function AnalyticProvider:onInit()
end

function AnalyticProvider:onRecord( events )
end

function AnalyticProvider:onPulse()
end

function AnalyticProvider:onSessionStart()
end

function AnalyticProvider:onSessionStop()
end

function AnalyticProvider:isBusy()
	return false
end

--------------------------------------------------------------------
CLASS: AnalyticManager ( GlobalManager )

function AnalyticManager:__init()
	self.providers = {}
	self.pendingEvents = false
	self.pulseInterval = 10
	self.pulseTimer = 0
	self.maxPendingEvents = 32
	self.pendingEventsCount = 0
end

function AnalyticManager:onInit( game )
	local providers = {}
	for name, clas in pairs( _analyticProviders ) do
		local provider = clas()
		if provider:onInit() ~= false then
			providers[ name ] = provider
		end
	end
	self.providers = providers
end

function AnalyticManager:onStart( game )
	self.pulseTimer = game:getTime()
	for name, provider in pairs( self.providers ) do
		provider:onSessionStart()
	end
	self:recordEvent( 'session_start' )
end

function AnalyticManager:onStop( game )
	for name, provider in pairs( self.providers ) do
		provider:onSessionStop()
	end
	self:recordEvent( 'session_stop' )
end

function AnalyticManager:onUpdate()	
	local t1 = game:getTime()
	local dt = t1 - self.pulseTimer

	if dt >= self.pulseInterval then
		self.pulseTimer = self.pulseTimer + self.pulseInterval
		for name, provider in pairs( self.providers ) do
			provider:onPulse()
		end
		self:flushEvents()
	end

end

function AnalyticManager:flushEvents()
	local pendingEvents = self.pendingEvents
	if pendingEvents then
		for name, provider in pairs( self.providers ) do
			provider:onRecord( pendingEvents )
		end
		self.pendingEvents = false
		self.pendingEventsCount = 0
	end
end

function AnalyticManager:recordEvent( etype, data )
	local clas = _analyticEventTypes[ etype ]
	if not clas then
		return _error( 'Analytic Event not registered: ', etype )
	end
	local ev = clas( etype, data )
	local pending = self.pendingEvents
	if not pending then
		pending = {}
		self.pendingEvents = pending
	end
	insert( pending, ev )
	self.pendingEventsCount = self.pendingEventsCount + 1
	if self.pendingEventsCount > self.maxPendingEvents then
		self:flushEvents()
	end
	return ev
end


--------------------------------------------------------------------
_analyticManager = AnalyticManager()

function getAnalyticManager()
	return _analyticManager
end

--------------------------------------------------------------------
local function nullFunction()
end

local function analyticRecord( eventType, data )
	return _analyticManager:recordEvent( eventType, data )
end

--------------------------------------------------------------------
_AnalyticRecord = analyticRecord


registerAnalyticEvents{ 'session_start', 'session_stop' }
