module 'mock'



local TexturePendingRelease = {}
function flushTextureRelease()
	for tex in pairs( TexturePendingRelease ) do
		tex:purge()
	end
	TexturePendingRelease = table.cleared( TexturePendingRelease )
end

--------------------------------------------------------------------
function makeSolidTexture( w, h, r,g,b,a )
	local img = MOAIImage.new()
	img:init( 1,1 )
	img:fillRect( 0,0, w, h, r,g,b,a )
	local texture = MOAITexture.new()
	texture:load( img, MOAIImage.TRUECOLOR, 'solid', true )
	return texture
end

--------------------------------------------------------------------
local texturePlaceHolder      = false
local texturePlaceHolderImage = false

function getTexturePlaceHolderImage( w, h )
	if not texturePlaceHolderImage then
		w, h = w or 32, h or 32
		texturePlaceHolderImage = MOAIImage.new()
		texturePlaceHolderImage:init( w, h )
		texturePlaceHolderImage:fillRect( 0,0, w, h, 0, 1, 0, 1 )
	end
	return texturePlaceHolderImage
end

function getTexturePlaceHolder()
	if not texturePlaceHolder then
		texturePlaceHolder = MOAITexture.new()
		texturePlaceHolder:load( getTexturePlaceHolderImage( 32, 32 ) )		
	end
	return texturePlaceHolder
end

local _whiteTexture = false
local _blackTexture = false
local _emptyTexture = false

function getWhiteTexture()
	if not _whiteTexture then
		_whiteTexture = makeSolidTexture( 1,1,1,1,1,1 )
	end
	return _whiteTexture
end

function getEmptyTexture()
	if not _emptyTexture then
		_emptyTexture = makeSolidTexture( 1,1,0,0,0,0 )
	end
	return _emptyTexture
end

function getBlackTexture()
	if not _blackTexture then
		_blackTexture = makeSolidTexture( 1,1,0,0,0,1 )
	end
	return _blackTexture
end

--------------------------------------------------------------------
local textureLibrary = false
local textureLibraryIndex = false
function getTextureLibrary()
	return textureLibrary
end

function preloadTextureGroup( groupName )
	local group = textureLibrary:getGroup( groupName )
	return group:_preloadAll()
end

function initTextureLibrary( indexPath )
	textureLibrary = TextureLibrary()	
	textureLibrary:initDefault()
	return textureLibrary
end

function loadTextureLibrary( indexPath )
	if not indexPath then return end
	_stat 'init texture library'
	textureLibraryIndex = indexPath
	textureLibrary = TextureLibrary()	
	if MOAIFileSystem.checkFileExists( indexPath ) then
		textureLibrary:load( indexPath )
	else
		textureLibrary:initDefault()
	end
	return textureLibrary
end

function updateTextureLibrary()
	local indexPath = textureLibraryIndex
	local lib1 = TextureLibrary()
	if MOAIFileSystem.checkFileExists( indexPath ) then
		lib1:load( indexPath )
	else
		return false
	end
	local lib0 = textureLibrary
	local updatedGroups = {}
	for i, group1 in ipairs( lib1.groups ) do
		local group0 = lib0:getGroup( group1.name )
		if not group0 then --new group
			group0 = lib0:addGroup()
			cloneData( group1, group0 )
		else
			updatedGroups[ group1.name ] = true
		end
	end

	--find removed group
	local removedGroups = {}
	for i, group0 in ipairs( lib0.groups ) do
		if not updatedGroups[ group0.name ] then
			removedGroups[ group0 ] = true
		end
	end

	for g in pairs( removedGroups ) do
		local idx = table.index( lib0.groups, g )
		if idx then
			table.remove( lib0.groups, idx )
		end
		g.parent = false
	end

	--
	for path, tex1 in pairs( lib1.textureMap ) do
		local tex0 = lib0.textureMap[ path ]
		if not tex0 then --new
			local group0 = lib0:getGroup( tex1.parent.name )
			tex0 = group0:addTextureFromPath( path )
			cloneData( tex1, tex0 )
		else
			cloneData( tex1, tex0 )
			if tex1.parent.name ~= tex0.parent.name then --group changed, move
				local group0 = lib0:getGroup( tex1.parent.name )
				group0:addTexture( tex0 )
			end
		end
	end

	--find removed
	local removed = {}
	for path, tex0 in pairs( lib0.textureMap ) do
		if not lib1.textureMap[ path ] then --removed
			tex0.valid = false
		else
			tex0.valid = true
		end
	end

	lib0:updateIndex()
