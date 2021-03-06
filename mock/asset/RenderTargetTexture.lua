module 'mock'
CLASS: RenderTargetTexture ( Texture )
	:MODEL{
		Field 'width'  :int();
		Field 'height' :int();
		Field 'filter' :enum( EnumTextureFilter );
		Field 'depth'  :boolean();
	}

function RenderTargetTexture:__init()
	self.framebuffer = MOAIFrameBufferTexture.new()
	self.renderTarget = TextureRenderTarget()
	self.renderTarget.owner = self
	self.updated = false
	self.depth  = false
	self.width  = 256
	self.height = 256
	self.filter = 'linear'
	self.type   = 'framebuffer'
end

function RenderTargetTexture:getSize()
	return self.width, self.height
end

function RenderTargetTexture:getMoaiTextureUV()
	return self:getMoaiTexture(), { 0,0,1,1 }
end

function RenderTargetTexture:getMoaiTexture()
	return self:getRenderTarget():getFrameBuffer()
end

function RenderTargetTexture:getMoaiFrameBuffer()
	self:update()
	return self.framebuffer
end

function RenderTargetTexture:getRenderTarget()
	self:update()
	return self.renderTarget
end

function RenderTargetTexture:update()
	if self.updated then return end
	self.renderTarget:initFrameBuffer()
	self.renderTarget.mode = 'fixed'
	self.renderTarget:setPixelSize( self.width, self.height )
	self.updated = true
end


function RenderTargetTextureLoader( node )
	local data = loadAssetDataTable( node:getObjectFile( 'def' ) )
	return deserialize( nil, data )
end

registerAssetLoader( 'render_target',   RenderTargetTextureLoader )
