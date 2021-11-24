module 'mock'

--------------------------------------------------------------------
CLASS: UITextSelectionRenderer ( DrawScript )

function UITextSelectionRenderer:__init()
	self.spans = {}
end

function UITextSelectionRenderer:onAttach( ent )
	UITextSelectionRenderer.__super.onAttach( self, ent )
	inheritTransform( self.prop, ent.textBox.box )
	self.prop:setLoc( 0,0,-0.00001 )
	setPropBlend( self.prop, 'alpha' )
	self:setColor( 0.5,0,0,0.7 )
end

local min, max = math.min, math.max
local insert = table.insert
function UITextSelectionRenderer:update( u0, u1 )
	local edit = self:getEntity()
	local box = edit:getMoaiTextBox()
	local t = edit:getTextObject()
	local l = t:len()
	u0 = u0 + 1
	if t:sub( u0, u0 ) == '\n' then
		u0 = u0 + 1
	end
	local b0 = t:bytepos( math.min( u0, l ) )
	local b1 = t:bytepos( math.min( u1, l ) )
	local l0 = box:getLineIndex( b0 )
	local l1 = box:getLineIndex( b1 )
	local spans = {}
	for l = l0, l1 do
		local s, e = box:getLineStringIndex( l )
		if t:bsub( s,s ) == '\n' then --empty line
			local x0, y0, x1, y1 = box:getLineBounds( l )
			local span = { x0, y0, x0+3, y1 }
			insert( spans, span )
		else
			local h = edit:getLineHeight( l )
			s = max( s, b0 )
			e = min( e, b1 )
			local size = e-s
			local x0, y0, x1, y1 = box:getTextBounds( s, size + 1 )
			if x0 then
				local span = { x0, y1, x1, y1 + h }
				insert( spans, span )
			end
		end
	end

	local x0, y0, x1, y1 = box:getTextBounds( b0, b1 )
	self:setRect( x0, y0, x1, y1 )
	self.spans = spans
end

function UITextSelectionRenderer:onDraw()
	for i, span in ipairs( self.spans ) do
		MOAIDraw.fillRect( unpack( span ) )
	end
end

--------------------------------------------------------------------
CLASS: UITextEditCursor ( DrawScript )

function UITextEditCursor:__init()
	self.line = 0
	self.pos  = 1
	self.col  = 1
	self.selectionStart = false
	self.selectionEnd   = false
	self.flickerPower = 0
end

function UITextEditCursor:onAttach( ent )
	UITextEditCursor.__super.onAttach( self, ent )
	self:setRect( -1,0,1,30 )
	inheritTransform( self.prop, ent.textBox.box )
	self:setPiv( 0,0,-5)
end

function UITextEditCursor:onStart( ent )
	self:addCoroutine( 'actionFlicker' )
end

function UITextEditCursor:onDraw()
	MOAIDraw.fillRect( -1,0,1, self.height )
end

function UITextEditCursor:actionFlicker()
	local prop = self:getMoaiProp()
	setPropBlend( prop, 'alpha' )
	local pow = math.pow
	local clamp = math.clamp
	local cos = math.cos
	while true do
		local dt = coroutine.yield()
		local v = cos( self.flickerPower )/2 + 0.5
		self.flickerPower = self.flickerPower + dt*3.1415926*2
		self:setAlpha( clamp( lerp( -1.2, 1.5, v ), 0, 1 ) )
	end
end


local function _isLineEnd( t, p )
	local l = t:len()
	if p > l then return true end
	local c = t:sub( p, p )
	if c == '\n' then return true end
	return false
end

