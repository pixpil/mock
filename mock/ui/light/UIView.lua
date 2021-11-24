module 'mock'

local TOUCH_PADDING = 20;

local insert,remove = table.insert,table.remove
local pairs, ipairs = pairs, ipairs

local UIOptions = {}

function getUIOption( key, default )
	local v = UIOptions[ key ]
	if v == nil then return default end
	return v
end

function setUIOption( key, v )
	UIOptions[ key ] = v
end

--------------------------------------------------------------------
CLASS: UIView ( UIWidgetBase )
	:MODEL{
		'----';
		Field 'inputCategory' :string();
		Field 'mappingName' :string();
		Field 'targetCamera':type( Camera );
		'----';
		Field 'focusCursorEnabled' :boolean() :on_set( 'updateFocusCursor' );
	}

	:SIGNAL{
		focus_in = 'onFocusIn';
		focus_out = 'onFocusOut';
		focus_widget_changed = 'onFocusWidgetChanged';
	}

mock.registerEntity( 'UIView', UIView )

function UIView:__init()
	self.pointers = {}

	self._parentView = self
	self._UIPartition = MOAIPartition.new()
	self.cursorTransform = getUICursorManager():getTransform()
	self.cursorManager = getUICursorManager()

	self.targetCamera  = false

	self.mappingName   = ''
	self.inputCategory = 'ui'
	self.inputMapping  = 'defaultUI'
	self.inputEnabled  = true
	self.inputSensors  = 'all'
	self.extraInputOptions = false
	self.modalWidget   = false

	self.eventQueue = BufferedTable()
	self.eventCount = 0

	self.globalEventFilters = {}
	
	self.pendingVisualUpdates = {}
	self.pendingLayoutUpdates = {}

	self._dirty = false
	self._updateNode = MOAIScriptNode.new()
	self._updateNode:setCallback( self:methodPointer( 'doUpdate' ) )

	self._updateNode:setNodeLink( self:getProp() )

	self.focusManager = UIFocusManager( self )
	self.resManager = UIResourceManager()

	self.repeatingEnabled   = true
	self.repeatingThreshold = 0.4
	self.repeatingInterval  = 0.1

	self.pressedKeys = {}
	self.pressedCommands = {}
	self.pressedJoyButtons = {}

	self.stringTable = false
	self.stringTableDict = false

	--lift
	self.getInputEventTarget = self.getInputEventTarget
	self.isInteractive = self.isInteractive

	self.focusCursor = UIFocusCursor()
	self.focusCursor:setName( '__FocusCursor__')
	self.focusCursor:hide()
	self.focusCursorEnabled = true

	self.isLocked = false

end


function UIView:_createEntityProp()
	return Entity._createEntityProp( self )
end

function UIView:onLoad()
	self.soundSource = self:attachInternal( SoundSource() )
	self.pointers = {}
	self:_updateInputListener()	
end

function UIView:_updateInputListener()
	-- print( 'update input listener', self, self.inputMapping )
	local options =  {
		category = self.inputCategory,
		mapping  = self.inputMapping,
		sensors  = self.inputSensors --all sensors
	}

	uninstallInputListener( self )
	if self.extraInputOptions then
		options = table.extend( options, self.extraInputOptions )
	end

	installInputListener( self, options	)

end

function UIView:setInputCommandMapping( mapping )
	if self.inputMapping == mapping then return end
	if not getInputCommandMapping( mapping ) then
		_error( 'no input mapping', mapping )
		return
	end
	self.inputMapping = mapping
	self:_updateInputListener()
end

function UIView:setInputSensors( sensors )
	self.inputSensors = sensors
	self:_updateInputListener()
end

function UIView:setExtraInputOptions( opt )
	self.extraInputOptions = opt
	self:_updateInputListener()
end

function UIView:setInputCategory( category )
	if self.inputCategory == category then return end
	self.inputCategory = category
	self:_updateInputListener()
end

