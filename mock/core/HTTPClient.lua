module 'mock'

local insert, remove = table.insert, table.remove

local _httpClientManager
---------------------------------------------------------------------
CLASS: HTTPClient ()

function HTTPClient:__init()
	self.requests = {}
	self.activeTasks = {}
	self.taskPool = {}
	self.timeout = 10
	self.maxConnection = 5
	self.defaultContentType = 'text/plain'
	_httpClientManager:addClient( self )
end

function HTTPClient:setMaxConnection( conn )
	self.maxConnection = conn or 5
end

function HTTPClient:setDefaultContentType( contentType )
	self.defaultContentType = contentType or 'text/plain'
end

function HTTPClient:getConnectionCount()
	return table.len( self.activeTasks )
end

function HTTPClient:setTimeout( t )
	self.timeout = t or 10
end

function HTTPClient:update()
	self.needUpdate = false
	local requests = self.requests
	local activeTasks = self.activeTasks
	local null = {}
	local count = table.len( activeTasks )
	local processed = 0
	while true do
		local request = remove( requests, 1 )
		if not request then break end
		local method = request[1]
		local options= request[2] or null
		local user_agent   = options.userAgent
		local verbose      = options.verbose
		local blocking     = options.blocking
		local timeout      = options.timeout
		
		local contentType  = options.contentType or self.defaultContentType
		
		local onResponse   = options.onResponse
		
		local task = self:requestHttpTask()
		if timeout then
			task:setTimeout( timeout )
		end
		task._onResponse = onResponse or false
		local url    = request[3]
		local data   = request[4]
		if method == 'get' then
			_stat( 'http get', url )
			task:httpGet( url, user_agent, verbose, blocking )
		elseif method == 'post' then
			if contentType then
				task:setHeader( 'Content-Type', contentType )
			end
			_stat( 'http post', url, contentType )
			task:httpPost( url, data, user_agent, verbose, blocking )
		end
		count = count + 1
		processed = processed + 1
		if count >= self.maxConnection then break end
	end
end

function HTTPClient:scheduleUpdate()
	self.needUpdate = true
end

function HTTPClient:get( url, args, options )
	local request = {	'get', options, url }
	insert( self.requests, request )
	self:scheduleUpdate()
end

function HTTPClient:post( url, data, options )
	local request = {	'post', options, url, data }
	insert( self.requests, request )
	self:scheduleUpdate()
end

function HTTPClient:requestHttpTask()
	local task = remove( self.taskPool, 1 )
	if not task then
		task = MOAIHttpTask.new()
		task:setCallback( self:methodPointer( 'onHttpResponse' ) )
		task:setTimeout( self.timeout )
		self.activeTasks[ task ] = true
	end
	return task
end

function HTTPClient:onHttpResponse( task, code )
	_stat( 'http response', task, code )
	local onResponse = task._onResponse
	if onResponse then
		onResponse( task, code )
	end
	--return to pool
	self.activeTasks[ task ] = nil
	task._onResponse = false
	insert( self.taskPool, task )
	self:scheduleUpdate()
end


---------------------------------------------------------------------
CLASS: HTTPClientManager ( GlobalManager )

function HTTPClientManager:__init()
	self.clients = table.weak_k()
end

function HTTPClientManager:onUpdate()
	for client in pairs( self.clients ) do
		if client.needUpdate then
			client:update()
		end
	end
end

function HTTPClientManager:addClient( client )
	self.clients[ client ] = true
end


--------------------------------------------------------------------
function getHTTPClientManager()
	return _httpClientManager
end

_httpClientManager = HTTPClientManager()