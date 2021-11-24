module 'mock'
local MOAINXInputMgr = MOAINXInputMgr

local axisNames = {
	'stickLX',
	'stickLY',
	'stickRX',
	'stickRY',
}

local motionSensorNames = {
	'motionL',
	'motionR',
}

local NAPDStyleNames = {
	[ MOAINXInputMgr.NPAD_STYLE_FULLKEY  ]  = 'NPAD_STYLE_FULLKEY',
	[ MOAINXInputMgr.NPAD_STYLE_JOYDUAL  ]  = 'NPAD_STYLE_JOYDUAL',
	[ MOAINXInputMgr.NPAD_STYLE_HANDHELD ]  = 'NPAD_STYLE_HANDHELD',
	[ MOAINXInputMgr.NPAD_STYLE_JOYLEFT  ]  = 'NPAD_STYLE_JOYLEFT',
	[ MOAINXInputMgr.NPAD_STYLE_JOYRIGHT ]	 = 'NPAD_STYLE_JOYRIGHT',
}



local function _makeButtonMap( t )
	local a = table.simplecopy( t )
	local b = table.swapkv( t )
	return b, a
end

--------------------------------------------------------------------
local _NpadToMock_Fullkey, _MockToNpad_Fullkey = _makeButtonMap {
 ['b']          = MOAINXInputMgr.NPAD_BUTTON_A,
 ['a']          = MOAINXInputMgr.NPAD_BUTTON_B,
 ['y']          = MOAINXInputMgr.NPAD_BUTTON_X,
 ['x']          = MOAINXInputMgr.NPAD_BUTTON_Y,
 ['L3']         = MOAINXInputMgr.NPAD_BUTTON_STICKL,
 ['R3']         = MOAINXInputMgr.NPAD_BUTTON_STICKR,
 ['LB']         = MOAINXInputMgr.NPAD_BUTTON_L,
 ['RB']         = MOAINXInputMgr.NPAD_BUTTON_R,
 ['LT']         = MOAINXInputMgr.NPAD_BUTTON_ZL,
 ['RT']         = MOAINXInputMgr.NPAD_BUTTON_ZR,
 ['start']      = MOAINXInputMgr.NPAD_BUTTON_PLUS,
 ['back']       = MOAINXInputMgr.NPAD_BUTTON_MINUS,
 ['left']       = MOAINXInputMgr.NPAD_BUTTON_LEFT,
 ['up']         = MOAINXInputMgr.NPAD_BUTTON_UP,
 ['right']      = MOAINXInputMgr.NPAD_BUTTON_RIGHT,
 ['down']       = MOAINXInputMgr.NPAD_BUTTON_DOWN,
 ['LSL']        = MOAINXInputMgr.NPAD_BUTTON_LEFTSL,
 ['LSR']        = MOAINXInputMgr.NPAD_BUTTON_LEFTSR,
 ['RSL']        = MOAINXInputMgr.NPAD_BUTTON_RIGHTSL,
 ['RSR']        = MOAINXInputMgr.NPAD_BUTTON_RIGHTSR,
 -- ['L-right']    = MOAINXInputMgr.NPAD_BUTTON_STICKL_RIGHT,
 -- ['L-up']       = MOAINXInputMgr.NPAD_BUTTON_STICKL_UP,
 -- ['L-left']     = MOAINXInputMgr.NPAD_BUTTON_STICKL_LEFT,
 -- ['L-down']     = MOAINXInputMgr.NPAD_BUTTON_STICKL_DOWN,
 -- ['R-right']    = MOAINXInputMgr.NPAD_BUTTON_STICKR_RIGHT,
 -- ['R-up']       = MOAINXInputMgr.NPAD_BUTTON_STICKR_UP,
 -- ['R-left']     = MOAINXInputMgr.NPAD_BUTTON_STICKR_LEFT,
 -- ['R-down']     = MOAINXInputMgr.NPAD_BUTTON_STICKR_DOWN,
}