function UITextEditCursor:updatePos()
	self.flickerPower = 0
	local edit = self:getEdit()
	local box = edit.textBox.box
	local pos = self.pos
	box:forceUpdate()
	local t = edit.text
	if t:bytelen() == 0 then
		box:setText( ' ' )
		local height = edit:getDefaultLineHeight()
		self.height = height
		local x0,y0,x1,y1 = box:getRect()
		local x0,y0,x1,y1 = box:getLineBounds( 1 )
		self:setLoc( x1, y0 )
		box:setText( '' )
		self.pos = 0
		return
	end

	local emptyEnd = t:bsub( -1,-1 ) == '\n' --ending empty line
	local l = t:len()
	local line

	if pos == l  then
		if emptyEnd then
			line = box:getLineCount()
			self.line = line
			local x0,y0,x1,y1 = box:getLineBounds( line )
			self:setLoc( x0, y0 )
		else
			line = box:getLineCount()
			self.line = line
			local x0,y0,x1,y1 = box:getLineBounds( line )
			self:setLoc( x1, y0 )
		end

	else
		local bpos
		bpos = t:bytepos( math.min( pos + 1, l )  )
		boff = -1

		line = box:getLineIndex( bpos )
		if not line then return end

		self.line = line
		local s, e = box:getLineStringIndex( line )
		local upos0 = t:pos( s )
		self.col = pos - upos0 + 1
		local lineSize = e - s
		if lineSize > 0 then --use text bound
			if _isLineEnd( t, pos + 1 ) then
				local x0,y0,x1,y1 = box:getLineBounds( line )
				self:setLoc( x1, y0 )
			else
				local x0,y0,x1,y1 = box:getTextBounds( bpos, 1 )
				if x0 then
					self:setLoc( x0, y1 )
				end
			end
		else --empty line, use line bound
			local x0,y0,x1,y1 = box:getLineBounds( line )
			self:setLoc( x0, y0 )
		end
	end

	self.prop:forceUpdate()
	local x, y = self.prop:getWorldLoc()
	local wndX,wndY = edit:worldToWnd( x, y )
	--TODO
	game:setTextInputRect ( wndX, wndY + 30, wndX, wndY + 30 )

	--height
	local height = edit:getLineHeight( line )
	self.height = height
	self:setRect( -1,0,1,height )

end

function UITextEditCursor:getEdit()
	return self:getEntity()
end

function UITextEditCursor:getMoaiTextBox()
	return self:getEdit():getMoaiTextBox()
end

function UITextEditCursor:reset()
	self.pos = 1
	self.selectionStart = 1
	self.selectionEnd = 1
	self:updatePos()
end

function UITextEditCursor:moveToStart( selecting )
	self:set( 0, selecting )
end

function UITextEditCursor:moveToEnd( selecting )
	self:set( -1, selecting )
end

function UITextEditCursor:moveToLineStart( selecting )
	if self.line == 1 then
		return self:_set( 0, selecting )
	end
	local box = self:getMoaiTextBox()
	local b0, b1 = box:getLineStringIndex( self.line )
	if b0 then
		local t = self:getEdit():getTextObject()
		local upos = t:pos( b0 )
		self:_set( upos - 1, selecting )
	end
end

function UITextEditCursor:moveToLineEnd( selecting )
	local box = self:getMoaiTextBox()
	local b0, b1 = box:getLineStringIndex( self.line )
	if b0 then
		local t = self:getEdit():getTextObject()
		local upos = t:pos( b1 )
		upos = upos
		if t:sub( upos, upos ) == '\n' then
			upos = upos - 1
		end
		self:_set( upos, selecting )
	end
end

function UITextEditCursor:moveX( dx, selecting )
	local pos
	if not selecting then
		local s,e = self:getSelection()
		if e > s then
			if dx > 0 then
				pos = e
			else
				pos = s
			end
		else
			pos = self.pos + dx
		end
	else
		pos = self.pos + dx
	end
	self:_set( pos, selecting )
end

function UITextEditCursor:moveY( dy, selecting )
	local box = self:getMoaiTextBox()
	local lineCount = box:getLineCount()
	local line1 = self.line + dy
	if line1 > lineCount then return end
	if line1 < 0 then return end
	if line1 == 0 then
		return self:_set( 0, selecting )
	end

	local lineHeight = self:getEdit():getLineHeight( self.line )
	if lineHeight then
		local x, y = self:getLoc()
		local off = dy < 0 and - lineHeight or ( lineHeight + box:getLineSpacing() )
		local upos, off = self:getEdit():hitCharOrLine( x, y + off )
		if upos then
			if off < 0 then
				self:_set( upos - 1, selecting )
			else
				self:_set( upos, selecting )
			end
		end
	end

