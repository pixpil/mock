module 'mock'

EnumListGrowDirection = _ENUM_V {
	'+x','+y','-x','-y'
}

-------------------------------------------------------------------
CLASS: UIListItem ( UIButton )
	:MODEL{
	}

function UIListItem:__init()
	self.selected = false
	self.selectable = true
	self.focusPolicy = false
end

function UIListItem:isSelected()
	return self.selected
end

function UIListItem:getListView()
	return self:findParentWidgetOf( UIListView )
end

function UIListItem:ensureVisible( instant )
	local list = self:getListView()
	if list then
		return list:ensureItemVisible( self, instant )
	end
end

function UIListItem:isInView( padding )
	local list = self:getListView()
	if not list then return false end
	local x0,y0,x1,y1 = self:getWorldRect()
	local px0,py0,px1,py1 = list:getWorldRect()
	
	padding = padding or 0
	return x0 + padding >= px0 
		and y0 + padding >= py0
		and x1 - padding <= px1
		and y1 - padding <= py1
end

function UIListItem:setSelected( selected )
	return self:getListView():selectItem( self )
end

function UIListItem:fitGridSize( w, h )
	self:setSize( w, h )
end

function UIListItem:procEvent( ev )
	UIListItem.__super.procEvent( self, ev )
	local t = ev.type
	if t == UIEvent.POINTER_DCLICK then
		if self:isSelected() then
			self:getListView():activateItem( self )
		end
	end
end

function UIListItem:onPressed()
	self:getListView():setFocus( 'item_pressed' )
	self:getListView():selectItem( self )
end

function UIListItem:onDeselect()
end

function UIListItem:onSelect()
end


function UIListItem:updateStyleState()
	if self.selected then
		return self:setState( 'selected' )
	end
	return UIListItem.__super.updateStyleState( self )
end

function UIListItem:setUserData( data )
	self.userData = data
end

function UIListItem:getUserData()
	return self.userData
end

--------------------------------------------------------------------
CLASS: UIListView ( UIWidget )
	:MODEL{
		Field 'layoutRow' :int() :label('row');
		Field 'layoutCol' :int() :label('column');
		Field 'gridSize' :type( 'vec2' ) :getset( 'GridSize' );
		Field 'growDirection'	 :enum( EnumListGrowDirection ) :onset( 'updateItemLayout' );
	}
	
	:SIGNAL{
		selection_changed = 'onSelectionChanged';
		item_activated = 'onItemActivated';
	}

registerEntity( 'UIListView', UIListView )

function UIListView:__init()
	self.itemLayoutDirty = false
	
	self.selection  = false
	self.items      = {}
	self.gridWidth  = 100
	self.gridHeight = 100
	self.growDirection = '-y'
	self.layoutRow = 5
	self.layoutCol = 5
	self.contentCol = 0
	self.contentRow = 0
	
	self.frame = UIScrollArea()
	self.frame:setName( '__inner' )
	self.frame:setFocusProxy( self )

	self.focusPolicy = 'click'

end

function UIListView:onLoad()
	UIListView.__super.onLoad( self )
	self:addInternalChild( self.frame )
end

function UIListView:setRow( row )
	self.layoutRow = row or 1
	return self:updateItemLayout()
end

function UIListView:setColumn( col )
	self.layoutCol = col or 1
	return self:updateItemLayout()
end

function UIListView:setGridSize( w, h )
	self.gridWidth = w
	self.gridHeight = h
	self:updateItemLayout()
end

function UIListView:getGridSize()
	return self.gridWidth, self.gridHeight
end


function UIListView:getGridDimension()
	return self.layoutCol, self.layoutRow
end

function UIListView:getContentDimension()
	return self.contentCol, self.contentRow
end

function UIListView:selectItemByIdx( idx )
	local item = self:getItem( idx )
	if item then return self:selectItem( item ) end
end

function UIListView:selectItem( item )
	local pitem = self.selection
	if pitem == item then return end

	if item then
		if not item.selectable then
			_warn( 'item not selectable' )
			return false
		end
		if item:getListView() ~= self then
			_warn( 'item doesnt belong to the list' )
			return false
		end	
	end
	self.selection = item
	if pitem then
		pitem.selected = false
		pitem:onDeselect()
		pitem:updateStyleState()
	end

	if item then
		item.selected = true
		item:onSelect()
		item:updateStyleState()
	end	
	self.selection_changed:emit( self.selection )
	return
end

function UIListView:getSelection()
	return self.selection
end

function UIListView:activateItem( item )
	if self.selection ~= item then
		if self:selectItem( item ) == false then
			return false
		end
	end
	if item then
		assert( self.selection == item )
		self.item_activated:emit( self.selection )
	end
end