function UIView:setInputLock( lock )
	self.isLocked = lock
	self:setInputListenerActive( not lock )
end

function UIView:setInputListenerActive( active )
	return setInputListenerActive( self, active and not self.isLocked )
end

function UIView:isInputListenerActive()
	return isInputListenerActive( self )
end

function UIView:setVisible( visible )
	if not visible then
		self:blurFocus()
	end
	self:scheduleUpdate()
	return UIView.__super.setVisible( self, visible )
end

function UIView:onStart()
	self:setFocusedWidget( false )
	self.threadUpdate = self:addCoroutine( 'actionUpdate' )
	self.threadRepeatingUpdate = self:addCoroutine( 'actionUpdateInputRepeating' )
	--affirm mapping
	self:updateMapping()
	self:updateFocusGroup()
	self:addChild( self.focusCursor )
	self:connect( 'ui.viewmapping.change', 'onViewMappingChange' )
	self:connect( 'locale.change', 'onLocaleChange' )
	self:updateFocusCursor()
end

function UIView:onViewMappingChange()
	self:updateMapping()
end

function UIView:updateMapping()
	local mappingName = self.mappingName
	local mapping = false
	if mappingName ~= '' then
		mapping = getUIViewMapping( mappingName )
		if not mapping then
			_error( 'no view mapping found', mappingName )
		end
	end
	self.viewMapping = mapping
end

function UIView:onDestroy()
	self.focusManager:deactivate()
	self.focusManager = false
	self.soundSource = false
	uninstallInputListener( self )
	self._UIPartition:clear()
	self._updateNode:setCallback( nilFunc )
	self._updateNode:clearNodeLink( self:getProp() )
end

function UIView:requestResource( resType, id )
	return self.resManager:request( resType, id )
end

function UIView:tryPlaySoundFor( widget, eventName )
	-- if checkAsset( eventName)
	local eventAsset = self:requestResource( 'sound', eventName ) or eventName
	return self.soundSource:playEvent( eventAsset )
end

function UIView:tryPlaySound( eventName )
	return self:tryPlaySoundFor( nil, eventName )
end

function UIView:scheduleUpdate()
	self._dirty = true
	return self._updateNode:scheduleUpdate()
end

function UIView:flushUpdate()
	return self._updateNode:flushUpdate()
end

function UIView:actionUpdate()
	while true do
		self:flushUpdate()
		coroutine.yield()
	end
end

local xxx = 0
function UIView:doUpdate()
	self:setInputListenerActive( self:isVisible() )
	--update visual
	self._dirty = false
	
	self:dispatchEvents()
	self:flushLayoutUpdate()
	self:flushVisualUpdate()
	if self._dirty then --temporary workaround
		self:flushLayoutUpdate()
		self:flushVisualUpdate()
	end

end

function UIView:getUpdateThread()
	return self.threadUpdate
end

function UIView:onWidgetDestroyed( widget )
	self.pendingVisualUpdates[ widget ] = nil
	self.pendingLayoutUpdates[ widget ] = nil
	self.focusManager:onWidgetDestroyed( widget )
end

function UIView:isRootWidget()
	return true
end

--------------------------------------------------------------------
function UIView:setContextData( data ) --for templating
	self.contextData = data
	--TODO
end

function UIView:getContextData()
	return self.contextData
end

--------------------------------------------------------------------
--INPUT
function UIView:getPointer( touch, create )
	local p = self.pointers[ touch ]
	if (not p) and create then 
		p  =  UIPointer( self )
		p.touch = touch
		if isInstance( touch, TouchState ) then
			p.padding = TOUCH_PADDING
		end
		self.pointers[touch] = p
	end
	return p
end

function UIView:getMousePointer()
	return self:getPointer( 'mouse', true )
end

function UIView:hasFocus()
	return self.focusManager:isActive()
end

function UIView:setFocus()
	self.focusManager:activate()
end

function UIView:blurFocus()
	self.focusManager:deactivate()