end

--------------------------------------------------------------------
CLASS: TextureLibrary ()
CLASS: TextureGroup ()
CLASS: Texture ()

--------------------------------------------------------------------
--Texture
--------------------------------------------------------------------
Texture	:MODEL{
		Field 'path' :asset('texture') :readonly() :no_edit(); --view only	
		Field 'w'    :readonly();
		Field 'h'    :readonly();

		----
		Field 'ow' :readonly() :no_edit(); -- for cropped texture
		Field 'oh' :readonly() :no_edit();
		
		Field 'rotated' :boolean() :no_edit();

		Field 'x' :readonly() :no_edit(); --for atlas
		Field 'y' :readonly() :no_edit();
		
		Field 'parent' :type( TextureGroup ) :no_edit();
		Field 'u0' :no_edit();
		Field 'v0' :no_edit();
		Field 'u1' :no_edit();
		Field 'v1' :no_edit();
		
		'----';
		Field 'atlasId' :int() :no_edit();
		Field 'prebuiltAtlasPath' :string() :no_edit();

		'----';		
		Field 'scale'     ;
		Field 'noGroupProcessor' :boolean();
		Field 'processor' :asset('texture_processor');
		Field 'allowPacked' :boolean();

		Field 'modifyState' :string() :no_edit();
	}

function Texture:__init( path )
	self.path = path
	self.u0 = 0
	self.v0 = 1
	self.u1 = 1
	self.v1 = 0
	self.x  = 0
	self.y  = 0
	self.w  = 100
	self.h  = 100
	self.ow = 100
	self.oh = 100
	
	self.rotated       = false
	self.prebuiltAtlasPath = false
	self.atlasId       = false
	self.scale         = -1
	self.allowPacked   = true
	self.parent        = false

	self.modifyState   = false

	self.valid = true

	self.refcount = 0
	self.noGroupProcessor = false

end

function Texture:setModifyState( s )
	self.modifyState = s
end

function Texture:getParentGroup()
	return self.parent
end

function Texture:saveConfigData()
	local data = {}
	data[ 'group' ]       = self.parent:getName()
	data[ 'scale' ]       = self.scale
	data[ 'processor' ]   = self.processor
	data[ 'noGroupProcessor' ] = self.noGroupProcessor
	data[ 'allowPacked' ] = self.allowPacked
	return data
end

function Texture:onFieldChanged( fid )
	self.modifyState = 'all'	
end

function Texture:updateConfigData( data )
	--check modification
	local groupName   = data[ 'group' ]
	local scale       = data[ 'scale' ]
	local processor   = data[ 'processor' ]
	local allowPacked = data[ 'allowPacked' ]
	local noGroupProcessor = data[ 'noGroupProcessor' ] or false

	if allowPacked ~= self.allowPacked then
		self.allowPacked = allowPacked
		self.modifyState = 'all'
	end

	if noGroupProcessor ~= self.noGroupProcessor then
		self.noGroupProcessor = noGroupProcessor
		self.modifyState = 'all'
	end
	
	if groupName ~= self.parent:getName() then
		local group =  groupName and textureLibrary:getGroup( groupName )
		if group then
			group:addTexture( self )
			self.modifyState = 'all'
		else
			_error( 'unknown texture group', groupName, self.path )
		end
	end
	
	if scale ~= self.scale then
		self.scale = scale
		self.modifyState = 'all'
	end
	if processor ~= self.processor then
		self.processor = processor
		self.modifyState = 'all'
	end
	