local _NpadToMock_JoyLeft, _MockToNpad_JoyLeft = _makeButtonMap {
 ['L3']         = MOAINXInputMgr.NPAD_BUTTON_STICKL,
 ['R3']         = MOAINXInputMgr.NPAD_BUTTON_STICKR,
 ['LB']         = MOAINXInputMgr.NPAD_BUTTON_L,
 ['LT']         = MOAINXInputMgr.NPAD_BUTTON_ZL,
 ['back']       = MOAINXInputMgr.NPAD_BUTTON_MINUS,
 ['left']       = MOAINXInputMgr.NPAD_BUTTON_LEFT,
 ['up']         = MOAINXInputMgr.NPAD_BUTTON_UP,
 ['right']      = MOAINXInputMgr.NPAD_BUTTON_RIGHT,
 ['down']       = MOAINXInputMgr.NPAD_BUTTON_DOWN,
 ['LSL']        = MOAINXInputMgr.NPAD_BUTTON_LEFTSL,
 ['LSR']        = MOAINXInputMgr.NPAD_BUTTON_LEFTSR,
 -- ['L-right']    = MOAINXInputMgr.NPAD_BUTTON_STICKL_RIGHT,
 -- ['L-up']       = MOAINXInputMgr.NPAD_BUTTON_STICKL_UP,
 -- ['L-left']     = MOAINXInputMgr.NPAD_BUTTON_STICKL_LEFT,
 -- ['L-down']     = MOAINXInputMgr.NPAD_BUTTON_STICKL_DOWN,
}

local _NpadToMock_JoyRight, _MockToNpad_JoyRight = _makeButtonMap {
 ['b']          = MOAINXInputMgr.NPAD_BUTTON_A,
 ['a']          = MOAINXInputMgr.NPAD_BUTTON_B,
 ['y']          = MOAINXInputMgr.NPAD_BUTTON_X,
 ['x']          = MOAINXInputMgr.NPAD_BUTTON_Y,
 ['R3']         = MOAINXInputMgr.NPAD_BUTTON_STICKR,
 ['RB']         = MOAINXInputMgr.NPAD_BUTTON_R,
 ['RT']         = MOAINXInputMgr.NPAD_BUTTON_ZR,
 ['start']      = MOAINXInputMgr.NPAD_BUTTON_PLUS,
 ['RSL']        = MOAINXInputMgr.NPAD_BUTTON_RIGHTSL,
 ['RSR']        = MOAINXInputMgr.NPAD_BUTTON_RIGHTSR,
 -- ['R-right']    = MOAINXInputMgr.NPAD_BUTTON_STICKR_RIGHT,
 -- ['R-up']       = MOAINXInputMgr.NPAD_BUTTON_STICKR_UP,
 -- ['R-left']     = MOAINXInputMgr.NPAD_BUTTON_STICKR_LEFT,
 -- ['R-down']     = MOAINXInputMgr.NPAD_BUTTON_STICKR_DOWN,
}


local _NpadToMock_JoyLeftV, _MockToNpad_JoyLeftV = _makeButtonMap {
 ['L3']         = MOAINXInputMgr.NPAD_BUTTON_STICKL,
 ['LB']         = MOAINXInputMgr.NPAD_BUTTON_L,
 ['LT']         = MOAINXInputMgr.NPAD_BUTTON_ZL,
 ['start']      = MOAINXInputMgr.NPAD_BUTTON_MINUS,
 ['left']       = MOAINXInputMgr.NPAD_BUTTON_LEFT,
 ['up']         = MOAINXInputMgr.NPAD_BUTTON_UP,
 ['right']      = MOAINXInputMgr.NPAD_BUTTON_RIGHT,
 ['down']       = MOAINXInputMgr.NPAD_BUTTON_DOWN,
 ['LSL']        = MOAINXInputMgr.NPAD_BUTTON_LEFTSL,
 ['LSR']        = MOAINXInputMgr.NPAD_BUTTON_LEFTSR,
 -- ['L-right']    = MOAINXInputMgr.NPAD_BUTTON_STICKL_RIGHT,
 -- ['L-up']       = MOAINXInputMgr.NPAD_BUTTON_STICKL_UP,
 -- ['L-left']     = MOAINXInputMgr.NPAD_BUTTON_STICKL_LEFT,
 -- ['L-down']     = MOAINXInputMgr.NPAD_BUTTON_STICKL_DOWN,
}

