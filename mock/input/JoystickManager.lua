module 'mock'

local _joystickManager

function getJoystickManager()
	return _joystickManager
end

--------------------------------------------------------------------
CLASS: JoystickMapping ()
	:MODEL{}


function JoystickMapping:getName()
	return false
end

function JoystickMapping:mapButtonEvent( btnId, down )
	return nil
end

function JoystickMapping:mapAxisEvent( axisId, value, prevValue )
	return nil
end

function JoystickMapping:mapHatEvent( hatId, value, prevValue )
	return nil
end

function JoystickMapping:unmapAxis( cmd )
	return nil
end

function JoystickMapping:unmapButton( cmd )
	return nil
end

function JoystickMapping:unmapHat( cmd )
	return nil
end


--------------------------------------------------------------------
CLASS: JoystickState ()
	:MODEL{}

function JoystickState:__init( deviceInstance )
	self._instance = deviceInstance

	self._mgr = false
	self.connected = false
	self.userName  = false
	self.mapping   = false
	self.name      = false
	self.deviceID  = false

	self.axisValues  = {}
	self.buttonState = {}
	self.hatStates = {}

	self.mappedAxisValues = {}
	self.mappedButtonState = {}

	self:initSensor()
	self:initMapping()
end

function JoystickState:getInputDevice()
	return self._instance:getInputDevice()
end

function JoystickState:getJoystickInstance()
	return self._instance
end

function JoystickState:initSensor()
	self:initButtonSensor()
	self:initAxisSensor()
	self:initHatSensor()
	self:initFFB()
end

function JoystickState:initButtonSensor()
	local device = self:getInputDevice()
	local instance = self:getJoystickInstance()
	device.buttons:setCallback(
		function( btn, down )
			if self._mgr then
				return self:onButtonEvent( btn, down )
			end
		end
	)
end

function JoystickState:initAxisSensor()
	local device = self:getInputDevice()
	local instance = self:getJoystickInstance()
	for axisId = 0, instance:getAxeCount()-1 do
		self.axisValues[ axisId ] = 0
		local axisSensor = device[ 'a'..axisId ]
		axisSensor:setCallback(
			function( value )
				if self._mgr then
					return self:onAxisMove( axisId, value )
				end
			end
		)
	end
end

function JoystickState:initHatSensor()
	local device = self:getInputDevice()
	local instance = self:getJoystickInstance()
	for hatId = 0, instance:getHatCount()-1 do
		local hatToButtonName = {
			[ 0 ] = 'h'..hatId .. '.1',
			[ 1 ] = 'h'..hatId .. '.2',
			[ 2 ] = 'h'..hatId .. '.4',
			[ 3 ] = 'h'..hatId .. '.8',
		}
		self.hatStates[ hatId ] = 
			{ false, false, false, false } 
			--U = 0, R = 1, D = 2, L = 3
		local hatSensor = device[ 'h' .. hatId ]
		if hatSensor then
			hatSensor:setCallback(
				function( dir, down )
					if self._mgr then
						return self:onHatEvent( hatId, dir, hatToButtonName[ dir ],  down )
					end
				end
			)
		end
	end
end

function JoystickState:initFFB()
	local device = self:getInputDevice()
	self.FFB = FFBController( device.FFB )
end

function JoystickState:initMapping()
end

function JoystickState:setUserName( name )
	self.userName = name
end

function JoystickState:getMappingName()
	return self.mapping and self.mapping:getName() or false
end

function JoystickState:getName()
	return self.name
end

function JoystickState:getDeviceID()
	return self.deviceID
end

function JoystickState:getUserName()
	return self.userName
end

function JoystickState:setMapping( mapping )
	self.mapping = mapping
end

function JoystickState:onButtonEvent( btn, down )
	if self.mapping then
		local ev, cmd, value = self.mapping:mapButtonEvent( btn, down )
		if ev == 'button' then
			self.buttonState[ cmd ] = value
			self._mgr:dispatchButtonEvent( self, cmd, value )
		end
	end
	self._mgr:dispatchRawButtonEvent( self, btn, down )
