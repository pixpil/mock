module 'mock'

CLASS: TexturePlane ( GraphicsPropComponent )
	:MODEL{
		Field 'texture' :asset_pre(getSupportedTextureAssetTypes()) :getset( 'Texture' );
		Field 'size'    :type('vec2') :getset('Size');
		'----';
		Field 'resetSize' :action( 'resetSize' );
	}

registerComponent( 'TexturePlane', TexturePlane )
mock.registerEntityWithComponent( 'TexturePlane', TexturePlane )

function TexturePlane:__init()
	self.texture = false
	self.w = 100
	self.h = 100
	self.deck = self:_createDeck()
	self.deck.name = tostring( self )
	self.deck:setSize( 100, 100 )
	self.prop:setDeck( self.deck:getMoaiDeck() )
end

function TexturePlane:_createDeck()
	return Quad2D()
end

function TexturePlane:getTexture()
	return self.texture
end

function TexturePlane:setTexture( t )
	self.texture = t
	self.deck:setTexture( t, false ) --dont resize
	self.deck:update()
	self.prop:forceUpdate()
end

function TexturePlane:getSize()
	return self.w, self.h
end

function TexturePlane:setSize( w, h )
	self.w = w
	self.h = h
	self.deck:setSize( w, h )
	self.deck:update()
	self.prop:forceUpdate()
end

function TexturePlane:getWorldSize()
	local sx, sy = self:getWorldScl()
	return self.w * sx, self.h * sy
end

function TexturePlane:setWorldSize( w, h )
	local sx, sy = self:getWorldScl()
	return self:setSize( w / sx, h / sy )
end

function TexturePlane:resetSize()
	if self.texture then
		local tex = self:loadAsset( self.texture )
		if tex then
			self:setSize( tex:getOutputSize() )
		end
	end
end

--------------------------------------------------------------------
function TexturePlane:inside( x, y, z, pad )
	local _,_,z1 = self.prop:getWorldLoc()
	return self.prop:inside( x,y,z1, pad )
end

--------------------------------------------------------------------
function TexturePlane:drawBounds()
	GIIHelper.setVertexTransform( self.prop )
	local x1,y1,z1, x2,y2,z2 = self.prop:getBounds()
	MOAIDraw.drawRect( x1,y1,x2,y2 )
end

function TexturePlane:getPickingProp()
	return self.prop
end