function UIListView:clear()
	self:selectItem( false )
	for i, item in ipairs( self.items ) do
		item:destroyAllNow()		
	end
	self.items = {}
	self.itemLayoutDirty = true
end

function UIListView:getItemCount()
	return #self.items
end

function UIListView:getItem( idx )
	local itemCount = #self.items
	if idx < 0 then
		idx = itemCount + idx + 1
	end
	return self.items[ idx ]
end

function UIListView:getItems()
	return self.items
end

function UIListView:removeItem( item )
	if self.selection == item then
		self:selectItem( false )
	end
	for i, it in ipairs( self.items ) do
		if it == item then
			table.remove( self.items, i )
			self:onItemRemoved( item )
			item:destroyAllNow()
			break
		end
	end
	self:updateItemLoc()
end

function UIListView:sortItems( cmpFunc )
	table.sort( self.items, cmpFunc )
	self:updateItemLoc()
end

function UIListView:addItem( option )
	local item = self:createItem( option )
	if not item then return false end
	self.frame:addInternalChild( item )
	table.insert( self.items, item )
	local id = #self.items
	local x,y = self:calcItemLoc( id )
	item:setLoc( x, y, 1 )
	self:invalidateItemLayout()
	return item
end

function UIListView:createItem( option )
	return UIListItem()
end

function UIListView:createEmptyItem()
	local item = UIListItem()
	item.selectable = false
	return item
end

function UIListView:getItemId( item )
	for i, it in ipairs( self.items ) do
		if it == item then return i end
	end
	return nil
end

function UIListView:getSelectionId()
	local item = self:getSelection()
	if item then
		return self:getItemId( item )
	else
		return nil
	end
end

function UIListView:getItemGridLoc( item )
	local id = self:getItemId( item )
	if not id then return nil end
	return self:calcGridLoc( id )
end

function UIListView:calcItemLoc( id )
	local x, y = self:calcGridLoc( id )
	local dir = self.growDirection
	if dir == '+y' then
		y = y + 1
	end
	local gridWidth = self.gridWidth
	local gridHeight = self.gridHeight
	local sl,st,sr,sb = self:getSpacing()
	return x * gridWidth + sl, y*gridHeight - st
end

function UIListView:getItemAtGridLoc( x, y )
	local id = self:calcGridId( x, y )
	if not id then return nil end
	return self.items[ id ]	
end

function UIListView:calcGridLoc( id )
	id = id - 1
	local row = math.max( self.layoutRow, 1 )
	local col = math.max( self.layoutCol, 1 )
	local dir = self.growDirection
	if dir == '-y' then
		local y = math.floor( id/col )
		local x = id % col
		return x, -y
	elseif dir == '+y' then
		local y = math.floor( id/col )
		local x = id % col
		return x, y
	elseif dir == '-x' then
		local x = math.floor( id/row )
		local y = id % row 
		return -x, y
	elseif dir == '+x' then
		local x = math.floor( id/row )
		local y = id % row 
		return x, y
	end
end

function UIListView:isValidGridLoc( x, y )
	local id = self:calcGridId( x, y )
	return id and true or false
end

function UIListView:calcGridId( x, y )
	local col, row = self:getContentDimension()
	local id
	local dir = self.growDirection
	if dir == '-y' then
		y = -y
		id = y * col + x + 1

	elseif dir == '+y' then
		id = y * col + x + 1

	elseif dir == '-x' then
		x = -x
		id = x * row + y + 1

	elseif dir == '+x' then
		id = x * row + y + 1

	end
	if x < 0 or x >= col then return false end
	if y < 0 or y >= row then return false end
	return id
end

function UIListView:onUpdateVisual()
	if self.itemLayoutDirty then
		self.itemLayoutDirty = false
		self:updateItemLoc()
	end

end

function UIListView:invalidateItemLayout()
	self.itemLayoutDirty = true
	self:invalidateVisual()
end

function UIListView:updateItemLayout()
	local w, h = self:getInnerSize()
	local gridWidth = self.gridWidth
	local gridHeight = self.gridHeight
	if self.growDirection == '-y' then
		self.frame.innerTransform:setPiv( 0, 0 )
	elseif self.growDirection == '+y' then
		self.frame.innerTransform:setPiv( 0, h )
	elseif self.growDirection == '-x' then
		self.frame.innerTransform:setPiv( -w, 0 )
	end
	self:invalidateItemLayout()
end