local _NpadToMock_JoyRightV, _MockToNpad_JoyRightV = _makeButtonMap {
 ['right']      = MOAINXInputMgr.NPAD_BUTTON_A,
 ['down']       = MOAINXInputMgr.NPAD_BUTTON_B,
 ['left']       = MOAINXInputMgr.NPAD_BUTTON_X,
 ['up']         = MOAINXInputMgr.NPAD_BUTTON_Y,
 ['L3']         = MOAINXInputMgr.NPAD_BUTTON_STICKR,
 ['LB']         = MOAINXInputMgr.NPAD_BUTTON_R,
 ['LT']         = MOAINXInputMgr.NPAD_BUTTON_ZR,
 ['start']      = MOAINXInputMgr.NPAD_BUTTON_PLUS,
 ['LSL']        = MOAINXInputMgr.NPAD_BUTTON_RIGHTSL,
 ['LSR']        = MOAINXInputMgr.NPAD_BUTTON_RIGHTSR,
 -- ['R-right']    = MOAINXInputMgr.NPAD_BUTTON_STICKR_RIGHT,
 -- ['R-up']       = MOAINXInputMgr.NPAD_BUTTON_STICKR_UP,
 -- ['R-left']     = MOAINXInputMgr.NPAD_BUTTON_STICKR_LEFT,
 -- ['R-down']     = MOAINXInputMgr.NPAD_BUTTON_STICKR_DOWN,
}


local _NpadToMock_JoyLeftH, _MockToNpad_JoyLeftH = _makeButtonMap {
 ['L3']         = MOAINXInputMgr.NPAD_BUTTON_STICKL,
 ['start']      = MOAINXInputMgr.NPAD_BUTTON_MINUS,
 ['a']          = MOAINXInputMgr.NPAD_BUTTON_LEFT,
 ['x']          = MOAINXInputMgr.NPAD_BUTTON_UP,
 ['y']          = MOAINXInputMgr.NPAD_BUTTON_RIGHT,
 ['b']          = MOAINXInputMgr.NPAD_BUTTON_DOWN,
 ['LT']         = MOAINXInputMgr.NPAD_BUTTON_LEFTSL,
 ['RT']         = MOAINXInputMgr.NPAD_BUTTON_LEFTSR,
 -- ['L-right']    = MOAINXInputMgr.NPAD_BUTTON_STICKL_RIGHT,
 -- ['L-up']       = MOAINXInputMgr.NPAD_BUTTON_STICKL_UP,
 -- ['L-left']     = MOAINXInputMgr.NPAD_BUTTON_STICKL_LEFT,
 -- ['L-down']     = MOAINXInputMgr.NPAD_BUTTON_STICKL_DOWN,
}


local _NpadToMock_JoyRightH, _MockToNpad_JoyRightH = _makeButtonMap {
 ['L3']         = MOAINXInputMgr.NPAD_BUTTON_STICKR,
 ['start']      = MOAINXInputMgr.NPAD_BUTTON_PLUS,
 ['a']          = MOAINXInputMgr.NPAD_BUTTON_A,
 ['x']          = MOAINXInputMgr.NPAD_BUTTON_B,
 ['b']          = MOAINXInputMgr.NPAD_BUTTON_X,
 ['y']          = MOAINXInputMgr.NPAD_BUTTON_Y,
 ['LT']         = MOAINXInputMgr.NPAD_BUTTON_RIGHTSL,
 ['RT']         = MOAINXInputMgr.NPAD_BUTTON_RIGHTSR,
 -- ['R-right']    = MOAINXInputMgr.NPAD_BUTTON_STICKR_RIGHT,
 -- ['R-up']       = MOAINXInputMgr.NPAD_BUTTON_STICKR_UP,
 -- ['R-left']     = MOAINXInputMgr.NPAD_BUTTON_STICKR_LEFT,
 -- ['R-down']     = MOAINXInputMgr.NPAD_BUTTON_STICKR_DOWN,
}


--------------------------------------------------------------------
CLASS: JoystickMappingNpadFullKey ( JoystickMapping )

function JoystickMappingNpadFullKey:mapButtonEvent( btnId, down )
	local mapped = _NpadToMock_Fullkey[ btnId ]
	if mapped then
		return 'button',  mapped, down
	else
		return nil
	end
end

function JoystickMappingNpadFullKey:unmapButton( cmd )
	return _MockToNpad_Fullkey[ cmd ]
end

