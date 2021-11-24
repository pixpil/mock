module 'mock'

CLASS: ImGuiLayer ()
	:MODEL{}

function ImGuiLayer:__init()
	self.imgui = markRenderNode( MOAIImGui.new() )
	self.imgui:start()
	
	self.imgui:setScl( 1, -1, 1 )
	self.imgui:setSize( 1280, 720 )
	self.imgui:setLoc( 0, 0 )

	local layer = MOAITableViewLayer.new()
	self.imguiLayer = layer
	self.viewport = false
	layer:setClearMode( MOAILayer.CLEAR_NEVER )
	layer:setFrameBuffer( MOAIGfxMgr.getFrameBuffer() )
	layer:setRenderTable{ self.imgui }
	
	local quadCamera = MOAICamera.new()
	quadCamera:setOrtho( true )
	quadCamera:setNearPlane( -100000 )
	quadCamera:setFarPlane( 100000 )
	quadCamera:setScl( 1, 1, 1 )
	layer:setCamera( quadCamera )

	self.camera = quadCamera
	self.inputCategory = false
	self.captureingMouse = false
	self.captureingKeyboard = false
end

function ImGuiLayer:init( option )
	option = option or {}
	self.inputCategory = option.inputCategory or 'imgui'
	installInputListener( self, { category = self.inputCategory } )
	self.imgui:init()
	self.imgui:setListener( MOAIImGui.EVENT_CAPTURE_KEYBOARD,  function( imgui )
			return self:onCaptureKeyboard()
		end
	)

	self.imgui:setListener( MOAIImGui.EVENT_CAPTURE_MOUSE, function( imgui )
			return self:onCaptureMouse()
		end
	)

	self.imgui:setListener( MOAIImGui.EVENT_RELEASE_KEYBOARD, function( imgui )
			return self:onReleaseKeyboard()
		end
	)

	self.imgui:setListener( MOAIImGui.EVENT_RELEASE_MOUSE, function( imgui )
			return self:onReleaseMouse()
		end
	)

	self.imgui:setListener( MOAIImGui.EVENT_START_TEXTINPUT, function( imgui )
			return self:onStartTextInput()
		end
	)

	self.imgui:setListener( MOAIImGui.EVENT_STOP_TEXTINPUT, function( imgui )
			return self:onStopTextInput()
		end
	)

end

function ImGuiLayer:setEnabled( enabled )
	if not enabled then
		setInputListenerCategorySolo( 'all', self.inputCategory, false )
	end
end

function ImGuiLayer:setVisible( vis )
	self.imguiLayer:setEnabled( vis )
end

function ImGuiLayer:getRenderLayer()
	return self.imguiLayer
	-- if not self.renderCommand then
	-- 	local renderCommand = createTableRenderLayer()
	-- 	renderCommand:setClearColor()
	-- 	renderCommand:setFrameBuffer( game:getDeviceFrameBuffer() )
	-- 	-- renderCommand:setFrameBuffer( game:getMainFrameBuffer() )
	-- 	-- renderCommand:setFrameBuffer( MOAIGfxMgr.getFrameBuffer() )
	-- 	renderCommand:setRenderTable( { self.imguiLayer } )

	-- 	self.renderCommand = renderCommand
	-- end
	-- return self.renderCommand
end

function ImGuiLayer:setViewport( vp )
	self.viewport = vp
	self.imguiLayer:setViewport( vp )
end

function ImGuiLayer:setSize( w, h )
	self.imgui:setSize( w, h )
end

function ImGuiLayer:setLoc( w, h )
	self.camera:setLoc( w, h )
end

function ImGuiLayer:getMoaiLayer()
	return self.imguiLayer
end

function ImGuiLayer:setCallback( callback )
	self.imgui:setCallback( callback )
end

local btnNameToId = {
	left = 0,
	middle = 2,
	right = 1,
}


