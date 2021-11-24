module 'mock'

--------------------------------------------------------------------
CLASS: UIWidgetElementText ( UIWidgetElement )
	:MODEL{}

function UIWidgetElementText:__init()
	self.styleBaseName = ''
	self.text = ''
	self.label = false
	self.defaultAlignment  = 'left'
	self.defaultAlignmentV = 'center'
	self.role = 'content'
end

function UIWidgetElementText:setDefaultAlignment( h, v )
	self.defaultAlignment = h or 'left'
	self.defaultAlignmentV = h or 'center'
end

function UIWidgetElementText:setText( text )
	self.text = text
end

function UIWidgetElementText:onLoad()
	local label = self:attach( TextLabel() )
	self.label = label
	label:setText('')
	label:setVisible( false )
	label:setWordBreak( true )
	label.fitAlignment = false
end

function UIWidgetElementText:getTextLabel()
	return self.label
end

function UIWidgetElementText:onUpdateStyle( widget, style )
	local align          = style:get( self:makeStyleName( 'alignment' ), self.defaultAlignment )
	local alignV         = style:get( self:makeStyleName( 'alignment_vertical' ), self.defaultAlignmentV )
	local font           = style:getAsset( self:makeStyleName( 'font' ) )
	
	local fontSize       = style:get( self:makeStyleName( 'font_size' ), 12 )
	local fontScale      = style:get( self:makeStyleName( 'font_scale' ), 1 )
	local fontRawSize    = style:get( self:makeStyleName( 'font_raw_size' ) )

	local fontItalic     = style:get( self:makeStyleName( 'font_italic' ), false )
	
	local textScale      = { style:getVec2( self:makeStyleName( 'scale' ), { 1, 1 } ) }

	local color          = { style:getColor( self:makeStyleName( 'color' ), { 1,1,1,1 } ) }
	local alpha          = style:getNumber( self:makeStyleName( 'alpha' ) )
	local actualFontSize = fontSize * fontScale
	local styleSheet     = makeFontStyleSheetFromFont( font, actualFontSize, nil, fontRawSize )
	local wordBreak      = style:getBoolean( self:makeStyleName( 'word_break' ), true )
	local lineSpacing    = style:get( self:makeStyleName( 'line_spacing' ), 2 )
	local material       = style:getAsset( self:makeStyleName( 'material' ) )

	self:setOffset( style:getVec2( self:makeStyleName( 'offset' ), { 0, 0 } ) )

	local label = self.label
	label:setBlend( 'alpha' )
	label:setMaterial( material )
	label:setAlignment( align )
	label:setAlignmentV( alignV )
	label:setStyleSheet( AdHocAsset( styleSheet ) )
	local r,g,b,a = unpack( color )
	if alpha then a = alpha end
	label:setColor( r,g,b,a )
	label:setLineSpacing( lineSpacing )
	label:setWordBreak( wordBreak )
	label:setScl( unpack( textScale ) )
	label:setItalic( fontItalic )
	label:updateRect()

	self.currentTextStyleSheet = styleSheet

end

function UIWidgetElementText:onUpdateSize( widget, style )
	local label = self.label
	local ox, oy = self:getOffset()
	local x0, y0, x1, y1 = self:getRect()
	label:setRect( x0, y0 - 5, x1, y1 + 5 )
	label:setLocZ( self:getZOffset() )
	label:setPiv( -ox, oy, 0 )
	local prop = label:getMoaiProp()
	prop:forceUpdate()
end

function UIWidgetElementText:onUpdateContent( widget, style )
	local label = self.label
	local text = self.text
	if text then 
		label:setVisible( true )
		local translated = widget:parseAndTranslate( text )
		label:setText( translated )
	else
		label:setVisible( false )
	end
end

function UIWidgetElementText:getContentRect()
	if not self.text then
		return nil
	end
	return self.label:getTextBounds()
end


function UIWidgetElementText:testTextHeight( width )
	local label = self.label
	if not label then return 0 end
	local x0, y0, x1, y1 = label:getRect()
	width = width or ( x1 - x0 )
	label:setRect( 0, width, 0, 1000000 )
	local bx0, by0, bx1, by1 = label:getTextBounds()
	label:setRect( x0, y0, x1, y1 )
	local h1 = by1 - by0
	return h1
end

function UIWidgetElementText:testTextWidth( height )
	local label = self.label
	if not label then return 0 end
	local x0, y0, x1, y1 = label:getRect()
	height = height or ( y1 - y0 )
	label:setRect( 0, 1000000, 0, height )
	local bx0, by0, bx1, by1 = label:getTextBounds()
	local w1 = bx1 - bx0
	return w1
end