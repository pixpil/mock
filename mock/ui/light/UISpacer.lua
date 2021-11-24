module 'mock'

CLASS: UISpacer ( UIWidget )
	:MODEL{}

registerEntity( 'UISpacer', UISpacer )

function UISpacer:__init()
	self.focusPolicy = false
end

function UISpacer:getDefaultRendererClass()
	return false
end
