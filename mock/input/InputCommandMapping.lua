module 'mock'

local _inputCommandMappingManager

function getInputCommandMappingManager()
	return _inputCommandMappingManager
end

function isNavigationInputCommand( cmd )
	return cmd == 'up' or cmd == 'down' or cmd == 'left' or cmd == 'right'
end

--------------------------------------------------------------------
CLASS: InputCommandMapping ()

function InputCommandMapping:__init( name )
	self.name = name
	self.commandListeners = {}
	self.commandStates = {}

	self.keyToCmd  = {}
	self.mbtnToCmd = {}
	self.jbtnToCmd = {}

	self.commands = {}

	self.commandAlias = {} --TODO:

	self.currentSource = false
	self.currentSourceJoystick = false
end

function InputCommandMapping:load( config )
	self.config = config
	local settings = config.settings
	local mappings = config.mappings
	assert( mappings, 'invalid mapping config')
	--
	self:clear()
	self:loadKeyboardMapping ( mappings.keyboard )
	self:loadMouseMapping    ( mappings.mouse    )
	self:loadJoystickMapping ( mappings.joystick )
	emitGlobalSignal( 'input.mapping.change', self )
end

function InputCommandMapping:getConfig()
	return table.clone( self.config )
end

function InputCommandMapping:clear()
	self.keyToCmd  = {}
	self.mbtnToCmd = {}
	self.jbtnToCmd = {}
	self.commands = {}
end

function InputCommandMapping:getCurrentSource()
	return self.currentSource
end

function InputCommandMapping:getCurrentSourceJoystickName()
	if self.currentSourceJoystick then
		return self.currentSourceJoystick:getMappingName()
	else
		return false
	end
end

function InputCommandMapping:getCommandEntry( cmd )
	return self.commands[ cmd ]
end

function InputCommandMapping:getCommandEntryForSource( cmd, source )
	local entry = self.commands[ cmd ]
	if not entry then return false end
	
	source = source or 'keyboard'
	if type( source ) == 'string' then
		local res = entry[ source ] or false
		if res then
			return { 
				{ source = source, key = res }
			}
		end
	elseif type( source ) == 'table' then
		local result = {}
		for i, src in ipairs( source ) do
			local res = entry[ src ]
			if res then table.insert( result, { source = src, key = res } ) end
		end
		if next( result ) then
			return result
		end
	end
	return false
end

function InputCommandMapping:keyToCommand( key )
	return self.keyToCmd[ key ]
end

function InputCommandMapping:mouseToCommand( mbutton )
	return self.mbtnToCmd[ mbutton ]
end

function InputCommandMapping:joyButtonToCommand( jbtn )
	return self.jbtnToCmd[ jbtn ]
end

function InputCommandMapping:getCommand( source, raw )
	local cmd1
	if source == 'joystick' then
		cmd1 = self:joyButtonToCommand( raw )
	elseif source == 'keyboard' then
		cmd1 = self:keyToCommand( raw )
	elseif source == 'mouse' then
		cmd1 = self:mouseToCommand( raw )
	end
	return cmd1
end

function InputCommandMapping:isCommand( source, raw, cmd )
	local cmd1 = self:getCommand( source, raw )
	return cmd1 == cmd
end

local function _addMappingEntry( reg, map, src, cmd, inputSource )
	local tt = type( src )	
	if tt == 'string' then
		local list = reg[ cmd ]
		if not list then
			list = {}
			reg[ cmd ] = list
		end
		local sub = list[ inputSource ]
		if not sub then
			sub = {}
			list[ inputSource ] = sub
		end
		table.insert( sub, src )

		-- _log( 'add mapping for', inputSource, src, '->', cmd )
		if not map[ src ] then
			map[ src ] = cmd
		else
			_warn( 'duplciated mapping for', inputSource, src, '->', cmd )
		end
	elseif tt == 'table' then
		for i, s in ipairs( src ) do
			if type( s ) == 'string' then
				_addMappingEntry( reg, map, s, cmd, inputSource )
			end
		end
	end
end

function InputCommandMapping:loadKeyboardMapping( data )
	if not data then return end
	local map = self.keyToCmd
	local reg = self.commands
	for cmd, key in pairs( data ) do
		_addMappingEntry( reg, map, key, cmd, 'keyboard' )
	end
end

function InputCommandMapping:loadMouseMapping( data )
	if not data then return end
	local map = self.mbtnToCmd
	local reg = self.commands
	for cmd, btn in pairs( data ) do
		_addMappingEntry( reg, map, btn, cmd, 'mouse' )
	end
end

function InputCommandMapping:loadJoystickMapping( data )
	if not data then return end
	local map = self.jbtnToCmd
	local reg = self.commands
	for cmd, btn in pairs( data ) do
		_addMappingEntry( reg, map, btn, cmd, 'joystick' )
	end
end

function InputCommandMapping:mapKeyEvent( key )
	return self.keyToCmd[ key ]
end

function InputCommandMapping:mapMouseButtonEvent( btn )
	return self.mbtnToCmd[ btn ]
end

function InputCommandMapping:mapJoystickButtonEvent( btn )
	return self.jbtnToCmd[ btn ]
end

function InputCommandMapping:mapRawInput( source, sourceData )
	if source == 'keyboard' then
		return self:mapKeyEvent( sourceData.key )
	elseif source == 'mouse' then
		return self:mapMouseButtonEvent( sourceData.button )
	elseif source == 'joystick' then
		return self:mapJoystickButtonEvent( sourceData.button )
	end