end

function Texture:getOriginalSize()
	return self.ow, self.oh
end

function Texture:getSize()
	return self.w, self.h
end

function Texture:getOutputSize()
	return self.w, self.h
end

function Texture:getPixmapRect()
	return 0, 0, self.w, self.h
end

function Texture:getUVRect()
	return self.u0, self.v0, self.u1, self.v1	
end

function Texture:getPath()
	return self.path
end

function Texture:isPrebuiltAtlas()
	local node = getAssetNode( self.path )
	if not node then
		_warn( 'no asset node', self.path )
	end
	return node:getType() == 'prebuilt_atlas'
end

function Texture:buildInstance()
	return TextureInstance( self )
end

function Texture:getScale()
	local scl = self.scale
	if scl <= 0 then
		return self.parent:getScale()
	end
	return scl
end

function Texture:retain()
	self.refcount = self.refcount + 1
	TexturePendingRelease[ self ] = nil
end

function Texture:release()
	self.refcount = self.refcount - 1
	if self.refcount == 0 then
		TexturePendingRelease[ self ] = true
	end
end

function Texture:purge()
end

--------------------------------------------------------------------
CLASS: TextureInstance ( TextureInstanceBase )
	:MODEL{}

function TextureInstance:__init( src )
	self._src = src
	self._texture = false
	self._prebuiltAtlas = false
	src:retain()
end

function TextureInstance:__tostring()
	return string.format( '%s:%s', self:__repr(), self:getPath() )
end

function TextureInstance:getSource()
	return self._src
end

function TextureInstance:getPath()
	return self._src.path
end

function TextureInstance:load()
	local src = self._src
	if src.valid then
		src.parent:loadTexture( self )

	else
		local tex = MOAITexture.new()
		tex:load( getTexturePlaceHolderImage() )
		instance.valid = false		
		self._texture = tex
		
	end
end

function TextureInstance:unload()
	self._src:release()
	self._texture = false
	self._prebuiltAtlas = false
end

function TextureInstance:getMoaiTexture()
	return self._texture
end

function TextureInstance:getOriginalSize()
	return self._src:getOriginalSize()
end

function TextureInstance:getSize()
	return self._src:getSize()
end

function TextureInstance:getOutputSize()
	return self._src:getOutputSize()
end

function TextureInstance:getPixmapRect()
	return self._src:getPixmapRect()
end

function TextureInstance:getUVRect()
	return self._src:getUVRect()
end

function TextureInstance:getScale()
	return self._src:getScale()
end

function TextureInstance:isPrebuiltAtlas()
	return self._src:isPrebuiltAtlas()
end

function TextureInstance:getPrebuiltAtlas()
	return self._prebuiltAtlas
end

function TextureInstance:isPacked()
	return self.packed
end


--------------------------------------------------------------------
CLASS: AdhocTextureInstance( TextureInstanceBase )
: MODEL {}

function AdhocTextureInstance:__init( moaiTexture )
    self._moaiTexture = moaiTexture or MOAITexture.new()
end

function AdhocTextureInstance:load( input, ... )
	local tex = self._moaiTexture
	tex:load( input, ... )
end

function AdhocTextureInstance:getSize()
    return self._moaiTexture:getSize()
end

function AdhocTextureInstance:getUVRect()
	return 0,1,1,0
end

function AdhocTextureInstance:getMoaiTexture()
    return self._moaiTexture
end


--------------------------------------------------------------------
--Texture Group
--------------------------------------------------------------------

local _loadedTextureTable = table.weak()
function reportLoadedMoaiTextures()
	local output = {}
	for file, tex in pairs( _loadedTextureTable ) do
		local w, h = tex:getSize()
		table.insert( output, { tex.debugName or '<unknown>', w*h*4 } )
	end
	local function _sortFunc( i1, i2 )
		return i1[1] < i2[1]
	end
	table.sort( output, _sortFunc )
	for i , item in ipairs( output ) do
		printf( '%10d\t%s', item[2], item[1] )
	end
