module ('mock')

--------------------------------------------------------------------
local REPORT_DEPRECATED_ASSET = true
local DEPRECATED_ASSET_LOG = 'DeprecatedAsset.json'

local _assetLogFile = false
local _deprecatedAssets = false
local _assetTagGroups = {}

local _assetMapping = false
local _assetMappingDisabled = false
local _newTable = mock_luaext.new_table

local function loadDeprecatedAssetList()
	if not _deprecatedAssets then
		_deprecatedAssets = mock.tryLoadJSONFile( DEPRECATED_ASSET_LOG ) or {}
	end
	return _deprecatedAssets
end

local function reportAssetDeprecation( assetNode, requester )
	local logList = loadDeprecatedAssetList()
	logList[ assetNode:getPath() ] = true
	-- saveJSONFile( logList, DEPRECATED_ASSET_LOG )
	-- _warn ( 'attempt to use DEPRECATED asset:', assetNode:getPath() or '???', requester )
	-- _warn ( singletraceback( 3 ) )
end

function setReportDeprecatedAsset( report )
	REPORT_DEPRECATED_ASSET = report ~= false
end

--------------------------------------------------------------------
registerGlobalSignals{
	'asset_library.loaded',
}

local setmetatable = setmetatable
local getmetatable = getmetatable

--------------------------------------------------------------------
local	bundleItemAssetTypes = {}
function registerBundleItemAssetType( t )
	bundleItemAssetTypes[ t ] = true
end

local function isBundleItemAssetType( t )
	return bundleItemAssetTypes[ t ] or false
end

--------------------------------------------------------------------
local __AssetCacheMap = {}
local __ASSET_NODE_READONLY = false

local function makeAssetNodeCacheTable( node )
	local cacheTable = {}
	__AssetCacheMap[ node ] = cacheTable
	return cacheTable
end

function _allowAssetCacheWeakMode( allowed )
	-- __ASSET_CACHE_WEAK_MODE = allowed and 'kv' or false
end

--------------------------------------------------------------------
local __pendingAssetInvalidate = {}
function flushAssetClear()
	for a in pairs( __pendingAssetInvalidate ) do
		a:invalidate()
		-- a:enableGC()
	end
	__pendingAssetInvalidate = table.cleared( __pendingAssetInvalidate )
end


local pendingAssetGarbageCollection = false
local _assetCollectionPreGC

function _doAssetCollection()
	_Stopwatch.start( 'asset_gc' )
	game:startBoostLoading()

	MOAISim.forceGC( 1 )

	game:stopBoostLoading()
	_Stopwatch.stop( 'asset_gc' )
	_log( _Stopwatch.report( 'asset_gc' ) )
end

function _assetCollectionPreGC()
	_doAssetCollection()
	MOAISim.setListener( MOAISim.EVENT_PRE_GC, nil ) --stop
			-- reportLoadedMoaiTextures()
			-- reportAssetInCache()
			-- reportHistogram()
			-- reportTracingObject()
end

--------------------------------------------------------------------
function collectAssetGarbage()
	local collectThread = MOAICoroutine.new()
	collectThread:run( function()
			while true do
				if not isAssetLoadTaskBusy() then break end
				coroutine.yield()
			end
			if MOAIRenderMgr.isAsync() then
				getRenderManager():addPostSyncRenderCall( _doAssetCollection )
			else
				MOAISim.setListener( MOAISim.EVENT_PRE_GC, _assetCollectionPreGC )
			end
		end
	)
	collectThread:attach( game:getSceneActionRoot() )
	return collectThread
end


--------------------------------------------------------------------

--tool functions
local function fixpath(p)
	p=string.gsub(p,'\\','/')
	return p
end

local match = string.match
local function _splitAssetPath( path )
	path = fixpath( path )
	local dir, file = match( path, '(.*)/(.*)' )
	if not dir then
		dir = ''
		file = path
	end
	return dir, file
end


