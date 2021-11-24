module 'mock'
local _giiSyncManager
--------------------------------------------------------------------
local queryHandlers = {}
--[[query mode:
	'game',
	'editor',
	'both'
]]
function registerSyncQueryHandler( handler, mode )
	mode = mode or 'game'
	local entry = {
		handler     = handler,
		allowGame   = mode == 'game' or mode == 'both',
		allowEditor = mode == 'editor' or mode == 'both',
	}
	table.insert( queryHandlers, entry )
end

if not getG( 'MOCKNetworkMgr' ) then return end

--------------------------------------------------------------------
local PORT = 27192
local BroadcastPORT = 200637

local SYNC_FIELDS = {
	'name',
	'loc',
	'scl',
	'rot',
	'piv',
	'visible',
	'color',
}

CLASS: GIISyncHost ()
--------------------------------------------------------------------
function GIISyncHost:__init()
	self.host = MOCKNetworkMgr.createHost()
	self.queryId = 0
	self.queries = {}
end

function GIISyncHost:getMode()
	return 'game'
end

function GIISyncHost:start()
	self:onStart()
end

function GIISyncHost:init()
	self.localPeer = self.host:getLocalPeer()
	self:initRPC()
	self:onInit()
end

function GIISyncHost:onStart()
end

function GIISyncHost:initRPC()
	local RPCTell = MOCKNetworkRPC.new()
	RPCTell:init(
		'TELL', 
		function( peer, msg, dataString )
			local data = MOAIMsgPackParser.decode( dataString )
			return self:procRemoteMsg( peer, msg, data ) 
		end,
		MOCKNetworkRPC.RPC_MODE_ALL
	)
	RPCTell:setArgs( 'pss' )
	self.host:registerRPC( RPCTell )
	self.RPCTell = RPCTell
end

function GIISyncHost:tellPeer( peer, msg, data )
	local dataString = MOAIMsgPackParser.encode( data )
	return self.host:sendRPCTo( peer, self.RPCTell, self.localPeer, msg, dataString )
end

function GIISyncHost:procRemoteMsg( peer, msg, data )
	emitGlobalSignal( 'gii_sync.remote_msg', peer, msg, data )
	-- _warn( 'remote_msg', peer, msg, data )
	if msg == 'query.start' then
		local result = self:procQuery( data )
		local queryId = data[ 'queryId' ]
		local output = {
			queryId = queryId,
			result = result,
		}
		self:tellPeer( peer, 'query.answer', output )
	elseif msg == 'query.answer' then
		self:onQueryAnswer( peer, msg, data )
	end

	return self:onRemoteMsg( peer, msg, data )

end

function GIISyncHost:onRemoteMsg( peer, msg, data )

end

function GIISyncHost:query( peers, key, context, callback )
	local qid = self.queryId + 1
	self.queryId = qid
	local query = {
		queryId = qid,
		key = key,
		callback = callback,
		context = context,
		time = os.clock()
	}
	self.queries[ qid ] = query
	self:sendQuery( peers, query )
end

function GIISyncHost:sendQuery( peers, query )
	if not peers then return end
	for _, peer in ipairs( peers ) do
		self:tellPeer( peer, 'query.start', query )
	end
end

function GIISyncHost:procQuery( data )
	local key = data.key
	local context = data.context
	local tt = type( key )
	local result = {}
	if tt == 'table' then
		for i, k in ipairs( key ) do
			result[ k ] = self:procQueryKey( k, context )
		end
	elseif tt == 'string' then
		result[ key ] = self:procQueryKey( key, context )
	else
		_warn( 'invalid query', tt )
	end
	return result
end

function GIISyncHost:procQueryKey( key, context )
	local mode = self:getMode()
	for i, entry in ipairs( queryHandlers ) do
		local handler = entry.handler
		local allowed = 
			( mode == 'game' and entry.allowGame ) or
			( mode == 'editor' and entry.allowEditor ) or
			false
		if allowed then
			local output = handler( key, context )
			if output then return output end
		end
	end
	return nil
end

function GIISyncHost:onQueryAnswer( peer, msg, data )
	local result = data.result or false
	local queryId = data.queryId
	local query = self.queries[ queryId ]
	if query then
		local callback = query.callback
		if callback then
			callback( peer, result )
		end 
		self.queries[ queryId ] = nil
	end
end

--------------------------------------------------------------------
CLASS: GIISyncEditorHost ( GIISyncHost )
	:MODEL{}

function GIISyncEditorHost:__init()
	self.connectedGames = {}
end

function GIISyncEditorHost:getMode()
	return 'editor'
end

function GIISyncEditorHost:isGameConnected()
	return next( self.connectedGames ) and true or false
end

function GIISyncEditorHost:addConnectedGame( peer )
	self.connectedGames[ peer ] = true
end

