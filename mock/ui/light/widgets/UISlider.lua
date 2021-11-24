module 'mock'

local clamp = math.clamp

--------------------------------------------------------------------
CLASS: UISliderHandle ( UIButtonBase )
	:MODEL{}

function UISliderHandle:__init()
	self._pressedLoc = false
	self._pressedSelfLoc = false
end

function UISliderHandle:procEvent( ev )
	UISliderHandle.__super.procEvent( self, ev )
	if ev.type == UIEvent.POINTER_MOVE then
		if ev.data.pointer:getActiveWidget() == self and self:isPressed() then
			local px1, py1 = ev.data.x, ev.data.y
			local px0, py0 = unpack( self._pressedLoc )
			local x0, y0 = unpack( self._pressedSelfLoc )
			local x1, y1 = x0 + ( px1-px0 ), y0 + ( py1-py0 )
			local orientation = self:getParentWidget().orientation
			local w, h = self:getParentWidget():getSlotSize()
			x1, y1 = self:getParentWidget():limitHandleMovement( x0, y0, x1, y1 )
			self:setLoc( x1, y1 )
			self:getParentWidget():_syncValue()
			ev:accept()
		end

	elseif ev.type == UIEvent.POINTER_DOWN then
		self._pressedLoc = { ev.data.x, ev.data.y }
		self._pressedSelfLoc ={ self:getLoc() }
		ev:accept()
	end
end

--------------------------------------------------------------------
CLASS: UISliderSlot ( UIButtonBase )
	:MODEL{}

function UISliderSlot:onEvent( ev )
	if ev.type == UIEvent.POINTER_DOWN then
		local x, y = ev.data.x, ev.data.y
		local lx, ly = self:worldToModel( x, y )
		local value = self:locToValue( lx, ly )
		-- self:getParentWidget():setValue( value )
	end
end

function UISliderSlot:locToValue( x, y )
	--TODO
	return 0
end

--------------------------------------------------------------------
CLASS: UISlider ( UIButtonBase )
	:MODEL{
		Field 'value' :getset( 'Value' );
		'----';
		Field 'minValue' :getset( 'MinValue' ) :label( 'min' );
		Field 'maxValue' :getset( 'MaxValue' ) :label( 'max' );
		Field 'step';
	}
	:SIGNAL{
		valueChanged = ''
	}

local function EventFilterSliderHandle( handle, ev )
	local etype = ev.type
end

function UISlider:__init()
	self.value = 0
	self.handlePos = 0
	self.minValue = 0
	self.maxValue = 1
	self.handleSize = 10
	self.step = 0
	self.pageStep = 0
	self._syncing = false
	self.trackingPointer = true
	self.focusPolicy = 'click'
	self.orientation = 'h'
	
	self.keyboardChangeAcceleration = 0.5
	self.keyboardChangeSpeed = 1
	self.keyboardChangeSpeedMin = 1
	self.keyboardChangeSpeedMax = 100

end

function UISlider:onLoad()
	self.slot = self:addSubEntity( UISliderSlot() )
	self.handle = self:addSubEntity( UISliderHandle() )
	self.handle:setSize( 50, 50 )

	self.handle:setFocusProxy( self )
	
	self.handle:setZOrder( 1 )
	self.slot:setZOrder( 0 )
end

function UISlider:setKeyboardChangeSpeed( min, max, acc )
	self.keyboardChangeSpeedMin = min or 1
	self.keyboardChangeSpeedMax = max or 100
	self.keyboardChangeAcceleration = acc or 0.5
end

function UISlider:getContentData( key, role )
	if key == 'value' then
		return self.value
	end
end

function UISlider:setPageStep( s )
	self.pageStep = s
end

function UISlider:getPageStep()
	return self.pageStep
end

function UISlider:setRange( min, max )
	self.minValue = min or 0
	self.maxValue = max or min
	self:_syncPos()
end

function UISlider:setMinValue( min )
	self.minValue = min
	self:_syncPos()
end