local function stripExt(p)
	return string.gsub( p, '%..*$', '' )
end

local function stripDir(p)
	p=fixpath(p)
	return string.match(p, "[^\\/]+$")
end

--------------------------------------------------------------------
--asset index library
local AssetLibrary = {}
local AssetSearchCache = {}

local function _getAssetNode( path )
	return AssetLibrary[ path ]
end

--asset loaders
local AssetLoaderConfigs = setmetatable( {}, { __no_traverse = true } )

---env
local AssetLibraryIndex = false

function getAssetLibraryIndex()
	return AssetLibraryIndex
end

function getAssetLibrary()
	return AssetLibrary
end

--------------------------------------------------------------------
function loadAssetLibrary( indexPath, searchPatches )
	if MOAIEnvironment.osBrand == 'NS' then
		searchPatches = false
	end
	
	if not indexPath then
		_stat( 'asset library not specified, skip.' )
		return
	end

	local msgpackPath = indexPath .. '.packed'

	local useMsgPack = MOAIFileSystem.checkFileExists( msgpackPath )

	-- local useMsgPack = false
	_log( 'loading library from', indexPath )
	_Stopwatch.start( 'load_asset_library' )
	
	--json assetnode
	local indexData = false
	if useMsgPack then
		_log( 'use packed asset table', msgpackPath )
		indexData = loadMsgPackFile( msgpackPath )
	else
		indexData = tryLoadJSONFile( indexPath )
	end

	if not indexData then
		_error( 'can not parse asset library index file', indexPath )
		return
	end
	_Stopwatch.stopAndLog( 'load_asset_library' )

	_Stopwatch.start( 'load_asset_library' )
	
	AssetLibrary = _newTable( 0, 10000 ) --init with big hash space
	_Stopwatch.start( 'register_asset_nodes' )
	AssetSearchCache = _newTable( 0, 100 )
	local count = 0
	for path, value in pairs( indexData ) do
		--we don't need all the information from python
		count = count + 1
		-- if count % 1000 == 0 then
		-- 	print( 'registering asset',  count )
		-- end
		registerAssetNode( path, value, true )
	end
	AssetLibraryIndex = indexPath

	if searchPatches then
		--TODO: better asset patch storage
		findAndLoadAssetPatches( '../../asset_index_patch.json' )
		findAndLoadAssetPatches( '../asset_index_patch.json' )
		findAndLoadAssetPatches( 'asset_index_patch.json' )
	end
	emitSignal( 'asset_library.loaded' )
	_Stopwatch.stopAndLog( 'register_asset_nodes' )
	_log( 'asset registered', count )

	__ASSET_NODE_READONLY = true
	return true
end

local function _extendDeep( t0, t1 )
	for k, v1 in pairs( t1 ) do
		local v0 = t0[ k ]
		if v0 == nil then
			t0[ k ] = v1
		end
		if type( v0 ) == 'table' then
			if type( v1 ) ~= 'table' then
				return false
			end
			if not _extendDeep( v0, v1 ) then return false end
		else
			if type( v1 ) == 'table' then
				return false
			end
			t0[ k ] = v1
		end
	end
	return true
end

function findAndLoadAssetPatches( patchPath, noNew )
	if MOAIFileSystem.checkFileExists( patchPath ) then
		_log( 'loading asset patch', patchPath )
		local data = loadJSONFile( patchPath )
		if data then
			if noNew then
				local filtered = {}
				for path, item in pairs(data) do
					if getAssetNode( path ) then
						filtered[ path ] = item
					end
				end
				_extendDeep( AssetLibrary, filtered )
			else
				_extendDeep( AssetLibrary, data )
			end
		end
	end
end

--------------------------------------------------------------------
-- Asset Node
--------------------------------------------------------------------
CLASS: AssetNode ()
:MODEL{
	extra_size = 12
}

function AssetNode:__init()
	self.children = {}
	self.holders = false
	self.staticData = false
	self.parent   = false
	self.refcount = 0
