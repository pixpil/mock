module 'mock'

--------------------------------------------------------------------
CLASS: PaintBrushStroke ()
	:MODEL{}

function PaintBrushStroke:__init()
	self.updateOnly = false
end

function PaintBrushStroke:applyToCanvas( canvas )
	local props = self:buildGraphicsProp( canvas )
	if not props then return end

	local tt = type( props )
	if tt == 'table' then
		--pass
	elseif tt == 'userdata' then
		props = { props }
	end

	local partition = canvas.propPartition
	local dirtyTiles = canvas.dirtyTiles
	local canvasTransform = canvas.transform
	local updateOnly = self.updateOnly

	for _, prop in pairs( props ) do
		local x0, y0, z0, x1, y1, z1 = prop:getWorldBounds()
		local ix0, iy0 = canvas:locToCoord( x0, y0 )
		local ix1, iy1 = canvas:locToCoord( x1, y1 )
		canvas:markDirtyAABB( ix0, iy0, ix1, iy1, updateOnly )
		inheritTransform( canvasTransform, prop )
		prop:setPartition( partition )
	end
	
end

function PaintBrushStroke:buildGraphicsProp( canvas )
	return nil
end


--------------------------------------------------------------------
CLASS: PaintCanvasBrush ()
	:MODEL{}

function PaintCanvasBrush:__init()
end

function PaintCanvasBrush:makeStroke( x0,y0, x1,y1 )
end