end

function getLoadedMoaiTextures()
	return _loadedTextureTable
end


TextureGroup :MODEL{
		Field 'name'           :string()  :no_edit();
		Field 'default'        :boolean() :no_edit();

		Field 'format'         :enum( EnumTextureFormat );
		'----';
		Field 'filter'         :enum( EnumTextureFilter );
		Field 'premultiplyAlpha' :boolean();
		Field 'mipmap'         :boolean();
		Field 'wrap'           :boolean();
		Field 'pow2'           :boolean();
		-- Field 'compression'    :enum( EnumTextureCompression );
		'----';
		Field 'atlasMode'      :enum( EnumTextureAtlasMode );
		Field 'maxAtlasWidth'  :enum( EnumTextureSize );
		Field 'maxAtlasHeight' :enum( EnumTextureSize );
		'----';
		Field 'repackPrebuiltAtlas' :boolean();

		'----';
		Field 'scale'          :range( 0.1 );
		Field 'processor'      :asset('texture_processor');

		Field 'atlasCachePath' :string() :no_edit();
		Field 'textures'       :array( Texture ) :no_edit();
		Field 'parent'         :type( TextureLibrary ) :no_edit();
		Field 'expanded'       :boolean() :no_edit();

		Field 'modifyState' :string() :no_edit();

	}

function TextureGroup:__init()
	self.name                = 'TextureGroup'
	self.format              = 'auto'
	self.filter              = 'linear'
	self.mipmap              = false
	self.wrap                = false
	self.atlasMode           = false
	self.maxAtlasWidth       = 1024
	self.maxAtlasHeight      = 1024
	self.default             = false
	self.expanded            = true
	self.atlasCachePath      = false
	self.compression         = false
	self.premultiplyAlpha    = true
	self.repackPrebuiltAtlas = false
	self.pow2                = false
	self.textures            = {}

	self.scale               = 1

	self._atlasTexturesCache  = {}

	self.modifyState = false
end

function TextureGroup:getName()
	return self.name
end

function TextureGroup:saveConfigData()
	local data = {}
	data['name']                = self.name
	data['default']             = self.default
	data['format']              = self.format
	data['filter']              = self.filter
	data['premultiplyAlpha']    = self.premultiplyAlpha
	data['mipmap']              = self.mipmap
	data['wrap']                = self.wrap
	data['pow2']                = self.pow2
	data['compression']         = self.compression
	data['atlasMode']           = self.atlasMode
	data['maxAtlasWidth']       = self.maxAtlasWidth
	data['maxAtlasHeight']      = self.maxAtlasHeight
	data['repackPrebuiltAtlas'] = self.repackPrebuiltAtlas
	data['scale']               = self.scale
	data['processor']           = self.processor
	return data
end

local _FlagFields  = { 'filter', 'premultiplyAlpha', 'mipmap', 'wrap', 'pow2' }
local _AtlasFields = { 'atlasMode','maxAtlasWidth','maxAtlasHeight', 'repackPrebuiltAtlas' }
local _FileFields  = { 'format', 'compression', 'scale', 'processor' }

local function _updateFields( obj, data, fields )
	local updated = false
	for i, f in ipairs( fields ) do
		local v = data[ f ]
		if obj[ f ] ~= v then
			obj[ f ] = v
			updated = true
		end
	end
	return updated
end

function TextureGroup:onFieldChanged( fid )
	local flagChanged  = table.index( _FlagFields, fid ) and true or false
	local atlasChanged = table.index( _AtlasFields, fid ) and true or false
	local fileChanged  = table.index( _FileFields, fid ) and true or false
	if fileChanged then
		self:setModifyState( 'file' )
	elseif atlasChanged then
		self:setModifyState( 'atlas' )
	elseif flagChanged then
		self:setModifyState( 'flag' )
	end
end

