module 'mock'

CLASS: UIFrame ( UIWidget )
	:MODEL{}

function UIFrame:__init()
	self.focusPolicy = false
	self:setClippingChildren( true )
end

function UIFrame:getDefaultRendererClass()
	return UIFrameRenderer
end

-- function UIFrame:setSize( w, h, ... )
-- 	UIFrame.__super.setSize( self, w, h, ... )
-- end

registerEntity( 'UIFrame', UIFrame )

