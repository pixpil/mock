module 'mock'

--------------------------------------------------------------------
CLASS: UIWidgetGroup ( UIWidget )
	:MODEL{}

registerEntity( 'UIWidgetGroup', UIWidgetGroup )

function UIWidgetGroup:__init()
	self.clippingChildren = false
	self.trackingPointer = false
end