end

function AssetNode:__tostring()
	return string.format( '%s|%s|%s', self:__repr(), self:getType(), self:getPath() or '???' )
end

function AssetNode:getName()
	return stripDir( self.path )
end

function AssetNode:getBaseName()
	return stripExt( self:getName() )
end

function AssetNode:getType()
	return self.type
end

function AssetNode:isVirtual()
	return not self.filePath
end

function AssetNode:affirmTagCache()
	local cache = self.tagCache
	if not cache then
		local p = self:getParentNode()
		if self.tags then
			cache = {}
			for i, t in ipairs( self.tags ) do
				cache[ t ] = true
			end
			if p then
				local c = p:affirmTagCache()
				for t in pairs( c ) do
					cache[ t ] = true
				end
			end
		else
			if p then
				cache = p:affirmTagCache()
			else
				cache = {}
			end
		end
		self.tagCache = cache
	end
	return cache
end


function AssetNode:hasTag( tag )
	local cache = self:affirmTagCache()
	return cache and cache[ tag ] or false
end

function AssetNode:getSiblingPath( name )
	local parent = self.parent
	if parent == '' then return name end
	return self.parent..'/'..name
end

function AssetNode:getChildPath( name )
	return self.path..'/'..name
end

function AssetNode:getChildren()
	return self.children
end

local function _collectAssetOf( node, targetType, collected, deepSearch )
	collected = collected or {}
	local t = node:getType()
	if ( not targetType ) or t:match( targetType ) then
		collected[ node.path ] = node
	end
	if deepSearch then
		for name, child in pairs( node.children ) do
			_collectAssetOf( child, targetType, collected, deepSearch )
		end
	end
	return collected
end

function AssetNode:enumChildren( targetType, deepSearch )
	local collected = {}
	for name, child in pairs( self.children ) do
		_collectAssetOf( child, targetType, collected, deepSearch )
	end
	return collected
end


local function _findChildAsset( node, name, targetType, deep, result )
	for childName, child in pairs( node.children ) do
		if childName == name or childName:match( name ) or child:getPath():match( name ) then
			local t = child:getType()
			if ( not targetType ) or t:match( targetType ) then
				if childName == name then
					result[ 1 ] = child
					return 'equal'
				else
					local result0 = result[1]
					if not result0 or ( child:getPath() < result0:getPath() ) then
						result[ 1 ] = child
					end
				end
			end
		end
		if deep then
			local result = _findChildAsset( child, name, targetType, deep, result )
			if result == 'equal' then return result end			
		end
	end
end

function AssetNode:findChild( name, targetType, deep )
	local result = {}
	_findChildAsset( self, name, targetType, deep, result )
	return result[ 1 ]
end

function AssetNode:getObjectFile( name )
	local objectFiles = self.objectFiles
	if not objectFiles then return false end
	return objectFiles[ name ]
end

function AssetNode:getProperty( name )
	local properties = self.properties
	return properties and properties[ name ]
end

function AssetNode:getDeployMeta( name )
	local meta = self.deployMeta
	return meta and meta[ name ]
end

function AssetNode:isDeprecated()
	return self:getProperty( 'deprecated' ) or self:getProperty( 'user_deprecated' )
end

function AssetNode:getPath()
	return self.path
end

function AssetNode:getNodePath()
	return self.path
end

function AssetNode:getFilePath( )
	return self.filePath
end

function AssetNode:getAbsObjectFile( name )
	local objectFiles = self.objectFiles
	if not objectFiles then return false end
	local path = objectFiles[ name ]
	if path then
		return getProjectPath( path )
	else
		return false
	end
end

function AssetNode:getAbsFilePath()
	return getProjectPath( self.filePath )
end

function AssetNode:getNonVirtualParentNode()
	local p = self:getParentNode()
	while p do
		if not p:isVirtual() then return p end
		p = p:getParentNode()
	end
	return nil
end

