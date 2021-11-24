module 'mock'


local function _valueList( ... )
	local output = {}
	local insert = table.insert
	local n = select( '#', ... )
	for i = 1, n do
		local v = select( i, ... )
		if v then
			insert( output, v )
		end
	end
	return output
end

--------------------------------------------------------------------
CLASS: GameRenderContext ( RenderContext )

function GameRenderContext:__init()
	-- body
	self.outputMode = 'direct'
	-- self._deviceToViewport = function( x, y ) return x, y end
	-- self._viewportToDevice = function( x, y ) return x, y end
end

function GameRenderContext:getOutputViewport()
	return self.outputViewport
end

function GameRenderContext:setOutputMode( mode )
	assert( mode == 'direct' or mode == 'scaled' )
	self.outputMode = mode
end

function GameRenderContext:onInit()
	_stat( 'init game render context' )
	--todo: move game renderlayer creation here
	if self.outputMode == 'direct' then
		self:initDeviceOutputRenderTarget()

	elseif self.outputMode == 'scaled' then
		self:initTextureOutputRenderTarget()

	else
		error( 'invalid output mode' )
	end

	self:initPlaceHolderRenderTable()
	self:setFrameBuffer()

end

function GameRenderContext:setOutputScale( scl )
	if self.outputMode == 'scaled' then
		-- self.mainRenderTarget:setZoom( 1/scl, 1/scl )
		self.outputViewport:setFixedScale( 1/scl, 1/scl )
	else
		self.mainRenderTarget:setZoom( scl, scl )
	end
end

function GameRenderContext:initDeviceOutputRenderTarget()
	local w, h = self:getContentSize()
	_stat( 'init device output render target' )
	
	local outputViewport = Viewport()
	outputViewport:setParent( game:getDeviceRenderTarget() )
	outputViewport:setMode( 'relative' )
	outputViewport:setKeepAspect( false )
	outputViewport:setFixedScale( w, h )

	local mainRenderTarget   = RenderTarget()
	mainRenderTarget:setFrameBuffer( assert( game:getDeviceRenderTarget():getFrameBuffer() ) )
	mainRenderTarget:setParent( outputViewport )
	mainRenderTarget:setMode( 'relative' )
	mainRenderTarget:setAspectRatio( w / h )
	mainRenderTarget:setKeepAspect( true )
	mainRenderTarget:setZoom( 1, 1 )
	mainRenderTarget:setDebugName( 'deviceRT' )
	mainRenderTarget.__main = true

	-- self.outputViewport = outputViewport
	self.mainRenderTarget = mainRenderTarget
	self.textureRenderTarget = false

	self:setRenderTarget( mainRenderTarget )
	self.outputViewport = outputViewport
	self.dummyLayer:setViewport( mainRenderTarget:getMoaiViewport() )
end

function GameRenderContext:initTextureOutputRenderTarget()
	
	local w, h = self:getContentSize()
	_stat( 'init texture ouput render target', w, h )

	local mainRenderTarget = TextureRenderTarget()
	local option = {
		filter = MOAITexture.GL_LINEAR,
		-- filter = MOAITexture.GL_NEAREST,
		useDepthBuffer = false,
		useStencilBuffer = false,
		colorFormat = MOAITexture.GL_RGBA8,
	}

	local fixed = false

	local viewport = Viewport()
	viewport:setParent( game:getDeviceRenderTarget() )
	viewport:setMode( 'relative' )
	
	viewport:setKeepAspect( true )
	viewport:setFixedScale( 1, 1 )
	viewport:setAspectRatio( w/h )

	mainRenderTarget.__main = true
	mainRenderTarget:initFrameBuffer( option )
	mainRenderTarget:setDebugName( 'deviceTRT' )
	mainRenderTarget:setFixedScale( w, h )

	if fixed then
		mainRenderTarget.mode = 'fixed'
		mainRenderTarget:setPixelSize( w, h  )
	else
		mainRenderTarget.mode = 'relative'
		mainRenderTarget:setAspectRatio( w / h )
		mainRenderTarget:setKeepAspect( true )
		mainRenderTarget:setParent( viewport )
	end

	local quad = MOAISpriteDeck2D.new()
	quad:setRect( -1/2, -1/2, 1/2, 1/2 )
	if getRenderManager().flipRenderTarget then
		quad:setUVRect( 0,1,1,0 )
	else
		quad:setUVRect( 0,0,1,1 )
	end

	local outputRenderProp = createRenderProp()
	outputRenderProp:setDeck( quad )
	setPropBlend( outputRenderProp, 'solid' )
	outputRenderProp:setDepthTest( 0 )
	
	quad:setTexture( mainRenderTarget:getFrameBuffer() )
	
	outputRenderProp:setColor( 1,1,1,1 )

	local outputRenderPass = MOAITableViewLayer.new()
	outputRenderPass:setClearColor( 0,0,0,1 )
	outputRenderPass:setClearMode( MOAILayer.CLEAR_NEVER )

	outputRenderPass:setViewport( viewport:getMoaiViewport() )
	outputRenderPass:setFrameBuffer( MOAIGfxMgr.getFrameBuffer() )
	outputRenderPass:setRenderTable{ 
		outputRenderProp
	}

	self.outputViewport    = viewport
	viewport._main = true
	
	self.outputRenderPass  = outputRenderPass
	self.outputRenderProp  = outputRenderProp
	
	self.mainRenderTarget = mainRenderTarget
	self.textureRenderTarget = mainRenderTarget

	self:setRenderTarget( mainRenderTarget )

	self:updateViewportDeviceMapping()

	local mainClearRenderPass = createTableRenderLayer()
	if game:isEditorMode() then
		mainClearRenderPass:setClearColor( 0.1, 0.1, 0.1, 1 )
	else
		mainClearRenderPass:setClearColor( 0, 0, 0, 1 )
	end
	self.mainClearRenderPass = mainClearRenderPass
	mainClearRenderPass:setFrameBuffer( mainRenderTarget:getFrameBuffer() )
	mainClearRenderPass:setClearMode( MOAILayer.CLEAR_ALWAYS )

