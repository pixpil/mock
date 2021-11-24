module 'mock'
--------------------------------------------------------------------
--example component for PaintCanvas
--------------------------------------------------------------------
CLASS: PaintCanvasPlane ( mock.RenderComponent )
	:MODEL{}

registerComponent( 'PaintCanvasPlane', PaintCanvasPlane )

function PaintCanvasPlane:__init()
	self.canvas = false
	self.props = {}
	self.mainProp = createRenderProp()
end

function PaintCanvasPlane:onAttach( ent )
	ent:_attachProp( self.mainProp, 'render' )
	local canvas = ent:com( 'PaintCanvas' ) or false
	self.canvas = canvas
	if canvas then
		self:connect( canvas.changed, 'onCanvasUpdate' )
		linkTransform( self.mainProp, canvas.transform )
		canvas:update()
	end
end

function PaintCanvasPlane:onStart( ent )
	if self.canvas then
		self.canvas:update()
	end
end

function PaintCanvasPlane:onDetach( ent )
	self.canvas = false
	self:clear()
	ent:_detachProp( self.mainProp )
end

function PaintCanvasPlane:onCanvasUpdate( event, subset )
	self:update( event, subset )
end

function PaintCanvasPlane:affirmTileProp( tile )
	local canvas = self.canvas
	local w, h = canvas:getTileSize()
	local props = self.props
	local prop = props[ tile ]
	if prop then return prop end
	
	local prop0 = self.mainProp
	local materialInstance = self:getMaterialInstance()
	local prop = createRenderProp()
	local deck = MOAISpriteDeck2D.new()
	local tex = tile:getMoaiTexture()
	deck:setRect( 0, 0, w, h )
	deck:setTexture( tex )
	prop:setDeck( deck )
	prop:setLoc( tile.locX, tile.locY )
	if getRenderManager().flipRenderTarget then
		deck:setUVRect( 0,0,1,1 )
	end

	materialInstance:applyToMoaiProp( prop )
	linkPartition( prop, prop0 )
	linkIndex( prop, prop0 )
	inheritTransformColorVisible( prop, prop0 )
	props[ tile ] = prop
	prop.textureSeq = tile.textureSeq
	return prop
end

function PaintCanvasPlane:_removeProp( prop )
	-- clearLinkPartition( prop )
	-- clearLinkIndex( prop )
	-- clearInheritTransform( prop )
	-- clearInheritColor( prop )
	prop:clearAllLinks()
	prop:setPartition( nil )
	prop:forceUpdate()
end

function PaintCanvasPlane:removeTileProp( tile )
	local prop = self.props[ tile ]
	if not prop then return end
	self.props[ tile ] = nil
	self:_removeProp( prop )
	return prop
end

function PaintCanvasPlane:update( event, subset )
	local canvas = self.canvas
	if not canvas then return end
	if event == 'clear' then
		if not subset then
			self:clear()
		else
			for i, tile in ipairs( subset ) do
				self:removeTileProp( tile )
			end
		end

	else
		for i, tile in ipairs( subset or canvas:collectTiles() ) do
			local prop = self:affirmTileProp( tile )
			if prop.textureSeq < tile.textureSeq then
				prop:setTexture( tile:getMoaiTexture() )
				prop.textureSeq = tile.textureSeq
			end
		end

	end

end

function PaintCanvasPlane:clear()
	local ent = self:getEntity()
	for _, prop in pairs( self.props ) do
		self:_removeProp( prop )
	end
	self.props = {}
end

function PaintCanvasPlane:applyMaterial( materialInstance )
	for _, prop in pairs( self.props ) do
		materialInstance:applyToMoaiProp( prop )
	end
end
