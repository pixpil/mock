module 'mock'
--------------------------------------------------------------------
local charCodes = " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,:.?!{}()<>+_="
--------------------------------------------------------------------

-------font
local function loadFont( node )
	local font  = MOAIFont.new()
	local atype = node.type

	--TODO: support serialized font
	local attributes = node.attributes or {}
	local size          = attributes['size'] or 20

	if attributes[ 'serialized' ] then
		local sdataPath   = node.objectFiles['data']
		local texturePath = node.objectFiles['texture']
		font = dofile( sdataPath )
		-- load the font image back in
		local image = MOAIImage.new ()
		image:load ( texturePath, 0 )
		-- set the font image
		font:setCache()
		font:setReader()
		font:setImage( image )
	end

	if atype == 'font_bmfont' then
		local texPaths = {}
		for k, v in pairs( node.dependency ) do
			if k:sub(1,3) == 'tex' then
				local id = tonumber( k:sub(5,-1) )
				texPaths[ id ] = v
			end
		end
		local textures = {}
		for i, path in ipairs( texPaths ) do
			local tex, node = loadAsset( path )
			if not tex then 
				_error( 'failed load font texture' ) 
				return getFontPlaceHolder()
			end
			table.insert( textures, tex:getMoaiTexture() )
		end
		if #textures > 0 then
			font:loadFromBMFont( node.objectFiles['font'], textures )
		else
			_warn('bmfont texture not load', node:getNodePath() )
		end
		local defaultShader = MOAIShaderMgr.getShader( MOAIShaderMgr.DECK2D_SHADER )
		font:setShader( defaultShader )
		

	elseif atype == 'font_ttf' then
		local filename = node.objectFiles['font']
		local reader = font:getReader()
		reader:setKeepOpen( true )
		reader:enableAntiAliasing( true )
		font:getCache():setColorFormat( MOAIImage.COLOR_FMT_RGBA_8888 )
		font:load( filename, 0 )
		
		if getRenderManager().useSDF then
			font:setListener( MOAIFont.EVENT_RENDER_GLYPH, function( font, reader, img, code, x,y, gx0,gy0,gx1,gy1 )
				reader:renderGlyph( img, x, y )
				img:generateSDFAA( gx0,gy0,gx1,gy1 )
			end )

			local shaderConfig = loadMockAsset( 'shader/image_effect/SDFFont.shader_script' )
			local shader = shaderConfig:affirmDefaultShader( { SDF = true } )
			shader:setAttr( 'smoothing', 1/24 )
			font:setShader( shader:getMoaiShader() )
		end

	elseif atype == 'font_bdf' then
		font:load( node.objectFiles['font'] )

	else
		_error( 'failed to load font:', node.path )
		return getFontPlaceHolder()
	end

	local dpi           = 72
	local size          = attributes['size'] or 20
	local preloadGlyphs = attributes['preloadGlyphs']

	if preloadGlyphs then	
		font:preloadGlyphs( preloadGlyphs, size )
	else
		font:preloadGlyphs( charCodes, size )
	end
	font.size = size
	node:disableGC()
	return font
end

local function loadPFont( node )
	local dataPath = node.objectFiles['font']
	local loaderPath = dataPath .. '/loader'
	local imagePath = dataPath .. '/tex'
	local charsetPath = dataPath .. '/charset'

	local loader, err = loadfile( loaderPath )
	local font = loader and loader()
	if not font then return end
	local image = MOAIImage.new ()
	image:load( imagePath )

	font:setCache ()
	font:setReader ()
	font:setImage ( image )
	font.size = font:getSize()
	node:disableGC()
	return font
end

--------------------------------------------------------------------
registerAssetLoader( 'font_ttf',    loadFont )
registerAssetLoader( 'font_bdf',    loadFont )
registerAssetLoader( 'font_bmfont', loadFont )
registerAssetLoader( 'font_pfont',  loadPFont )

--preload font placeholder
getFontPlaceHolder()