function JoystickMappingNpadFullKey:mapAxisEvent( axisId, value, prevValue )
	if axisId == 'stickLX' then
		return 'axis', 'LX', value
	elseif axisId == 'stickLY' then
		return 'axis', 'LY', -value
	elseif axisId == 'stickRX' then
		return 'axis', 'RX', value
	elseif axisId == 'stickRY' then
		return 'axis', 'RY', -value
	else
		return nil
	end
end

function JoystickMappingNpadFullKey:unmapAxis( cmd )
	if cmd == 'LX' then
		return 'stickLX'
	elseif cmd == 'LY' then
		return 'stickLY', -1
	elseif cmd == 'RX' then
		return 'stickRX'
	elseif cmd == 'RY' then
		return 'stickRY', -1
	end
end


--------------------------------------------------------------------
CLASS: JoystickMappingNpadJoyLeftH ( JoystickMapping )

function JoystickMappingNpadJoyLeftH:mapButtonEvent( btnId, down )
	local mapped = _NpadToMock_JoyLeftH[ btnId ]
	if mapped then
		return 'button',  mapped, down
	else
		return nil
	end
end

function JoystickMappingNpadJoyLeftH:unmapButton( cmd )
	return _MockToNpad_JoyLeftH[ cmd ]
end

function JoystickMappingNpadJoyLeftH:mapAxisEvent( axisId, value, prevValue )
	if axisId == 'stickLX' then
		return 'axis', 'LY', -value
	elseif axisId == 'stickLY' then
		return 'axis', 'LX', -value
	else
		return nil
	end
end

function JoystickMappingNpadJoyLeftH:unmapAxis( cmd )
	if cmd == 'LX' then
		return 'stickLY', -1

	elseif cmd == 'LY' then
		return 'stickLX', -1
	end
end



--------------------------------------------------------------------
CLASS: JoystickMappingNpadJoyRightH ( JoystickMapping )

function JoystickMappingNpadJoyRightH:mapButtonEvent( btnId, down )
	local mapped = _NpadToMock_JoyRightH[ btnId ]
	if mapped then
		return 'button',  mapped, down
	else
		return nil
	end
end

function JoystickMappingNpadJoyRightH:unmapButton( cmd )
	return _MockToNpad_JoyRightH[ cmd ]
end

function JoystickMappingNpadJoyRightH:mapAxisEvent( axisId, value, prevValue )
	if axisId == 'stickRX' then
		return 'axis', 'LY', value
	elseif axisId == 'stickRY' then
		return 'axis', 'LX', value
	else
		return nil
	end
end

function JoystickMappingNpadJoyRightH:unmapAxis( cmd )
	if cmd == 'LX' then
		return 'stickLY'
		
	elseif cmd == 'LY' then
		return 'stickLX'
	end
end


--------------------------------------------------------------------
CLASS: JoystickStateNX ( JoystickState )
	:MODEL{}


function JoystickStateNX:__init( instance )
	self.orientation = 'horizontal' --'vertical'
	self.name = instance:getName()
	self.deviceID = instance:getDeviceID()
	self.mapped = false
end

function JoystickStateNX:initMapping()
	return self:updateMapping()
end

function JoystickStateNX:initHatSensor()
	--nothing
end

function JoystickStateNX:initAxisSensor()
	local device = self:getInputDevice()
	local instance = self:getJoystickInstance()
	for i, axisId in ipairs( axisNames ) do
		self.axisValues[ axisId ] = 0
		local axisSensor = device[ axisId ]
		axisSensor:setCallback(
			function( value )
				if self._mgr then
					return self:onAxisMove( axisId, value )
				end
			end
		)
	end
end


function JoystickStateNX:setHorizontal()
	self.orientation = 'horizontal'
	self:updateMapping()
end

function JoystickStateNX:setVertical()
	self.orientation = 'vertical'
	self:updateMapping()
end

function JoystickStateNX:updateMapping()
	local style = self._instance:getStyle()
	local orientation = self.orientation
	
	print( 'style', self, NAPDStyleNames[ style ], orientation )

	if style == MOAINXInputMgr.NPAD_STYLE_JOYLEFT then
		if orientation == 'horizontal' then
			return self:setMapping( JoystickMappingNpadJoyLeftH() )
		elseif orientation == 'vertical' then
			return self:setMapping( JoystickMappingNpadJoyLeftV() )
		end
	end

	if style == MOAINXInputMgr.NPAD_STYLE_JOYRIGHT then
		if orientation == 'horizontal' then
			return self:setMapping( JoystickMappingNpadJoyRightH() )
		elseif orientation == 'vertical' then
			return self:setMapping( JoystickMappingNpadJoyRightV() )
		end
	end

	return self:setMapping( JoystickMappingNpadFullKey() )
