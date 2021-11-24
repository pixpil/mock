module 'mock'


--------------------------------------------------------------------
CLASS: UIEvent ()
	:MODEL{}

function UIEvent:__init( type, data )
	self.type = assert( type, 'nil event type' )
	self.data = data
	self.accepted = false
	self.spontaneous = false
	self.target = false
end

function UIEvent:__tostring()
	return string.format( '%s(type=%s)', self:__repr(), tostring( self.type ) )
end

function UIEvent:getType()
	return self.type
end

function UIEvent:getTarget()
	return self.target
end

local select = select
function UIEvent:checkType( ... )
	local tt = self.type
	local c = select( '#', ... )
	for i = 1, c do
		local a = select( i, ... )
		if a == tt then return true end
	end
	return false
end

function UIEvent:tostring()
	return self.type
end

function UIEvent:isAccepted()
	return self.accepted
end

function UIEvent:isIgnored()
	return not self.accepted
end

function UIEvent:accept()
	self.accepted = true
end

function UIEvent:ignore()
	self.accepted = false
end

--TODO: decent way in Class.lua
local UIEventPool = {}
local poolCursor = 0
local newUIEvent = UIEvent.__new

local function reuseUIEvent( clas, ... )
	if poolCursor > 0 then
		local o = UIEventPool[ poolCursor ]
		poolCursor = poolCursor - 1
		o:__init( ... )
		return o
	else
		return newUIEvent( clas, ... )
	end
end
getmetatable( UIEvent ).__call = reuseUIEvent

function UIEvent:recycle()
	poolCursor = poolCursor + 1
	UIEventPool[ poolCursor ] = self
	self:__clear()
end


--------------------------------------------------------------------

--INPUT
UIEvent.POINTER			   = "pointer"
UIEvent.POINTER_DOWN   = "pointerDown"
UIEvent.POINTER_UP     = "pointerUp"
UIEvent.POINTER_DCLICK = "pointerDClick"
UIEvent.POINTER_MOVE   = "pointerMove"
UIEvent.POINTER_SCROLL = "pointerScroll"
UIEvent.CLICK          = "click"

UIEvent.POINTER_ENTER = "pointerEnter"
UIEvent.POINTER_EXIT  = "pointerExit"

UIEvent.JOYSTICK_BUTTON_DOWN  = "joystickButtonDown"
UIEvent.JOYSTICK_BUTTON_UP  = "joystickButtonUp"
UIEvent.JOYSTICK_BUTTON     = "joystickButton"
UIEvent.JOYSTICK_AXIS_MOVE  = "joystickAxisMove"

UIEvent.KEY				= 'key'
UIEvent.KEY_DOWN  = "keyDown"
UIEvent.KEY_UP    = "keyUp"

UIEvent.INPUT_COMMAND  			= "inputCommand"
UIEvent.INPUT_COMMAND_DOWN  = "inputCommandDown"
UIEvent.INPUT_COMMAND_UP    = "inputCommandUp"

UIEvent.TEXT_INPUT  = "textInput"
UIEvent.TEXT_EDIT   = "textEdit"

UIEvent.RESIZE        = "resize"
UIEvent.SKIN_CHANGED  = "themeChanged"
UIEvent.STYLE_CHANGED = "styleChanged"
UIEvent.FOCUS_IN      = "focusIn"
UIEvent.FOCUS_OUT     = "focusOut"
UIEvent.VIEW_FOCUS_IN = "viewFocusIn"
UIEvent.VIEW_FOCUS_OUT= "viewFocusOut"
UIEvent.CANCEL        = "cancel"
UIEvent.VALUE_CHANGED = "valueChanged"
UIEvent.STICK_CHANGED = "stickChanged"
UIEvent.MSG_SHOW      = "msgShow"
UIEvent.MSG_HIDE      = "msgHide"
UIEvent.MSG_END       = "msgEnd"
UIEvent.SPOOL_STOP    = "spoolStop"

UIEvent.ITEM_CHANGED  = "itemChanged"
UIEvent.ITEM_ENTER    = "itemEnter"
UIEvent.ITEM_CLICK    = "itemClick"

UIEvent.SCROLL        = "scroll"
