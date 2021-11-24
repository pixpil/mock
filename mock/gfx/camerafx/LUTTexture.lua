module 'mock'

local _textures = table.weak()

function getLoadedLUTTexture( path )
	return _textures[ path ]
end

local function LUTTextureLoader( node )
	local imagePath  = node:getObjectFile('texture')
	local filter = node:getProperty( 'filter' )
	local path = node:getPath()
	local tex = _textures[ path ]
	if not tex then
		tex = MOAITexture.new()
		_textures[ path ] = tex
	else
		print( 'reloading texture', path )
	end

	if filter == 'nearest' then
		tex:setFilter( MOAITexture.GL_NEAREST )
	else
		tex:setFilter( MOAITexture.GL_LINEAR )
	end
	
	--TODO:save texture size in asset data
	local asyncTexture = TEXTURE_ASYNC_LOAD 
	local asyncTexture = false
	if asyncTexture then
		local task = AsyncTextureLoadTask( imagePath, MOAIImage.TRUECOLOR )
		task:setTargetTexture( tex )
		task:start()
	else
		tex:load( imagePath, MOAIImage.TRUECOLOR )
	end

	return tex
end

registerAssetLoader ( 'lut_texture', LUTTextureLoader )