function GIISyncEditorHost:removeConnectedGame( peer )
	self.connectedGames[ peer ] = nil
end

function GIISyncEditorHost:onInit()
	self.host:setListener( MOCKNetworkHost.EVENT_CONNECTION_ACCEPTED, 
		function( host, client )
			local ip = dec2ip( client:getHostIP() )
			local accepted
			if ip == '127.0.0.1' then
				accepted = true
			elseif game:getConfig( 'gii_sync_client_ip' ) then
				if game:getConfig( 'gii_sync_client_ip' ) == '*' then
					accepted = true
				else
					accepted = string.match( ip, game:getConfig( 'gii_sync_client_ip' ))
				end
			else
				accepted = false
			end

			if accepted then
				self:addConnectedGame( client )
				_log( 'connected to game', client )
				_log( 'client IP:', ip )
			else
				_log( 'game ignored', ip )
				self.host:disconnectPeer( client )
			end
		end
	)

	self.host:setListener( MOCKNetworkHost.EVENT_CONNECTION_CLOSED, 
		function( host, client )
			_log( 'connection to game closed', client )
			self:removeConnectedGame( client )
		end
	)

	if not self.host:startServer( nil, PORT ) then
		_warn( 'failed to start gii sync server' )
	end
end

function GIISyncEditorHost:syncEntityChange( event, entity, component )
	if not entity then return end
	local entId = entity.__guid
	if not entId then return false end
	local scene = entity:getScene()
	local scenePath = scene and scene:getPath()
	if event == 'modify' then
		-- local objData = _serializeObject( entity )
		if not entity.components then return end
		local objData = _serializeObject( entity, nil, nil, nil, 'sync' )
		local comData = {}
		for com in pairs( entity.components ) do
			local comid = com.__guid
			if comid then
				comData[ comid ] = _serializeObject( com, nil, nil, nil, 'sync' )
			end
		end
		local data = {
			scn = scenePath,
			id  = entId,
			objData = objData,
			comData = comData
		}
		for peer in pairs( self.connectedGames ) do
			self:tellPeer( peer, 'entity.modified', data )
		end
		return true

	elseif event == 'remove' then
		local data = {
			scn = scenePath,
			id  = entId
		}
		for peer in pairs( self.connectedGames ) do
			self:tellPeer( peer, 'entity.removed', data )
		end

	elseif event == 'add' then
		if entity:isInstance( EntityGroup ) then
			--TODO
			return
		end
		local objData = serializeEntity( entity )
		local parent = entity:getParentOrGroup()
		local parentId = parent and parent.__guid
		if not parentId then return false end
		local data = {
			scn = scenePath,
			id  = entId,
			objData = objData,
			parentId = parentId
		}
		for peer in pairs( self.connectedGames ) do
			self:tellPeer( peer, 'entity.added', data )
		end

	elseif event == 'com_remove' then
		local comId = component and component.__guid
		if not comId then return end
		local data = {
			scn = scenePath,
			id  = comId,
			entityId = entId,
		}
		for peer in pairs( self.connectedGames ) do
			self:tellPeer( peer, 'component.removed', data )
		end

	elseif event == 'com_add' then
		local comId = component and component.__guid
		if not comId then return false end
		local objData = serialize( component )
		local data = {
			scn = scenePath,
			id  = comId,
			entityId = entId,
			objData = objData
		}
		for peer in pairs( self.connectedGames ) do
			self:tellPeer( peer, 'component.added', data )
		end

	elseif event == 'com_modify' then
		local comId = component and component.__guid
		if not comId then return false end
		local objData = _serializeObject( component, nil, nil, nil, 'sync' )
		local data = {
			scn = scenePath,
			id  = comId,
			entityId = entId,
			objData = objData
		}
		for peer in pairs( self.connectedGames ) do
			self:tellPeer( peer, 'component.modified', data )
		end
		return true

	end
end

function GIISyncEditorHost:tellConnectedPeers( msg, data )
	for peer in pairs( self.connectedGames ) do
		self:tellPeer( peer, msg, data )
	end
end

function GIISyncEditorHost:onRemoteMsg( peer, msg, data )
end

function GIISyncEditorHost:queryGame( key, context, callback )
	local peers = table.keys( self.connectedGames )
	return self:query( peers, key, context, callback )
end

--------------------------------------------------------------------
CLASS: GIISyncGameHost ( GIISyncHost )
	:MODEL{}

function GIISyncGameHost:__init()
	self.serverPeer = false
	self.connected = false

	self.remoteMouseX = 0
	self.remoteMouseY = 0
	self.overrideHostIP = false
end

function GIISyncGameHost:setOverrideHostIP( overrideHostIP )
	self.overrideHostIP = overrideHostIP
end

function GIISyncGameHost:getMode()
	return 'game'
end