end

function JoystickStateNX:updateStyle()
	self:updateMapping()
	self.mapped = true
end


--------------------------------------------------------------------
CLASS: JoystickManagerNX ( JoystickManager )
	:MODEL{}

function JoystickManagerNX:onInit()
	self.showingControllerApplet = false
	self.mode = 'NX'
	
	MOAINXInputMgr.setListener(
			MOAINXInputMgr.EVENT_NPAD_ADD, 
			function( instance )
				return self:onNpadAdd( instance )				
			end
	)

	MOAINXInputMgr.setListener(
			MOAINXInputMgr.EVENT_NPAD_REMOVE, 
			function( instance )
				return self:onNpadRemove( instance )
			end
	)

	MOAINXInputMgr.setListener(
			MOAINXInputMgr.EVENT_NPAD_STYLE_CHANGE, 
			function( instance )
				return self:onNpadStyleChange( instance )
			end
	)
	
	self.mainState = false

end

function JoystickManagerNX:setPlayerCount()
end

function JoystickManagerNX:getMainState()
	return self.mainState
end

function JoystickManagerNX:_getJoystickStateByInstance( instance )
	for i, joystickState in ipairs( self.joystickStates ) do
		if joystickState._instance == instance then
			return joystickState
		end
	end
end


function JoystickManagerNX:onNpadAdd( instance )
	local state = JoystickStateNX( instance )
	self:addJoystickState( state )
	state:updateStyle()
	if not self.mainState then
		self.mainState = state
		state:getFFBController():setGroup( 'player' )
	else
		self:affirmJoysticks( true )
	end
end


function JoystickManagerNX:onNpadRemove( instance )
	_log( 'joystick removing', instance )
	local joystickState = self:_getJoystickStateByInstance( instance )
	if not joystickState then 
		return _warn( 'unregistered joystick', instance )
	end
	self:removeJoystickState( joystickState )
	if self.mainState == joystickState then
		self.mainState = false
		self:affirmJoysticks()
	end
end


function JoystickManagerNX:onNpadStyleChange( instance )
	_log( 'joystick style changed', instance )
	local joystickState = self:_getJoystickStateByInstance( instance )
	if not joystickState then return end
	local prevMapped = joystickState.mapped
	joystickState:updateStyle()
	-- if prevMapped and joystickState == self.mainState then
	-- 	self:affirmJoysticks( true )
	-- end
end

function JoystickManagerNX:affirmJoysticks( forced )
	if (not self.mainState) or forced then
		self:showControllerApplet()
	end
end

function JoystickManagerNX:showControllerApplet()
	--TODO:Single player mode support only for now
	if self.showingControllerApplet then return end
	self.showingControllerApplet = true
	-- print("OVERLAY ON SIGNAL EMIT")
	emitGlobalSignal( 'app.overlay.on' )
	-- print("TRY showing Controller Applet")
	game:callNextFrame( function()
			game:callNextFrame( function()
			game:callNextFrame( function()
				self:_showControllerAppletInner()
			end )
			end )
		end
	)
end

function JoystickManagerNX:_showControllerAppletInner()
	-- game:callOnSyncingRenderState( function()
		-- print("ENTER showing Controller Applet")
		local res, playerCount, playerID = MOAINXInputMgr.showControllerSupportApplet()
		-- print("EXIT showing Controller Applet")
		self.showingControllerApplet = false
		emitGlobalSignal( 'app.overlay.off' )	
		-- print("SIGNAL EMITTED")
		if res then
			local state = self:findJoystickStateByDeviceID( playerID )
			if self.mainState and self.mainState ~= state then
				self.mainState:getFFBController():setGroup( false )
			end
			if state then
				self.mainState = state
				state:getFFBController():setGroup( 'player' )
				emitGlobalSignal( 'input.joystick.assign', state, 'main' )
			end

		else

		end
	-- end )
end

--------------------------------------------------------------------
JoystickManagerNX()
