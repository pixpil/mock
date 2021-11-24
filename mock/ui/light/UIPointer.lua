module 'mock'

local DOUBLE_CLICK_INTERVAL = 0.3
local DOUBLE_CLICK_OFFSET   = 2

--------------------------------------------------------------------
CLASS: UIPointer ()
function UIPointer:__init( view )
	self.view         = view
	self.state        = {}
	self.activeWidget = false
	self.hoverWidget  = false
	self.touch        = false
	self.grabOwner    = false
	self.x = 0
	self.y = 0     
	self.padding = 4

	self.prevDownX = 0
	self.prevDownY = 0
	self.prevDownButton = false
	self.prevDownTime = 0
end

function UIPointer:getTouch()
	return self.touch
end

function UIPointer:getLoc()
	return self.x, self.y
end

function UIPointer:getActiveWidget()
	return self.activeWidget
end

function UIPointer:getHoverWidget()
	return self.hoverWidget
end

function UIPointer:updateHover( view, x, y, debug )
	--find hover
	local hoverWidget0  = self.hoverWidget
	
	local hoverWidget1 = view:findTopWidgetForPointer( self, x, y, debug )
	if hoverWidget0 == hoverWidget1 then return hoverWidget0 end
	self.hoverWidget = hoverWidget1 or false
	if hoverWidget0 then
		local evExit = UIEvent(
			UIEvent.POINTER_EXIT, 
			{ pointer = self }
		)
		view:postEvent( hoverWidget0, evExit )
	end
	if hoverWidget1 then
		local evEnter = UIEvent(
			UIEvent.POINTER_ENTER, 
			{ pointer = self }
		)
		view:postEvent( hoverWidget1, evEnter )

	end
	return hoverWidget1
end

function UIPointer:onMove( view, x, y )
	-- print( "onMOVE!!!", os.clock() )
	local x0, y0 = self:getLoc()
	local dx = x - x0
	local dy = y - y0
	self.x = x
	self.y = y
	self.dx = dx
	self.dy = dy

	local targetWidget = false
	local activeWidget = self.activeWidget
	if activeWidget then
		targetWidget = activeWidget
	else
		targetWidget = self:updateHover( view, x, y )
	end
	local ev = UIEvent(
		UIEvent.POINTER_MOVE, 
		{ x = x, y = y, dx = dx, dy = dy, pointer = self }
	)
	return view:postEvent( targetWidget or view, ev )
end

function UIPointer:onDown( view, x, y, button )
	button = button or 'left'
	self.state[ button ] = true
	-- print( 'down!', os.clock() )
	local hover = self:updateHover( view, x, y )
	local t = os.clock()
	local isDClick = false
	if button == self.prevDownButton then
		local x0, y0 = self.prevDownX, self.prevDownY
		local t0 = self.prevDownTime
		local dt = t - t0
		if dt < DOUBLE_CLICK_INTERVAL and distance( x,y,x0,y0 ) <= DOUBLE_CLICK_OFFSET then
			isDClick = true
		end
	end
	self.prevDownX, self.prevDownY = x, y
	self.prevDownTime = t
	self.prevDownButton = button

	if hover then
		self.activeWidget = hover
	end

	local data = { 
		x = x, y = y,
		button = button,
		down   = true,
		pointer = self,
		dclick = isDClick,
		modifiers = getModifierKeyStates()
	}

	local ev = UIEvent(	UIEvent.POINTER_DOWN, data )
	view:postEvent( hover or view, ev )
	
	local ev = UIEvent(	UIEvent.POINTER, data )
	view:postEvent( hover or view, ev )

	if isDClick then
		local ev = UIEvent(
			UIEvent.POINTER_DCLICK,
			{ x = x, y = y, button = button, pointer = self }
		)
		view:postEvent( hover or view, ev )
	end

end

function UIPointer:onUp( view, x, y, button )
	button = button or 'left'
	self.state[ button ] = false
	local activeWidget = self.activeWidget

	local data = { 
		x = x, y = y,
		button = button,
		down   = false,
		pointer = self,
		dclick = false,
		modifiers = getModifierKeyStates()
	}

	self.activeWidget = false
	local ev = UIEvent(	UIEvent.POINTER_UP, data )
	view:postEvent( activeWidget or view, ev )
	
	local ev = UIEvent(	UIEvent.POINTER, data )
	view:postEvent( activeWidget or view, ev )

end

function UIPointer:onScroll( view, x, y )
	local targetWidget = self.activeWidget or self.hoverWidget
	local ev = UIEvent(
			UIEvent.POINTER_SCROLL,
			{ x = x, y = y, pointer = self }
		)
	view:postEvent( targetWidget or view, ev )
end

function UIPointer:updateCursor()
	local hover = self.hoverWidget
	local cursor = hover:getCursor()
	getUICursorManager():setCursor( cursor )
end