end

function JoystickState:updateAxisArrowButton( axisId, v, pv )
	-- gate = gate or 0.5
	local gate = 0.7
	local i1 = ( v >gate and 1 ) or ( v < -gate and -1 ) or 0
	local i0 = ( pv >gate and 1 ) or ( pv < -gate and -1 ) or 0
	local btnHigh, btnLow

	if i0 == i1 then return false end
	--simulate axis->arrow
	if axisId == 'LX' then
		btnLow = 'L-left'
		btnHigh = 'L-right'
	elseif axisId == 'LY' then
		btnLow = 'L-up'
		btnHigh = 'L-down'
	elseif axisId == 'RX' then
		btnLow = 'R-left'
		btnHigh = 'R-right'
	elseif axisId == 'RY' then
		btnLow = 'R-up'
		btnHigh = 'R-down'
	end
	local downHigh, downLow = i1 == 1, i1 == - 1
	local bs = self.buttonState
	local downLow0 = bs[ btnLow ] or false
	local downHigh0 = bs[ btnHigh ] or false
	if downLow0 ~= downLow then
		self.buttonState[ btnLow ] = downLow
		self._mgr:dispatchButtonEvent( self, btnLow, downLow )
	end
	if downHigh0 ~= downHigh then
		self.buttonState[ btnHigh ] = downHigh
		self._mgr:dispatchButtonEvent( self, btnHigh, downHigh )
	end
end

function JoystickState:onAxisMove( axisId, value )
	local prevValue = self.axisValues[ axisId ]
	self.axisValues[ axisId ] = value
	if self.mapping then
		local ev, cmd, mappedValue = self.mapping:mapAxisEvent( axisId, value, prevValue )
		if ev == 'button' then
			self.buttonState[ cmd ] = mappedValue
			self._mgr:dispatchButtonEvent( self, cmd, mappedValue )
		elseif ev == 'axis' then
			local prevMappedValue = self.mappedAxisValues[ cmd ]
			self.mappedAxisValues[ cmd ] = mappedValue
			self._mgr:dispatchAxisEvent( self, cmd, mappedValue )
			if cmd == 'LX' or cmd == 'LY' or cmd == 'RX' or cmd == 'RY' then
				self:updateAxisArrowButton( cmd, mappedValue, prevMappedValue or 0 )
			end
		end
	end
	-- self._mgr:dispatchRawAxisEvent( self, axisId, value )
end

function JoystickState:onHatEvent( hat, dir, hatBtnName,  down )
	return self:onButtonEvent( hatBtnName, down )
end

function JoystickState:getFFBController()
	return self.FFB
end

function JoystickState:getAxisValue( name )
	local mapping = self.mapping
	local id, scale
	if mapping and type( name ) == 'string' then
		id, scale = mapping:unmapAxis( name )
	else
		id = name
	end
	local v = self.axisValues[ id ] or 0
	if scale then
		return v * scale
	else
		return v
	end
end

function JoystickState:isButtonDown( name )
	return self.buttonState[ name ]
end

function JoystickState:onConnect()
	-- body
end

function JoystickState:onDisconnect()
end


--------------------------------------------------------------------
CLASS: JoystickManager ( GlobalManager )
	:MODEL{}

function JoystickManager:getKey()
	return 'JoystickManager'
end

function JoystickManager:__init()
	assert( not _joystickManager )
	_joystickManager = self
	self.joystickStates = {}
	self.joystickListeners = {}
	self.joystickListenerCount = 0
end

function JoystickManager:getMainState()
	--TODO
	return false
end

function JoystickManager:findJoystickState( userName )
	if not userName then return nil end
	for i, state in ipairs( self.joystickStates ) do
		if userName == state:getUserName() then
			return state
		end
	end
