module 'mock'

local _httpServerModules = {}
local _httpServer 

--------------------------------------------------------------------
CLASS: HTTPServer ( GlobalManager )
	:MODEL{}

function HTTPServer:__init()
	self.modules = {}
end

function HTTPServer:onStart( game )
	if game:isEditorMode() then return end --only for runtime

	if not game:getPlatformSupport():getNetworkState() then return end
	if not game:getConfig( 'http_server_enabled' ) then return end
	if not getG( 'MOCKHttpServer' ) then return end
	
	local port = game:getConfig( 'http_server_port', '21103' )
	local docRoot = game:getConfig( 'htdoc_root', '$USERDATA' )
	docRoot = docRoot:gsub( '$USERDATA', game:getUserDataPath()  )
	local serverOption = {
		listening_ports = port,
		-- document_root = docRoot,
		num_threads = "2",
	}

	local server = MOCKHttpServer.new()
	self.server = server
	_log( "start http server", port, docRoot )
	server:setListener ( MOCKHttpServer.EVENT_HANDLE_REQUEST, self:methodPointer( 'onHttpRequest' ) )
	server:start( serverOption )
	server:attach( game.sysActionRoot )
	
	connectGlobalSignalFunc( 'asset_reloader.script_update', function()
		self:refreshModules()
	end )
	
	self:refreshModules()
end

function HTTPServer:refreshModules()
	for _, m in pairs( self.modules ) do
		m:onUnload()
	end

	--load modules
	local modules = {}
	for path, clas in pairs( _httpServerModules ) do
		_log( "loading http module", path, clas )
		local serverModule = clas()
		serverModule:onInit()
		modules[ path ] = serverModule
	end
	self.modules = modules

end

local pcall = pcall
function HTTPServer:onHttpRequest( server, method, uri, queryString, headers )
	local ok, a, b, c =	pcall( function()
		if uri:startwith( '/' ) then
			uri = uri:sub( 2, -1 )
		end
		local m = self.modules[ uri ]
		if m then
			_stat( uri, queryString )
			local query = queryString and url.parseQuery( queryString ) or {}
			return m:onRequest( method, query, headers )
		else
			_stat( 'no respones', method, uri )
		end
	end )

	if ok then
		local code, mime, data = a,b,c
		return code, mime, data
	else
		_error( a )
		return nil
	end
end


--------------------------------------------------------------------
CLASS: HTTPServerModule ()

function HTTPServerModule.register( clas, path )
	_httpServerModules[ path ] = clas
end

function HTTPServerModule:__init()
end

function HTTPServerModule:onUnload()
end

function HTTPServerModule:onInit()
end

function HTTPServerModule:onRequest( method, query, headers )
end

function HTTPServerModule:sendOK()
	return self:sendText( 'ok' )
end

function HTTPServerModule:send200( mime, data )
	return 200, mime or 'text/plain', data or ''
end

function HTTPServerModule:send404()
	return 404
end

function HTTPServerModule:send500()
	return 500
end

function HTTPServerModule:sendData( mime, data )
	return self:send200( mime, data )
end

function HTTPServerModule:sendText( t )
	return self:sendData( 'text/plain', t )
end

function HTTPServerModule:sendAsJSON( data )
	local jsonText = encodeJSON( data )
	return self:sendData( 'application/json', jsonText )
end

function HTTPServerModule:sendRaw( data )
	return self:sendData( '	application/octet-stream', data )
end


--------------------------------------------------------------------
CLASS: HTTPServeModuleInfo ( HTTPServerModule )
:register( 'info' )

function HTTPServeModuleInfo:onRequest( method, query, headers )
	local info = game:getInfo()
	if query.id == 'title' then
		return self:sendText( info.title )
	else
		return self:sendAsJSON( info )
	end
end


--------------------------------------------------------------------
CLASS: HTTPServerCommandModule ( HTTPServerModule )

function HTTPServerCommandModule:onRequest( method, query, headers )
	local command = query.command
	if not command then return self:send404() end
	local cmdMethodName = 'cmd' .. command
	local func = self[ cmdMethodName ]
	if not func then
		return self:send404()
	else
		return func( self, query )
	end
end

function HTTPServerCommandModule:onCommand( cmd, query )
end

--------------------------------------------------------------------
_httpServer = HTTPServer()
function getHTTPServer()
	return _httpServer
end