end

function UIView:setFocusCursor( cursor )
	local cursor0 = self.focusCursor
	if cursor0 then
		cursor0:destroy()
	end
	self.focusCursor = cursor
	self:updateFocusCursor()
end

function UIView:setFocusCursorEnabled( enabled )
	self.focusCursorEnabled = enabled ~= false
	self:updateFocusCursor()
end

function UIView:updateFocusCursor()
	if not getUIOption( 'focus_cursor', true ) then return end

	if not self.focusCursor then return end
	if self.focusCursorEnabled then
		local w = self:getFocusedWidget()
		if w == self then w = false end
		self.focusCursor:setTargetWidget( w )
	else
		self.focusCursor:hide()
	end
end

function UIView:onFocusIn()
end

function UIView:onFocusOut()
	self:flushInput()
end

function UIView:onFocusWidgetChanged( focusedWidget, focusedWidget0 )
	-- self:flushInput()
	if focusedWidget then
		focusedWidget:ensureVisible()
	end
	self:updateFocusCursor()
end

function UIView:flushInput()
	self.pressedKeys = {}
	self.pressedCommands = {}
	self.pressedJoyButtons = {}	
end

function UIView:getInputEventTarget()
	if not self:isVisible() then return false end
	if self.focusManager:isActive() then 
		return self:getFocusedWidget() or self
	else
		return self
	end
end

function UIView:getFocusedWidget()
	return self.focusManager:getFocusedWidget()
end

function UIView:setFocusedWidget( widget, reason )
	return self.focusManager:setFocusedWidget( widget, reason )
end

function UIView:moveFocus( dir, wrap, reason )
	return self.focusManager:moveFocus( dir, wrap, reason )
end

function UIView:setModalWidget( w )
	if self.modalWidget == w then return end

	if self.modalWidget then
		self.modalWidget.__modal = false
	end
	self.modalWidget = w
	
	if w then
		w.__modal = true
		local focused = self:getFocusedWidget()
		if focused and ( not focused:isChildOf( w ) ) then
			return self:setFocusedWidget( false )
		end
	end

end

function UIView:getModalWidget()
	return self.modalWidget
end

function UIView:addGlobalEventFilter( filter )
	if not type( filter ) == 'function' then return end
	local idx = table.index( self.globalEventFilters, filter )
	if not idx then
		table.insert( self.globalEventFilters, filter )
	end
end

function UIView:removeGlobalEventFilter( filter )
	local idx = table.index( self.globalEventFilters, 1, filter )
	if idx then
		table.remove( self.globalEventFilters, idx )
	end
end

function UIView:postEvent( target, ev )
	assert( target, ev.type )
	local eventCount = self.eventCount + 1
	self.eventCount = eventCount

	ev.target = target
	self.eventQueue:set( eventCount, ev )

	self:scheduleUpdate()
	return ev
end

function UIView:dispatchEvents()
	local events = self.eventQueue:table()
	local count = self.eventCount
	if count == 0 then return end

	self.eventQueue:swap()
	self.eventCount = 0

	local filters = self.globalEventFilters
	if not next( filters ) then filters = false end

	local filterCount = filters and #filters or 0
	for eid = 1, count do
		local event  = events[ eid ]
		local target = event.target
		local filtered = false
		for i = 1, filterCount do
			local f = filters[ i ]
			local result = f( target, event )
			if result == false then filtered = true end
		end
		if not filtered then
			target:sendEvent( event )
		end
		event:recycle()
	end

	table.clear( events )
end

function UIView:clearEvents()
	self.eventCount = 0
	self.eventQueue:swap()
end