function AssetNode:getParentNode()
	if not self.parent then return nil end
	return AssetLibrary[ self.parent ]
end

function AssetNode:enableGC()
	self.gcDisabled = false
end

function AssetNode:disableGC()
	self.gcDisabled = true
end

function AssetNode:_affirmCache()
	local cache = __AssetCacheMap[ self ]
	if not cache then
		cache = makeAssetNodeCacheTable( self )
	end
	return cache
end

function AssetNode:getCacheData( key )
	local cache = __AssetCacheMap[ self ]
	return cache and cache[ key ]
end

function AssetNode:bindMoaiFinalizer( obj )
	if obj then
		-- return obj:setFinalizer( function() return self:invalidate() end )
	end
end

function AssetNode:setCacheData( key, data )
	local cache = __AssetCacheMap[ self ]
	cache[ key ] = data
end

function AssetNode:getCachedAsset()
	local cache = __AssetCacheMap[ self ]
	return cache and cache.asset
end

function AssetNode:invalidate()
	local cache = __AssetCacheMap[ self ]
	if not cache then return end
	-- if not self.holders then return end --not loaded?
	_stat( 'invalidate asset:', self )
	-- assert( not( next( self.holders	)) )
	--invalid no refed
	for name, child in pairs( self.children ) do
		-- print( 'invalidate child:', child )
		child:invalidate()
	end

	local atype  = self.type

	self.staticData = false
	local assetLoaderConfig =  AssetLoaderConfigs[ atype ]
	local unloader = assetLoaderConfig and assetLoaderConfig.unloader
	
	if unloader then
		local prevCache, prevAsset
		prevCache = table.simplecopy( cache )
		prevAsset = cache.asset
		table.clear( cache )
		unloader( self, prevAsset, cache, prevCache )

	else
		table.clear( cache )

	end
	
end


function AssetNode:setCachedAsset( data )
	local cache = __AssetCacheMap[ self ]
	cache.asset = data
end

function AssetNode:load()
	return loadAsset( self:getNodePath() )
end

function AssetNode:retainFor( holder )
	if self.gcDisabled then return end

	if self:isVirtual() then
		return holder:retainAsset( self:getNonVirtualParentNode() )

	else
		if not self.holders then
			self.holders = {}
		end
		if self.holders[ holder ] then return end
		self.holders[ holder ] = true
		self.refcount = self.refcount + 1 
		
		__pendingAssetInvalidate[ self ] = nil	
	end
end

function AssetNode:releaseFor( holder )
	if self.gcDisabled then return end
	
	local holders = self.holders
	if not ( holders and holders[ holder ] ) then return end

	-- print( 'release', holder, self )
	-- print(debug.traceback())

	holders[ holder ] = nil
	self.refcount = self.refcount - 1
	if self.refcount == 0 then
		__pendingAssetInvalidate[ self ] = true
	end
end

--------------------------------------------------------------------
-- local rawset = rawset
-- function AssetNode:__newindex( k, v )
-- 	if __ASSET_NODE_READONLY then
-- 		return error( 'trying to change readonly AssetNode ')
-- 	end
-- 	return rawset( self, k, v )
-- end

local newAssetNode = AssetNode.__new
local function _newAssetNode( path, force )
	local node = newAssetNode()
	node.path = path or ''
	node.type = '' --not ready
	AssetLibrary[ path ] = node
	return node
end

local function _affirmAssetNode( path, force )
	local node
	node = AssetLibrary[ path ]
	if not node then
		node = _newAssetNode( path )
	end
	return node
end

local _skipEmptyTable = function( a )
	if not a then return nil end
	if not next( a ) then return nil end
	return a
end

local function updateAssetNode( node, data ) --dynamic attributes
	node.type        = data['type']
	node.properties  = _skipEmptyTable( data['properties'] )
	node.objectFiles = _skipEmptyTable( data['objectFiles'] )
	node.deployMeta  = _skipEmptyTable( data['deployMeta'] )
	node.dependency  = _skipEmptyTable( data['dependency'] )
	-- node.deploy      = data['deploy'] == true
	-- node.fileTime    = data['fileTime']
