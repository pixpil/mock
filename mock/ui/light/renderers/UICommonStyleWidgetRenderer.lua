module 'mock'

--------------------------------------------------------------------
CLASS: UICommonStyleWidgetRenderer ( UIWidgetRenderer )
	:MODEL{}

function UICommonStyleWidgetRenderer:onInit( widget )
	self.textElement = self:addElement( UIWidgetElementText(), 'text', 'content' )
	self.bgElement   = self:addElement( UIWidgetElementImage(), 'background', 'background' )

	self.bgElement:setZOrder( -1 )
	self.textElement:setZOrder( 1 )
end

function UICommonStyleWidgetRenderer:onUpdateContent( widget, style )
	local text = widget:getContentData( 'text', 'render' )
	self.textElement:setText( text )
end