function TextureGroup:updateConfigData( data )
	local default             = data['default']
	local flagChanged  = _updateFields( self, data, _FlagFields )
	local atlasChanged = _updateFields( self, data, _AtlasFields )
	local fileChanged  = _updateFields( self, data, _FileFields )
	if fileChanged then
		self:setModifyState( 'file' )
	elseif atlasChanged then
		self:setModifyState( 'atlas' )
	elseif flagChanged then
		self:setModifyState( 'flag' )
	end
end

function TextureGroup:addTextureFromPath( path )
	local t = Texture()
	t.path = path
	return self:addTexture( t )
end

function TextureGroup:addTexture( t )
	local pg = t.parent
	if pg == self then return end
	if pg then 
		pg:removeTexture( t )
	else
		t.modifyState = 'all'
	end
	table.insert( self.textures, t )
	t.parent = self
	self:setModifyState( 'atlas' )
	return t
end

function TextureGroup:setModifyState( s )
	local s0 = self.modifyState
	if s0 == s then return end
	if not s0 then
		self.modifyState = s
	elseif s0 == 'flag' then
		if s == 'file' or s == 'atlas' then self.modifyState = s end
	elseif s0 == 'atlas' then
		if s == 'file' then self.modifyState = s end
	elseif s0 == 'file' then
		--do nothing
	end
end

function TextureGroup:removeTexture( t )
	_stat( 'removing texture from library', t.path )
	for i, t1 in ipairs( self.textures ) do
		if t1 == t then 
			table.remove( self.textures, i )
			t.parent = false
			self:setModifyState( 'atlas' )
			return t
		end
	end
	return false
end

function TextureGroup:findTexture( path )
	for i, t in ipairs( self.textures ) do
		if t.path == path then
			return t
		end
	end
	return nil
end

function TextureGroup:findAndRemoveTexture( path )
	for i, t in ipairs( self.textures ) do
		if t.path == path then
			return self:removeTexture( t )
		end
	end
	return false
end

function TextureGroup:findPrebuiltAtlas()
	local result = {}
	for i, t in ipairs( self.textures ) do
		if t:isPrebuiltAtlas() then
			table.insert( result, t )
		end
	end
	return result
end

function TextureGroup:getScale()
	return self.scale
end

function TextureGroup:getAssetPath()
	return '@texture_pack/'..self.name
end

function TextureGroup:isAtlas()
	return self.atlasMode
end

function TextureGroup:loadAtlas()
	local base = self.atlasCachePath
	if not base then return nil end
	_stat( 'loading atlas for texture group', self.name )
	local configPath = base .. '/atlas.json'
	local f = io.open( configPath, 'r' )
	if not f then 
		_error( 'file not found:' .. configPath )   --TODO: proper exception handle
		return nil
	end
	local text = f:read( '*a' )
	f:close()
	local data = MOAIJsonParser.decode( text )

	if not data then 
		_error('atlas config file not parsable') --TODO: proper exception handle
		return nil
	end	

	local prevTex
	for i, atlasInfo in pairs( data[ 'atlases' ] ) do
		local texpath = atlasInfo['name']
		local tex = self:_loadSingleTexture( 
			base .. '/' .. texpath,
			self:getAssetPath() .. '/' .. texpath
		)
		if not tex then
			error( 'error loading texture:' .. texpath )
		end
		if not prevTex then
			tex:setFinalizer( function()
				self:invalidate()
			end )
		end
		tex._previous = prevTex -- make a ref-ring to avoid partial collection
		self._atlasTexturesCache[ i ] = tex
		prevTex = tex
	end
	prevTex._previous = self._atlasTexturesCache[ 1 ]
	
	return true
end

function TextureGroup:unloadAtlas()
	self._atlasTexturesCache = {}
	-- self.atlasLoaded = false
end

function TextureGroup:isAtlasLoaded()
	return next( self._atlasTexturesCache ) ~= nil
end

function TextureGroup:invalidate()
	table.clear( self._atlasTexturesCache )
	for i, tex in ipairs( self.textures ) do
		local path = tex:getPath()
		local node = getAssetNode( path )
		if node then node:invalidate() end
	end

end