end

function GameRenderContext:initPlaceHolderRenderTable()

	-- local placeHolderRect = MOAIGraphicsProp.new()
	-- local deck = MOAIDrawDeck.new()
	-- deck:setDrawCallback( function()
	-- 	MOAIDraw.setPenColor( .1,1,.1,1 )
	-- 	MOAIDraw.fillRect( -10000,-10000,10000,10000)
	-- end)
	-- placeHolderRect:setDeck( deck )
	
	local clearPass = createTableRenderLayer()
	clearPass:setClearColor( .0, .2, .0, 1 )
	clearPass:setFrameBuffer( MOAIGfxMgr.getFrameBuffer() )
	clearPass:setClearMode( MOAILayer.CLEAR_ALWAYS )

	local async = MOAIRenderMgr.isAsync()
	self.placeHolderRenderTable = _valueList{
		(not async) and function() return game:preSyncRender() end,
		clearPass,
		getLogViewManager():getRenderLayer(),	
		not mock.__nodebug and getDebugUIManager():getRenderLayer() or false,
		(not async) and function() return game:postRender() end,
		getUICursorManager():getRenderLayer()
	}

end

function GameRenderContext:applyPlaceHolderRenderTable()
	_stat( 'apply placeholder render table' )
	self:getRenderRoot():setRenderTable( self.placeHolderRenderTable )
end

function GameRenderContext:applyMainRenderTable( contentTable )
	local async = MOAIRenderMgr.isAsync()
	_stat( 'apply main render table', contentTable, contentTable and #contentTable )
	local game = game
	local insert = table.insert
	local allowDebug = not mock.__nodebug
	

	local finalTable = _valueList(
		
		(not async) and function() return game:preSyncRender() end,

		--preRender
		game.baseClearRenderPass,
		self.mainClearRenderPass or false,
		game.preRenderTable,

		--main
		contentTable or false,
		
		--postRender
		self.outputRenderPass,
		allowDebug and getTopOverlayManager():getRenderLayer() or false,
		allowDebug and getLogViewManager():getRenderLayer() or false,
		allowDebug and getDebugUIManager():getRenderLayer() or false,
		(not async) and function() return game:postRender() end,
		getUICursorManager():getRenderLayer() or false,
		game.postRenderTable
	)
	self:getRenderRoot():setRenderTable( finalTable )
end

function GameRenderContext:setRenderTable( contentTable )
	if not contentTable then
		return self:applyPlaceHolderRenderTable()
	else
		return self:applyMainRenderTable( contentTable )
	end
end

function GameRenderContext:deviceToViewport( x, y )
	return x, y
end

function GameRenderContext:viewportToDevice( x, y )
	return x, y
end

function GameRenderContext:onResize()
	self:updateViewportDeviceMapping()
end

function GameRenderContext:updateViewportDeviceMapping()
	if self.outputMode == 'direct' then
		self.deviceToContext = nil
		self.contextToDevice = nil
	else

		local x0,y0,x1,y1 = self.outputViewport:getAbsPixelRect()
		local vw, vh = x1 - x0, y1 - y0
		local w, h = self:getContentSize() --TODO: content size change?
		local w, h = self.mainRenderTarget:getPixelSize()
		self.deviceToContext = function( _, x, y )
			local ox, oy = x - x0, y - y0
			return ox / vw * w, oy / vh * h
		end

		self.contextToDevice = function( _, x, y )
			return x/w * vw + x0, y/h * vh + y0
		end

		-- self.deviceToContext = nil
		-- self.contextToDevice = nil
	end
end