local function _findTopPointerInteractiveWidget( pointer, parent, x, y, padding, debug )
	local childId = 0
	local children = parent.childWidgets
	local count = #children
	for k = count , 1, -1 do
		local child = children[ k ]
		if child:isInteractive() then
			local px,py,pz = child:getWorldLoc()
			local pad = padding or child:getTouchPadding()
			local inside = child:inside( x, y, pz, pad )
			if inside == 'group' then
				local found = _findTopPointerInteractiveWidget( pointer, child, x, y, padding, debug )
				if debug then
					print( 'hover in group', found )
				end
				if found then	return found end
			elseif inside then
				local result = _findTopPointerInteractiveWidget( pointer, child, x, y, padding, debug )
				if debug then
					print( 'hover', result )
				end
				if not result then
					if child:isTrackingPointer() then
						result = child
					end
				end
				return result
			else
				if debug then
					print( 'ignored', child )
				end
			end
		end
	end
	return nil
end

function UIView:findTopWidgetForPointer( pointer, x, y, debug )
	local padding = pointer.padding
	local start = self.modalWidget or self 
	local target =  _findTopPointerInteractiveWidget( pointer, start, x, y, padding, debug )
	-- print( 'top widget', target )
	return target
end


---------------------------------------------------------------------
--Visual control
function UIView:getStyleSheetObject()
	if self.localStyleSheet then
		return self.localStyleSheet
	else
		return getBaseStyleSheet()
	end
end

function UIView:onLocalStyleSheetChanged()
	self.pendingVisualUpdates = {}
	self.pendingLayoutUpdates = {}
	--update
end

function UIView:flushVisualUpdate()
	local updates = self.pendingVisualUpdates
	self.pendingVisualUpdates = {}
	local mpointer = self:getMousePointer()
	local hover = mpointer:getHoverWidget()
	local needUpdateCursor = hover and hover.styleModified

	for w in pairs( updates ) do
		w:updateVisual()
	end

	if needUpdateCursor then
		mpointer:updateCursor()
	end

end

local function _sortUIWidgetForLayout( a, b )
	return a.widgetDepth < b.widgetDepth
end

local insert = table.insert
local sort = table.sort
local next = next
function UIView:flushLayoutUpdate()
	while true do
		local updates = self.pendingLayoutUpdates
		if not next( updates ) then break end
		self.pendingLayoutUpdates = {}
		local queue = table.keys( updates )
		sort( queue, _sortUIWidgetForLayout )
		for i = 1, #queue do
			local w = queue[ i ]
			w:updateLayout()
		end
	end
	self:updateRenderOrder()
end

function UIView:scheduleVisualUpdate( widget )
	self.pendingVisualUpdates[ widget ] = true
	return self:scheduleUpdate()
end

function UIView:scheduleLayoutUpdate( widget )
	self.pendingLayoutUpdates[ widget ] = true
	return self:scheduleUpdate()
end

--------------------------------------------------------------------
--INPUT handling

function UIView:setInputRepeating( repeating, threshold, interval )
	self.repeatingEnabled   = repeating ~= false
	self.repeatingThreshold = threshold or 0.5
	self.repeatingInterval  = interval or 0.1
end

