module 'mock'

CLASS: DeckComponentSequence ( GraphicsPropComponent )
	:MODEL{
		Field 'deckMap'  :asset( 'asset_map' ) :getset( 'DeckMap' );
		'----';
		Field 'sequence'  :string() :onset( 'updateProps' );
		'----';
		Field 'direction' :type( 'vec3' ) :getset( 'Direction' );
		Field 'spacing'   :number() :onset( 'updateLayout' );

	}

registerComponent( 'DeckComponentSequence', DeckComponentSequence )

function DeckComponentSequence:__init()
	self.deckMapPath  = false
	self.spacing      = 0
	self.props        = {}
	self.attached     = false
	self.sequence     = '1'
	self.direction    = { 1, 0, 0 }
end

function DeckComponentSequence:onAttach( ent )
	DeckComponentSequence.__super.onAttach( self, ent )
	self.attached = true
	self:updateProps()
end

function DeckComponentSequence:onDetach( ent )
	self:clearProps()
	self.attached = false
	DeckComponentSequence.__super.onDetach( self, ent )
end

function DeckComponentSequence:setDeckMap( deckMapPath )
	self.deckMapPath = deckMapPath
	self:updateProps()
end

function DeckComponentSequence:getDeckMap( deckMapPath )
	return self.deckMapPath	
end

function DeckComponentSequence:getSpacing()
	return self.spacing
end

function DeckComponentSequence:setSpacing( spacing )
	self.spacing = spacing or 0
	self:updateLayout()
end

function DeckComponentSequence:getDirection()
	return unpack( self.direction )
end

function DeckComponentSequence:setDirection( x,y,z )
	self.direction = { x,y,z }
	self:updateLayout()
end

local char = string.char
function DeckComponentSequence:updateProps()
	if not self.attached then return end
	self:clearProps()
	
	local deckMapPath = self.deckMapPath
	local deckMap = deckMapPath and loadAsset( deckMapPath ) or false
	if not deckMap then return end

	local entries = deckMap:getEntries()
	if not entries then return end

	local materialInstance = self:getMaterialInstance()

	local prop0 = self:getMoaiProp()
	local props = {}
	for s in self.sequence:gmatch( '%w' ) do
		local entry = entries[ s ]
		local assetPath = entry and entry[ 'path' ]
		local asset = assetPath and loadAsset( assetPath ) 
		if asset and asset:isInstance( Deck2D ) then
			local prop = createRenderProp()
			linkPartition( prop, prop0 )
			linkIndex( prop, prop0 )
			inheritTransformColorVisible( prop, prop0 )
			prop._deck = asset
			prop:setDeck( asset:getMoaiDeck() )
			materialInstance:applyToMoaiProp( prop )
			prop:forceUpdate()
			table.insert( props, prop )
			local size = entry[ 'size' ]
			prop._overridedSize = false
			if type( size ) == 'table' then
				local w, h, d = unpack( size )
				if ( type( w ) == 'number' and type( h ) == 'number' ) then
					d = tonumber( d ) or 0
					prop._overridedSize = { w, h, d }
				end
			end

			local offset = entry[ 'offset' ]
			if type( offset ) == 'table' then
				local x, y, z = unpack( offset )
				prop._overridedOffset = { x,y,z }
				prop:setPiv( -(x or 0 ), -( y or 0 ), -( z or 0 ) )
			end

		end
	end

	self.props = props

	return self:updateLayout()
end

local max = math.max
function DeckComponentSequence:updateLayout()
	local x, y, z = 0, 0, 0
	local nx, ny, nz = self:getDirection()
	local spacing = self.spacing or 0
	local w1, h1, d1 = 0, 0, 0
	for i, prop in ipairs( self.props ) do
		local bx, by, bz, bx1, by1, bz1 = prop:getBounds()
		local w, h, d = bx1 - bx, by1 - by, bz1 - bz
		w1 = max( w, w1 )
		h1 = max( h, h1 )
		d1 = max( d, d1 )
		prop:setLoc( x, y, z )
		local dx = ( w + spacing ) * nx
		local dy = ( h + spacing ) * ny
		local dz = ( d + spacing ) * nz
		x = x + dx
		y = y + dy
		z = z + dz
	end
	if nx ~= 0 then w1 = 0 end
	if ny ~= 0 then h1 = 0 end
	if nz ~= 0 then d1 = 0 end
	self.prop:setBounds( 0,0,0, x + w1,y + h1,z + d1 )
end

function DeckComponentSequence:clearProps()
	for i, prop in ipairs( self.props ) do
		prop:clearAllLinks()
		-- clearLinkPartition( prop )
		-- clearLinkIndex( prop )
		-- clearInheritTransform( prop )
		-- clearInheritColor( prop )
		prop:setPartition( nil )
		-- prop:forceUpdate()
	end
	self.props = {}
end

function DeckComponentSequence:applyMaterial( mat )
	mat:applyToMoaiProp( self.prop )
	for i, prop in ipairs( self.props ) do
		mat:applyToMoaiProp( prop )
	end
end	

--------------------------------------------------------------------
function DeckComponentSequence:drawBounds()
	GIIHelper.setVertexTransform( self.prop )
	local x1,y1,z1, x2,y2,z2 = self.prop:getBounds()
	MOAIDraw.drawRect( x1,y1,x2,y2 )
end

function DeckComponentSequence:onBuildSelectedGizmo()
	return mock_edit.SimpleBoundGizmo()
end
