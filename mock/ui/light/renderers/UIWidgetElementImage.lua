module 'mock'

--------------------------------------------------------------------
CLASS: UIWidgetElementImage ( UIWidgetElement )
	:MODEL{}

function UIWidgetElementImage:__init()
	self.defaultSprite  = false
	self.defaultBlend   = 'alpha'
	self.defaultStretch = true
	self.stretch = true
end

function UIWidgetElementImage:setDefaultSprite( sprite )
	self.defaultSprite = sprite
end

function UIWidgetElementImage:setDefaultBlend( blend )
	self.defaultBlend = blend
end

function UIWidgetElementImage:setDefaultStretch( stretch )
	self.defaultStretch = stretch
end

function UIWidgetElementImage:onLoad()
	local sprite = self:attach( DeckComponent() )
	self.sprite = sprite
	self.spriteDeck = false
end

local function _affirmDeck( data )
	if not data then return nil end
	if type( data ) == 'string' then --path
		local imagePath = data
		local deck = mock.Quad2D()
		deck:setTexture( imagePath )
		local dw, dh = deck:getSize()
		deck:setOrigin( dw/2, dh/2 )
		deck:update()
		return AdHocAsset( deck )
	else
		if isAdHocAsset( data ) then
			return data
		elseif isInstance( data, mock.Deck2D ) then
			return AdHocAsset( data )
		end
	end
end

function UIWidgetElementImage:updateSprite( widget, style )
	local sprite = self.sprite
	local spriteDeck = style:getAsset( self:makeStyleName( 'sprite' ), self.defaultSprite )
	spriteDeck = _affirmDeck( spriteDeck )
	if self.spriteDeck ~= spriteDeck then
		self.spriteDeck = spriteDeck
		if not spriteDeck then
			sprite:hide()
		else
			sprite:setDeck( spriteDeck )
			sprite:show()
		end
	end
end

function UIWidgetElementImage:onUpdateContent( widget, style )
	self:updateSprite( widget, style )
end

function UIWidgetElementImage:onUpdateStyle( widget, style )	
	self:updateSprite( widget, style )
	local sprite = self.sprite
	local material = style:getAsset( self:makeStyleName( 'material' ) )
	local blend = style:get( self:makeStyleName('blend'), self.defaultBlend )
	local color = { style:getColor( self:makeStyleName( 'color' ), { 1,1,1,1 } ) }
	local alpha = style:getNumber( self:makeStyleName('alpha') )
	if material then
		sprite:setMaterial( material )
	end
	local r,g,b,a = unpack( color )
	sprite:setColor( r,g,b,alpha or a )
	sprite:setBlend( blend )
	self.stretch = style:getBoolean( 'stretch', self.defaultStretch )
end

function UIWidgetElementImage:onUpdateSize( widget, style )
	local sprite = self.sprite
	local ox, oy = self:getOffset()
	local x0, y0, x1, y1 = self:getRect()
	if self.stretch then
		sprite:setRect( x0 + ox, y0 + oy, x1 + ox, y1 + oy )
	else
		sprite:fitRect( x0 + ox, y0 + oy, x1 + ox, y1 + oy )
	end
	sprite:setLocZ( self:getZOffset() )
end
