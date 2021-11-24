module 'mock'


local function moveRect( rect, x, y )
	local x0, y0, x1, y1 = unpack( rect )
	return { x0+x, y0+y, x1+x, y1+y }
end

local function expandRect( pixRect, rect )
	local x0, y0, x1, y1 = unpack( pixRect )
	local w, h = x1 - x0, y1 - y0
	local u0, v0, u1, v1 = unpack( rect )
	return { x0 + u0*w, y0 + v0*h, x0 + u1*w, y0 + v1*h }
end

local function fitRectAspect( rect, aspect )
	local x0, y0, x1, y1 = unpack( rect )
	local w, h = x1 - x0, y1 - y0
	local w1 = math.min( w, h * aspect )
	local h1 = math.min( w / aspect, h )

	local ox0 = ( w - w1 ) / 2 + x0
	local oy0 = ( h - h1 ) / 2 + y0
	local ox1 = ox0 + w1
	local oy1 = oy0 + h1

	return { ox0, oy0, ox1, oy1 }
end

local function roundRect( rect )
	rect[1] = math.floor( rect[1] )
	rect[2] = math.floor( rect[2] )
	rect[3] = math.floor( rect[3] + 0.5 )
	rect[4] = math.floor( rect[4] + 0.5 )
end

local function projRect( parentRect, selfRect )
	local x0, y0, x1, y1 = unpack( parentRect )
	local w, h = x1 - x0, y1 - y0
	local sx0, sy0, sx1, sy1 = unpack( selfRect )
	local ox0, oy0, ox1, oy1 = sx0 - x0, sy0 -y0, sx1 - x0, sy1 -y0
	return { ox0/w, oy0/h, ox1/w, oy1/h }
end

--------------------------------------------------------------------
CLASS: Viewport ()
	:MODEL{}

function Viewport:__init( mode )
	self.mode  = mode or 'relative' --'fixed', 'relative'

	self.keepAspect = false
	self.aspectRatio = 1

	self.alignCenter = true
	self.subViewports = {}
	self.parent = false

	self.rect            = { 0,0,1,1 }
	self.pixelRect       = { 0,0,1,1 }

	self.absPixelRect    = { 0,0,1,1 }

	self.fixedScale      = false
	self.scaleSize       = { 1, 1 }
	self.scalePerPixel   = false

	self._viewport             = MOAIViewport.new()

	self._viewport.source      = self
	self.zoomSize        = { 1, 1 }

	self.margin = {0,0,0,0}
end


function Viewport:__tostring()
	return string.format( '%s: (%d,%d,%d,%d)', self:__repr(), self:getAbsPixelRect() )
end


function Viewport:setMode( mode )
	self.mode = mode
	self:updateSize()
end

function Viewport:getMoaiViewport()
	return self._viewport
end

function Viewport:setAspectRatio( aspectRatio )
	self.aspectRatio = aspectRatio or 1
	if self.mode == 'relative' and self.keepAspect then self:updateSize() end
end

function Viewport:setKeepAspect( keep )
	self.keepAspect = keep
	if self.mode == 'relative' then self:updateSize() end
end

function Viewport:setRect( x0, y0, x1, y1 )
	self.rect = { x0, y0, x1, y1 }
	if self.mode == 'relative' then self:updateSize() end
end

function Viewport:setSize( w, h )
	local x0, y0 = self.rect[1], self.rect[2]
	self:setRect( x0, y0, x0+w, y0+h )
end

function Viewport:setZoom( w, h )
	self.zoomSize = { w, h }
	self:updateSize()
end

function Viewport:getZoom()
	return unpack( self.zoomSize )
end

function Viewport:setPixelRect( x0, y0, x1, y1 )
	self.pixelRect = { x0, y0, x1, y1 }
	if self.mode == 'fixed' then
		self:updateSize()
	end
end

function Viewport:setPixelSize( w, h )
	local x0, y0 = self.pixelRect[1], self.pixelRect[2]
	self:setPixelRect( x0, y0, x0+w, y0+h )
end

function Viewport:setFixedScale( w, h )
	self.fixedScale = true
	self.scaleSize  = { w, h }
	self:updateScale()
end

function Viewport:setScalePerPixel( sx, sy )
	self.fixedScale = false
	sx = sx or 1
	sy = sy or sx
	self.scalePerPixel = { sx, sy }
	self:updateSize()
