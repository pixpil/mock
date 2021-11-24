module 'mock'

--------------------------------------------------------------------
CLASS: UIWidgetElementScript ( UIWidgetElement )
	:MODEL{}

function UIWidgetElementScript:__init()
	local prop = markRenderNode( MOAIGraphicsProp.new() )
	local deck = MOAIDrawDeck.new()
	self.drawScriptProp = prop
	self.drawScriptDeck = deck
	prop:setDeck( deck )
end

function UIWidgetElementScript:onLoad()
	self:_attachProp( self.drawScriptProp )
end

function UIWidgetElementScript:getDrawScriptProp()
	return self.drawScriptProp
end

function UIWidgetElementScript:setDrawCallback( callback )
	self.drawScriptDeck:setDrawCallback( callback )
end

function UIWidgetElementScript:onDestroy()
	self:_detachProp( self.drawScriptProp )
	self.drawScriptDeck:setDrawCallback( nil )
end

function UIWidgetElementScript:onUpdateStyle( widget, style )
	local draw = self.draw
	local color = { style:getColor( self:makeStyleName( 'color' ), { 1,1,1,1 } ) }
	self.drawScriptProp:setColor( unpack( color ) )
end

function UIWidgetElementScript:onUpdateSize( widget, style )
	local draw = self.draw
	local ox, oy = self:getOffset()
	local x0, y0, x1, y1 = self:getRect()
	self.drawScriptDeck:setRect( x0 + ox, y0 + oy, x1 + ox, y1 + oy )
end

