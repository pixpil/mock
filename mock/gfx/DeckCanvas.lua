module 'mock'

local insert = table.insert
local index  = table.index
local remove = table.remove

CLASS: DeckCanvas ( GraphicsPropComponent )
	:MODEL{
		Field 'index' :no_edit();
		--'----';
		--Field 'size'    :type('vec2') :getset('Size');
		Field 'serializedData' :getset( 'SerializedData' ) :no_edit();
		'----';
		Field 'edit'    :action('editPen')  :meta{ icon='edit', style='tool'};
		Field 'clear'   :action('editClear') :meta{ icon='clear' };
	}

registerComponent( 'DeckCanvas', DeckCanvas )
--mock.registerEntityWithComponent( 'DeckCanvas', DeckCanvas )

function DeckCanvas:__init()
	self.props = {}
	--self.size  = { 500, 500 }
	self:getMoaiProp().inside = function()
		return self:inside( x,y,z, pad )
	end
end

function DeckCanvas:__collect_dependency( collected, collector )
	local set = {}
	for i, prop in ipairs( self.props ) do
		local deckPath = prop.deckPath
		if deckPath then
			set[ deckPath ] = true
		end
	end
	for deckPath in pairs( set ) do
		collector( self, false, deckPath, collected )
	end
end

function DeckCanvas:inside( x,y,z, pad )
	for i, prop in ipairs( self.props ) do
		if prop:inside( x,y,z, pad ) then return true end
	end
	return false
end

-- function DeckCanvas:setSize( w, h )
-- 	self.size = { w, h }
-- 	self:getMoaiProp():setBounds( -w/2, -h/2, 0, w/2, h/2, 0 )
-- end

-- function DeckCanvas:getSize()
-- 	return unpack( self.size )
-- end

function DeckCanvas:getSerializedData()
	local deckset = {}
	local decklist = {}
	local id0 = 0
	local function affirmDeckId( path )
		local id = deckset[ path ]
		if not id then
			id0 = id0 + 1
			id = id0
			deckset[ path ] = id
			decklist[ id ] = path
		end
		return id
	end
	local propDatas = {}
	for i, prop in ipairs( self.props ) do
		local deckPath = prop.deckPath
		if deckPath then
		-- assert( deckPath, tostring(prop) )
		-- if deckPath then
			local deckId = affirmDeckId( deckPath )
			local x, y, z = prop:getLoc()
			local rx, ry, rz = prop:getRot()
			local sx, sy, sz = prop:getScl()
			local r,g,b,a    = prop:getColor()
			table.insert( propDatas, {
				deck = deckId,
				transform = { x,y,z, rx,ry,rz, sx,sy,sz },
				color = { r,g,b,a },
			})
		end
	end

	local output  = {
		props = propDatas,
		decks = decklist
	}
	return output
end

function DeckCanvas:setSerializedData( data )
	if not data then return end
	local decks = data.decks
	self:clear()
	for i, propData in ipairs( data.props ) do
		local deckId = propData.deck
		local x,y,z, rx,ry,rz, sx,sy,sz = unpack( propData.transform )
		local r,g,b,a = unpack( propData.color )
		local deckPath = decks[ deckId ]
		local prop = self:createProp( deckPath )
		prop:setLoc( x,y,z )
		prop:setRot( rx,ry,rz )
		prop:setScl( sx,sy,sz )
		prop:setColor( r,g,b,a )
		self:_addProp( prop )
	end
	self.deckData = data

end

function DeckCanvas:onDetach( ent )
	for i, prop in ipairs( self.props ) do
		self:destroyProp( prop )
	end
	self.deckData = nil
	DeckCanvas.__super.onDetach( self, ent )
end


local DeckCanvsPropPool = createMOAIObjectPool( MOAIGraphicsProp, {
	clear = function( prop )
		prop:reset()
		prop:setDeck( nil )
	end
} )

function DeckCanvas:createProp( deckPath )
	local deck = loadAsset( deckPath )
	if deck then
		local prop = markRenderNode( DeckCanvsPropPool.reuse() )
		prop:setDeck( deck:getMoaiDeck() )
		prop:setVisible( true )
		prop.deckPath = deckPath
		return prop
	end
end

function DeckCanvas:destroyProp( prop )
	prop:clearRenderState()
	DeckCanvsPropPool.recycle( prop )
end

function DeckCanvas:clear()
	for i, prop in ipairs( self.props ) do
		self:_removeProp( prop, false )
	end
	self.props = {}
end

