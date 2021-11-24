module 'mock'

--------------------------------------------------------------------
CLASS: QuadsDeck ( Deck2D )
	:MODEL {
	}

function QuadsDeck:__init()
	self.data = false

end

function QuadsDeck:createMoaiDeck()
	local deck = MOAISpriteDeck2D.new()
	return deck
end

function QuadsDeck:load( deckData )
	self.data = deckData
end

function QuadsDeck:update()
	local data = self.data
	if not data then return end
	local deck = self:getMoaiDeck()
	local texColor = self.pack.texColor
	local texNormal = self.pack.texNormal
	deck:setTexture( 1,texColor )
	deck:setTexture( 1,1, texColor )
	deck:setTexture( 1,2, texNormal )
	local count = #data.quads
	deck:reserveQuads( count )
	for i, quadData in ipairs( data.quads ) do
		local index = quadData.index
		deck:setRect( index, unpack( quadData.rect ) )
		deck:setUVRect( index, unpack( quadData.uv ) )
	end

end


--------------------------------------------------------------------
registerAssetLoader ( 'deck2d.quads',     DeckPackItemLoader )