function TextureGroup:loadTexture( instance )
	if instance:isPrebuiltAtlas() then
		return self:loadPrebuiltAtlas( instance )
	end
	local node = getAssetNode( instance:getPath() )
	if self:isAtlas() then
		instance.packed = true
		if not self:isAtlasLoaded() then
			self:loadAtlas()
		end
		local atlasId = instance:getSource().atlasId
		local tex = self._atlasTexturesCache[ atlasId ]
		if not tex then
			_error( 'texture atlas not in cache', atlasId, self.name )
			instance.valid = false
		else
			instance.valid = true
		end
		instance._texture = tex
	else
		instance.packed = false
		local pixmapPath = node:getObjectFile( 'pixmap' )
		local tex = self:_loadSingleTexture( pixmapPath, instance:getPath() )
		if tex then
			tex:setFinalizer( function() return node:invalidate() end )
			tex._ownerObject = instance
			instance.valid = true
		else
			tex = MOAITexture.new()
			tex:load( getTexturePlaceHolderImage() )
			instance.valid = false
		end
		instance._texture = tex
	end
end

function TextureGroup:loadPrebuiltAtlas( instance )
	local node = getAssetNode( instance:getPath() )
	if self:isAtlas() then --TODO
		if not self:isAtlasLoaded() then
			self:loadAtlas()
		end
	end
	local prebuiltAtlasPath = node:getObjectFile( 'atlas' )
	local prebuiltAtlas = PrebuiltAtlas()
	prebuiltAtlas:load( prebuiltAtlasPath )
	if self:isAtlas() then
		for i, page in ipairs( prebuiltAtlas.pages ) do
			if page.textureAtlasId > 0 then
				local tex = self._atlasTexturesCache[ page.textureAtlasId ]
				if not tex then
					_warn( 'atlas cache not loaded', page.textureAtlasId )				
				end
				page._texture = tex
			end
		end
	else
		for i, page in ipairs( prebuiltAtlas.pages ) do
			local pixmapName = 'pixmap_'..i
			local pixmapPath = node:getObjectFile( pixmapName )
			local debugName  = node:getNodePath() .. '@' .. pixmapName
			local tex = self:_loadSingleTexture( pixmapPath, debugName )
			page._texture = tex
			tex._ownerObject = page
		end
	end
	instance._prebuiltAtlas = prebuiltAtlas
end

function TextureGroup:_loadSingleTexture( pixmapPath, debugName )
	local tex = MOAITexture.new()
	_stat( 'loading single texture from pixmap:', tex, pixmapPath, debugName )
	tex.pixmapPath = pixmapPath

	local transform = 0
	
	--NOTE: this should've been processed by GII
	-- if self.premultiplyAlpha then
	-- 	transform = transform + MOAIImage.PREMULTIPLY_ALPHA
	-- end
	-- transform = transform + MOAIImage.QUANTIZE

	local filter
	if self.filter == 'linear' then
		if self.mipmap then
			filter = MOAITexture.GL_LINEAR_MIPMAP_LINEAR
		else
			filter = MOAITexture.GL_LINEAR
		end
	else  --if self.filter == 'nearest' then
		if self.mipmap then
			filter = MOAITexture.GL_NEAREST_MIPMAP_NEAREST
		else
			filter = MOAITexture.GL_NEAREST
		end
	end	

	tex:setFilter( filter )
	tex:setWrap( self.wrap )

	local filePath = getProjectPath( pixmapPath )	
	if not ( pixmapPath and filePath ) then
		_warn( 'nil imagepath specified', self.debugName )
		return nil		
	end
	
	local async = TEXTURE_ASYNC_LOAD
	if self.format == 'PVR-4' or self.format == 'PVR-2' then
		--todo: use async raw data loading routine
		async = false
	end

	if async then
		local task = AsyncTextureLoadTask( filePath, transform )
		task:setTargetTexture( tex )
		task:setDebugName( debugName or filePath )
		task:setRetryCount( 3 )
		task:start()
	else
		tex:load( filePath, transform, debugName, true )
		if tex:getSize() <= 0 then
			_warn( 'failed load texture file:', filePath, debugName )
			tex:load( getTexturePlaceHolderImage() )
		end
		if MOCKHelper.setTextureDebugName then
			MOCKHelper.setTextureDebugName( tex, debugName )
		end
	end
	tex.debugName = debugName
	_loadedTextureTable[ filePath ] = tex
	return tex