function UISlider:setMaxValue( max )
	self.maxValue = max
	self:_syncPos()
end

function UISlider:getRange()
	return self.minValue,self.maxValue
end

function UISlider:getRangeDiff()
	return self.maxValue - self.minValue
end

function UISlider:getHandleSize()
	return self.handleSize
end

function UISlider:getSlotSize()
	return self:getSize()
end

function UISlider:getSlotRect()
	local w, h = self:getSlotSize()
	return 0, 0, w, h
end

function UISlider:getSlotRange()
	local w, h = self:getSize()
	if self.orientation == 'h' then
		return w
	else
		return h
	end
end

function UISlider:getScrollRange()
	local r0 = self:getSlotRange()
	local diff = self:getRangeDiff()
	if diff == 0 then
		return 0
	else
		local handleSize = math.abs( self:getPageStep()/self:getRangeDiff() ) * r0
		return r0 - handleSize
	end
end

function UISlider:getMaxValue()
	return self.maxValue
end

function UISlider:getMinValue()
	return self.minValue
end

function UISlider:getValue()
	return self.value
end

function UISlider:setValue( v )
	local r0,r1 = self.minValue, self.maxValue
	if self.pageStep > 0 then
		r1 = math.max( r0, r1 - self.pageStep )
	end
	v = math.clamp( v, r0, r1 )
	local v0 = self.value
	if v0 == v then return end
	self.value = v
	if not self.handle then return end
	self:invalidateContent()
	self.valueChanged( v, v0 ) --signal
	if not self._syncing then
		--sync pos
		self:_syncPos()
	end
end

function UISlider:addValue( dv )
	return self:setValue( self.value + dv )
end

function UISlider:addPixel( p )
	local delta = self:pixelToDelta( p )
	return self:addValue( delta )
end

function UISlider:_syncPos()
	if not self.handle then return end
	self._syncing = true
	local d = self.maxValue - self.minValue
	if d == 0 then
		self.handlePos = 0
	else
		self.handlePos = math.clamp( ( self.value - self.minValue ) / d, 0, 1 )
	end
	local x, y = self:handlePosToLoc( self.handlePos )
	local x0, y0 = self.handle:getLoc()
	local x1, y1
	if self.orientation == 'h' then
		x1,y1 = x, y0
	else
		x1,y1 = x0, y
	end
	x1, y1 = self:limitHandleMovement( x0, y0, x1, y1 )
	self.handle:setLoc( x1, y1 )
	self._syncing = false
end

function UISlider:limitHandleMovement( x0, y0, x, y )
	local handleSize = self.handleSize
	if self.orientation == 'h' then --limit x
		local r = self:getScrollRange()
		return math.clamp( x, 0 + handleSize/2, r - handleSize/2 ), y0
	elseif self.orientation == 'v' then
		local r = self:getScrollRange()
		return x0, math.clamp( y, -r + handleSize/2, 0 - handleSize/2 )
	end
end

function UISlider:onUpdateVisual( style )
	local w, h = self:getSize()
	
	local handleSize = style:getNumber( 'handle_size', 30 )
	local slotSize = style:getNumber( 'slot_size', 10 )
	
	self.handleSize = handleSize

	if self.orientation == 'h' then
		self.slot:setSize( w-2, slotSize )
		self.slot:setPivY( -slotSize/2 )
		self.slot:setLoc( 1, -h/2 )
		self.handle:setSize( handleSize, handleSize )
		self.handle:setPiv( handleSize/2, -handleSize/2 )
		self.handle:setLocY( -h/2 )
	else
		self.slot:setSize( slotSize, h-2 )
		self.slot:setPivX( slotSize/2 )
		self.slot:setLoc( w/2, 1 )
		self.handle:setSize( handleSize, handleSize )
		self.handle:setPiv( handleSize/2, -handleSize/2 )
		self.handle:setLocX( w/2 )
	end
	self:_syncPos()
end