end

function UITextEditCursor:_set( pos, selecting )
	local l = self:getEdit():getTextLength()
	local pos0 = self.pos
	pos = math.clamp( pos, 0, l )
	if selecting then
		self:setSelection( nil, pos )
	else
		self:setSelection( pos, pos )
	end
	self.pos = pos
	self:updatePos()
	return true
end

function UITextEditCursor:set( pos, selecting )
	if not pos then return false end
	local t = self:getEdit():getTextObject()
	local l = t:len() or 0
	if pos < 0 then
		pos = (l + 1) - pos
	end
	if pos < 0 then return false end
	return self:_set( pos, selecting )

end

function UITextEditCursor:setSelecting( selecting )
	self.selecting = selecting
end

function UITextEditCursor:getSelection()
	local s, e = self.selectionStart, self.selectionEnd
	if s > e then 
		return e, s
	else
		return s, e
	end
end

function UITextEditCursor:getSelectionSize()
	local s,e = self:getSelection()
	return e - s
end

function UITextEditCursor:setSelection( start, stop )
	self.selectionStart = start or self.selectionStart
	self.selectionEnd = stop or self.selectionEnd
	self:getEdit():callNextFrame( function()
			self:getEdit():updateSelection()
		end)
end

function UITextEditCursor:clearSelection()
	self:setSelection( self.pos, self.pos )
end

function UITextEditCursor:selectAll()
	local length = self:getEdit():getTextLength()
	self:_set( length )
	self:setSelection( 0, length )
end

function UITextEditCursor:delete( dir )
	local t = self:getEdit():getTextObject()
	local ss = self:getSelectionSize()
	if ss > 0 then
		local s,e = self:getSelection()
		t:remove( s + 1, ss )
		self:_set( s )
	else
		local pos = self.pos
		if dir < 0 then --back
			if pos > 0 then
				t:remove( pos, 1 )
				self:_set( pos - 1 )
			end
		else
			if pos < t:len() then
				t:remove( pos + 1, 1 )
			end
		end
	end
	self:getEdit():invalidateContent()
end

function UITextEditCursor:insert( text, append )
	if self:getSelectionSize() > 0 then
		self:delete()
	end
	local t = self:getEdit():getTextObject()
	t:insert( self.pos, text )
	if not append then
		self.pos = self.pos + utf8.len( text )
	end
	self:getEdit():invalidateContent()
end


--------------------------------------------------------------------
CLASS: UITextEditRenderer ( UICommonStyleWidgetRenderer )
	:MODEL{}

function UITextEditRenderer:onUpdateContent( widget, style )
	UITextEditRenderer.__super.onUpdateContent( self, widget, style )
	widget:callNextFrame( function()
			widget.cursor:updatePos()
		end
	)
end

--------------------------------------------------------------------
CLASS: UITextEdit ( UIWidget )
	:MODEL{}

registerEntity( 'UITextEdit', UITextEdit )

function UITextEdit:__init()
	self.text = TextObject()
	self.imeEditing = false
	self.pointerPressed = false

	self.textBox = false
	self.selectionRenderer = false
	self.cursor = false
end

function UITextEdit:onLoad()
	UITextEdit.__super.onLoad( self )
	self:setText( 'TextInput' )
end

function UITextEdit:getDefaultRendererClass()
	return UITextEditRenderer	
end

function UITextEdit:onRendererLoad( renderer )
	assert( renderer:isInstance( UITextEditRenderer ) )
	self.textBox = renderer.textElement:getTextLabel()
	self.selectionRenderer = self:attachInternal( UITextSelectionRenderer() )
	self.cursor  = self:attachInternal( UITextEditCursor() )
	self.cursor:hide()

end

