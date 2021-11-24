module 'mock'
--[[
	each InputScript will hold a listener to responding input sensor
	filter [ mouse, keyboard, touch, joystick ]
]]

local _SupportedInputSensors = {
	'mouse', 'keyboard', 'touch', 'joystick'
}

local DEFAULT_INPUT_CATEGORY = 'default'

---------------------------------------------------------------------
CLASS: InputListenerCategory ()

function InputListenerCategory:__init()
	self.active = true
	self.muted  = false
	self.id = false
	self.sensorMuteState = {}
	for _, key in ipairs( _SupportedInputSensors ) do
		self.sensorMuteState[ key ] = false
	end

	--lift
	self.isAllowed = self.isAllowed
end

function InputListenerCategory:getId()
	return self.id
end

function InputListenerCategory:isActive()
	return self.active and ( not self.muted )
end

function InputListenerCategory:setActive( act )
	self.active = act ~= false
	-- _log( 'input active changed', self.id, self.active )
end

function InputListenerCategory:setMuted( sensorId, muted )
	muted = muted ~= false
	self.muted = muted
	-- _log( 'input category mute changed:', self.id, sensorId, muted )
	if sensorId then
		self.sensorMuteState[ sensorId ] = muted
	else
		for k in pairs( self.sensorMuteState ) do
			self.sensorMuteState[ sensor ] = muted
		end
	end
end

function InputListenerCategory:isAllowed( sensorId )
	if not self.active then return false end
	if self.sensorMuteState[ sensorId ] == true then return false end
	return true
end


--------------------------------------------------------------------
local inputListenerCategories = {}
local soloInputListenerCategoryBySensor = {}

function affirmInputListenerCategory( id )
	local category = inputListenerCategories[ id ]
	if category == nil then
		category = InputListenerCategory()
		category.id = id
		inputListenerCategories[ id ] = category
	end
	return category
end

function getInputListenerCategory( id )
	return inputListenerCategories[ id ]
end

function setInputListenerCategoryActive( id, active )
	local cat = getInputListenerCategory( id )
	if not cat then
		_error( 'no input category', id )
		return false
	end
	return cat:setActive( active ~= false )
end

function isInputListenerCategoryActive( id )
	local cat = getInputListenerCategory( id )
	if cat then return cat:isActive() end
	return nil
end

function getSoloInputListenerCategory( sensorId )
	return soloInputListenerCategoryBySensor[ sensorId ]
end

function setInputListenerCategorySolo( sensorId, id, solo )
	if (not sensorId) or sensorId == 'all' then
		for _, sensorId in ipairs( _SupportedInputSensors ) do
			setInputListenerCategorySolo( sensorId, id, solo )
		end
	end

	-- _log( 'solo input sensor', sensorId, id, solo )

	solo = solo ~= false
	local cat = getInputListenerCategory( id )
	if not cat then
		_error( 'no input category', id )
		return false
	end

	local soloCategory = soloInputListenerCategoryBySensor[ sensorId ]
	if solo then
		if cat == soloCategory then return false end
		soloInputListenerCategoryBySensor[ sensorId ] = cat
		for _, cat0 in pairs( inputListenerCategories ) do
			cat0:setMuted( sensorId, true )
		end
		cat:setMuted( sensorId, false )
	else
		if cat ~= soloCategory then return false end
		soloInputListenerCategoryBySensor[ sensorId ] = false
		for _, cat0 in pairs( inputListenerCategories ) do
			cat0:setMuted( sensorId, false )
		end
	end
	
end