function UIListView:updateItemLoc()
	self._updatingItemLayout = true
	local itemCount = #self.items
	for i, item in ipairs( self.items ) do
		item:setLoc( self:calcItemLoc( i ) )
		item:fitGridSize( self:getGridSize() )
	end
	if itemCount > 0 then
		local x, y = self:calcGridLoc( itemCount )
		local grow = self.growDirection
		if grow == '+x' or grow == '-x' then --by col
			self.contentCol = math.abs( x ) + 1
			self.contentRow = ( self.contentCol > 1 ) and self.layoutRow or itemCount
		elseif grow == '+y' or grow == '-y' then  --by row
			self.contentRow = math.abs( y ) + 1
			self.contentCol = ( self.contentRow > 1 ) and self.layoutCol or itemCount
		end
	else
		self.contentCol = 0
		self.contentRow = 0
	end
end

function UIListView:onSelectionChanged()
end

function UIListView:onItemActivated( item )
end

function UIListView:setSize( w, h, ... )
	UIListView.__super.setSize( self, w,h, ... )
	self.frame:setSize( w, h, ... )
end

function UIListView:procEvent( ev )
	local etype = ev.type
	if etype == UIEvent.FOCUS_IN then
		if not self.selection then
			local first = self:getItem( 1 )
			if first then
				self:selectItem( first )
			end
		end
	elseif etype == UIEvent.FOCUS_OUT then

	elseif etype == UIEvent.INPUT_COMMAND then
		self:procInputCommand( ev.data )

	end

	return UIListView.__super.procEvent( self, ev )
end

function UIListView:procInputCommand( cmdData )
	if not cmdData.down then return end
	
	local cmd = cmdData.cmd
	if isNavigationInputCommand( cmd ) then
		self:onInputCommandNavigate( cmd )

	elseif cmd == 'confirm' then
		if self.selection then
			self:activateItem( self.selection )
		end

	end
end

--world loc
function UIListView:pickNearestItem( x, y )
	local distanceSqrd = distanceSqrd
	local picked, minDist
	minDist = math.huge
	for i, item in ipairs( self.items ) do
		local ix, iy = item:getWorldLoc()
		local dist = distanceSqrd( x,y, ix,iy )
		if dist < minDist then
			minDist = dist
			picked = item
		end
	end
	return picked
end

--world loc
function UIListView:pickItem( x, y )
	for i, item in ipairs( self.items ) do
		if item:inside( x, y ) then return item end
	end
	return false
end

function UIListView:onInputCommandNavigate( dir, down )
	local selection = self.selection
	local result

	if not selection then
		result = 1

	else
		local id0 = self:getItemId( selection )
		local x, y = self:calcGridLoc( id0 )
		local w, h = self:getContentDimension()

		-- local x0,y0 = x, y
		local navigated = false
		if dir == 'right' then
			-- x = x + 1
			for i = x + 1, w - 1 do
				local item = self:getItemAtGridLoc( i, y )
				if item and item.selectable then
					x = i
					navigated = true
					break
				end
			end
			if not navigated then x = x + 1 end

		elseif dir == 'left' then
			-- x = x - 2
			for i = x - 1, 0, -1 do
				local item = self:getItemAtGridLoc( i, y )
				if item and item.selectable then
					x = i
					navigated = true
					break
				end
			end
			if not navigated then x = x - 1 end

		elseif dir == 'up' then
			-- y = y + 1
			for i = y + 1, h - 1 do
				local item = self:getItemAtGridLoc( x, i )
				if item and item.selectable then
					y = i
					navigated = true
					break
				end
			end
			if not navigated then y = y + 1 end

		elseif dir == 'down' then
			-- y = y - 1
			for i = y - 1, 0, -1 do
				local item = self:getItemAtGridLoc( x, i )
				if item and item.selectable then
					y = i
					navigated = true
					break
				end
			end
			if not navigated then y = y - 1 end
		end

		-- local t = os.clock()
		-- -- if t - self.lastMove < 0.03 then return end --reduce sensitivity
		-- -- self.lastMove = t
		-- local w, h = self:getContentDimension()

		local item1
		if self:isValidGridLoc( x, y ) then
			item1 = self:getItemAtGridLoc( x, y )
			if not item1 then --try wrapping?
				if dir == 'left' or dir == 'right' then
					-- item1 = self:getItemAtGridLoc( x, 0 )
				else
					for xx = 0, x do
						local item = self:getItemAtGridLoc( xx, y )
						if not item then break end
						item1 = item
					end
				end
			end
		end
		
		if item1 and item1.selectable and item1:isVisible() then
			self:selectItem( item1 )
		else
			local target = self:getFocusConnection( dir )
			if target and target.hasSelectableItem and not target:hasSelectableItem() then return end
			self:moveFocus( dir )
		end
	end
end

function UIListView:hasSelectableItem()
	for i, it in ipairs( self.items ) do
		if it.selectable then return true end
	end
	return false
end

function UIListView:ensureItemVisible( item, instant )
	if item:getListView() ~= self then return end
	self.frame:ensureWidgetVisible( item, instant )
end