local UIEvent = UIEvent
function UITextEdit:procEvent( ev )
	UITextEdit.__super.procEvent( self, ev )
	local e = ev.type
	local data = ev.data
	if e == UIEvent.KEY_DOWN then
		if not self.imeEditing then 
			self:procKeyDown( ev )
		end

	elseif e == UIEvent.KEY_UP then
		if not self.imeEditing then 
			self:procKeyUp( ev )
		end

	elseif e == UIEvent.POINTER_DOWN then
		self:setFocus()
		self:procPointerMotion( ev )
		self.cursor:clearSelection()
		self.pointerPressed = true

	elseif e == UIEvent.POINTER_MOVE then
		if self.pointerPressed then
			self:procPointerMotion( ev )
		end

	elseif e == UIEvent.POINTER_UP then
		self.pointerPressed = false
	
	elseif e == UIEvent.TEXT_INPUT then
		if self.imeEditing then
			self:clearIMEState()
			self.cursor:insert( data.text )
		else
			self.cursor:insert( data.text )
		end

	elseif e == UIEvent.TEXT_EDIT then
		local text = data.text
		if text and #text > 0 then
			self.imeEditing = true
		else
			self:clearIMEState()
		end

	elseif e == UIEvent.FOCUS_IN then
		game:startTextInput()
		self.cursor:show()
		self.cursor:updatePos()

	elseif e == UIEvent.FOCUS_OUT then
		game:stopTextInput()
		self.cursor:hide()
		self:clearIMEState()
		self.pointerPressed = false

	end
end

function UITextEdit:clearIMEState()
	self.imeEditing = false
end

function  UITextEdit:onDestroy()
	UITextEdit.__super.onDestroy( self )
end

function UITextEdit:procKeyDown( ev )
	local key = ev.data.key
	local modifiers = ev.data.modifiers
	local cursor = self.cursor
	selecting = modifiers.shift and true or false
	if key == 'up' then
		if modifiers.ctrl then
			cursor:moveToStart( selecting )
		else
			cursor:moveY( -1, selecting )
		end
	elseif key == 'down' then
		if modifiers.ctrl then
			cursor:moveToEnd( selecting )
		else
			cursor:moveY( 1, selecting )
		end
	elseif key == 'left' then
		if modifiers.ctrl then
			cursor:moveToLineStart( selecting )
		else
			cursor:moveX( -1, selecting )
		end
	elseif key == 'right' then
		if modifiers.ctrl then
			cursor:moveToLineEnd( selecting )
		else
			cursor:moveX( 1, selecting )
		end
	elseif key == 'home' then
		if modifiers.ctrl then
			cursor:moveToStart( selecting )
		else
			cursor:moveToLineStart( selecting )
		end
	elseif key == 'end' then
		if modifiers.ctrl then
			cursor:moveToEnd( selecting )
		else
			cursor:moveToLineEnd( selecting )
		end

	elseif key == 'delete' then
		cursor:delete( 1 ) --forward

	elseif key == 'backspace' then
		cursor:delete( -1 ) --backward

	elseif key == 'enter' or key == 'return' then
		cursor:insert( '\n' )
	
	elseif key == 'a' and modifiers.ctrl then --copy
		self.cursor:selectAll()

	elseif key == 'c' and modifiers.ctrl then --copy
		local text = self:getSelectedText()
		if text then
			game:setClipboard( text )
		end

	elseif key == 'x' and modifiers.ctrl then --cut
		local text = self:getSelectedText()
		if text then
			game:setClipboard( text )
			cursor:delete()
		end

	elseif key == 'v' and modifiers.ctrl then --paste
		local text = game:getClipboard()
		if text then
			cursor:insert( text )
		end

	elseif key == 'z' and modifiers.ctrl then --undo
		self:undo()

	end
end

function UITextEdit:procKeyUp( ev )
	local key = ev.key
end


function UITextEdit:procPointerMotion( ev )
	local x, y = ev.data.x, ev.data.y
	local box = self.textBox.box
	x, y = box:worldToModel( x, y )
	local upos, off = self:hitCharOrLine( x, y )
	if upos then
		local selecting = ev.type == UIEvent.POINTER_MOVE
		if off > 0 then
			self.cursor:_set( upos, selecting )
		else
			self.cursor:_set( upos - 1, selecting )
		end
	end
