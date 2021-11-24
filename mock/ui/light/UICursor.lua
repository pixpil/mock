module 'mock'

local UICursorRegistry = {}

--------------------------------------------------------------------
CLASS: UICursor ()
function UICursor.register( clas, id )
	if UICursorRegistry[ id ] then
		_warn( 'duplicated cursor id', id )
	end
	UICursorRegistry[ id ] = clas
end

function UICursor:__init()
	self.transform = MOAITransform.new()
	self.transform:setScl( 1, -1, 1 )
	self.visible = false
	self.active = false
	self.margin = 0
end

function UICursor:getManager()
	return self.manager
end

function UICursor:getLoc()
	return self.transform:getLoc()
end

function UICursor:getTransform()
	return self.transform
end

function UICursor:setActive( active )
	if self.active == active then return end
	self.active = active
	if active then
		return self:onActivate()
	else
		return self:onDeactivate()
	end
end

function UICursor:onLoad()
end

function UICursor:onUpdate( dt )
end

function UICursor:onActivate( ... )
end

function UICursor:onDeactivate( ... )
end

function UICursor:setScl( scl )
end

--------------------------------------------------------------------
CLASS: UIGraphicsPropCursor ( UICursor )

function UIGraphicsPropCursor:__init()
	local prop = createRenderProp()
	self.prop = prop
	setPropBlend( prop, 'alpha' )
	inheritTransform( prop, self.transform )
	prop:setScl( 1, -1, 1 )
end


function UIGraphicsPropCursor:setScl( scl )
	self.prop:setScl( scl, -scl, scl )
end

function UIGraphicsPropCursor:setOrigin( x, y )
	return self.prop:setPiv( x or 0, -( y or 0 ) )
end

function UIGraphicsPropCursor:onActivate()
	self.prop:setPartition( self:getManager():getRenderLayer() )
end

function UIGraphicsPropCursor:onDeactivate()
	self.prop:setPartition()
end

--------------------------------------------------------------------
CLASS: UITexturePlaneCursor ( UIGraphicsPropCursor )

function UITexturePlaneCursor:__init( texture, w, h, ox, oy )
	if type( texture ) == 'string' then
		texture = mock.loadAsset( texture )
	end
	if not isInstance( texture, TextureInstance ) then
		_error( 'no texture' )
		return
	end
	local tw, th = texture:getSize()
	local tex, uv = texture:getMoaiTextureUV()
	w = w or tw
	h = h or th
	local deck = MOAISpriteDeck2D.new()
	deck:setTexture( tex )
	deck:setUVRect( unpack( uv ) )
	deck:setRect( 0, 0, w, h )
	self:setOrigin( ( ox or 0 ) * w, ( oy or 0 ) * h - h/2 )
	self.prop:setDeck( deck )
	self.textureInstance = texture
end

--------------------------------------------------------------------
CLASS: UIDefaultCursor ( UIGraphicsPropCursor )

function UIDefaultCursor:onLoad()
	local pngData = require 'mock.ui.light.default_cursor_png'
	local img = loadImageBase64( nil, pngData )
	local texture = MOAITexture.new()
	texture:load( img, MOAIImage.TRUECOLOR )
	local deck = MOAISpriteDeck2D.new()
	deck:setTexture( texture )
	deck:setRect( 0, -24, 18, 0 )
	self.prop:setDeck( deck )
end

--------------------------------------------------------------------
CLASS: UICursorSimple ( UICursor )

function UICursorSimple:__init( option )
end

function UICursorSimple:onLoad()
end

--------------------------------------------------------------------
CLASS: UICursorManager ( GlobalManager )
	:MODEL{}

function UICursorManager:__init()
	self.cursors = {}
	self.showCursorReasons = {}
	self.transform = MOAITransform.new()
	self.transform:setScl( 1, 1, 1 )
	self.transform:setLoc( 100, 100 )
	self.activeCursor = false
	self.visible = false
	self.relativeMode = false
	self.updateLoc = self.updateLocNormal
	self.currentX = 0
	self.currentY = 0
	self.targetX = 0
	self.targetY = 0

	self.scaled = true
	self.sx = 1
	self.sy = 1
	self.ox = 0
	self.oy = 0
end

function UICursorManager:init()
	
	connectGlobalSignalMethod( 'device.resize', self, 'onDeviceResize' )
	connectGlobalSignalMethod( 'input.mouse.mode_change', self, 'onMouseModeChange' )
	
	local layer = createPartitionRenderLayer()
	local viewport = MOAIViewport.new ()
	layer:setViewport( viewport )
	layer:setClearMode( MOAILayer.CLEAR_NEVER )
	self.viewport = viewport
	self.renderLayer = layer

	local quadCamera = MOAICamera.new()
	quadCamera:setOrtho( true )
	quadCamera:setNearPlane( -100000 )
	quadCamera:setFarPlane( 100000 )
	quadCamera:setScl( 1, -1, 1 )
	layer:setCamera( quadCamera )
	layer:setFrameBuffer( game:getDeviceFrameBuffer() )

	local scissor = MOAIScissorRect.new()
	self.scissor = scissor
	layer:setScissorRect( scissor )

	local defaultCursor = UIDefaultCursor()
	self:registerCursor( 'default', defaultCursor )
	self:setCursor()

	self:updateViewport()
	self:setVisible( false )

	addMouseListener( function( ev, x, y, btn, rx, ry )
		if ev == 'move' then
			return self:updateLoc( x, y, rx, ry )
		end
	end)

	self:updateLoc( 100, 100 )

