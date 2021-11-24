module 'mock'

local min, max = math.min, math.max

--------------------------------------------------------------------
CLASS: UILayoutEntry ()
	:MODEL{}

function UILayoutEntry.fromWidget( widget )
	local minWidth, minHeight         = widget:getMinSize()
	local maxWidth, maxHeight         = widget:getMaxSize()
	local fixedWidth, fixedHeight     = widget:getFixedSize()
	local contentWidth, contentHeight = widget:getContentSize()
	local policyH, policyV            = widget:getLayoutPolicy()
	local alignH, alignV              = widget:getLayoutAlignment()
	local proportionH, proportionV    = widget:getLayoutProportion()
	local margins                     = { widget:getMargin() }
	return UILayoutEntry:rawInstance{
		widget        = widget,
		minWidth      = minWidth,
		minHeight     = minHeight,
		maxWidth      = maxWidth,
		maxHeight     = maxHeight,
		fixedWidth    = fixedWidth,
		fixedHeight   = fixedHeight,
		contentWidth  = contentWidth,
		contentHeight = contentHeight,
		policyH       = policyH,
		policyV       = policyV,
		alignH        = alignH,
		alignV        = alignV,
		proportionH   = proportionH,
		proportionV   = proportionV,
		margins       = margins,
	}
end

function UILayoutEntry.fromLayoutItem( item )
	local widget = item._entity
	local minWidth, minHeight         = item:getMinSize()
	local maxWidth, maxHeight         = item:getMaxSize()
	local policyH, policyV            = item:getPolicy()
	local alignH, alignV              = item:getAlignment()
	local proportionH, proportionV    = item:getProportion()
	local margins                     = { widget:getMargin() }
	return UILayoutEntry:rawInstance{
		widget        = widget,
		layoutItem    = item,
		minWidth      = minWidth,
		minHeight     = minHeight,
		maxWidth      = maxWidth,
		maxHeight     = maxHeight,
		policyH       = policyH,
		policyV       = policyV,
		alignH        = alignH,
		alignV        = alignV,
		proportionH   = proportionH,
		proportionV   = proportionV,
		margins       = margins
	}
end

function UILayoutEntry:setFrameSize( width, height )
	self.frameWidth = width
	self.frameHeight = height
	if self.minWidth <= 0 and self.minHeight <= 0 then --use minsizehint
		self.minWidth, self.minHeight = self.widget:getMinSizeHint( width, height )
	end
end

function UILayoutEntry:apply()
	local fw, fh = self.frameWidth, self.frameHeight
	local targetWidth, targetHeight = self.targetWidth or 0, self.targetHeight or 0
	local x, y = self.locX or 0, self.locY or 0
	local offsetX, offsetY = 0, 0
	if fw then
		local alignH = self.alignH
		if alignH == 'left' then
			offsetX = 0
		elseif alignH == 'center' then
			offsetX = max( ( fw - targetWidth )/2, 0 )
		elseif alignH == 'right' then
			offsetX = max( ( fw - targetWidth ), 0 )
		end
	end

	if fh then
		local alignV = self.alignV
		if alignV == 'top' then
			offsetY = 0
		elseif alignV == 'middle' or alignV == 'center' then
			offsetY = max( ( fh - targetHeight )/2, 0 )
		elseif alignV == 'bottom' then
			offsetY = max( ( fh - targetHeight ), 0 )
		end
	end
	
	local xx, yy = x + offsetX, y - offsetY
	if self.layoutItem then
		self.layoutItem:setGeometry( xx, yy, targetWidth, targetHeight, false, true )
	else
		self.widget:setGeometry( xx, yy, targetWidth, targetHeight, false, true )
	end

end

function UILayoutEntry:fitMinSize( w, h )
	local policyH, policyV = self.policyH, self.policyV
	local w1, h1 = w, h
	if policyH == 'expand' then
		w1 = math.max( w, self.minWidth )
	elseif policyH == 'minimum' then
		w1 = self.minWidth
	elseif policyH == 'fixed' then
		w1 = self.fixedWidth
	end
	
	if policyH == 'expand' then
		h1 = math.max( h, self.minHeight )
	elseif policyH == 'minimum' then
		h1 = self.minHeight
	elseif policyH == 'fixed' then
		h1 = self.fixedHeight
	end
	self:setTargetSize( w1, h1 )