end

function Viewport:addSubViewport( view, prepend )
	if table.index( self.subViewports, view ) then return end
	if prepend then
		table.insert( self.subViewports, 1, view )
	else
		table.insert( self.subViewports, view )
	end
	view.parent = self
	view:updateSize()
	return view
end

function Viewport:setParent( parent )
	assert( parent ~= self )
	if parent == self.parent then return end
	if self.parent then
		table.removevalue( self.parent.subViewports, self )
		self.parent = false
	end
	if parent then
		parent:addSubViewport( self )
	end
	self:updateSize()
end

function Viewport:updateSize()
	if self.mode == 'fixed' then
		self:updateFixedSize()

	elseif self.mode == 'relative' then
		self:updateRelativeSize()
		
	end

	--conver to integer
	self:onUpdateSize()
	roundRect( self.absPixelRect )

	for _, sub in ipairs( self.subViewports ) do
		sub:updateSize()
	end

	self:updateScale()

end

function Viewport:updateScale()
	if not self.fixedScale then
		if self.mode == 'fixed' then
			self:updateFixedScale()
		else
			self:updateRelativeScale()
		end		
	end

	self:onUpdateScale()
	for _, sub in ipairs( self.subViewports ) do
		sub:updateScale()
	end
	
	self:updateMoaiViewport()
end

function Viewport:onUpdateSize()
end

function Viewport:onUpdateScale()	
end

function Viewport:updateFixedSize()
	local pixelRect = table.simplecopy( self.pixelRect )
	if self.parent then
		self.absPixelRect = moveRect( pixelRect, self.parent:getAbsLoc() )
		self.rect = projRect( {self.parent:getAbsPixelRect()}, self.absPixelRect )
	else
		self.absPixelRect = pixelRect
		self.rect = { 0,0,1,1 }
	end
end

function Viewport:updateRelativeSize()
	if not self.parent then 
		-- _warn( 'relative viewport will not work without a parent viewport' )
		return
	end
	
	local boundRect = expandRect( { self.parent:getAbsPixelRect() }, self.rect )
	if self.keepAspect then
		self.absPixelRect = fitRectAspect( boundRect, self.aspectRatio )
	else
		self.absPixelRect = boundRect
	end

end

function Viewport:updateFixedScale()
	if self.scalePerPixel then
		local sx, sy = unpack( self.scalePerPixel )
		w, h = self:getPixelSize()
		local zw, zh = self:getZoom()
		self.scaleSize = { w*sx/zw, h*sy/zh }
		-- print( 'update fixed scale', self )
		-- print( unpack( self.scaleSize ))
	end
end

function Viewport:updateRelativeScale()
	if self.parent then
		local w, h = self.parent:getScale()
		local rw, rh = self:getRelativeSize()
		local zw, zh = self:getZoom()
		self.scaleSize = {
			w * rw / zw, h * rh / zh
		}
		-- print( 'update relative scale', self )
		-- print( unpack( self.scaleSize ))
	else
		return self:updateFixedScale()
	end
end

function Viewport:updateMoaiViewport()
	local x0,y0,x1,y1 = self:getAbsPixelRect()
	local sw, sh = self:getScale()
	self._viewport:setSize( x0, y0, x1, y1 )
	self._viewport:setScale( sw, sh )
end

function Viewport:getAbsPixelRect()
	return unpack( self.absPixelRect )
end

function Viewport:getAbsLoc()
	return self.absPixelRect[1], self.absPixelRect[2]
end

function Viewport:getPixelSize()
	local x0, y0, x1, y1 = unpack( self.absPixelRect )
	return x1-x0, y1-y0
end

function Viewport:getRelativeSize()
	local x0, y0, x1, y1 = unpack( self.rect )
	return x1-x0, y1-y0
end

function Viewport:getRelativeRect()
	return unpack( self.rect )
end

function Viewport:getScale()
	return unpack( self.scaleSize )
end

function Viewport:getRatio()
	local w, h = self:getPixelSize()
	return w/h
end

function Viewport:fitFramebuffer( fb )
end

function Viewport:resizeFramebuffer( fb )
end

function Viewport:clear()
	for _, sub in ipairs( self.subViewports ) do
		sub.parent = false
	end
	self.subViewports = {}
end
