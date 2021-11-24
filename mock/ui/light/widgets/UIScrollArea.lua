module 'mock'


--------------------------------------------------------------------
CLASS: UIScrollArea ( UIFrame )
	:MODEL{
		Field 'scrollSize' :type('vec2') :getset('ScrollSize');	
		'----';
		Field 'scrollDamping';
		Field 'maxScrollSpeed';
		Field 'allowScrollX' :boolean();
		Field 'allowScrollY' :boolean();
		'----';
		Field 'scroll'     :type('vec2') :getset('Scroll');
	}

registerEntity( 'UIScrollArea', UIScrollArea )

function UIScrollArea:__init()
	self.focusPolicy = 'normal'
	self.innerTransform = MOAITransform.new()
	inheritTransform( self.innerTransform, self._prop )
	self.scrollDamping  = 0.9

	self._syncingBars = false


	self.scrollW = -1
	self.scrollH = -1

	self.scrollX = 0
	self.scrollY = 0 

	self.allowScrollX = true
	self.allowScrollY = true
	self.clippingChildren = true

	self.scrollBarH = false
	self.scrollBarV = false
end

function UIScrollArea:getDefaultSize()
	return 50, 50
end

function UIScrollArea:_attachChildEntity( child )
	UIScrollArea.__super._attachChildEntity( self, child )
	if not child.FLAG_SUBENTITY then
		local inner  = self.innerTransform
		local p      = self._prop
		local pchild = child._prop
		inheritTransform( pchild, inner )
		inheritColor( pchild, p )
		inheritVisible( pchild, p )
	end
end

--------------------------------------------------------------------
function UIScrollArea:onLoad()
	self.scrollBarH = self:addSubEntity( UIHScrollBar() )
	self.scrollBarV = self:addSubEntity( UIVScrollBar() )
	self.scrollBarH:setName( '__scrollH' )
	self.scrollBarV:setName( '__scrollV' )
	self.scrollBarH:hide()
	self.scrollBarV:hide()
	self:connect(
		self.scrollBarH.valueChanged, 'syncScrollBarH'
	)
	self:connect(
		self.scrollBarV.valueChanged, 'syncScrollBarV'
	)
	self.threadSmoothScroll = self:addGameCoroutine( 'actionSmoothScroll' )
	self.threadSmoothScroll:pause()
end

--------------------------------------------------------------------
function UIScrollArea:worldToScroll( x, y )
	return self.innerTransform:worldToModel( x, y )
end

function UIScrollArea:modelToScroll( x, y )
	x,y = self:modelToWorld( x, y )
	return self.innerTransform:worldToModel( x, y )
end

function UIScrollArea:scrollToWorld( x, y )
	return self.innerTransform:modelToWorld( x, y )
end

function UIScrollArea:scrollToModel( x, y )
	return self:worldToModel( self:scrollToWorld( x, y ) )
end

--------------------------------------------------------------------
function UIScrollArea:syncScrollBarH( v )
	self._syncingBars = true
	self:setScrollX( v, true )
	self._syncingBars = false
end

function UIScrollArea:syncScrollBarV( v )
	self._syncingBars = true
	self:setScrollY( v, true )
	self._syncingBars = false
end

--------------------------------------------------------------------
function UIScrollArea:getScrollSize()
	return self.scrollW, self.scrollH	
end

function UIScrollArea:setScrollSize( w, h )
	self.scrollW, self.scrollH = w, h
	self:updateScrollBars()
	self:invalidateVisual()
end

function UIScrollArea:setScrollHeight( h )
	return self:setScrollSize( self.scrollW, h )
end

function UIScrollArea:setScrollWidth( w )
	return self:setScrollSize( w, self.scrollH )
end

function UIScrollArea:setScroll( x, y, smooth )
	local w, h = self:getSize()
	x = math.clamp( x, 0, math.max( self.scrollW - w, 0 ) )
	y = math.clamp( y, 0, math.max( self.scrollH - h, 0 ) )
	self.scrollX = x
	self.scrollY = y

	if not smooth then
		self.innerTransform:setLoc( -x, y )
	else
		self.threadSmoothScroll:pause( false )
	end
	if not self.scrollBarH then return end
	if not self._syncingBars then
		self.scrollBarH:setValue( x )
		self.scrollBarV:setValue( y )
	end