end

function UICursorManager:getTransform()
	return self.transform
end

function UICursorManager:updateViewport()
	local dw, dh = game:getDeviceResolution()
	local w, h = game:getMainRenderTarget():getPixelSize()
	local outputViewport = game:getOutputViewport()
	local scl = game:getOutputScale()

	self.viewport:setSize ( dw,dh )
	self.viewport:setScale ( w, h )
	self.viewport:setOffset ( -1,1 )

	self.scissor:setRect( outputViewport:getAbsPixelRect() )
	
	self.sx = dw/w * scl
	self.sy = dh/h * scl

	self.ox = dw*( 1-scl ) /2
	self.oy = dh*( 1-scl ) /2
end

function UICursorManager:onDeviceResize( w, h )
	self:updateViewport()
end


function UICursorManager:getRenderLayer()
	return self.renderLayer
end

function UICursorManager:registerCursor( id, cursor, force )
	_log( 'register cursor', id, cursor )
	local prevCursor = self.cursors[ id ]
	local prevActive = false
	if prevCursor then
		if not force then
			_warn( 'duplicated cursor', id )
			return
		end
		prevActive = prevCursor.active
		if prevActive then
			prevCursor:setActive( false )
		end
	end
	self.cursors[ id ] = cursor
	cursor.manager = self
	cursor.__id = id
	linkTransform( cursor:getTransform(), self.transform )
	self.transform:setLoc( 0,0 )
	cursor:onLoad()
	if prevActive then
		cursor:setActive( true )
	end
end

function UICursorManager:hide( reason )
	reason = reason or 'default'
	self.showCursorReasons[ reason ] = nil
	if not next( self.showCursorReasons ) then
		self:setVisible( false )
	end
end

function UICursorManager:show( reason )
	reason = reason or 'default'
	self.showCursorReasons[ reason ] = true
	self:setVisible( true )
end

function UICursorManager:setVisible( visible )
	self.renderLayer:setEnabled( visible )
end

function UICursorManager:isCursorVisible()
	return self.renderLayer:isVisible()
end

function UICursorManager:getCursorObject()
	return self.activeCursor
end

function UICursorManager:getCursor()
	return self.activeCursor and self.activeCursor.__id
end

function UICursorManager:setCursor( id )
	id = id or 'default'
	local cursor = self.cursors[ id ]
	if not cursor then
		_warn( 'cursor not defined', id )
		cursor = self.cursors[ 'default' ]
	end
	local prevCursor = self.cursor
	if prevCursor == cursor then return end
	if prevCursor then
		prevCursor:setActive( false )
	end
	self.activeCursor = cursor
	if cursor then
		cursor:setActive( true )
	end
	return cursor
end

function UICursorManager:setMargin( margin )
	self.margin = margin or 0
end

function UICursorManager:setRelativeMouseMode( relative )
	self.relativeMode = relative or false
	self.updateLoc = self.relativeMode and self.updateLocRelative  or self.updateLocNormal
end

function UICursorManager:isRelativeMouseMode()
	return self.relativeMode
end

function UICursorManager:setCursorLoc( x, y )
	self.targetX = x
	self.targetY = y
	return self.transform:setLoc( x, y )
end

function UICursorManager:onMouseModeChange( relative )
	return self:setRelativeMouseMode( relative )
end

function UICursorManager:cursorToWnd( x, y )
	local wx, wy = x * self.sx + self.ox, y * self.sy + self.oy
	return wx, wy
end

--------------------------------------------------------------------
local clamp = math.clamp
function UICursorManager:updateLocRelative( x, y, rx, ry )
	local w, h = game:getMainRenderTarget():getPixelSize()
	local ww,hh = game:getDeviceResolution()
	local ratioX, ratioY = w/ww, h/hh

	local margin = self.margin or 0
	local x0, y0 = self.targetX, self.targetY
	-- local x0, y0 = self.transform:getLoc()
	local x1, y1 = x0 + rx * ratioX, y0 + ry * ratioY

	x1 = clamp( x1, 0 + margin, w - margin )
	y1 = clamp( y1, 0 + margin, h - margin )
	self.targetX = x1
	self.targetY = y1
end

function UICursorManager:updateLocNormal( x, y, rx, ry )
	self.targetX = x
	self.targetY = y
end

function UICursorManager:onUpdate( dt )
	local LERP = 1
	local x1 = lerp( self.currentX, self.targetX, LERP )
	local y1 = lerp( self.currentY, self.targetY, LERP )
	self.transform:setLoc( x1, y1 )
	self.currentX = x1
	self.currentY = y1
end

function UICursorManager:getLoc()
	return self.currentX, self.currentY
end

---------------------------------------------------------------------
local _UICursorManager = UICursorManager()
function getUICursorManager()
	return _UICursorManager
end

function setCursor( id )
	return _UICursorManager:setCursor( id )
end

function registerCursor( id, cur, force )
	return _UICursorManager:registerCursor( id, cur, force )
end