--x,y = local coords
local defaultSortMode = MOAILayer.SORT_Z_ASCENDING
function DeckCanvas:findProps( x, y, radius )
	local radius = radius or 1
	local ent = self:getEntity()
	local x, y, z  = ent:getProp( 'render' ):modelToWorld( x, y )
	--TODO: use some spatial graph
	local partition = ent:getPartition()
	local propsInPartition = { 
		-- partition:hullListForRay( x, y, -1000000, 0, 0, 1, defaultSortMode )
		partition:hullListForBox( x-radius, y-radius, -100000, x+radius, y+radius, 100000, defaultSortMode )
	}
	local result = {}
	for i, prop in ipairs( propsInPartition ) do
		if prop.__deckCanvas == self then
			insert( result, prop )
		end
	end
	return result
end

function DeckCanvas:findTopProp( x, y )
	local props = self:findProps( x, y )
	local count = #props
	if count > 0 then
		return props[ count ]
	else
		return nil
	end
end

function DeckCanvas:removeProps( x, y )
	local found = self:findProps( x, y )
	for i, prop in ipairs( found ) do
		self:_removeProp( prop )
	end
end

function DeckCanvas:removeTopProp( x, y )
	local found = self:findTopProp( x, y )
	if found then
		self:_removeProp( found )
	end
end

function DeckCanvas:addProp( deckPath )
	local prop = markRenderNode( self:createProp( deckPath ) )
	if prop then
		return self:_addProp( prop )
	end
end

local linkPartition                 = linkPartition
local linkIndex                     = linkIndex
local linkBlendMode                 = linkBlendMode
local inheritTransformColorVisible  = inheritTransformColorVisible
local linkShader                    = linkShader

function DeckCanvas:_addProp( prop )
	local prop0 = self:getMoaiProp()

	local materialInstance = self:getMaterialInstance()
	insert( self.props, prop )
	linkPartition( prop, prop0 )
	linkIndex( prop, prop0 )
	inheritTransformColorVisible( prop, prop0 )

	materialInstance:applyToMoaiProp( prop )
	-- prop:forceUpdate()
	prop.__deckCanvas = self
	return prop
end

function DeckCanvas:_addBoundsProps()
end

local clearLinkPartition    = clearLinkPartition
local clearLinkIndex        = clearLinkIndex
local clearInheritTransform = clearInheritTransform
local clearInheritColor     = clearInheritColor
local clearLinkShader       = clearLinkShader
local clearLinkBlendMode    = clearLinkBlendMode
function DeckCanvas:_removeProp( prop, removeFromTable )
	prop:clearAllLinks()
	-- clearLinkPartition( prop )
	-- clearLinkIndex( prop )
	-- clearInheritTransform( prop )
	-- clearInheritColor( prop )
	prop:setPartition( nil )
	-- prop:forceUpdate()
	self:destroyProp( prop )
	if removeFromTable ~= false then
		local props = self.props
		local idx = index( props, prop )
		if idx then
			return remove( props, idx )
		end
	end
end

function DeckCanvas:applyMaterial( materialInstance )
	for i, prop in ipairs( self.props ) do
		materialInstance:applyToMoaiProp( prop )
	end
end	

-- function DeckCanvas:insideCanvas( x, y, z, pads )
-- 	x, y = self.prop:worldToModel( x, y, z )
-- 	local w, h = self:getSize()
-- 	return x > -w/2 and h > -h/2 and x < w/2 and y < h/2
-- end


--------------------------------------------------------------------
--Editor support

function DeckCanvas:onBuildSelectedGizmo()
	local giz = mock_edit.SimpleBoundGizmo()
	giz:setTarget( self )
	return giz
end

local deckCanvasItemBoundsVisible = true
function setDeckCanvasItemBoundsVisible( vis )
	deckCanvasItemBoundsVisible = vis
end

function isDeckCanvasItemBoundsVisible()
	return deckCanvasItemBoundsVisible
end

local drawRect = MOAIDraw.drawRect
function DeckCanvas:drawBounds()
	if not self._entity then return end
	if deckCanvasItemBoundsVisible then
		mock_edit.applyColor( 'deckcanvas-item' )
		for i, prop in ipairs( self.props ) do
			local x,y,z,x1,y1,z1 = prop:getWorldBounds()
			drawRect( x,y,x1,y1 )
		end
	end

	-- GIIHelper.setVertexTransform( self._entity:getProp() )
	-- local w, h = self:getSize()
	-- mock_edit.applyColor( 'deckcanvas-bound' )
	-- drawRect( -w/2, -h/2, w/2, h/2 )
end

function DeckCanvas:editPen()
	mock_edit.startAdhocSceneTool( 'deckcanvas_pen', { target = self } )
end

function DeckCanvas:editClear()
	self:clear()
	mock_edit.getCurrentSceneView():updateCanvas()
	markProtoInstanceOverrided( self, 'serializedData' )
end

function DeckCanvas:modelToCanvas( x, y, z, action )
	return x, y, z
end