function ImGuiLayer:onMouseEvent ( ev, x, y, btn, mock )
	local gui = self.imgui
	local layer = self.imguiLayer
	if ev == 'down' then
		gui:sendMouseButtonEvent( btnNameToId[ btn ] or -1, true )

	elseif ev == 'up' then
		gui:sendMouseButtonEvent( btnNameToId[ btn ] or -1, false )

	elseif ev == 'move' then
		x, y = layer:wndToWorld( x, y )
		x, y = gui:worldToModel( x, y )
		return gui:sendMouseMoveEvent( x, y )

	elseif ev == 'scroll' then
		return gui:sendMouseWheelEvent( y*0.1 )
		
	end
end

local key2ImguiKey = {
	[ 'tab'       ] = MOAIImGui.Key_Tab,
	[ 'left'      ] = MOAIImGui.Key_LeftArrow,
	[ 'right'     ] = MOAIImGui.Key_RightArrow,
	[ 'up'        ] = MOAIImGui.Key_UpArrow,
	[ 'down'      ] = MOAIImGui.Key_DownArrow,
	[ 'pageup'    ] = MOAIImGui.Key_PageUp,
	[ 'pagedown'  ] = MOAIImGui.Key_PageDown,
	[ 'home'      ] = MOAIImGui.Key_Home,
	[ 'end'       ] = MOAIImGui.Key_End,
	[ 'delete'    ] = MOAIImGui.Key_Delete,
	[ 'backspace' ] = MOAIImGui.Key_Backspace,
	[ 'enter'     ] = MOAIImGui.Key_Enter,
	[ 'escape'    ] = MOAIImGui.Key_Escape,
	
	[ 'a'    ] = MOAIImGui.Key_A,
	[ 'c'    ] = MOAIImGui.Key_C,
	[ 'v'    ] = MOAIImGui.Key_V,
	[ 'x'    ] = MOAIImGui.Key_X,
	[ 'y'    ] = MOAIImGui.Key_Y,
	[ 'z'    ] = MOAIImGui.Key_Z,

}

local modifierKeys = {
	[ 'lshift' ] = true;
	[ 'rshift' ] = true;
	[ 'lctrl'  ] = true;
	[ 'rctrl'  ] = true;
	[ 'lalt'   ] = true;
	[ 'ralt'   ] = true;
	[ 'lmeta'  ] = true;
	[ 'rmeta'  ] = true;
}

function ImGuiLayer:onKeyEvent( key, down )
	local code = key2ImguiKey[ key ]
	if code then
		return self.imgui:sendKeyEvent( code, down )
	elseif modifierKeys[ key ] then
		return self.imgui:sendModifierState( 
			isShiftDown() or false, isMetaDown() or false, isAltDown() or false, isCtrlDown() or false
		)
	end
end

function ImGuiLayer:onKeyChar( char )
	return self.imgui:sendTextEvent( char )
end

function ImGuiLayer:onCaptureMouse()
	self.captureingMouse = true
	setInputListenerCategorySolo( 'mouse', self.inputCategory, true )
end

function ImGuiLayer:onCaptureKeyboard()
	self.captureingKeyboard = true
	setInputListenerCategorySolo( 'keyboard', self.inputCategory, true )
end

function ImGuiLayer:onStartTextInput()
	game:startTextInput()
	if self.captureingKeyboard then return end
	setInputListenerCategorySolo( 'keyboard', self.inputCategory, true )
end

function ImGuiLayer:onReleaseMouse()
	self.captureingMouse = false
	setInputListenerCategorySolo( 'mouse', self.inputCategory, false )
end

function ImGuiLayer:onReleaseKeyboard()
	self.captureingKeyboard = false
	setInputListenerCategorySolo( 'keyboard', self.inputCategory, false )
end

function ImGuiLayer:onStopTextInput()
	game:stopTextInput()
	if self.captureingKeyboard then return end
	setInputListenerCategorySolo( 'keyboard', self.inputCategory, false )
end