end

local function registerAssetNode( path, data, init )
	local ppath, name = _splitAssetPath( path )
	if ppath == '' then ppath = false end

	local node
	node = _affirmAssetNode( path )

	node.name        = name
	node.parent      = ppath
	node.path        = path
	node.type        = data['type']
	node.filePath    = data['filePath']

	node.tags      = data['tags'] or false
	updateAssetNode( node, data )
	AssetLibrary[ path ] = node
	
	if node.tags then
		local tags = node.tags
		for i = 1, #tags do
			local t = tags[ i ]
			local reg = _assetTagGroups[ t ]
			if reg then
				reg[ path ] = node
			end
		end
	end

	if ppath then
		local pnode = _affirmAssetNode( ppath )
		node.parentNode = pnode
		pnode.children[ name ] = node
	end
	return node
end


function unregisterAssetNode( path )
	local node = AssetLibrary[ path ]
	if not node then return end
	for name, child in pairs( node.children ) do
		unregisterAssetNode( child.path )
	end
	releaseAsset( node )
	local pnode = node.parentNode
	if pnode then
		pnode.children[ node.name ] = nil
	end
	node.parentNode = nil
	AssetLibrary[ path ] = nil
	__AssetCacheMap[ node ] = nil
end

function getAssetNode( path )
	return _getAssetNode( path )
end

function checkAsset( path )
	return AssetLibrary[ path ] ~= nil
end

function matchAssetType( path, pattern, plain )
	local t = getAssetType( path )
	if not t then return false end
	if plain then
		return t == pattern and t or false
	else
		return t:match( pattern ) and t or false
	end
end

function getAssetType( path )
	local node = _getAssetNode( path )
	return node and node.type
end

--------------------------------------------------------------------
--loader: func( assetType, filePath )
function registerAssetLoader( assetType, loader, unloader, option )
	assert( loader )
	option = option or {}
	AssetLoaderConfigs[ assetType ] = {
		loader      = loader,
		unloader    = unloader or false,
		skip_parent = option['skip_parent'] or false,
		option      = option
	}
end

--------------------------------------------------------------------
--put preloaded asset into AssetNode of according path
function preloadIntoAssetNode( path, asset )
	local node = _getAssetNode( path )
	if node then
		node:setCachedAsset( asset )
		return asset
	end
	return false
end


--------------------------------------------------------------------
function findAssetNode( path, assetType )
	local tag = path..'|'..( assetType or '' )	
	local result = AssetSearchCache[ tag ]
	if result == nil then
		for k, node in pairs( AssetLibrary ) do
			local typeMatched = false
			local deprecated = node:hasTag( 'deprecated' )
			if deprecated then
				typeMatched = false
			else
				if not assetType then
					typeMatched = true
				else
					if string.match( node:getType(), assetType ) then
						typeMatched = true
					end
				end
			end

			if typeMatched then
				if k == path then
					result = node
					break
				elseif k:endwith( path ) then
					result = node
					break
				elseif stripExt( k ):endwith( path ) then
					result = node
					break
				end
			end
		end
		AssetSearchCache[ tag ] = result or false
	end
	return result or nil
end	

function affirmAsset( pattern, assetType )
	local path = findAsset( pattern, assetType )
	if not path then
		_error( 'asset not found', pattern, assetType or '<?>' )
	end
	return path
end

function findAsset( path, assetType )
	local node = findAssetNode( path, assetType )
	return node and node.path or nil
end

function findChildAsset( parentPath, name, assetType, deep )
	assert( parentPath )
	assert( name )
	deep = deep ~= false
	local parentNode = getAssetNode( parentPath )
	if not parentNode then
		_error( 'no parent asset:', parentPath )
		return
	end
	local node = parentNode:findChild( name, assetType, deep )
	return node and node.path or nil	