end

function InputCommandMapping:onKeyEvent( key, down, mockup )
	local map = self.keyToCmd
	local cmd = map[ key ]
	if cmd then
		return self:sendCommandEvent( cmd, down, 'keyboard', { key = key }, mockup )
	end
end

function InputCommandMapping:onMouseButtonEvent( btn, down, mockup )
	local map = self.mbtnToCmd
	local cmd = map[ btn ]
	if cmd then
		return self:sendCommandEvent( cmd, down, 'mouse', { button = btn }, mockup )
	end
end

function InputCommandMapping:onJoystickButtonEvent( joy, btn, down, mockup )
	local map = self.jbtnToCmd
	local cmd = map[ btn ]
	if cmd then
		return self:sendCommandEvent( cmd, down, 'joystick', { joy = joy, button = btn }, mockup )
	end
end

function InputCommandMapping:sendCommandEvent( cmd, down, source, sourceData, mockup )
	local state = self.commandStates[ cmd ]
	if not state then
		state = { down = false, hit = 0 }
		self.commandStates[ cmd ] = state
	end
	
	state.down = down
	if down then
		state.hit  = state.hit + 1
	end

	for func in pairs( self.commandListeners ) do
		func( cmd, down, source, sourceData, mockup )
	end

	if self.currentSource ~= source then
		self.currentSource = source
		emitGlobalSignal( 'input.source.change', self, source )

	elseif source == 'joystick' and self.currentSourceJoystick ~= sourceData.joy then
		self.currentSourceJoystick = sourceData.joy
		emitGlobalSignal( 'input.source.change', self, source )

	end

end

function InputCommandMapping:pollCommandHit( cmd ) --get cmd hit counts since last polling
	local commandStates = self.commandStates

	local state = commandStates[ cmd ]
	if not state then return 0 end
	local count = commandStates[ cmd ].hit
	commandStates[ cmd ].hit = 0
	return count
end

function InputCommandMapping:isCommandDown( cmd )
	local state = self.commandStates[ cmd ]
	return state and state.down
end

function InputCommandMapping:isCommandUp( cmd )
	local state = self.commandStates[ cmd ]
	return state and ( not state.down )
end

function InputCommandMapping:clearState()
	local st = self.commandStates
	self.commandStates = {}
	for cmd, state in pairs( st ) do
		if state then
			self:sendCommandEvent( cmd, false, 'keyboard', {} )
		end
	end
end

function InputCommandMapping:pollCommandHit( cmd ) --get cmd hit counts since last polling
	local commandStates = self.commandStates

	local state = commandStates[ cmd ]
	if not state then return 0 end
	local count = commandStates[ cmd ].hit
	commandStates[ cmd ].hit = 0
	return count
end

function InputCommandMapping:isCommandHit( cmd )
	return self:pollKeyHit( cmd ) > 0
end

function InputCommandMapping:addListener( func )
	self.commandListeners[ func ] = true
end

function InputCommandMapping:removeListener( func )
	assert( self.commandListeners[ func ] )
	self.commandListeners[ func ] = nil
end

--------------------------------------------------------------------
CLASS: InputCommandMappingManager ( GlobalManager )
	:MODEL{}

function InputCommandMappingManager:__init()
	self.keyboardMapping = false	
	self.mappings = {}
	self.defaultMapping   = self:affirmMapping( 'default' )
	self.defaultUIMapping = self:affirmMapping( 'defaultUI' )
end

function InputCommandMappingManager:getMapping( name )
	return self.mappings[ name ]
end

function InputCommandMappingManager:affirmMapping( name )
	local mapping = self.mappings[ name ]
	if not mapping then
		mapping = InputCommandMapping( name )
		self.mappings[ name ] = mapping
	end
	return mapping
end

function InputCommandMappingManager:loadMapping( name, config )
	local mapping = self:affirmMapping( name )
	mapping:load( config )
end

function InputCommandMappingManager:onKeyEvent( key, down, mockup )
	for name, mapping in pairs( self.mappings ) do
		mapping:onKeyEvent( key, down ,mockup )
	end
end

function InputCommandMappingManager:onMouseButtonEvent( btn, down, mockup )
	for name, mapping in pairs( self.mappings ) do
		mapping:onMouseButtonEvent( btn, down ,mockup )
	end
end

function InputCommandMappingManager:onJoystickButtonEvent( joy, btn, down, mockup )
	for name, mapping in pairs( self.mappings ) do
		mapping:onJoystickButtonEvent( joy, btn, down ,mockup )
	end
end

--------------------------------------------------------------------
_inputCommandMappingManager = InputCommandMappingManager()


function getDefaultInputCommandMapping()
	return _inputCommandMappingManager.defaultMapping
end

function getDefaultUIInputCommandMapping()
	return _inputCommandMappingManager.defaultUIMapping
end

function getInputCommandMapping( name )
	return _inputCommandMappingManager:getMapping( name )
end

function affirmInputCommandMapping( name )
	return _inputCommandMappingManager:affirmMapping( name )
end

function isInputCommandDown( cmd )
	return _inputCommandMappingManager.defaultMapping:isCommandDown( cmd )	
end

function isInputCommandUp( cmd )
	return _inputCommandMappingManager.defaultMapping:isCommandUp( cmd )	
end
