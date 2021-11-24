module 'mock'


local sortModeValue = {
	iso                  = MOAIPartitionViewLayer.SORT_ISO;
	priority_ascending   = MOAIPartitionViewLayer.SORT_PRIORITY_ASCENDING;
	priority_descending  = MOAIPartitionViewLayer.SORT_PRIORITY_DESCENDING;
	x_ascending          = MOAIPartitionViewLayer.SORT_X_ASCENDING;
	x_descending         = MOAIPartitionViewLayer.SORT_X_DESCENDING;
	y_ascending          = MOAIPartitionViewLayer.SORT_Y_ASCENDING;
	y_descending         = MOAIPartitionViewLayer.SORT_Y_DESCENDING;
	z_ascending          = MOAIPartitionViewLayer.SORT_Z_ASCENDING;
	z_descending         = MOAIPartitionViewLayer.SORT_Z_DESCENDING;
	vector_ascending     = MOAIPartitionViewLayer.SORT_VECTOR_ASCENDING;
	vector_descending    = MOAIPartitionViewLayer.SORT_VECTOR_DESCENDING;
	dist_sqrd_ascending  = MOAIPartitionViewLayer.SORT_DIST_SQUARED_ASCENDING;
	dist_sqrd_descending = MOAIPartitionViewLayer.SORT_DIST_SQUARED_DESCENDING;
}

CLASS: Layer ()
	:MODEL {
		Field 'name'      :string()   :getset('Name');
		Field 'visible'   :boolean()  :isset('Visible') :no_edit();
		Field 'editVis'   :boolean()  :isset('EditorVisible') :no_edit();
		Field 'locked'    :boolean()  :no_edit(); --editor only property
		Field 'solo'      :boolean()  :isset('EditorSolo') :no_edit();
		Field 'parallax'  :type('vec3') :getset('Parallax');
		Field 'sortMode'  :enum( EnumLayerSortMode ) :getset('SortMode');
		Field 'priority'  :int() :no_edit();
	}

function Layer:__init( name )
	self.name          = name or ''
	self.visible       = true
	self.editorVisible = true
	self.editorSolo    = false
	self.sortMode      = 'z_ascending'
	self.default       = false
	self.moaiLayers    = setmetatable( {}, { __mode='k' } )
	self.locked        = false
	self.parallax      = {1,1,1}
end

function Layer:setName( name )
	self.name = name
	emitSignal( 'layer.update', self, 'name' )
end

function Layer:getName()
	return self.name
end

function Layer:setVisible( visible )
	emitSignal( 'layer.update', self, 'visible' )
	self.visible = visible
end

function Layer:isVisible()
	return self.visible
end

function Layer:setEditorVisible( visible )
	self.editorVisible = visible	
	emitSignal( 'layer.update', self, 'editor_visible' )
end

function Layer:isEditorVisible()
	return self.editorVisible
end

function Layer:setEditorSolo( solo )
	self.editorSolo = solo and 'solo' or false
	emitSignal( 'layer.update', self, 'editor_visible' )
end

function Layer:isEditorSolo()
	return self.editorSolo == 'solo'
end

function Layer:setLocked( locked )
	self.locked = locked
end

function Layer:isLocked()
	return self.locked
end

function Layer:getSortMode()
	return self.sortMode
end

function Layer:setSortMode( mode )
	self.sortMode = mode
	emitSignal( 'layer.update', self, 'sort' )
end

function Layer:getParallax()
	return unpack( self.parallax )
end

function Layer:setParallax( x, y, z )
	self.parallax = { x or 1, y or 1, z or 1 }
end


local function _initAsQuadTree( partition, w, h, levels )
	partition:reserveLevels( #levels )
	for i, grid in ipairs( levels )  do
		local gw, gh = math.ceil( w / grid ), math.ceil( h / grid )
		partition:setLevel( i, grid, gw, gh )
	end
end

function Layer:makeMoaiLayer( partition )
	local layer     = createPartitionRenderLayer()
	layer:setKeepResultBuffer( true )
	if partition then
		layer:setLayerPartition( partition )

	else
		local partition = MOAIPartition.new()
		-- _initAsQuadTree( 
		-- 	partition,
		-- 	10000, 10000, 
		-- 	{ 400, 200, 100 }
		-- )
		layer:setLayerPartition( partition )
	end
	layer.name     = self.name

	layer.priority = self.priority or 0

	local moaiSortMode	
	if self.sortMode then
		moaiSortMode = sortModeValue[ self.sortMode ]
	else
		moaiSortMode = MOAILayer.SORT_NONE
	end

	layer:setSortMode( moaiSortMode )
	layer.sortMode = moaiSortMode
	layer.source   = self
	layer:setVisible( self.visible )
	self.moaiLayers[ layer ] = true
	return layer
end

