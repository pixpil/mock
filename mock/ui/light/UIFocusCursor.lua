module 'mock'

local nilFunc = function() end
--------------------------------------------------------------------
CLASS: UIFocusCursor ( UIWidget )
	:MODEL{}

function UIFocusCursor:__init()
	self.focusPolicy = false
	self.trackingPointer = false
	self.zorder = 100000
	self.layoutDisabled = true
	self.updateNode = MOAIScriptNode.new()
	self.targetWidget = false
	self.hugeScissorRect = MOAIScissorRect.new()
	self.hugeScissorRect:setRect( -100000, -100000, 100000, 100000 )
end

function UIFocusCursor:isInteractive()
	return false
end

function UIFocusCursor:getDefaultRendererClass()
	return UIFrameRenderer
end

function UIFocusCursor:updateClippingRect()
	-- body
end

function UIFocusCursor:setTargetWidget( target )
	local prevTarget = self.targetWidget
	if prevTarget == target then return end
	self.targetWidget = target
	
	if prevTarget then
		self.updateNode:clearNodeLink( prevTarget:getProp() )
		self.updateNode:setCallback( nilFunc )
	end

	if target then
		local cursorFeature = target:getStyleAcc():get( 'focus_cursor' )
		if cursorFeature == 'none' then
			self:hide()
		else
			self:show()
			self:clearFeatures()
			if cursorFeature then
				self:setFeature( cursorFeature )
			end
			self.updateNode:setNodeLink( target:getProp() )
			self.updateNode:setCallback( self:methodPointer( 'onTargetUpdate' ))
			clearLinkScissorRect( self:getProp() )
			self:getProp():setScissorRect( self.hugeScissorRect )
			self:getProp():forceUpdate()
			linkScissorRect( self:getProp(), target:getProp() )
			self:syncToTarget()
		end
	else
		self:hide()
	end
end

function UIFocusCursor:syncToTarget()
	-- body
	local target = self.targetWidget
	local padding = 8
	local x, y = target:getViewLoc()
	local _, _, z = target:getWorldLoc()
	self:setLoc( x-padding, y+padding, 0 )
	self:setPivZ( -z )
	local w, h = target:getSize()
	self:setSize( w + padding*2, h + padding*2 )
	if not target:isVisible() then
		return self:setTargetWidget( false )
	end
end

function UIFocusCursor:onTargetUpdate()
	self:syncToTarget()
end
