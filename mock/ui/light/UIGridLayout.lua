module 'mock'

EnumGrowDirection = _ENUM_V{
	'x',
	'y'
}

CLASS: UIGridLayout ( UILayout )
	:MODEL{
		Field 'size' :type( 'vec2' ) :getset( 'Size' ) :meta{ decimals = 0 };
		Field 'gridSize' :type( 'vec2' ) :getset( 'GridSize' );
		Field 'growDirection' :enum( EnumGrowDirection );
		'----';
		Field 'margin' :type('vec4') :getset( 'Margin' );
		Field 'spacingX' :getset( 'SpacingX' );
		Field 'spacingY' :getset( 'SpacingY' );
	}

registerComponent( 'UIGridLayout', UIGridLayout )


function UIGridLayout:__init()
	self.gridWidth, self.gridHeight = 50, 50
	self.width, self.height = -1, -1
	self.spacingX, self.spacingY = 5, 5
	self.growDirection = 'y'
end

function UIGridLayout:getSize()
	return self.width, self.height
end

function UIGridLayout:setSize( w, h )
	self.width, self.height = w, h
	self:invalidate()
end


function UIGridLayout:setSpacingX( s )
	self.spacingX = s
	self:invalidate()
end

function UIGridLayout:getSpacingX()
	return self.spacingX
end

function UIGridLayout:setSpacingY( s )
	self.spacingY = s
	self:invalidate()
end

function UIGridLayout:getSpacingY()
	return self.spacingY
end

function UIGridLayout:getSpacing()
	return self.spacingX, self.spacingY
end

function UIGridLayout:setSpacing( x, y )
	x = x or 0
	y = y or x
	self.spacingX = x
	self.spacingY = y
	self:invalidate()
end

function UIGridLayout:calcSize( count )
	local cols, rows = self.width, self.height
	local gw, gh = self.gridWidth, self.gridHeight
	local sx, sy = self:getSpacing()
	local growDir = self.growDirection
	local maxInnerWidth, maxInnerHeight = self:getMaxAvailableSize()
	local innerWidth, innerHeight = self:getAvailableSize()
	gw = gw
	gh = gh
	local availableCols = math.floor( ( innerWidth + sx  )/ ( gw + sx ) )
	local availableRows = math.floor( ( innerHeight + sy ) / ( gh + sy ) )
	if cols <= 0 then
		cols = availableCols
	end
	if rows <= 0 then
		rows = availableRows
	end
	if cols <= 0 or rows <= 0 then return 0,0 end
	
	if growDir == 'x' then
		local cols1 = math.ceil( count/rows )
		local maxCols = 
			maxInnerWidth > 0 and math.floor( ( maxInnerWidth + sx ) / ( gw + sx ) ) or -1
		cols = maxCols > 0 and math.min( cols1, maxCols ) or cols1

	elseif growDir == 'y' then
		local rows1 = math.ceil( count/cols )
		local maxRows =
			maxInnerHeight > 0 and math.floor( ( maxInnerHeight + sy ) / ( gh + sy ) ) or -1
		rows = maxRows > 0 and math.min( rows1, maxRows ) or rows1
	else
		return w, h
	end
	return cols, rows
end

function UIGridLayout:getGridSize()
	return self.gridWidth, self.gridHeight
end

function UIGridLayout:setGridSize( w, h )
	self.gridWidth, self.gridHeight = w, h
	self:invalidate()
end

function UIGridLayout:onUpdate( entries )
	local count = #entries
	--calculate grid
	local cols, rows = self:calcSize( count )
	local gw, gh = self:getGridSize()
	local sx, sy = self:getSpacing()

	for i, entry in ipairs( entries ) do
		entry:setFrameSize( gw, gh )
	end

	local i = 1
	local growDir = self.growDirection
	local marginL, marginT, marginR, marginB = self:getMargin()

	if growDir == 'x' then
		for x = 1, cols do
			local px = ( x - 1 ) * ( gw + sx ) + marginL
			for y = 1, rows do
				local py = ( y - 1 ) * ( gh + sy ) + marginT
				if i > count then return end
				local entry = entries[ i ]
				entry:fitMinSize( gw, gh )
				entry:setLoc( px, -py )
				i = i + 1
			end
		end

	else
		for y = 1, rows do
			local py = ( y - 1 ) * ( gh + sy ) + marginT
			for x = 1, cols do
				local px = ( x - 1 ) * ( gw + sx ) + marginL
				if i > count then return end
				local entry = entries[ i ]
				entry:fitMinSize( gw, gh )
				entry:setLoc( px, -py )
				i = i + 1
			end
		end
	end
end