function GIISyncGameHost:onInit()
	self.host:setListener( MOCKNetworkHost.EVENT_CONNECTION_ACCEPTED, 
		function()
			_log( 'connected to Gii' )
			self.connected = true
			self.serverPeer = self.host:getServerPeer()
			_log( 'server IP:', dec2ip( self.serverPeer:getHostIP() ) )
	end )

	self.host:setListener( MOCKNetworkHost.EVENT_CONNECTION_FAILED, 
		function()
			self:tryNextHost()
		end
	)

	self.host:setListener( MOCKNetworkHost.EVENT_CONNECTION_CLOSED, 
		function( host, server )
			_log( 'connection closed from Gii' )
			self.connected = false
		end
	)	
end

function GIISyncGameHost:onStart()
	if game:getConfig( 'gii_sync_enabled', true ) then
		self:connectToGii()
	end
end

function GIISyncGameHost:tryNextHost()
	game:callNextFrame( function()
		self.host:shutdown()
		self.tryingHostIdx = self.tryingHostIdx + 1
		local ip = self.hostIPs[ self.tryingHostIdx ]
		if ip then
			_log( 'trying to connect Gii:', ip, ':', PORT )
			if not self.host:connectServer( ip, PORT ) then	
				_log( 'failed to connect Gii:', ip, ':', PORT )
			end
		else
			_log( 'Gii not found.' )
		end
	end )
end

function GIISyncGameHost:connectToGii()
	if not game:getPlatformSupport():getNetworkState() then return end
	self.host:shutdown()
	local ipoption 
	if self.overrideHostIP then
		ipoption = self.overrideHostIP
	else
		ipoption = game:getConfig( 'gii_host_ip', '127.0.0.1' )
	end
	local iplist = ipoption:split( ';', true )
	self.hostIPs = iplist
	self.tryingHostIdx = 0
	return self:tryNextHost()
end

local function _findScene( path )
	for i, session in ipairs( game.sceneSessions ) do
		if session:getPath() == path then
			return session:getScene()
		end
	end
	return false
end

function GIISyncGameHost:onRemoteMsg( peer, msg, data )
	local scenePath = data and data.scn
	local scene = scenePath and _findScene( scenePath )
	
	if msg == 'entity.removed' then
		-- if not scene then return end
		local id = data.id
		for i, session in ipairs( game.sceneSessions ) do
			local scene = session:getScene()
			local ent = scene:findEntityByGUID( id )
			if ent then
				ent:tryDestroy()
				return
			end
		end
		
	elseif msg == 'entity.added' then
		if not scene then return end
		local pasteData = data.objData
		local parentId = data.parentId
		local parent = scene:findEntityOrGroupByGUID( parentId )
		if not parent then return end
		local ent = deserializeEntity( pasteData )
		if ent then
			print( 'new entity', ent, ent.__guid )
			parent:addChild( ent )
		end

	elseif msg == 'entity.modified' then
		if not scene then return end
		local id = data.id
		local objData = data.objData
		local ent = scene:findEntityByGUID( id )
		if not ent then return end
		_deserializeObject( ent, objData, nil, nil, nil, 'sync' )
		local comData = data.comData
		for com in pairs( ent.components ) do
			local id = com.__guid
			if id then
				local singleComData = comData[ id ]
				if singleComData then
					_deserializeObject( com, singleComData, nil, nil, nil, 'sync' )
				end
			end
		end

	elseif msg == 'component.modified' then
		if not scene then return end
		local comId = data.id
		local entId = data.entityId
		local objData = data.objData
		local ent = scene:findEntityByGUID( entId )
		if not ent then return end
		for com in pairs( ent.components ) do
			if com.__guid == comId then
				_deserializeObject( com, objData, nil, nil, nil, 'sync' )
			end
		end

	elseif msg == 'component.added' then
		if not scene then return end
		local comId = data.id
		local entId = data.entityId
		local objData = data.objData
		local ent = scene:findEntityByGUID( entId )
		if not ent then return end
		local com = deserialize( nil, objData )
		if com then
			ent:attach( com )
			com.__guid = comId
		end

	elseif msg == 'component.removed' then
		if not scene then return end
		local comId = data.id
		local entId = data.entityId
		local ent = scene:findEntityByGUID( entId )
		if not ent then return end
		for com in pairs( ent.components ) do
			if com.__guid == comId then
				return ent:detach( com )
			end
		end

	elseif msg == 'command.open_scene' then
		local path = data
		if path then
			return game:scheduleOpenSceneByPath( path, false )
		end

	elseif msg == 'command.run_script' then
		local script = data
		if script then
			local func, err = loadstring( script )
			if func then
				setfenv( func, _G )
				local res, err = pcall( func )
				if not res then
					_warn( 'error in execution:' )
					_warn( err )
				end
			else
				_warn( 'failed to load remote script' )
				_warn( err )
			end
		end

	elseif msg == 'remote_input' then
		self:processRemoteInput( data )
	end