end


function findAndLoadAsset( path, assetType )
	local node = findAssetNode( path, assetType )
	if node then
		return loadAsset( node.path )
	end
	return nil
end


--------------------------------------------------------------------
--load asset of node
--------------------------------------------------------------------
local loadingAsset = table.weak_k() --TODO: a loading list avoid cyclic loading?

function isAssetLoading( path )
	return loadingAsset[ path ] and true or false
end

function setAssetMappingDisabled( disabled )
	_assetMappingDisabled = disabled ~= false
end

function setAssetMapping( mapping )
	_assetMapping = mapping or false
end

function hasAsset( path )
	local node = _getAssetNode( path )
	return node and true or false 
end

function canPreload( path ) --TODO:use a generic method for arbitary asset types
	local node = _getAssetNode( path )
	if not node then return false end
	if node.type == 'scene' then return false end
	if node:hasTag( 'no_preload' ) then return false end
	return true
end

-- local AdHocAssetRegistry = table.weak() --todo: is weak safe?
-- local AdHocAssetRegistry = {}
local AdhocAssetMT = {
	__tostring = function( t ) return 'AdHocAsset:'..tostring( t.__traceback ) end
}

function AdHocAsset( object )
	local traceback = debug.traceback()
	local box = setmetatable( {	object, __traceback = traceback }, AdhocAssetMT )
	-- AdHocAssetRegistry[ box ] = object
	return box
end

function isAdHocAsset( box )
	-- return AdHocAssetRegistry[ box ] and true or false
	local mt = getmetatable( box )
	return mt == AdhocAssetMT
end

local assetLoadTimers = {}
local assetLoadCounts = {}

function clearAssetLoadTimers()
	assetLoadTimers = {}
	assetLoadCounts = {}
end

function reportAssetLoadTimers()
	if checkLogLevel( 'stat' ) then
		_log( 'asset loading time:')
		for _, k in ipairs( table.sortedkeys( assetLoadTimers )) do
			printf( '\t\t%s\t%.2f\t%d', k, assetLoadTimers[ k ]*1000, assetLoadCounts[ k ] )
		end
	end
end

function loadAssetInternal( path, option, warning, requester, nomapping )
	if isAdHocAsset( path ) then
		local adhocAsset = path
		return adhocAsset[ 1 ], false
	end
	-- local adhocAsset = AdHocAssetRegistry[ path ]
	-- if adhocAsset then return adhocAsset, false end
	
	if not path   then return nil end
	
	if path == '' then return nil end
	
	if path:startwith( '$' ) then
		path = findAsset( path:sub( 2, -1 ) )
	end

	if not _assetMappingDisabled then
		if _assetMapping and not nomapping then
			local mapped = _assetMapping[ path ]
			if mapped then
				return loadAssetInternal( mapped, option, warning, requester, true )
			end
		end
	end

	option = option or {}
	local policy   = option.policy or 'auto'
	local node     = _getAssetNode( path )
	
	if not node then 
		if warning ~= false then
			_warn ( 'no asset found', path or '???', requester )
			_warn ( singletraceback( 2 ) )
		end
		return nil
	end
	
	if REPORT_DEPRECATED_ASSET and node:isDeprecated() then
		reportAssetDeprecation( node, requester )		
	end

	
	if policy ~= 'force' then
		local asset  = node:getCachedAsset()
		if asset then
			_stat( 'get asset from cache:', path, node )
			return asset, node
		end
	end

	_stat( 'loading asset from:', path )
	if policy ~= 'auto' and policy ~='force' then return nil end
	
	local atype  = node.type
	if atype == 'folder' then
		node:_affirmCache().asset = true
		return true, node
	end

	local loaderConfig = AssetLoaderConfigs[ atype ]
	if not loaderConfig then
		if warning ~= false then
			_warn( 'no loader config for asset', atype, path )
		end
		return false
	end
	
	local t0 = os.clock()
	if node.parent and ( not ( loaderConfig.skip_parent or option['skip_parent'])) then
		if not loadingAsset[ node.parent ] then
			loadAssetInternal( node.parent, option )
		end
		local cachedAsset = node:getCachedAsset()
		if cachedAsset then 
			return cachedAsset, node
		end --already preloaded		
	end

	--load from file
	local loader = loaderConfig.loader
	if not loader then
		_warn( 'no loader for asset:', atype, path )
		return false
	end
	loadingAsset[ path ] = true
	node:_affirmCache()
	local asset, canCache  = loader( node, option )	
	loadingAsset[ path ] = nil
	local loadDuration = os.clock() - t0
	assetLoadTimers[ atype ] = (assetLoadTimers[ atype ] or 0) + loadDuration
	assetLoadCounts[ atype ] = (assetLoadCounts[ atype ] or 0) + 1
	_statf( 'loaded: %s  (%.1f)', path, loadDuration * 1000 )

	if asset then
		if canCache ~= false then
			node:setCachedAsset( asset )
		end
		return asset, node
	else
		_stat( 'failed to load asset:', path )
		return nil
	end