end

function TextureGroup:_preloadAll()
	local instances = {}
	for path, texture in pairs( self.textures ) do
		local instance = texture:buildInstance()
		instance:load()
		instances[ instance ] = true
	end
	return instances
end

--------------------------------------------------------------------
--Texture Library
--------------------------------------------------------------------
TextureLibrary :MODEL{
		Field 'groups' :array( TextureGroup ) :no_edit();
	}

function TextureLibrary:__init()
	self.groups = {}	
	self.textureMap = {}
	-- local defaultGroup = self:addGroup()
	-- defaultGroup.name = 'DEFAULT'
	-- defaultGroup.default = true
	-- self.defaultGroup = defaultGroup
	self.modifiedGroups = false
	self.modifiedTextures = false
end

function TextureLibrary:initDefault()
	_stat( 'initializing texture library' )
	self.groups = {}
	local defaultGroup = self:addGroup()
	defaultGroup.name = 'DEFAULT'
	defaultGroup.default = true
	self.defaultGroup = defaultGroup
end

function TextureLibrary:save( path )
	_stat( 'saving texture library', path )
	return serializeToFile( self, path )
end

function TextureLibrary:saveGroupData()
	local output = {}
	for i, group in ipairs( self.groups ) do
		local data = group:saveConfigData()
		local name = group.name
		output[ name ] = data
	end
	return output
end

function TextureLibrary:loadGroupData( data )
	local groups = {}
	local defaultGroup = false
	for i, entry in ipairs( data ) do
		local group = TextureGroup()
		group.parent = self
		groups[ i ] = group
		group:loadConfigData( entry )
		if group.default then
			if defaultGroup then
				_warn( 'multiple default texture group', defaultGroup.name, group.name )
			end
			defaultGroup = group
		end
	end
	self.groups = groups
	self.defaultGroup = defaultGroup
end

function TextureLibrary:collectTextureConfigData()
	local result = {}
	for i, group in ipairs( self.groups ) do
		for _, tex in ipairs( group.textures ) do
			result[ tex.path ] = tex:saveConfigData()
		end
	end
	return result
end

function TextureLibrary:load( path )
	_stat( 'loading textureLibrary', path )
	self.defaultGroup = nil
	self.groups = {}
	deserializeFromFile( self, path )
	for i, group in ipairs( self.groups ) do
		if group.default then
			self.defaultGroup = group
			break
		end
	end
	self:updateIndex()
end

function TextureLibrary:updateIndex()
	 --clear removed textures
	local insert = table.insert
	local textureMap = {}
	local getAssetNode = getAssetNode
	for i, group in ipairs( self.groups ) do
		local newTextures = {}
		for i, tex in ipairs( group.textures ) do
			if getAssetNode( tex.path ) then
				insert( newTextures, tex )
				textureMap[ tex.path ] = tex
			else
				_warn( 'texture node removed', tex.path )
			end
		end
		group.textures = newTextures
	end
	self.textureMap = textureMap
end

function TextureLibrary:saveGroupDataToFile( path )
	local data = self:saveGroupData()
	saveJSONFile( data, path )
end

function TextureLibrary:updateGroupDataFromFile( path )
	local data = loadJSONFile( path )
	if not data then return false end
	for name, groupData in pairs( data ) do
		local group0 = self:getGroup( name )
		if group0 then
			group0:updateConfigData( groupData )
		else --new group?
			local group = self:addGroup()
			group.name = name
			group:updateConfigData( groupData )
			group.modifyState = 'file'
		end
	end
	return true
end