end

function UILayoutEntry:setTargetSize( w, h )
	self.targetWidth  = w
	self.targetHeight = h
end

function UILayoutEntry:setLoc( x, y )
	self.locX = x
	self.locY = y
end

--------------------------------------------------------------------
CLASS: UILayout ( Component )
	:MODEL{
		Field 'margin' :type('vec4') :getset( 'Margin' );
		'----';
		Field 'addChildLayoutItems' :action( '_toolAddChildLayoutItems' );
	}
	:META{
		category = 'UI'
	}

function UILayout:__init( widget )
	self.margin = { 10,10,10,10 }

	self.owner = false
	if widget then
		widget:setLayout( self )
	end
end

function UILayout:setOwner( owner )
	if self.owner == owner then return end
	assert( not self.owner )
	self.owner = owner
end

function UILayout:getOwner()
	return self.owner
end

function UILayout:getMargin()
	return unpack( self.margin )
end

function UILayout:getInnerMargin()
	return 0,0,0,0
end

function UILayout:calcMargin()
	local a,b,c,d = self:getMargin()
	local a0,b0,c0,d0 = self:getInnerMargin()
	return a+a0, b+b0, c+c0, d+d0
end

function UILayout:getInnerSize()
	local w, h = self:getAvailableSize()
	local marginL, marginT, marginR, marginB = self:calcMargin()
	w  = w - marginL - marginR
	h  = h - marginT - marginB
	return w, h
end

function UILayout:getMinInnerSize()
	local w, h = self:getMinAvailableSize()
	local marginL, marginT, marginR, marginB = self:calcMargin()
	w  = w - marginL - marginR
	h  = h - marginT - marginB
	return w, h
end

function UILayout:getMaxInnerSize()
	local w, h = self:getMaxAvailableSize()
	local marginL, marginT, marginR, marginB = self:calcMargin()
	if w < 0 then w = -1 else w  = w - marginL - marginR end
	if h < 0 then h = -1 else h  = h - marginT - marginB end
	return w, h
end

function UILayout:getAvailableSize()
	local owner = self:getOwner()
	local w, h = owner:getSize()
	local sl, st, sr, sb = owner:getSpacing()
	return math.max(w - sl - sr,0), math.max(h - st - sb,0)
end

function UILayout:getMinAvailableSize()
	local owner = self:getOwner()
	local w, h = owner:getMinSize()
	local sl, st, sr, sb = owner:getSpacing()
	return math.max(w - sl - sr,0), math.max(h - st - sb,0)
end

function UILayout:getMaxAvailableSize()
	local owner = self:getOwner()
	local w, h = owner:getMaxSize()
	local sl, st, sr, sb = owner:getSpacing()
	return math.max(w - sl - sr,0), math.max(h - st - sb,0)
end

function UILayout:setMargin( left, top, right, bottom )
	self.margin = { left or 0, top or 0, right or 0, bottom or 0 }
	self:invalidate()
end

function UILayout:invalidate()
	local owner = self:getOwner()
	if owner then
		return owner:invalidateLayout()
	end
end

function UILayout:update()
	self.updating = true
	local owner = self:getOwner()
	local entries = owner:getChildLayoutEntries()
	self:onUpdate( entries )
	for i, e in ipairs( entries ) do
		e:apply()
	end
	self.updating = false
end

function UILayout:onUpdate()
end


function UILayout:onAttach( ent )
	if not ent:isInstance( UIWidget ) then
		_warn( 'UILayout should be attached to UIWidget' )
		return false
	end
	local widget = ent
	widget:setLayout( self )
end

function UILayout:onDetach( ent )
	if not ent:isInstance( UIWidget ) then return end
	local widget = ent
	self.owner = false
	widget:setLayout( false )
end


function UILayout:_toolAddChildLayoutItems()
	if not self:getEntity():isInstance( UIWidget ) then return end
	for i, w in ipairs( self:getEntity():getChildWidgets() ) do
		w:_toolAffirmLayoutItem()
	end
end

function UILayout:createLayoutItem()
	return UILayoutItem()
end
