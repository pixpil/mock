module 'mock'

local _assetReloaderManager

registerGlobalSignals{
	'asset_reloader.reopen_scene',
	'asset_reloader.script_update'
}

--------------------------------------------------------------------
CLASS: AssetReloader ()

function AssetReloader.register( clas, key )
	_assetReloaderManager:registerReloader( key, clas )
end

function AssetReloader:__init()
end

function AssetReloader:getPriority()
	return 1
end

function AssetReloader:onInit()
end

function AssetReloader:onAssetModified( node )
end

function AssetReloader:onTextureRebuild( node )
end

--------------------------------------------------------------------
CLASS: AssetReloaderManager ( GlobalManager )
	:MODEL{}

function AssetReloaderManager:__init()
	_assetReloaderManager = self
	self.modifiedLuaScript = {}
	self.reloaderClasses = {}
	self.reloaders = {}
	self.msgBox = {}
	self.textureUpdated = false
	self.autoReloadScript = false
end

function AssetReloaderManager:getKey()
	return 'AssetReloaderManager'
end

function AssetReloaderManager:postInit( game )
	local reloaders = {}
	for key, clas in pairs( self.reloaderClasses ) do
		local reloader = clas()
		table.insert( reloaders, reloader )
	end
	table.sort( reloaders, function( a, b ) return a:getPriority() > b:getPriority() end )
	self.reloaders = reloaders
	for i, reloader in ipairs( self.reloaders ) do
		reloader:onInit()
	end
	
	connectGlobalSignalFunc( 'gii_sync.remote_msg', self:methodPointer( 'onRemoteMsg' ) )

end

function AssetReloaderManager:setAutoReloadScript( active )
	self.autoReloadScript = active ~= false
end

function AssetReloaderManager:registerReloader( key, clas )
	self.reloaderClasses[ key ] = clas
end

function AssetReloaderManager:onUpdate()
	self:flushMsgBox()
end

local insert = table.insert
function AssetReloaderManager:onRemoteMsg( peer, msg, data )
	if msg == 'asset.modified'
		or msg == 'asset.register'
		or msg == 'asset.unregister'
		or msg == 'texture.rebuild'
	then
		insert( self.msgBox, { peer, msg, data } )
		if msg == 'texture.rebuild' then
			self.textureUpdated = true
		end
	end
end

function AssetReloaderManager:flushMsgBox()
	local msgBox = self.msgBox
	if #msgBox == 0 then return end
	self.msgBox = {}
	
	if self.textureUpdated then
		_stat( 'update texture library' )
		updateTextureLibrary()
		self.textureUpdated = false
	end
	
	local scriptModified = false
	for i, entry in ipairs( msgBox ) do
		local peer, msg, data = unpack( entry )
		if msg == 'asset.modified' then
			local path = data.nodePath
			local node = getAssetNode( path )
			releaseAsset( node )
			if node then
				updateAssetNode( node, data )
				for _, reloader in ipairs( self.reloaders ) do
					reloader:onAssetModified( node )
				end
				if node:getType() == 'lua' then
					self:onLuaScriptModified( node )
					scriptModified = true
				end
			end

		elseif msg == 'asset.register' then
			local path = data.nodePath
			registerAssetNode( path, data )

		elseif msg == 'asset.unregister' then
			local path = data
			unregisterAssetNode( path )

		elseif msg == 'texture.rebuild' then
			local path = data
			local node = getAssetNode( path )
			if node then
				for _, reloader in ipairs( self.reloaders ) do
					reloader:onTextureRebuild( node )
				end
			end
		end
	end

	if scriptModified then
		emitGlobalSignal( 'asset.script_modified' )
		if self.autoReloadScript or self.pendingScriptReload then
			self:updateLuaScript( true )
		end
	end

end


function AssetReloaderManager:onLuaScriptModified( node )
	self.modifiedLuaScript[ node ] = true
end

function AssetReloaderManager:isLuaScriptModified()
	if next( self.modifiedLuaScript ) then
		return true
	else
		return false
	end
end

function AssetReloaderManager:tryReloadScript()
	self.pendingScriptReload = true
	if self:isLuaScriptModified() then
		self:updateLuaScript( true )
	end
end

local function pathToModuleName( path )
	local name = stripext( path ):gsub( '/', '.' )
	return name
end

function AssetReloaderManager:updateLuaScript( reopenTargetScene )
	if not self:isLuaScriptModified() then return end
	self.pendingScriptReload = false
	local modified = self.modifiedLuaScript
	self.modifiedLuaScript = {}
	--verify first
	local pass = true
	for node in pairs( modified ) do 
		local path  = node:getPath()
		local filePath = node:getFilePath()
		local func, err = loadfile( filePath )
		if not func then 
			_error( 'error in script:', path, err )
			pass = false
		end
	end
	
	if not pass then return false end

	clearClassSearchCache()
	for node in pairs( modified ) do
		local path  = node:getPath()
		local moduleName = pathToModuleName( path )
		GameModule.updateGameModule( moduleName )
	end
	
	emitGlobalSignal( 'asset_reloader.script_update' )

	if reopenTargetScene then
		emitGlobalSignal( 'asset_reloader.reopen_scene' )
		game:reopenMainScene()
	end

end

AssetReloaderManager()