function UISlider:_syncValue()
	self._syncing = true
	local x, y = self.handle:getLoc()
	local orientation = self.orientation
	self.handlePos = self:handleLocToPos( x, y )
	local v1 = lerp( self.minValue, self.maxValue, self.handlePos )
	if self.step > 0 then
		v1 = stepped( v1, self.step, true )
	end

	self:setValue( v1 )
	self._syncing = false
	if self.step > 0 then
		self:_syncPos()
	end
end

function UISlider:deltaToPixel( v )
	v = v or 1
	local prange = self:getSlotRange()
	local drange = self.maxValue - self.minValue
	if drange == 0 then return 0 end
	return prange/drange * v
end

function UISlider:pixelToDelta( p )
	p = p or 1
	local prange = self:getSlotRange()
	local drange = self.maxValue - self.minValue
	if prange == 0 then return 0 end
	return drange/prange * p
end

function UISlider:handleLocToPos( x, y )
	local w, h = self:getSlotSize()
	local handleSize = self.handleSize

	if self.orientation == 'h' then
		w = w - handleSize
		x = x - handleSize/2
		return math.clamp( x/w, 0, 1 )
	else --'v'
		h = h - handleSize
		y = y + handleSize / 2
		return math.clamp( -y/h, 0, 1 )
	end
end

function UISlider:handlePosToLoc( pos )
	local w, h = self:getSlotSize()
	local handleSize = self.handleSize
	if self.orientation == 'h' then
		w = w - handleSize
		return pos * w + handleSize / 2, 0
	else --'v'
		h = h - handleSize
		return 0, -pos*h - handleSize / 2
	end
end

local function getSliderInputCommandDir( orientation, cmd )
	if orientation == 'h' then
		if cmd == 'left' then return -1 end
		if cmd == 'right' then return 1 end
	else
		if cmd == 'up' then return -1 end
		if cmd == 'down' then return 1 end
	end
	return false
end

function UISlider:procEvent( ev )
	if ev.type == UIEvent.FOCUS_OUT then
		self:findAndStopCoroutine( 'actionSmoothUpdate' )
	end
	return UISlider.__super.procEvent( self, ev )
end

function UISlider:procInputCommand( cmdData )
	local cmd = cmdData.cmd
	local down = cmdData.down
	local sign = getSliderInputCommandDir( self.orientation, cmd )
	if sign then
		if not down then
			self:findAndStopCoroutine( 'actionSmoothUpdate' )
			self.keyboardChangeSpeed = self.keyboardChangeSpeedMin
		else
			local repeating = cmdData.repeating
			if repeating then
				local r = self:getSlotRange()
				-- self.keyboardChangeSpeed = clamp( 
				-- 	self.keyboardChangeSpeed + self.keyboardChangeAcceleration, 
				-- 	self.keyboardChangeSpeedMin,
				-- 	self.keyboardChangeSpeedMax
				-- )
				return
			else
				self.keyboardChangeSpeed = self.keyboardChangeSpeedMin
				return self:replaceCoroutine( 'actionSmoothUpdate', sign )
			end
		end
	end

	return UISlider.__super.procInputCommand( self, cmdData )
end

function UISlider:actionSmoothUpdate( sign )
	while true do
		local dt = coroutine.yield()
		local speed = self.keyboardChangeSpeed + self.keyboardChangeAcceleration
		self.keyboardChangeSpeed = clamp( speed, self.keyboardChangeSpeedMin, self.keyboardChangeSpeedMax )
		self:addPixel( speed * sign * dt * 10 )
	end
end
--------------------------------------------------------------------

CLASS: UIHSlider ( UISlider )
	:MODEL{}

function UIHSlider:__init()
	self.orientation = 'h'
end

--------------------------------------------------------------------
CLASS: UIVSlider ( UISlider )
	:MODEL{}

function UIVSlider:__init()
	self.orientation = 'v'
end

registerEntity( 'UIHSlider', UIHSlider )
registerEntity( 'UIVSlider', UIVSlider )
-- registerEntity( 'UISlider', UISlider )
