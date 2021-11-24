module 'mock'

CLASS: UIButtonBase ( UIWidget )
	:MODEL{
	}
	:SIGNAL{
		pressed  = 'onPressed';
		released = 'onReleased';
		clicked  = 'onClicked';
	}

function UIButtonBase:__init()
	self._hoverd = false
	self._pressed = false
	self.layoutPolicy = { 'expand', 'expand' }
	self.focusPolicy = 'click'
	self.clickCount = 0
end

function UIButtonBase:getDefaultRendererClass()
	return UIFrameRenderer
end

function UIButtonBase:isPressed()
	return self._pressed
end

function UIButtonBase:isHovered()
	return self._hoverd
end

function UIButtonBase:setText( t )
	self.text = t
	self:invalidateContent()
end


function UIButtonBase:updateStyleState()
	if not self:isActive() then
		return self:setState( 'disabled' )
	end

	if self._pressed then
		return self:setState( 'press' )
	end

	if self._hoverd then
		return self:setState( 'hover' )
	end

	return UIButtonBase.__super.updateStyleState( self )
end


function UIButtonBase:procEvent( ev )
	local t = ev.type
	local d = ev.data

	if t == UIEvent.POINTER_ENTER then
		self._hoverd = true
		self:updateStyleState()
		ev:accept()

	elseif t == UIEvent.POINTER_EXIT then
		self._hoverd = false
		self:updateStyleState()
		ev:accept()

	elseif t == UIEvent.POINTER then

		if d.down then
			self:_press( d.x, d.y )
		else
			self:_release( d.x, d.y )
		end
		ev:accept()

	elseif t == UIEvent.INPUT_COMMAND then
		if self:procInputCommand( ev.data ) then
			ev:accept()
		end

	elseif t == UIEvent.FOCUS_OUT then
		self:_cancel()

	end
	
	return UIButtonBase.__super.procEvent( self, ev )
end

function UIButtonBase:_cancel()
	if not self._pressed then return end
	self._pressed = false
	self:updateStyleState()
	self.released:emit()
end

function UIButtonBase:_release( x, y )
	if not self._pressed then return end
	self._pressed = false
	self:updateStyleState()
	local px,py,pz = self:getWorldLoc()
	if ( not x ) or self:inside( x, y, pz, self:getTouchPadding() ) then
		self.clicked:emit()
		self.clickCount = self.clickCount + 1
	end
	self.released:emit()
end

function UIButtonBase:_press( x, y )
	if self._pressed then return end
	self._pressed = true
	self:updateStyleState()
	if self.focusPolicy then --use other policy?
		self:setFocus()
	end
	self.pressed:emit()
end

function UIButtonBase:procInputCommand( cmdData )
	local cmd = cmdData.cmd
	if cmd == 'confirm' and not cmdData.repeating then
		if cmdData.down then
			self:_press()
		else
			self:_release()
		end
		return true
	else
		if cmdData.down and isNavigationInputCommand( cmd ) then
			self:moveFocus( cmd )
			return true
		end
	end

end

function UIButtonBase:getLabelRect()
	return self:getContentRect()
end


----
function UIButtonBase:onPressed()
end

function UIButtonBase:onReleased()
end

function UIButtonBase:onClicked()
end

function UIButtonBase:pollClickCount()
	local count = self.clickCount
	self.clickCount = 0
	return count
end

--------------------------------------------------------------------
CLASS: UIButtonMsg ( UIMsgSource )
	:MODEL{
		'----';
		Field 'msgPressed' :string();
		Field 'msgReleased' :string();
		Field 'msgClicked' :string();
}

registerComponent( 'UIButtonMsg', UIButtonMsg )

function UIButtonMsg:__init()
	self.msgPressed = 'button.pressed'
	self.msgReleased = 'button.released'
	self.msgClicked = 'button.clicked'
end

function UIButtonMsg:onStart( ent )
	assert( ent:isInstance( UIButtonBase ))
	self:connect( ent.pressed, 'onPressed' )
	self:connect( ent.released, 'onReleased' )
	self:connect( ent.clicked, 'onClicked' )
end

function UIButtonMsg:onPressed()
	if self.msgPressed ~= '' then
		self:emitMsg( self.msgPressed )
	end
end

function UIButtonMsg:onReleased()
	if self.msgReleased ~= '' then
		self:emitMsg( self.msgReleased )
	end
end

function UIButtonMsg:onClicked()
	if self.msgClicked ~= '' then
		self:emitMsg( self.msgClicked )
	end
end