--------------------------------------------------------------------
function installInputListener( owner, option )
	uninstallInputListener( owner )
	option = option or {}
	local inputDevice       = option['device'] or getDefaultInputDevice()
	local refuseMockUpInput = option['no_mockup'] == true
	local categoryId        = option['category'] or DEFAULT_INPUT_CATEGORY
	local cmdMappingId      = option['mapping'] or 'default'

	local inputCommandDisabled = option['no_input_command'] == true
	local category = affirmInputListenerCategory( categoryId )
	----link callbacks
	local active = true
	local function setActive( a )
		active = a
	end
	local function isActive()
		return active
	end

	local mouseCallback    = false
	local keyboardCallback = false
	local keyboardCharCallback = false
	local keyboardEditCallback = false
	local touchCallback    = false
	local joystickCallback = false
	local commandCallback  = false
	local inputCommandMapping = false
	
	local sensors = option['sensors'] or false
	if sensors == 'all' then
		sensors = false
	end
	if not sensors or table.index( sensors, 'mouse' ) then
		----MouseEvent
		local onMouseEvent  = owner.onMouseEvent
		local onMouseDown   = owner.onMouseDown
		local onMouseUp     = owner.onMouseUp
		local onMouseMove   = owner.onMouseMove
		local onMouseEnter  = owner.onMouseEnter
		local onMouseLeave  = owner.onMouseLeave
		local onMouseScroll = owner.onMouseScroll

		if 
			onMouseDown or onMouseUp or onMouseMove or onMouseScroll or
			onMouseLeave or onMouseEnter or
			onMouseEvent
		then
			mouseCallback = function( ev, x, y, btn, rx, ry, mocked )
				if not active then return end
				if not category:isAllowed( 'mouse' ) then return end
				if mocked and refuseMockUpInput then return end
				if ev == 'move' then
					if onMouseMove then onMouseMove( owner, x, y, rx, ry, mocked ) end
				elseif ev == 'down' then
					if onMouseDown then onMouseDown( owner, btn, x, y, mocked ) end
				elseif ev == 'up'   then
					if onMouseUp  then onMouseUp  ( owner, btn, x, y, mocked ) end
				elseif ev == 'scroll' then
					if onMouseScroll   then onMouseScroll ( owner, x, y, mocked ) end
				elseif ev == 'enter'  then
					if onMouseEnter   then onMouseEnter ( owner, mocked ) end
				elseif ev == 'leave'  then
					if onMouseLeave   then onMouseLeave ( owner, mocked ) end
				end
				if onMouseEvent then
					return onMouseEvent( owner, ev, x, y, btn, rx, ry, mocked )
				end
			end
			inputDevice:addMouseListener( mouseCallback )
		end
	end

	if not sensors or table.index( sensors, 'touch' ) then
		----TouchEvent
		local onTouchEvent  = owner.onTouchEvent  
		local onTouchDown   = owner.onTouchDown
		local onTouchUp     = owner.onTouchUp
		local onTouchMove   = owner.onTouchMove
		local onTouchCancel = owner.onTouchCancel
		if onTouchDown or onTouchUp or onTouchMove or onTouchEvent then
			touchCallback = function( ev, id, x, y, mocked )
				if not active then return end
				if not category:isAllowed( 'touch' ) then return end
				if mocked and refuseMockUpInput then return end
				if ev == 'move' then
					if onTouchMove   then onTouchMove( owner, id, x, y, mocked ) end
				elseif ev == 'down' then
					if onTouchDown   then onTouchDown( owner, id, x, y, mocked ) end
				elseif ev == 'up' then
					if onTouchUp     then onTouchUp  ( owner, id, x, y, mocked ) end
				elseif ev == 'cancel' then
					if onTouchCancel then onTouchCancel( owner ) end
				end
				if onTouchEvent then
					return onTouchEvent( owner, ev, id, x, y, mocked )
				end
			end
			inputDevice:addTouchListener( touchCallback )
		end
	end

	----KeyEvent
	if not sensors or table.index( sensors, 'keyboard' ) then
		local onKeyEvent = owner.onKeyEvent
		local onKeyDown  = owner.onKeyDown
		local onKeyUp    = owner.onKeyUp
		if onKeyDown or onKeyUp or onKeyEvent then
			keyboardCallback = function( key, down, mocked )
				if not active then return end
				if not category:isAllowed( 'keyboard' ) then return end
				if mocked and refuseMockUpInput then return end
				if down then
					if onKeyDown then onKeyDown( owner, key, mocked ) end
				else
					if onKeyUp   then onKeyUp  ( owner, key, mocked ) end
				end
				if onKeyEvent then
					return onKeyEvent( owner, key, down, mocked )
				end
			end
			inputDevice:addKeyboardListener( keyboardCallback )
		end
		
		local onKeyChar = owner.onKeyChar
		if onKeyChar then
			keyboardCharCallback = function( char, mocked )
				if not active then return end
				if not category:isAllowed( 'keyboard' ) then return end
				if mocked and refuseMockUpInput then return end
				onKeyChar( owner, char, mocked )
			end
			inputDevice:addKeyboardCharListener( keyboardCharCallback )
		end

		local onKeyEdit = owner.onKeyEdit
		if onKeyEdit then
			keyboardEditCallback = function( str, start, length, mocked )
				if not active then return end
				if not category:isAllowed( 'keyboard' ) then return end
				if mocked and refuseMockUpInput then return end
				onKeyEdit( owner, str, start, length, mocked )
			end
			inputDevice:addKeyboardEditListener( keyboardEditCallback )
		end

	end

	---JOYSTICK EVNET
	if not sensors or table.index( sensors, 'joystick' ) then
		local onJoyButtonDown = owner.onJoyButtonDown
		local onJoyButtonUp   = owner.onJoyButtonUp
		local onJoyButtonEvent = owner.onJoyButtonEvent
		local onJoyAxisMove   = owner.onJoyAxisMove
		if onJoyButtonDown or onJoyButtonUp or onJoyAxisMove or onJoyButtonEvent then
			
			joystickCallback = function( ev, joyId, btnId, axisId, value, mocked )
				if not active then return end
				if not category:isAllowed( 'joystick' ) then return end
				if mocked and refuseMockUpInput then return end
				if ev == 'down' then
					if onJoyButtonDown then onJoyButtonDown( owner, joyId, btnId, mocked ) end
					if onJoyButtonEvent then return onJoyButtonEvent( owner, joyId, btnId, true, mocked ) end
				elseif ev == 'up' then
					if onJoyButtonUp then onJoyButtonUp( owner, joyId, btnId, mocked ) end
					if onJoyButtonEvent then return onJoyButtonEvent( owner, joyId, btnId, false, mocked ) end
				elseif ev == 'axis' then
					if onJoyAxisMove then return onJoyAxisMove( owner, joyId, axisId, value ) end
				end
			end

			inputDevice:addJoystickListener( joystickCallback )
		end
	end

	---Command Event
	if not inputCommandDisabled then
		local onInputCommandDown  = owner.onInputCommandDown
		local onInputCommandUp    = owner.onInputCommandUp
		local onInputCommandEvent = owner.onInputCommandEvent
		if onInputCommandDown or onInputCommandUp or onInputCommandEvent then
			commandCallback = function( cmd, down, source, sourceData, mocked )
				if not active then return end
				if source == 'keyboard' and not category:isAllowed( 'keyboard' ) then return end
				if source == 'mouse' and not category:isAllowed( 'mouse' ) then return end
				if source == 'joystick' and not category:isAllowed( 'joystick' ) then return end
				if source == 'touch' and not category:isAllowed( 'touch' ) then return end
				if mocked and refuseMockUpInput then return end
				if down then
					if onInputCommandDown then onInputCommandDown( owner, cmd, source, sourceData, mocked ) end
				else
					if onInputCommandUp   then onInputCommandUp  ( owner, cmd, source, sourceData, mocked ) end
				end
				if onInputCommandEvent then
					return onInputCommandEvent( owner, cmd, down, source, sourceData, mocked )
				end
			end
			-- inputDevice:addCommandListener( commandCallback )
			if isInstance( cmdMappingId, inputCommandMapping ) then
				inputCommandMapping = cmdMappingId
			else
				inputCommandMapping = getInputCommandMappingManager():getMapping( cmdMappingId )
			end
			if inputCommandMapping then
				inputCommandMapping:addListener( commandCallback )
			end
		end
	end

	--MOTION Callbakcs
	
	rawset( owner, '__inputListenerData', {
		mouseCallback        = mouseCallback,
		keyboardCallback     = keyboardCallback,
		keyboardCharCallback = keyboardCharCallback,
		keyboardEditCallback = keyboardEditCallback,
		commandCallback      = commandCallback,
		touchCallback        = touchCallback,
		joystickCallback     = joystickCallback,
		inputDevice          = inputDevice,
		inputCommandMapping  = inputCommandMapping,
		category             = category,
		setActive            = setActive,
		isActive             = isActive,
	} )

