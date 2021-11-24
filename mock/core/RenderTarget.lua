 module 'mock'

CLASS: RenderTarget ( Viewport )
	:MODEL{}

function RenderTarget:__init()
	self.mode = 'relative'
	self.frameBuffer = false
	self.debugName = ''
	self.renderViewport = false
end

function RenderTarget:__tostring()
	return string.format( '%s:%s (%d,%d,%d,%d)', self:__repr(), self.debugName or '???', self:getAbsPixelRect() )
end

function RenderTarget:setRenderViewport( vp )
	self.renderViewport = vp or false
end

function RenderTarget:getRenderViewport()
	return self.renderViewport or self
end

function RenderTarget:setDebugName( name )
	self.debugName = name
end

function RenderTarget:getFrameBuffer()
	return self.frameBuffer
end

function RenderTarget:grabCurrentFrame( img )
	assert( img )
	local fb = self:getFrameBuffer()
	if fb then
		local flip = not getRenderManager().flipRenderTarget
		fb:grabCurrentFrame( img, flip )
		return true
	else
		return false
	end
end

function RenderTarget:grabCurrentFrameRect( img, x, y, w, h )
	assert( img )
	local fb = self:getFrameBuffer()
	if fb then
		local flip = not getRenderManager().flipRenderTarget
		fb:grabCurrentFrameRect( img, x, y, w, h, flip )
		return true
	else
		return false
	end
end

function RenderTarget:setFrameBuffer( buffer )
	self.frameBuffer = buffer
end

function RenderTarget:getRootRenderTarget()
	local r = self
	while true do
		local p = r.parent
		if not p then break end
		if not p:isInstance( RenderTarget ) then break end
		r = p
	end
	return r
end

function RenderTarget:clear()
	RenderTarget.__super.clear( self )
	self.cleared = true
end

--------------------------------------------------------------------
CLASS: DeviceRenderTarget ( RenderTarget )
	:MODEL{}

function DeviceRenderTarget:__init( frameBuffer, w, h )
	self.frameBuffer = assert( frameBuffer )
	self.mode = 'fixed'
	self:setPixelSize( w, h )
end

function DeviceRenderTarget:setMode( m )
	_error( 'device rendertarget is fixed' )
end

