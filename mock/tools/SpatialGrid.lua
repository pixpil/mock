module 'mock'

local tinsert = table.insert
local tremove = table.remove
local tindex = table.index
---A integral grid based spatial helper

CLASS: SpatialGrid ()

function SpatialGrid:__init( gw, gh )
	gw = gw or 100
	gh = gh or gw
	self.gridWidth  = gw
	self.gridHeight = gh
	
	self.data = {}
	self.nodeToCell = {}
end

local floor = math.floor
function SpatialGrid:insert( x, y, node )
	local cell0 = self.nodeToCell[ node ]
	local cell = self:affirmCell( x, y )
	if cell0 then
		if cell == cell0 then return end
		local idx = tindex( cell0, node )
		tremove( cell0, idx )
		--todo: shrink
	end

	tinsert( cell, node )
	self.nodeToCell[ node ] = cell

end

function SpatialGrid:remove( node )
	local cell0 = self.nodeToCell[ node ]
	if cell0 then
		local idx = tindex( cell0, node )
		tremove( cell0, idx )
		self.nodeToCell[ node ] = nil
		--todo: shrink
	end
end

function SpatialGrid:affirmCell( x, y )
	local gw, gh = self.gridWidth, self.gridHeight
	local gx, gy = floor( x/gw ), floor( y/gh )
	return self:affirmCellI( gx, gy )
end

function SpatialGrid:affirmCellI( gx, gy )
	local row = self.data[ gy ]
	if not row then
		row = {}
		self.data[ gy ] = row
	end
	local cell = row[ gx ]
	if not cell then
		cell = {}
		row[ gx ] = cell
	end
	return cell
end

function SpatialGrid:findCellI( gx, gy )
	local row = self.data[ gy ]
	return row and row[ gx ]
end

function SpatialGrid:findCell( x, y )
	local gw, gh = self.gridWidth, self.gridHeight
	local gx, gy = floor( x/gw ), floor( y/gh )
	return self:findCellI( gx, gy )
end

function SpatialGrid:findCellRect( x0, y0, x1, y1 )
	--TODO
end

function SpatialGrid:findNodesInRect( x0, y0, x1, y1 )
	local gw, gh = self.gridWidth, self.gridHeight
	local gx0, gy0 = floor( x0/gw ), floor( y0/gh )
	local gx1, gy1 = floor( x1/gw ), floor( y1/gh )
	if gx1 < gx0 then gx1, gx0 = gx0, gx1 end
	if gy1 < gy0 then gy1, gy0 = gy0, gy1 end
	--TODO
end

local insert = table.insert
function SpatialGrid:collectCells()
	local result = {}
	for y, row in pairs( self.data ) do
		for x, cell in pairs( row ) do
			local entry = { x, y, cell }
			insert( result, entry )
		end
	end
	return result
end

