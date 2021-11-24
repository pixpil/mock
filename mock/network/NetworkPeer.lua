module 'mock'

--------------------------------------------------------------------
CLASS: NetworkPeer ()
	:MODEL{}

function NetworkPeer:__init()
	self.mode = false
	self.localPeer = false
	self.moaiPeer = false
	self.RPCConfig = false
end

function NetworkPeer:getMoaiPeer()
	return self.moaiPeer
end

function NetworkPeer:isLocal()
	return false
end

function NetworkPeer:isRemote()
	return false
end

function NetworkPeer:RPC( id, ... )
	return self.localPeer:RPCTo( self, id, ... )	
end

function NetworkPeer:isClient()
	local peer = self.moaiPeer
	return peer and peer:getState() == MOCKNetworkPeer.PEER_STATE_CLIENT
end

function NetworkPeer:isServer()
	local peer = self.moaiPeer
	return peer and peer:getState() == MOCKNetworkPeer.PEER_STATE_SERVER
end

function NetworkPeer:isConnecting()
	local peer = self.moaiPeer
	return peer and peer:getState() == MOCKNetworkPeer.PEER_STATE_CONNECTING
end

function NetworkPeer:getIP()
	local peer = self.moaiPeer
	return peer and peer:getHostIP()
end

function NetworkPeer:getPort()
	local peer = self.moaiPeer
	return peer and peer:getPort()
end


local function __ipString(i)
   local ret = 
   	bit.band(i,0xFF) .."."..
   	bit.band(bit.rshift(i,8),0xFF) .."."..
   	bit.band(bit.rshift(i,16),0xFF) .."."..
   	bit.band(bit.rshift(i,24),0xFF) 
   return ret
end

function NetworkPeer:getAddressString()
	local peer = self.moaiPeer
	if peer then
		return string.format( '%s:%d',__ipString( self:getIP() ), self:getPort() )
	else
		return ('<no_connection>')
	end
end

function NetworkPeer:__tostring()
	return string.format( '%s(%s)', self:__repr(), self:getAddressString() )
end

---------------------------------------------------------------------
CLASS: NetworkRemotePeer ( NetworkPeer )
	:MODEL{}

function NetworkRemotePeer:__init()
end

function NetworkRemotePeer:isRemote()
	return true
end

function NetworkRemotePeer:init( moaiPeer )
	self.moaiPeer = moaiPeer
end

function NetworkRemotePeer:onInit( peer )
end


--------------------------------------------------------------------
CLASS: NetworkLocalPeer ( NetworkPeer )
	:MODEL{}
	:SIGNAL{
		peer_connected = 'onPeerConnected',
		peer_disconnected = 'onPeerDisconnected',
		connection_failed = 'onConnectionFailed',
	}

function NetworkLocalPeer:__init()
	local host = MOCKNetworkMgr.createHost()
	self.serverPeer = false
	self.moaiHost = host
	self.moaiPeer = host:getLocalPeer()
	self.moaiPeer.__mockPeer = self
	self.peerMap = {}

	--init listeners
	host:setListener( MOCKNetworkHost.EVENT_CONNECTION_ACCEPTED, 
		function( host, moaiPeer )
			return self:_addRemotePeer( moaiPeer )
		end
	)

	host:setListener( MOCKNetworkHost.EVENT_CONNECTION_CLOSED, 
		function( host, moaiPeer )
			return self:_removeRemotePeer( moaiPeer )
		end
	)

	host:setListener( MOCKNetworkHost.EVENT_CONNECTION_FAILED, 
		function()
			_log( 'connection failed' )
			return self.connection_failed:emit()
		end
	)
end


function NetworkLocalPeer:initRPC( RPCConfig )
	self.RPCConfig = RPCConfig
	return RPCConfig:registerForHost( self.moaiHost )
end

function NetworkLocalPeer:isLocal()
	return true
end

function NetworkLocalPeer:getPeer( moaiPeer )
	return self.peerMap[ moaiPeer ]
end

function NetworkLocalPeer:getMoaiHost()
	return self.moaiHost
end

function NetworkLocalPeer:createRemotePeer( targetMoaiPeer ) --virtual
	local peer = NetworkRemotePeer()
	peer:init( targetMoaiPeer )
	return peer
end

function NetworkLocalPeer:_addRemotePeer( moaiPeer )
	local peer = self:createRemotePeer( moaiPeer )
	peer.localPeer = self
	if not peer then 
		return false
	end
	_log( 'peer connected', peer )
	moaiPeer.__mockPeer = peer
	if peer:isServer() then
		self.serverPeer = peer
	end
	self.peerMap[ moaiPeer ] = peer
	return self.peer_connected:emit( peer )
end

function NetworkLocalPeer:_removeRemotePeer( moaiPeer )
	local peer = self.peerMap[ moaiPeer ]
	if peer then
		moaiPeer.__mockPeer = nil
		self.peerMap[ moaiPeer ] = nil --TODO: allow restruction?
		_log( 'peer disconnected', peer )
		return self.peer_disconnected:emit( peer )
	end
end


function NetworkLocalPeer:RPCTo( target, id, ... )
	local moaiHost = self.moaiHost
	local moaiPeer = target:getMoaiPeer()
	return self.RPCConfig:sendRPC( id, moaiHost, moaiPeer, ... )
end

function NetworkLocalPeer:getServerPeer()
	return self.serverPeer
end

function NetworkLocalPeer:startAsServer( localIP, localPort )
	self.mode = 'server'
	self.serverPeer = self
	return self.moaiHost:startServer( localIP, localPort )
end

function NetworkLocalPeer:startAsClient( serverIP, serverPort )
	self.mode = 'client'
	self.serverPeer = false
	return self.moaiHost:connectServer( serverIP, serverPort )
end

--------------------------------------------------------------------
--EVENTS

function NetworkLocalPeer:onPeerConnected( peer )
end

function NetworkLocalPeer:onPeerDisconnected( peer )
end

function NetworkLocalPeer:onConnectionFailed()
end

---------------------------------------------------------------------
local _getCurrentRPCPeers = MOCKNetworkHost.getCurrentRPCPeers
function getCurrentRPCPeers()
	local rpcSender, rpcTarget = _getCurrentRPCPeers()
	local senderPeer = rpcSender and rpcSender.__mockPeer
	local targetPeer = rpcTarget and rpcTarget.__mockPeer
	return senderPeer, targetPeer
end

function getCurrentRPCTarget()
	local rpcSender, rpcTarget = _getCurrentRPCPeers()
	return rpcTarget and rpcTarget.__mockPeer
end

function getCurrentRPCSender()
	local rpcSender, rpcTarget = _getCurrentRPCPeers()
	return rpcSender and rpcSender.__mockPeer
end