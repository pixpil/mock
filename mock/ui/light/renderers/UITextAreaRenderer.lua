module 'mock'

--------------------------------------------------------------------
CLASS: UITextAreaRenderer ( UICommonStyleWidgetRenderer )
	:MODEL{}

function UITextAreaRenderer:onInit( widget )
	UITextAreaRenderer.__super.onInit( self, widget )
	self.textElement:setZOrder( 1 )
end

function UITextAreaRenderer:getTextLabel()
	return self.textElement:getTextLabel()
end