end

function GIISyncGameHost:processRemoteInput( data )
	local ev = data[1]
	if ev == 'k' then
		local key = data[2]
		local down = data[3]
		return _sendKeyEvent( key, down )

	elseif ev == 'm' then
		local etype = data[2]
		local dx = data[3]
		local dy = data[4]
		local btn = data[5]
		local w, h = game:getDeviceResolution()
		self.remoteMouseX = math.clamp( self.remoteMouseX + dx, 0, w )
		self.remoteMouseY = math.clamp( self.remoteMouseY + dy, 0, h )
		return _sendMouseEvent( etype, self.remoteMouseX, self.remoteMouseY, btn )

	elseif ev == 'c' then
		return _sendCharEvent( data[2] )
		
	elseif ev == 'v' then
		local vibA, vibB = data[2], data[3]
		return _sendVibEvent( vibA, vibB )
	end
end

function GIISyncGameHost:queryEditor( key, context, callback )
	if not self.serverPeer then
		_error( 'sync server not connected' )
		return false
	end
	return self:query( { self.serverPeer }, key, context, callback )
end

function GIISyncGameHost:tellServer( msg, data )
	if not self.serverPeer then
		_error( 'sync server not connected' )
		return false
	end
	return self:tellPeer( self.serverPeer, msg, data )
end

--------------------------------------------------------------------

CLASS: GIISyncManager ( GlobalManager )
	:MODEL{}

function GIISyncManager:__init()
	_giiSyncManager = self
	self.host = false
	self.editorHost = false
	self.gameHost   = false
	self.gameHost2  = false
end

function GIISyncManager:postStart( game )
	self.host:start()	
	if self.gameHost2 then
		self.gameHost2:start()
	end
end

function GIISyncManager:postInit( game )
	if game:isEditorMode() then
		self.editorHost = GIISyncEditorHost()
		self.editorHost:init()
		self.host = self.editorHost
	else
		local ipoption = game:getConfig( 'gii_host_ip', '127.0.0.1' )
		if ipoption ~= '127.0.0.1' then
			self.gameHost2 = GIISyncGameHost()
			self.gameHost2:setOverrideHostIP( '127.0.0.1' )
			self.gameHost2:init()
		end

		self.gameHost = GIISyncGameHost()
		self.gameHost:init()
		self.host = self.gameHost
	end
end

function GIISyncManager:getHost()
	return self.host
end

function GIISyncManager:queryGame( key, context, callback )
	if game:isEditorMode() then
		return self.editorHost:queryGame( key, context, callback )
	else
		_error( 'Mock is not in editor mode' )
		return false
	end
end

function GIISyncManager:queryEditor( key, context, callback )
	if not game:isEditorMode() then
		return self.gameHost:queryEditor( key, context, callback )
	else
		_error( 'Mock is not in game mode' )
		return false
	end
end


--------------------------------------------------------------------
local allowNetwork = true
if MOAIEnvironment.osBrand == 'HTML5' then
	allowNetwork = false
end

if allowNetwork then
	GIISyncManager()
end


--------------------------------------------------------------------
function getGiiSyncHost()
	local sync = game:getGlobalManager( 'GIISyncManager' )
	return sync:getHost()
end

function getGiiSyncManager()
	return _giiSyncManager
end


--------------------------------------------------------------------
registerSyncQueryHandler( function( key )
		if key == 'scene.info' then
			local info = {
				path = game:getMainScene():getPath(),
			}
			return info
		end
	end
)


mock.registerSyncQueryHandler( function( key, context )
	if key == 'cmd.reopen_mainscene' then
		game:reopenMainScene()

	elseif key == 'cmd.open_scene' then
		local path = context[ 'path' ]
		game:scheduleOpenSceneByPath( path )

	elseif key == 'cmd.reload_script' then
		local reloadManager = game:getGlobalManager( 'AssetReloaderManager' )
		reloadManager:tryReloadScript()
	end

end )

--------------------------------------------------------------------
--short cut
GIISync = {}
function GIISync.showFileInOS( path )
	return getGiiSyncManager():queryEditor( 'cmd.show_file_os', { path = path } )
end

function GIISync.openFileInOS( path )
	return getGiiSyncManager():queryEditor( 'cmd.open_file_os', { path = path } )
end

function GIISync.locateAssetInEditor( path )
	return getGiiSyncManager():queryEditor( 'cmd.locate_asset_editor', { path = path } )
end

function GIISync.editAssetInEditor( path )
	return getGiiSyncManager():queryEditor( 'cmd.edit_asset_editor', { path = path } )
end

function GIISync.openFileInSublime( path, line )
	return getGiiSyncManager():queryEditor( 'cmd.open_file_sublime', { path = path, line = line } )
end
