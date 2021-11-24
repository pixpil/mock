module 'mock'
--------------------------------------------------------------------
CLASS: UIFormLayoutLabel ( UILabel )


--------------------------------------------------------------------
CLASS: UIFormLayoutItem ( UILayoutItem )
	:MODEL{
		'----';
		Field 'label' :string() :getset( 'Label' );
		'----';
		Field 'labelFeatures' :string() :getset( 'LabelFeatures' );
	}

mock.registerComponent( 'UIFormLayoutItem', UIFormLayoutItem )
--mock.registerEntityWithComponent( 'UIFormLayoutItem', UIFormLayoutItem )

function UIFormLayoutItem:__init()
	self.label = 'Label'
	self.labelWidget = false
	self.policy = { 'expand', 'minimum' }
	self.alignment = { 'left', 'middle' }
	self.proportion = { 0, 0 }
	self.minSize = { 0, 30 }
	self.maxSize = { 10000, 10000 }
	self.labelFeatures = ''
end

function UIFormLayoutItem:onAttach( ent )
	UIFormLayoutItem.__super.onAttach( self, ent )
	if not ent:isInstance( 'UIWidget' ) then return end
	local p = ent:getParentWidget()
	if not p then return end
	local labelWidget = self:createLabelWidget()
	self.labelWidget = labelWidget
	p:addInternalChild( labelWidget )
	linkLocalVisible( labelWidget:getProp(), ent:getEntity():getProp() )
	labelWidget:setText( self.label )
	labelWidget:setDefaultFeatures( self.labelFeatures )
end

function UIFormLayoutItem:onDetach( ent )
	UIFormLayoutItem.__super.onDetach( self, ent )
	self.labelWidget:destroyAllNow()
	self.labelWidget = false
end

function UIFormLayoutItem:createLabelWidget()
	return UIFormLayoutLabel()
end

function UIFormLayoutItem:getLabel()
	return self.label
end

function UIFormLayoutItem:setLabel( text )
	self.label = text
	if self.labelWidget then
		self.labelWidget:setText( self.label )
	end
end

function UIFormLayoutItem:setLabelFeatures( features )
	self.labelFeatures = features
	if self.labelWidget then
		self.labelWidget:setDefaultFeatures( features )
	end
end

function UIFormLayoutItem:getLabelFeatures( features )
	return self.labelFeatures
end

function UIFormLayoutItem:setGeometry( x, y, w, h )
	local playout = self:getParentLayout()
	local labelSize = playout.labelSize
	local labelSpacing = playout.labelSpacing
	local labelWidget = self.labelWidget

	labelWidget:setGeometry( x - labelSize - labelSpacing, y, labelSize, h, false, true )
	
	local widget = self:getEntity()
	if isInstance( widget, 'UIWidget' ) then
		self:getEntity():setGeometry( x, y, w, h, false, true )
	end

end

--------------------------------------------------------------------
CLASS: UIFormLayout ( mock.UIVBoxLayout )
	:MODEL{
		Field 'labelProportion' :onset( 'onModified' );
		Field 'labelMinSize'    :onset( 'onModified' );
		Field 'labelSpacing'    :onset( 'onModified' );
}

mock.registerComponent( 'UIFormLayout', UIFormLayout )
--mock.registerEntityWithComponent( 'UIFormLayout', UIFormLayout )

function UIFormLayout:__init()
	self.labelProportion = 0.5
	self.labelMinSize = 100
	self.labelSpacing = 10
	self.labelSize = 0
end

function UIFormLayout:onModified()
	local entity = self:getEntity()
	if not entity then return end
	return entity:invalidateLayout()
end

function UIFormLayout:onUpdate( entries )
	self:calcLayoutVertical( entries )
	self:updateLabelSize( entries )
end

function UIFormLayout:getInnerMargin()
	return self.labelMinSize + self.labelSpacing, 0,0,0
end

function UIFormLayout:updateLabelSize( entries )
	local spacing = self.spacing
	local marginL, marginT, marginR, marginB = self:getMargin()

	--pos pass
	local y = - marginT
	local x = marginL

	--get max min widget size
	local labelMinSize = self.labelMinSize
	local availWidth, availableHeight = self:getAvailableSize()
	local maxWidgetWidth = 0
	for i, entry in ipairs( entries ) do
		maxWidgetWidth = math.max( maxWidgetWidth, entry.targetWidth )
	end

	local labelSpacing = self.labelSpacing
	local availWidth2 = availWidth - marginL - marginR - maxWidgetWidth - labelSpacing
	local labelSize = math.max( self.labelMinSize, availWidth2 * self.labelProportion )
	self.labelSize = labelSize
	-- for i, entry in ipairs( entries ) do
	-- 	local widget = entry.widget
	-- 	local item = widget:getLayoutItem()
	-- 	if item and item:isInstance( UIFormLayoutItem ) then
	-- 		entry.locX = x
	-- 	else
	-- 		entry.locX = x + labelSize + labelSpacing
	-- 	end
	-- end

	-- 	entry:setLoc( x, y )
	-- 		local labelWidget = item.labelWidget
	-- 		labelWidget:setLoc( x, y )
	-- 		labelWidget:setSize( labelSize, entry.targetHeight, false, true )
	-- 		widget:setLoc( x + labelSize + labelSpacing + ( entry.offsetX or 0 ), y - ( entry.offsetY or 0 ) )
	-- 		widget:setSize(	entry.targetWidth, entry.targetHeight, false, true )
	-- 	else
	-- 		widget:setLoc( x + labelSize + ( entry.offsetX or 0 ), y - ( entry.offsetY or 0 ) )
	-- 		widget:setSize( 
	-- 			entry.targetWidth, entry.targetHeight, 
	-- 			false, true
	-- 		)
	-- 	end
	-- 	y = y - entry.targetHeight - spacing
	-- end
end

function UIFormLayout:createLayoutItem()
	return UIFormLayoutItem()
end

