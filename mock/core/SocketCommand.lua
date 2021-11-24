module 'mock'

local _socketCommandClass = {}

--------------------------------------------------------------------
CLASS: SocketCommandManager ( GlobalManager )
	:MODEL{}


function SocketCommandManager:__init()
	self.commands = {}
	self.server = false
	self.ok = false
	self.clients = {}
end

function SocketCommandManager:onInit( game )
	if game:isEditorMode() then return end --only for runtime
	if not game:getPlatformSupport():getNetworkState() then return end
	
	local osBrand = MOAIEnvironment.osBrand
	if osBrand == 'NS' then return end

	if not game:getConfig( 'socket_command_enabled' ) then return end
	self.socket = require 'socket'
	
	if not self.socket then return end
	self.ok = true
end

function SocketCommandManager:postStart()
	if not self.ok then return end
	self.server = self.socket.tcp()
	local host = game:getConfig( 'socket_command_host', '127.0.0.1' )
	local port = game:getConfig( 'socket_command_port', 0x6a37 )

	for name, clas in pairs( _socketCommandClass ) do
		local cmd = clas( name )
		cmd:init()
		self.commands[ name ] = cmd
	end

	self.server:setoption( 'reuseaddr', true )
	self.ok = self.server:bind( host, port )

	if self.ok then
		self.server:listen( 32 )
		self.server:settimeout( 0 )
		_log( 'started socket server', host, port )

	else
		_warn( 'failed to start socket server' )
	end
end


function SocketCommandManager:onStop()
	if self.server then
		self.server:close()
	end
end

function SocketCommandManager:onReceive( client, data )
	if not data then return end

	local cmdName, qmark, queryBody = string.match( data, '([%w_]+)(%??)(.*)' )
	local cmd = self.commands[ cmdName ]
	local query = qmark == '?' and url.parseQuery( queryBody ) or {}
	if cmd then
		cmd:exec( query )
	end
end

function SocketCommandManager:onSysUpdate()
	if not self.ok then return end
	local server = self.server
	
	--accept
	local client = server:accept()
	if client then
		self.clients[ client ] = true
		client:settimeout( 0 )
	end
	
	--command
	local closed = false
	for client in pairs( self.clients ) do
		local line, err = client:receive( '*l' )
		if not err then
			self:onReceive( client, line )
		elseif err == 'closed' then
			if not closed then closed = {} end
			closed[ client ] = true
		end
	end

	if closed then
		for c in pairs( closed ) do
			self.clients[ c ] = nil
		end
	end

end


--------------------------------------------------------------------
CLASS: SocketCommand ()

function SocketCommand.register( clas, name )
	_socketCommandClass[ name ] = clas
end

function SocketCommand:__init( name )
	self.ok = false
	self.name = name
end

function SocketCommand:init()
	if self:onInit() == false then
		self.ok = false
	else
		self.ok = true
	end
end

function SocketCommand:exec( query )
	if self.ok then
		_log( 'socket command', self.name, query )
		return self:onExec( query )
	end
end

function SocketCommand:onInit()
end

function SocketCommand:onExec( query )
end


--------------------------------------------------------------------
CLASS: SocektCommandTerminate ( SocketCommand )
:register( 'terminate' )

function SocektCommandTerminate:onExec( query )
	os.exit()
end


--------------------------------------------------------------------
SocketCommandManager()