function UIView:actionUpdateInputRepeating()
	while true do
		local dt = coroutine.yield()
		local target = self:getInputEventTarget()
		if self.repeatingEnabled and target then
			--keys
			local pressedKeys = self.pressedKeys
			for key, t in pairs( pressedKeys ) do
				if t == true then --not repeatable
					--do nothing
				elseif t < 0 then --threshold
					t = t + dt
					pressedKeys[ key ] = t
				else
					t = t - dt
					if t<=0 then
						local data = { key = key, down = true, modifiers = getModifierKeyStates(), repeating = true }
						local ev = UIEvent( UIEvent.KEY_DOWN, data )
						self:postEvent( target, ev )
						local ev = UIEvent( UIEvent.KEY, data )
						self:postEvent( target, ev )
						pressedKeys[ key ] = self.repeatingInterval
					else
						pressedKeys[ key ] = t
					end
				end
			end
			--end of keys

			--commands
			local pressedCommands = self.pressedCommands
			for cmd, t in pairs( pressedCommands ) do
				if t == true then --not repeatable
					--do nothing
				elseif t < 0 then --threshold
					t = t + dt
					pressedCommands[ cmd ] = t
				else
					t = t - dt
					if t<=0 then
						local data = { cmd = cmd, down = true, modifiers = getModifierKeyStates(), repeating = true } 
						local ev = UIEvent( UIEvent.INPUT_COMMAND_DOWN, data )
						self:postEvent( target, ev )
						local ev = UIEvent( UIEvent.INPUT_COMMAND, data )
						self:postEvent( target, ev )
						pressedCommands[ cmd ] = self.repeatingInterval
					else
						pressedCommands[ cmd ] = t
					end
				end
			end
			--end of commands

			--j button
			local removingJoys = false
			for joy, state in pairs( self.pressedJoyButtons ) do
				if not joy.connected then --remove
					removingJoys = removingJoys or {}
					removingJoys[ joy ] = true
				else
					for btn, t in pairs( state ) do
						if t < 0 then --threshold
							t = t + dt
							state[ btn ] = t
						else
							t = t - dt
							if t<=0 then
								local data = { button = btn, down = true, joystick = joy, repeating = true }
								local ev = UIEvent( UIEvent.JOYSTICK_BUTTON_DOWN, data )
								self:postEvent( target, ev )
								local ev = UIEvent( UIEvent.JOYSTICK_BUTTON, data )
								self:postEvent( target, ev )
								state[ btn ] = self.repeatingInterval
							else
								state[ btn ] = t
							end
						end
					end
				end
				if removingJoys then
					for j in pairs( removingJoys ) do
						self.pressedJoyButtons[ joy ] = nil
					end
				end
				--end of j button
			end
			--end of if repeating enabled
		end
		--end of while
	end

end

function UIView:onKeyChar( char )
	if not self:isInteractive() then return end
	local target = self:getInputEventTarget()
	if not target then return end
	local ev = UIEvent( UIEvent.TEXT_INPUT, { text = char, modifiers = getModifierKeyStates() } )
	return self:postEvent( target, ev )
end

function UIView:onKeyEdit( str, start, length )
	if not self:isInteractive() then return end
	local target = self:getInputEventTarget()
	if not target then return end
	local ev = UIEvent( UIEvent.TEXT_EDIT, { 
		text = str, 
		start = start, 
		length = length, 
		modifiers = getModifierKeyStates()
	} )
	return self:postEvent( target, ev )
end

-- function UIView:refreshInputState()
	
-- end

function UIView:onInputCommandEvent( cmd, down, source, sourceData )
	if not down then
		self.pressedCommands[ cmd ] = nil
	end

	if not self:isInteractive() then return end
	local target = self:getInputEventTarget()
	if not target then return end
	
	local data = { 
		cmd        = cmd, 
		down       = down, 
		source     = source,
		sourceData = sourceData,
		repeating  = false, 
		modifiers  = getModifierKeyStates()
	}
	
	if down then
		self.pressedCommands[ cmd ] = - self.repeatingThreshold
		local ev = UIEvent( UIEvent.INPUT_COMMAND_DOWN, data )
		self:postEvent( target, ev )
	else
		local ev = UIEvent( UIEvent.INPUT_COMMAND_UP, data )
		self:postEvent( target, ev )
	end

	local ev = UIEvent( UIEvent.INPUT_COMMAND, data )
	self:postEvent( target, ev )

end

function UIView:onKeyEvent( key, down )
	if not down then
		self.pressedKeys[ key ] = nil
	end
	
	if not self:isInteractive() then return end
	local target = self:getInputEventTarget()
	if not target then return end

	local data = { 
		key = key, 
		down = down,
		repeating = false,
		modifiers = getModifierKeyStates()
	}

	if down then
		self.pressedKeys[ key ] = - self.repeatingThreshold
		local ev = UIEvent( UIEvent.KEY_DOWN, data )
		self:postEvent( target, ev )
	else
		local ev = UIEvent( UIEvent.KEY_UP, data )
		self:postEvent( target, ev )
	end

	local ev = UIEvent( UIEvent.KEY, data )
	self:postEvent( target, ev )
