module 'mock'
CLASS: RenderTargetTexture ( TextureInstanceBase )
	:MODEL{
		Field 'width'  :int();
		Field 'height' :int();
		Field 'format' :string();
		Field 'filter' :enum( EnumTextureFilter );
		Field 'depth'  :boolean();
		Field 'stencil':boolean();
		Field 'wrap':boolean();
	}


local _filterNameToFilter = {
	linear  = MOAITexture.GL_LINEAR,
	nearest = MOAITexture.GL_NEAREST,
}

local _formatNameToFormat = {
	rgba    = MOAITexture.GL_RGBA8,
	rgb     = MOAITexture.GL_RGB8,
	rgba16f = MOAITexture.GL_RGBA16F,
}


function RenderTargetTexture:__init()
	self.renderTarget = TextureRenderTarget()
	self.renderTarget.owner = self
	self.updated = false
	
	self.depth   = false
	self.stencil = false

	self.width  = 256
	self.height = 256
	self.filter = 'linear'
	self.type   = 'framebuffer'
	self.wrap = false

	self.format = 'rgba'
	self.colorFormat = false
	self.inited = false
end

function RenderTargetTexture:init( w, h, filter, colorFormat, depth, stencil )
	if self.updated then return false end
	self.width = w
	self.height = h
	self.filter = filter
	self.colorFormat = colorFormat
	self.depth = depth or false
	self.stencil = stencil or false
	self.inited = true
	self:update()
	return true
end

function RenderTargetTexture:getSize()
	return self.width, self.height
end

function RenderTargetTexture:getUVRect()
	if getRenderManager().flipRenderTarget then
		return 0,1,1,0
	else
		return 0,0,1,1
	end
end

function RenderTargetTexture:getMoaiTextureUV()
	if getRenderManager().flipRenderTarget then
		return self:getMoaiTexture(), { 0,1,1,0 }
	else
		return self:getMoaiTexture(), { 0,0,1,1 }
	end
end

function RenderTargetTexture:getMoaiTexture()
	return self:getRenderTarget():getFrameBuffer()
end

function RenderTargetTexture:getMoaiFrameBuffer()
	self:update()
	return self.renderTarget:getFrameBuffer()
end

function RenderTargetTexture:getRenderTarget()
	self:update()
	return self.renderTarget
end

function RenderTargetTexture:update()
	if self.updated then return end
	local colorFormat = self.colorFormat or _formatNameToFormat[ self.format ] or MOAITexture.GL_RGBA8
	local useStencilBuffer = false --no more separated depth/stencil
	if self.stencil or self.depth then
		useStencilBuffer = true
	end
	local option = {
		useStencilBuffer = useStencilBuffer,
		useDepthBuffer   = useStencilBuffer,
		filter           = _filterNameToFilter[ self.filter ],
		colorFormat      = colorFormat,
		wrap             = self.wrap
	}

	self.renderTarget:setDebugName( self.path or '' )
	self.renderTarget:initFrameBuffer( option )
	self.renderTarget.mode = 'fixed'
	self.renderTarget:setPixelSize( self.width, self.height )
	self.renderTarget:setFixedScale( self.width, self.height )
	local assetNode = self.path and getAssetNode( self.path )
	if assetNode then
		assetNode:bindMoaiFinalizer( self.renderTarget:getFrameBuffer() )
	end
	self.updated = true
end


function RenderTargetTextureLoader( node )
	local data = loadAssetDataTable( node:getObjectFile( 'def' ) )
	local obj = deserialize( nil, data )
	obj.path = node:getPath()
	print( obj.format )
	return obj
end

registerAssetLoader( 'render_target',   RenderTargetTextureLoader )
addSupportedTextureAssetType( 'render_target' )
