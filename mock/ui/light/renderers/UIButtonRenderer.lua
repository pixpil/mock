module 'mock'

--------------------------------------------------------------------
CLASS: UIButtonRenderer ( UIWidgetRenderer )
	:MODEL{}

function UIButtonRenderer:onInit( widget )
	self.textElement = self:addElement( UIWidgetElementText(), 'text', 'content' )
	self.bgElement   = self:addElement( UIWidgetElementImage(), 'background', 'background' )

	self.bgElement:setZOrder( -1 )
	self.textElement:setZOrder( 1 )
end

function UIButtonRenderer:onUpdateContent( widget, style )
	local text = widget:getContentData( 'text', 'render' )
	self.textElement:setText( text )
end