end

function tryLoadAsset( path, option ) --no warning
	return loadAssetInternal( path, option, false )
end

function forceLoadAsset( path ) --no cache
	return loadAssetInternal( path, { policy = 'force' } )
end

function loadMockAsset( path )
	path = '__mock/'..path
	return loadAssetInternal( path )
end

function getCachedAsset( path )
	if path == '' then return nil end
	if not path   then return nil end
	local node   = _getAssetNode( path )
	if not node then 
		_warn ( 'no asset found', path or '???' )
		return nil
	end
	return node:getCachedAsset()
end


--------------------------------------------------------------------
function releaseAsset( asset )
	local node
	if type( asset ) == 'string' then
		node = _getAssetNode( asset )
		if not node then
			_warn( 'no asset found', asset )
			return false
		end
	elseif isInstance( asset, AssetNode ) then
		node = asset
	end
	if node then
		node:invalidate()
		_stat( 'released node asset', node )
	end
	return true
end


--------------------------------------------------------------------
function reportAssetInCache( typeFilter )
	local output = {}
	if type( typeFilter ) == 'string' then
		typeFilter = { typeFilter }
	elseif type ( typeFilter ) == 'table' then
		typeFilter = typeFilter
	else
		typeFilter = false
	end
	for path, node in pairs( AssetLibrary ) do
		local atype = node:getType()
		if atype ~= 'folder' and node:getCachedAsset() then
			local matched
			if typeFilter then
				matched = false
				for i, t in ipairs( typeFilter ) do
					if t == atype then
						matched = true
						break
					end
				end
			else
				matched = true
			end
			if matched then
				table.insert( output, { path, atype, node:getCachedAsset() } )
			end
		end
	end
	local function _sortFunc( i1, i2 )
		if i1[2] == i2[2] then
			return i1[1] < i2[1]
		else
			return i1[2] < i2[2]
		end
	end
	table.sort( output, _sortFunc )
	for i, item in ipairs( output ) do
		printf( '%s \t %s', item[2], item[1]  )
	end
end

--------------------------------------------------------------------
function loadAssetFolder( path )
	local node = _getAssetNode( path )
	if not ( node and node:getAssetType() == 'folder' ) then 
		return _warn( 'folder path expected:', path )
	end
	
end

function isAssetLoadTaskBusy()
	local busy = isTextureLoadTaskBusy()
	return isTextureLoadTaskBusy() --TODO: other thread?
end

--------------------------------------------------------------------
function registerAssetTagGroup( key )
	_assetTagGroups[ key ] = _assetTagGroups[ key ] or {}
end

function getAssetTagGroup( key )
	return _assetTagGroups[ key ]
end

_M.registerAssetNode = registerAssetNode
_M.updateAssetNode = updateAssetNode