end

function setInputListenerActive( owner, active )
	local data = rawget( owner, '__inputListenerData' )
	if not data then return end	
	return data.setActive( active ~= false )
end

function getInputListener( owner )
	return rawget( owner, '__inputListenerData' )
end

function isInputListenerActive( owner )
	local data = rawget( owner, '__inputListenerData' )
	if not data then return end	
	return data.isActive()
end

function uninstallInputListener( owner )
	local data = rawget( owner, '__inputListenerData' )
	if not data then return end	
	local inputDevice = data.inputDevice
	if data.mouseCallback then
		inputDevice:removeMouseListener( data.mouseCallback )
	end

	if data.keyboardCallback then
		inputDevice:removeKeyboardListener( data.keyboardCallback )
	end

	if data.keyboardEditCallback then
		inputDevice:removeKeyboardEditListener( data.keyboardEditCallback )
	end

	if data.keyboardCharCallback then
		inputDevice:removeKeyboardCharListener( data.keyboardCharCallback )
	end

	if data.touchCallback then
		inputDevice:removeTouchListener( data.touchCallback )
	end

	if data.joystickCallback then
		inputDevice:removeJoystickListener( data.joystickCallback )
	end

	local inputCommandMapping = data.inputCommandMapping
	if data.commandCallback then
		inputCommandMapping:removeListener( data.commandCallback )
	end

	rawset( owner, '__inputListenerData', nil )
end


affirmInputListenerCategory( 'default' )
affirmInputListenerCategory( 'ui' )
affirmInputListenerCategory( 'imgui' )

--[[
	input event format:
		KeyDown     ( keyname )
		KeyUp       ( keyname )

		MouseMove   ( x, y )
		MouseDown   ( btn, x, y )
		MouseUp     ( btn, x, y )

		RawMouseMove   ( id, x, y )        ---many mouse (??)
		RawMouseDown   ( id, btn, x, y )   ---many mouse (??)
		RawMouseUp     ( id, btn, x, y )   ---many mouse (??)
		
		TouchDown   ( id, x, y )
		TouchUp     ( id, x, y )
		TouchMove   ( id, x, y )
		TouchCancel (          )
		
		JoystickMove( joy, x, y )
		JoystickDown( joy, btn )
		JoystickUp  ( joy, btn )

		CommandDown( cmd, joy )
		CommandUp  ( cmd, joy )

		LEVEL:   get from service
		COMPASS: get from service
]]