end

function UIScrollArea:setScrollX( x, smooth )
	return self:setScroll( x, self.scrollY, smooth )
end

function UIScrollArea:setScrollY( y, smooth )
	return self:setScroll( self.scrollX, y, smooth )
end

function UIScrollArea:getScroll()
	return self.scrollX, self.scrollY
end

function UIScrollArea:getScrollBar()
	return self.scrollBarH, self.scrollBarV
end

function UIScrollArea:addScroll( dx, dy, smooth )	
	self:setScroll( self.scrollX + dx, self.scrollY + dy, smooth )
end

--------------------------------------------------------------------
function UIScrollArea:ensureWidgetVisible( w, instant )
	assert( w:isChildOf( self ) )
	local rx0, ry0, rx1, ry1 = w:getRect()
	local wx, wy = w:getLoc()
	local wx0 = wx + rx0
	local wy1 = -( wy + ry0 )
	local wx1 = wx + rx1
	local wy0 = -( wy + ry1 )

	local sx, sy = self:getScroll()

	local sw, sh = self:getSize()
	local sx1 = sx + sw
	local sy1 = sy + sh
	local padding = sh/4
	if self.allowScrollX then
		--TODO
	end

	if self.allowScrollY then
		if wy0 - padding < sy then
			local sy1 = wy0 - padding
			if sy1 < 5 then --TODO: snap to scroll top ?
				sy1 = 0
			end
			self:setScrollY( sy1, not instant )

		elseif wy1 + padding > sy1 then
			local sy1 = wy1 - sh + padding
			self:setScrollY( sy1, not instant )

		end
	end

end


--------------------------------------------------------------------
function UIScrollArea:onUpdateVisual( style )
	self:updateScrollBars()
	UIScrollArea.__super.onUpdateVisual( self, style )
end

function UIScrollArea:updateScrollBars()
	local w, h = self:getSize()
	local scrollW, scrollH = self:getScrollSize()

	local barV = self.scrollBarV
	local barH = self.scrollBarH
	if not barV then return end
	if h > scrollH then
		barV:hide()
	else
		barV:show()
		barV:setSize( 10, h )
		barV:setLocX( w - 10 )
		barV:setRange( 0, scrollH )
		barV:setPageStep( h )
	end

	if w > scrollW then
		barH:hide()
	else
		barH:show()
		barH:setSize( w, 10 )
		barH:setLocY( -h + 10 )
		barH:setRange( 0, scrollW )
		barH:setPageStep( w )
	end
end

--------------------------------------------------------------------
function UIScrollArea:actionSmoothScroll()
	local transform = self.innerTransform
	while true do
		local dt = coroutine.yield()
		local tx, ty = self.scrollX, self.scrollY
		local x, y = transform:getLoc()
		local dx = tx - x
		local dy = ty - y
		if dx*dx + dy*dy < 0.1 then
			x = tx
			y = ty
			transform:setLoc( -x, y )
			self.threadSmoothScroll:pause()
		else
			x = lerp( x, tx, 0.4 )
			y = lerp( y, ty, 0.4 )
			transform:setLoc( -x, y )
		end
	end
end

function UIScrollArea:onEvent( ev )
	local t = ev.type
	local d = ev.data
	if t == UIEvent.POINTER_SCROLL then
		local dx = d.x * 10
		local dy = d.y * 10
		self:addScroll( dx, -dy, true )

	elseif t == UIEvent.INPUT_COMMAND then
		self.scrollBarH:procInputCommand( d )
		self.scrollBarV:procInputCommand( d )
		
	end
end
	
function UIScrollArea:hasMore()
	local n,s,e,w
	local tx, ty = self.scrollX, self.scrollY
	n = s
	return n,s,e,w
end