end

function JoystickManager:findJoystickStateByUserName( userName )
	if not userName then return nil end
	for i, state in ipairs( self.joystickStates ) do
		if userName == state:getUserName() then
			return state
		end
	end
end

function JoystickManager:findJoystickStateByName( name )
	if not name then return nil end
	for i, state in ipairs( self.joystickStates ) do
		if name == state:getName() then
			return state
		end
	end
end

function JoystickManager:findJoystickStateByDeviceID( id )
	if not id then return nil end
	for i, state in ipairs( self.joystickStates ) do
		if id == state:getDeviceID() then
			return state
		end
	end
end

local index = table.index
local insert = table.insert
local remove = table.remove
function JoystickManager:addJoystickListener( func )
	if index( self.joystickListeners, func ) then return end
	insert( self.joystickListeners, func )
	self.joystickListenerCount = #self.joystickListeners
end

function JoystickManager:removeJoystickListener( func )
	local idx = index( self.joystickListeners, func )
	if idx then
		remove( self.joystickListeners, idx )
		self.joystickListenerCount = #self.joystickListeners
	end
end

function JoystickManager:addJoystickState( joystickState )
	_log( 'joystick added', joystickState )
	table.insert( self.joystickStates, joystickState )
	joystickState._mgr = self
	joystickState.connected = true
	joystickState:onConnect()
	emitGlobalSignal( 'input.joystick.add', joystickState )
end

function JoystickManager:removeJoystickState( joystickState )
	_log( 'joystick removing', joystickState )
	table.removevalue( self.joystickStates, joystickState )
	joystickState._mgr = false
	joystickState:onDisconnect()
	joystickState.connected = false
	joystickState.FFB:setGroup( false )
	emitGlobalSignal( 'input.joystick.remove', joystickState )
	_log( 'joystick removed', joystickState )
end

function JoystickManager:dispatchButtonEvent( joystickState, button, down, mockup )
	local listeners = self.joystickListeners
	for i = 1, self.joystickListenerCount do
		local listener = listeners[ i ]
		if down then
			listener( 'down', joystickState, button, nil, nil, mockup )
		else
			listener( 'up', joystickState, button, nil, nil, mockup )
		end
	end
	return getInputCommandMappingManager():onJoystickButtonEvent( joystickState, button, down, mockup )
end

function JoystickManager:dispatchAxisEvent( joystickState, axisId, value, mockup )
	local listeners = self.joystickListeners
	for i = 1, self.joystickListenerCount do
		local listener = listeners[ i ]
		listener( 'axis', joystickState, nil, axisId, value, mockup )
	end
end

function JoystickManager:dispatchRawButtonEvent( joystickState, button, down, mockup )
	local listeners = self.joystickListeners
	for i = 1, self.joystickListenerCount do
		local listener = listeners[ i ]
		if down then
			listener( 'down-raw', joystickState, button, nil, nil, mockup )
		else
			listener( 'up-raw', joystickState, button, nil, nil, mockup )
		end
	end
end

function JoystickManager:dispatchRawAxisEvent( joystickState, axisId, value, mockup )
	local listeners = self.joystickListeners
	for i = 1, self.joystickListenerCount do
		local listener = listeners[ i ]
		listener( 'axis-raw', joystickState, nil, axisId, value, mockup )
	end
end

function JoystickManager:affirmJoysticks( forced )
	
end

--------------------------------------------------------------------

CLASS: DummyJoystickManager ( JoystickManager )
--------------------------------------------------------------------

local defaultBtnConfirm, defaultBtnCancel = 'a', 'b' --XBOX keymap
function setBasicUIJoystickButtons( btnConfirm, btnCancel )
	defaultBtnConfirm, defaultBtnCancel = btnConfirm, btnCancel
end

function isConfirmButton( btn )
	return btn == defaultBtnConfirm
end

function isCancelButton( btn )
	return btn == defaultBtnCancel
end

