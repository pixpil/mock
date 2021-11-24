module 'mock'

CLASS: UITextArea ( UIWidget )
	:MODEL{
		Field 'text' :string() :getset( 'Text' ) :widget('textbox');
}

mock.registerEntity( 'UITextArea', UITextArea )

function UITextArea:__init()
	self.text = 'Label Text'
end

function UITextArea:getDefaultRendererClass()
	return UITextAreaRenderer
end

function UITextArea:getTextLabel()
	return self:getRenderer():getTextLabel()
end

function UITextArea:getText( t )
	return self.text
end

function UITextArea:setText( t )
	self.text = t
	self:invalidateContent()
end

function UITextArea:setI18NText( t )
	return self:setText( self:translate( t ) )
end

function UITextArea:getContentData( key, role )
	if key == 'text' then
		return self.text
	end
end

function UITextArea:getContentSize()
	
end

function UITextArea:testTextHeight( width )
	local label = self:getTextLabel().box
	if not label then return 0 end
	width = width or self.w
	local x0, y0, x1, y1 = label:getRect()
	label:setRect( 0, 0, width, 1000000 )
	local bx0, by0, bx1, by1 = label:getTextBounds()
	label:setRect( x0, y0, x1, y1 )
	if by1 then
		return by1 - by0
	else
		return 0
	end
end

function UITextArea:testTextWidth( height )
	local label = self:getTextLabel().box
	if not label then return 0 end
	height = height or self.h
	local x0, y0, x1, y1 = label:getRect()
	label:setRect( 0, 0, 1000000, height )
	local bx0, by0, bx1, by1 = label:getTextBounds()
	if bx0 then
		return bx1 - bx0
	else
		return 0
	end
end