end

function UITextEdit:getContentData( key, role )
	if key == 'text' then
		return self.text:get()
	end
end

---
function UITextEdit:getMoaiTextBox()
	return self.textBox.box
end


function UITextEdit:setText( t )
	self.text:set( t )
	if self.cursor then
		self.cursor:reset()
	end
	self:invalidateContent()
end

function UITextEdit:getTextObject()
	return self.text
end

function UITextEdit:getText()
	return self.text:get()
end

function UITextEdit:getTextLength()
	return self.text:len()
end

function UITextEdit:getSelectedText()
	local s, e = self:getSelection()
	return self.text:sub( s + 1, e )
end

function UITextEdit:getSelection()
	return self.cursor:getSelection()
end

function UITextEdit:calcUTF8Pos( bytepos )
	return utf8.pos( self.text, bytepos )
end

function UITextEdit:calcBytePos( upos )
	return utf8.bytepos( self.text, upos )
end

function UITextEdit:getLineTextRange( line )
	local box = self:getMoaiTextBox()
	local s, e = box:getLineStringIndex( line )
	local us, ue
	local t = self.text
	if s then
		us = t:pos( s )
	end
	if e then
		ue = t:pos( e )
	end
	return us, ue
end

function UITextEdit:hitCharOrLine( x, y )
	local box = self.textBox.box
	local upos, off = self:hitChar( x, y )
	if upos then return upos, off end

	local line = self:hitLine( y )

	if not line then 
		local x0,y0,x1,y1 = box:getTextBounds()
		if x0 then
			if y < y0 then
				upos = 0 
				off = -1
			elseif y > y1 then
				upos = self.text:len()
				off = 1
			end
			return upos, off
		else
			return 0, -1
		end
	end

	local t = self.text
	local s, e = box:getLineStringIndex( line )
	if s == e then --empty line
		upos = t:pos( s )
		off = -1
	elseif s > e then --last empty line
		upos = t:len() + 1
		off = -1
	else
		local x0,y0,x1,y1 = box:getTextBounds( s, e-s )
		if x <= x0 then
			if line > 1 then
				upos = t:pos( s )
				if not _isLineEnd( t, upos - 1 ) then
					upos = upos - 1
				end
				off = -1
			else
				upos = 0
				off = -1
			end
		else
			upos = t:pos( e )
			if not _isLineEnd( t, upos - 1 ) then
				upos = upos - 1
			end
			off = 1
		end
	end

	return upos, off
end

function UITextEdit:getDefaultLineHeight()
	local box = self:getMoaiTextBox()
	return box:getStyle():getSize()
end

function UITextEdit:getLineHeight( l, noDefault )
	local box = self:getMoaiTextBox()
	local height = box:getLineHeight( l )
	if height and height > 0 then return height end
	if not noDefault then
		return box:getStyle():getSize()
	end
	return 0
end

function UITextEdit:hitLine( a, b )
	local box = self:getMoaiTextBox()
	if b then
		local x, y = a, b
		return box:hitLine( x, y )
	elseif a then
		local y = a
		return box:hitLine( y )
	end
end

function UITextEdit:hitChar( x, y )
	local box = self:getMoaiTextBox()
	local bpos = box:hitChar( x, y )
	if not bpos then return nil end

	local upos = self.text:pos( bpos )
	local x0,y0,x1,y1 = box:getTextBounds( bpos, 1 )
	--left/right?
	local w = x1 - x0
	if w == 0 then
		return upos, 0
	end
	local dx = x - (x0 + x1)/2
	local k = dx/w
	if x - x0 < x1 - x then
		return upos, k
	else
		return upos, k
	end
end

function UITextEdit:updateSelection()
	local s, e = self.cursor:getSelection()
	local size = s and e and ( e - s ) or 0
	if size > 0 then
		self.selectionRenderer:update( s, e )
		self.selectionRenderer:show()
	else
		self.selectionRenderer:hide()
	end
end

function UITextEdit:undo()

end