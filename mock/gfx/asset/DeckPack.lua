module 'mock'

--------------------------------------------------------------------
CLASS: DeckPackBase ()
	:MODEL{}

function DeckPackBase:getDeck( name )
	return nil
end


--------------------------------------------------------------------
--PSD DeckPack
--------------------------------------------------------------------
CLASS: DeckPack ( DeckPackBase )
	:MODEL{}

function DeckPack:__init()
	self.items = {}
	self.texColor = false
	self.texNormal = false
	self.assetNode = false
end

function DeckPack:getDeck( name )
	return self.items[ name ]
end

local function _findTexture( path, name )
	local noExtName = string.format( '%s/%s', path, name )
	if MOAIFileSystem.checkFileExists( noExtName ) then return noExtName end
	local texName = string.format( '%s/%s.tex', path, name )
	if MOAIFileSystem.checkFileExists( texName ) then return texName end
	local hmgName = string.format( '%s/%s.hmg', path, name )
	if MOAIFileSystem.checkFileExists( hmgName ) then return hmgName end
	local pngName = string.format( '%s/%s.png', path, name )
	if MOAIFileSystem.checkFileExists( pngName ) then return pngName end
	return nil
end

function DeckPack:load( path )
	self.dataPath = path
	local asyncTexture = TEXTURE_ASYNC_LOAD

	local packData = loadAssetDataTable( path .. '/' .. 'decks.json' )
	self.texColor  = MOAITexture.new()
	self.texNormal = MOAITexture.new()
	
	if asyncTexture then
		local taskC = AsyncTextureLoadTask( _findTexture( path, 'decks' ), MOAIImage.TRUECOLOR )
		taskC:setTargetTexture( self.texColor )
		local taskN = AsyncTextureLoadTask( _findTexture( path, 'decks_n' ), MOAIImage.TRUECOLOR )
		taskN:setTargetTexture( self.texNormal )

		taskC:start()
		taskN:start()
	else
		self.texColor :load( _findTexture( path, 'decks' ), MOAIImage.TRUECOLOR, nil, true )
		self.texNormal:load( _findTexture( path, 'decks_n' ), MOAIImage.TRUECOLOR, nil, true )
	end

	self.texColor :setFilter( MOAITexture.GL_NEAREST )
	self.texNormal:setFilter( MOAITexture.GL_NEAREST )

	-- self.assetNode:bindMoaiFinalizer( self.texColor )
	-- self.assetNode:bindMoaiFinalizer( self.texNormal )

	local deckDatas = packData['decks']
	local deckCount = #deckDatas
	for i = 1, deckCount do 
		local deckData = deckDatas[ i ]
		local deckType = deckData['type']

		local deck
		if deckType =='deck2d.mquad' then
			deck = MQuadDeck()

		elseif deckType == 'deck2d.mtileset' then
			deck = MTileset()

		elseif deckType == 'deck2d.quads' then
			deck = QuadsDeck()

		end

		local name = deckData[ 'name' ]
		deck:load( deckData )
		deck.name = name
		deck.pack = self
		self.items[ name ] = deck
	end

end


--------------------------------------------------------------------
local function DeckPackloader( node )
	local pack = DeckPack()
	pack.assetNode = node
	local dataPath = node:getObjectFile( 'export' )
	pack:load( dataPath )
	return pack
end

local function Deck2DPackUnloader( node )
	local pack = node:getCachedAsset()
	if not pack then return end
	if pack.texNormal then
		pack.texNormal:purge()
	end
	if pack.texColor then
		pack.texColor:purge()
	end
end

--------------------------------------------------------------------
--Legacy PACK
--------------------------------------------------------------------
CLASS: Deck2DPack( DeckPackBase )
:MODEL{
	Field 'name'  :string();
	Field 'decks' :array( Deck2D ) :no_edit() :sub()
}

function Deck2DPack:__init()
	self.decks = {}
end

function Deck2DPack:getDeck( name )
	for i, deck in ipairs( self.decks ) do
		if deck.name == name then return deck end
	end
	return nil
end

function Deck2DPack:addDeck( name, dtype, src )
	local deck
	if dtype == 'quad' then
		local quad = mock.Quad2D()
		quad:setTexture( src )
		deck = quad
	elseif dtype == 'tileset' then
		local tileset = mock.Tileset()
		tileset:setTexture( src )
		deck = tileset
	elseif dtype == 'stretchpatch' then
		local patch = mock.StretchPatch()
		patch:setTexture( src )
		deck = patch
	elseif dtype == 'quad_array' then
		local qa = mock.QuadArray()
		qa:setTexture( src )
		deck = qa
	elseif dtype == 'polygon' then
		local poly = mock.PolygonDeck()
		poly:setTexture( src )
		deck = poly
	end
	deck.type = dtype
	deck:setName( name )
	deck.pack = self
	table.insert( self.decks, deck )
	return deck
end

function Deck2DPack:removeDeck( deck )
	local idx  = table.index( self.decks, deck )
	if idx then table.remove( self.decks, idx ) end
end

--------------------------------------------------------------------
function Deck2DPackLoader( node )
	local packData   = loadAssetDataTable( node:getObjectFile('def') )
	local pack = deserialize( nil, packData )
	return pack
end

--------------------------------------------------------------------
registerAssetLoader ( 'deck2d', Deck2DPackLoader )
registerAssetLoader ( 'deck_pack', DeckPackloader )
registerAssetLoader ( 'deck_pack_raw', DeckPackloader )
