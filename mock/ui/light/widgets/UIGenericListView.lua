module 'mock'

CLASS: UIGenericListView ( UIListView )
	:MODEL{}
	:SIGNAL{
		object_selection_changed = 'onObjectSelectionChanged';
		object_activated = 'onObjectActivated';
	}
function UIGenericListView:__init( ... )
	-- body
	self.item2Obj = {}
	self.obj2Item = {}
end

function UIGenericListView:addObject( obj, option )
	local item = self.objects[ obj ]
	if item then
		_warn( 'object already added' )
		return item
	end
	local item = self:createItem( option )
	self.item2Obj[ item ] = obj
	self.obj2Item[ obj ] = item
	return obj
end

function UIGenericListView:createItem( obj )
	error( 'IMPLEMENT THIS' )
end

function UIGenericListView:getItemByObject( obj )
	return self.obj2Item[ obj ]
end

function UIGenericListView:getObjectByItem( item )
	return self.item2Objects[ item ]
end

function UIGenericListView:removeObject( obj )
	local item = self:getItemByObject( obj )
	if item then
		self:removeItem( item )
	end
end

function UIGenericListView:onItemRemoved( item )
	local obj = self.item2Obj[ item ]
	if obj then
		self.item2Obj[ item ] = nil
		self.obj2Item[ obj ] = nil
	end
end

function UIGenericListView:getObjectSelection()
	local selection = self:getSelection()
	local result = {}
	local i2o = self.item2Obj
	for i, item in ipairs( selection ) do
		result[ i ] = i2o[ item ]
	end
	return result
end

function UIGenericListView:onItemActivated( item )
	local obj = self.item2Objects[ item ]
	if obj then
		return self:onObjectActivated( obj )
	end
end


--------------------------------------------------------------------
function UIGenericListView:onObjectSelectionChanged()
end

function UIGenericListView:onObjectActivated( obj )
end