function TextureLibrary:updateTextureConfig( path, data )
	--data might be python dict
	local tex = self:findTexture( path )
	if not tex then
		--missing texture node?
		tex = self:addTexture( path )
	end
	tex:updateConfigData( data )
end

function TextureLibrary:getDefaultGroup()
	return self.defaultGroup
end

function TextureLibrary:getGroup( name )
	for i, g in ipairs( self.groups ) do
		if g.name == name then return g end
	end
	return nil
end

function TextureLibrary:addGroup()
	local g = TextureGroup()
	g.parent = self
	table.insert( self.groups, g )
	return g
end

function TextureLibrary:removeGroup( g, moveItemsToDefault )
	for i, g1 in ipairs( self.groups ) do
		if g1 == g then 
			table.remove( self.groups, i )
			g.parent = false
			if moveItemsToDefault then
				local default = self.defaultGroup
				for i, t in ipairs( g.textures ) do
					t.parent = false
					default:addTexture( t )
				end
			end
			return
		end
	end
end

function TextureLibrary:addTexture( path, groupName )
	local group = groupName and self:getGroup( groupName )
	if not group then
		group = self:getDefaultGroup()
	end
	local t = Texture( path )
	t.modifyState = 'all'
	group:addTexture( t )
	self.textureMap[ path ] = t
	return t
end

function TextureLibrary:findTexture( path )
	return self.textureMap[ path ]	
end

function TextureLibrary:affirmTexture( path )
	local t = self:findTexture( path )
	if not t then
		t = self:addTexture( path )
	end
	return t
end

function TextureLibrary:removeTexture( path )
	local found
	for i, g in ipairs( self.groups ) do
		local t = g:findAndRemoveTexture( path )
		if t then
			found = t
			break
		end
	end
	if found then
		self.textureMap[ path ] = nil
		return found
	else
		return false
	end
end

function TextureLibrary:getReport()
	local report = {}
	report[ 'count'  ] = 0
	report[ 'memory' ] = 0
	report[ 'count_peak'  ] = 0
	report[ 'memory_peak' ] = 0
	return report
end

function TextureLibrary:updateModifyState()
	local modifiedTextures = {}
	local modifiedGroups    = {}
	for i, g in ipairs( self.groups ) do
		if g:isAtlas() and not g.atlasCachePath then --missing atlas, try rebuild it
			g:setModifyState( 'atlas' )
			modifiedGroups[ g ] = g.modifyState
		end
		if g.modifyState then
			modifiedGroups[ g ] = g.modifyState
		end
		for j, t in ipairs( g.textures ) do
			if t.modifyState then
				modifiedTextures[ t ] = t.modifyState
			end
		end		
	end
	self.modifiedGroups   = modifiedGroups
	self.modifiedTextures = modifiedTextures
end

function TextureLibrary:clearModifyState()
	if self.modifiedGroups then 
		for g, s in pairs( self.modifiedGroups ) do
			g.modifyState = false
		end
	end
	if self.modifiedTextures then 
		for t, s in pairs( self.modifiedTextures ) do
			t.modifyState = false
		end
	end
	self.modifiedGroups = false
	self.modifiedTextures = false 
end

--------------------------------------------------------------------
function releaseTexPack( cachePath )
end


--------------------------------------------------------------------
--Asset Loaders
--------------------------------------------------------------------
local function loadTexture( node )
	local texNode = textureLibrary:findTexture( node:getNodePath() )
	if not texNode then return nil end
	local instance = texNode:buildInstance()
	instance:load()
	return instance
end

local function unloadTexture( node, textureInstance )
-- 	local texNode = textureLibrary:findTexture( node:getNodePath() )
-- 	if not texNode then return nil end
	-- textureInstance:unload()
end


local function loadTexturePack( node ) --nothing
	return {}
end


registerAssetLoader( 'texture_pack',    loadTexturePack )
registerAssetLoader( 'texture',         loadTexture, unloadTexture )
registerAssetLoader( 'prebuilt_atlas',  loadTexture, unloadTexture )


addSupportedTextureAssetType( 'texture' )
