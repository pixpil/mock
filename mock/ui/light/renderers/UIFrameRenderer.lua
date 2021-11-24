module 'mock'

--------------------------------------------------------------------
CLASS: UIFrameRenderer ( UIWidgetRenderer )
	:MODEL{}

function UIFrameRenderer:onInit( widget )
	self.bgElement = self:addElement( UIWidgetElementImage(), 'background', 'background' )
	self.bgElement:setZOrder( -1 )
end

