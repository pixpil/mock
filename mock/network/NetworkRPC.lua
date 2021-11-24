module 'mock'

local RPCModeMap = {
	all             = MOCKNetworkRPC.RPC_MODE_ALL,
	server          = MOCKNetworkRPC.RPC_MODE_SERVER,
	other           = MOCKNetworkRPC.RPC_MODE_OTHER,
	all_buffered    = MOCKNetworkRPC.RPC_MODE_ALL_BUFFERED,
	other_buffered  = MOCKNetworkRPC.RPC_MODE_OTHER_BUFFERED,
}

--------------------------------------------------------------------
CLASS: NetworkRPCConfig ()
	:MODEL{}

function NetworkRPCConfig:__init()
	self.RPCEntryList = {}
	self.RPCMap = {}
end

function NetworkRPCConfig:registerForHost( host )
	table.sort( self.RPCEntryList, function( a, b ) return a.__id < b.__id end )
	for i, rpc in ipairs( self.RPCEntryList ) do
		host:registerRPC( rpc )
	end
end

function NetworkRPCConfig:add( id, arguments, func, mode )
	local rpc = MOCKNetworkRPC.new()
	rpc:init(
		id,
		func,
		( mode and RPCModeMap[ mode ] ) or MOCKNetworkRPC.RPC_MODE_ALL
	)
	rpc:setArgs( arguments )
	self.RPCMap[ id ] = rpc
	rpc.__id = id
	rpc.__parentConfig = self
	table.insert( self.RPCEntryList, rpc )
	return rpc
end

function NetworkRPCConfig:sendRPC( id, host, peer, ... )
	local rpc = self.RPCMap[ id ]
	if rpc then
		return host:sendRPCTo( peer, rpc, ... )
	else
		error( 'no RPC defined', id )
	end
end