end

function UIView:onJoyAxisMove( joy, axis, value )
	if not self:isInteractive() then return end
	
	local target = self:getInputEventTarget()
	if not target then return end
	local ev = UIEvent( UIEvent.JOYSTICK_AXIS_MOVE, { axis = axis, value = value, joystick = joy } )
	return self:postEvent( target, ev )
end

function UIView:onJoyButtonEvent( joy, btn, down )
	if not self:isInteractive() then return end

	local target = self:getInputEventTarget()
	if not target then return end
	local data = { 
		button = btn, 
		joystick = joy, 
		down = down, 
		repeating = false
	}

	if down then
		local joybuttonStates = self.pressedJoyButtons[ joy ]
		if not joybuttonStates then
			joybuttonStates = {}
			self.pressedJoyButtons[ joy ] = joybuttonStates
		end
		joybuttonStates[ btn ] = - self.repeatingThreshold
		local ev = UIEvent( UIEvent.JOYSTICK_BUTTON_DOWN, data )
		self:postEvent( target, ev )

	else
		local joybuttonStates = self.pressedJoyButtons[ joy ]
		if joybuttonStates then
			joybuttonStates[ btn ] = nil
		end
		local ev = UIEvent( UIEvent.JOYSTICK_BUTTON_UP, data )
		self:postEvent( target, ev )		
		
	end
	local ev = UIEvent( UIEvent.JOYSTICK_BUTTON, data )
	self:postEvent( target, ev )
end

function UIView:wndToUI( x, y )
	local mapping = self.viewMapping
	if mapping then
		return mapping:wndToUI( self, x, y )
	elseif self.targetCamera then
		return self.targetCamera:wndToWorld( x, y )
	else
		return self:wndToWorld( x, y )
	end
end

function UIView:cursorToUI( x, y )
	x, y = self.cursorManager:cursorToWnd( x, y )
	return self:wndToUI( x, y )
end

function UIView:UIToWnd( x, y )
	local mapping = self.viewMapping
	if mapping then
		return mapping:UIToWnd( self, x, y )
	elseif self.targetCamera then
		return self.targetCamera:worldToWnd( x, y )
	else
		return self:worldToWnd( x, y )
	end
end

function UIView:onMouseEvent( ev, x, y, btn )
	if not self:isInteractive() then return end
	local pointer = self:getMousePointer()

	if ev == 'move' then
		local x, y = self.cursorTransform:getLoc()
		x, y = self:cursorToUI( x, y )
		pointer:onMove( self, x, y )

	elseif ev == 'down' then
		local x, y = self.cursorTransform:getLoc()
		x, y = self:cursorToUI( x, y )
		pointer:onDown( self, x, y, btn )

	elseif ev == 'up' then
		local x, y = self.cursorTransform:getLoc()
		x, y = self:cursorToUI( x, y )
		pointer:onUp( self, x, y, btn )

	elseif ev == 'scroll' then
		pointer:onScroll( self, x, y )

	end
end

function UIView:onTouchEvent( ev, touch, x, y )
	if not self:isInteractive() then return end
	local wx, wy = x, y
	x, y = self:wndToUI( x, y )
	local pointer = self:getPointer( touch, true )
	if ev == 'down' then
		pointer:onDown( self, x, y )

	elseif ev == 'up' then
		pointer:onUp( self, x, y )
		
	elseif ev == 'move' then
		pointer:onMove( self, x, y )

	end
end

function UIView:updateFocusGroup()
	for i, child in ipairs( self.childWidgets ) do
		child:updateFocusGroup()
	end
end

function UIView:onLocaleChange( locale )
	self.currentLocale = locale
	self:_updateTranslation( true )
end
