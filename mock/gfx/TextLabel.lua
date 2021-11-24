module 'mock'

local getBuiltinShader          = MOAIShaderMgr. getShader
local DECK2D_TEX_ONLY_SHADER    = MOAIShaderMgr. DECK2D_TEX_ONLY_SHADER
local DECK2D_SHADER             = MOAIShaderMgr. DECK2D_SHADER
local FONT_SHADER               = MOAIShaderMgr. FONT_SHADER


local OVERRUN_MOVE_WORD = MOAITextLabel.OVERRUN_MOVE_WORD
local OVERRUN_SPLIT_WORD = MOAITextLabel.OVERRUN_SPLIT_WORD
local OVERRUN_TRUNCATE_WORD = MOAITextLabel.OVERRUN_TRUNCATE_WORD
local OVERRUN_ABORT_LAYOUT = MOAITextLabel.OVERRUN_ABORT_LAYOUT


CLASS: TextLabel ( RenderComponent )
	:MODEL{
		'----';
		Field 'text'          :string()  :set('setText') :widget('textbox');
		'----';
		Field 'stylesheet'    :asset_pre('stylesheet') :getset( 'StyleSheet');
		Field 'defaultStyle'  :string()  :label('default') :set('setDefaultStyle') :selection( 'getStyleNames' );
		'----';
		Field 'italic'        :number() :set( 'setItalic' );
		'----';
		Field 'rectLimit'     :boolean() :set( 'setRectLimit' ); --TODO:update this
		Field 'size'          :type('vec2') :getset( 'Size' );
		Field 'alignment'     :enum( EnumTextAlignment )  :set('setAlignment')  :label('align H');
		Field 'alignmentV'    :enum( EnumTextAlignmentV ) :set('setAlignmentV') :label('align V');
		Field 'lineSpacing'   :set('setLineSpacing') :label('line spacing');
		Field 'wordBreak'     :boolean()  :set('setWordBreak') :label('break word');
	}

function TextLabel:__init(  )
	local box = markRenderNode( MOAITextBox.new() )
	box:setStyle( getFallbackTextStyle() )
	-- box:setScl( 1,-1,1 )
	-- box:setAutoFlip( true )
	box:setYFlip( true )
	self.box  = box
	self.text = 'Sample Text'
	self.alignment  = 'left'
	self.alignmentV = 'top'
	self:setSize( 100, 100 )
	self.defaultStyle = 'default'
	self.styleSheet = false
	self.rectLimit = true
	self:useDeckShader()	
	self.wordBreak = false
	self.lineSpacing = 0
	self.fitAlignment = true
	self.italic = 0.0

	self.prop = box
end

function TextLabel:onAttach( entity )
	entity:_attachProp( self.box, 'render' )
end

function TextLabel:onDetach( entity )
	entity:_detachProp( self.box )
	self.box:stop()
end

function TextLabel:getMoaiProp()
	return self.box
end

--------------------------------------------------------------------
function TextLabel:setBlend( b )
	self.blend = b
	setPropBlend( self.box, b )
end

function TextLabel:setWordBreak( wbreak )
	-- self.wordBreak = wbreak
	-- self.box:setWordBreak( wbreak and MOAITextLabel.WORD_BREAK_CHAR or MOAITextLabel.WORD_BREAK_NONE )
	if wbreak then
		self.box:setOverrunRules( OVERRUN_SPLIT_WORD, OVERRUN_SPLIT_WORD )
	else
		self.box:setOverrunRules( OVERRUN_ABORT_LAYOUT, OVERRUN_MOVE_WORD )
	end
end

function TextLabel:setOverrunRules( first, common )
	self.box:setOverrunRules( first, common )
end

function TextLabel:setItalic( italic )
	local tt = type( italic )
	if tt == 'number' then
		self.italic = italic
		self.box:setItalic( italic )
	else
		self.italic = italic and 0.25 or 0
		self.box:setItalic( self.italic )
	end
end

function TextLabel:setLineSpacing( spacing )
	self.lineSpacing = spacing
	self.box:setLineSpacing( spacing or 0 )
end

local defaultShader = MOAIShaderMgr.getShader( MOAIShaderMgr.DECK2D_SHADER )
function TextLabel:setShader( shaderPath )
	self.shader = shaderPath	
	-- if shaderPath then
	-- 	local shader = mock.loadAsset( shaderPath )
	-- 	if shader then
	-- 		local moaiShader = shader:getMoaiShader()
	-- 		return self.prop:setShader( moaiShader )
	-- 	end
	-- end
	-- self.prop:setShader( defaultShader )
end

--------------------------------------------------------------------
function TextLabel:setDefaultStyle( styleName )
	self.defaultStyle = styleName or 'default'
	self:updateStyles()
end

function TextLabel:setStyleSheet( sheetPath ) 
	local box = self.box
	self.styleSheetPath = sheetPath
	self.styleSheet = loadAsset( sheetPath )
	self:updateStyles()
end

function TextLabel:updateStyles()
	if self.styleSheet then
		self.styleSheet:applyToTextBox( self.box, self.defaultStyle )	
	end
end

function TextLabel:getStyleSheet()
	return self.styleSheetPath
end

function TextLabel:getStyleNames()
	local sheet = mock.loadAsset( self.styleSheetPath )
	if not sheet then return nil end
	local result = {}
	for i, name in pairs( sheet:getStyleNames() ) do
		table.insert( result, { name, name } )
	end
	return result
end

function TextLabel:setRectLimit( limit )
	self.rectLimit = limit
	self:updateRect()
end

function TextLabel:setRect( x0, y0, x1, y1 )
	local w = x1 - x0
	local h = y1 - y0
	self:setLoc( x0, y0 )
	self:setSize( w, h )
end

function TextLabel:getSize()
	return self.w, self.h
end

function TextLabel:setSize( w, h )
	if w == false then
		self.rectLimit = false
	else
		self.w = w or 100
		self.h = h or 100
	end
	self:updateRect()
end

function TextLabel:updateRect()
	if not self.rectLimit then
		self.box:setRectLimits( false, false )
	else
		local w, h = self.w, self.h
		local sx, sy = self.box:getScl()
		w = w * sx
		h = h * sy
		if self.fitAlignment then
			local alignH = self.alignment
			local alignV = self.alignmentV
			local x,y
			if alignH == 'left' then
				x = 0
			elseif alignH == 'center' then
				x = -w/2
			else --'right'
				x = -w
			end
			if alignV == 'top' then
				y = -h
			elseif alignV == 'center' then
				y = -h/2
			else --'right'
				y = 0
			end
			self.box:setRect( x, y, x + w, y + h )
		else
			self.box:setRect( 0,0,w,h )
		end
	end
	self.box:setString( self.text ) --trigger layout
end
	
function TextLabel:setText( text )
	text = tostring( text )
	self.text = text
	self.box:setString( text )
end

function TextLabel:setTextf( pattern, ... )
	return self:setText( string.format( pattern, ... ) )
end

function TextLabel:getText( )
	return self.text
end

function TextLabel:appendText( text )
	return self.text .. text
end

function TextLabel:appendTextf( pattern, ... )
	return self:appendText( string.format( pattern, ... ) )
end

--------------------------------------------------------------------
local textAlignments = {
	center    = MOAITextLabel.CENTER_JUSTIFY,
	left      = MOAITextLabel.LEFT_JUSTIFY,
	right     = MOAITextLabel.RIGHT_JUSTIFY,
	top       = MOAITextLabel.TOP_JUSTIFY,
	bottom    = MOAITextLabel.BOTTOM_JUSTIFY,
	baseline  = MOAITextLabel.BASELINE_JUSTIFY,
}

function TextLabel:setAlignment( align )
	align = align or 'left'
	self.alignment = align
	return self:_updateAlignment()
end

function TextLabel:setAlignmentV( align )
	align = align or 'top'	 
	self.alignmentV = align
	return self:_updateAlignment()
end

function TextLabel:_updateAlignment()	
	self.box:setAlignment( textAlignments[ self.alignment ], textAlignments[ self.alignmentV ] )
	return self:updateRect()
end

function TextLabel:getBounds()
	return self.box:getBounds()	
end

function TextLabel:getTextBounds( ... )
	return self.box:getTextBounds( ... )	
end

function TextLabel:getLineBounds( line )
	return self.box:getLineBounds( line )
end

function TextLabel:getLineCount()
	return self.box:getLineCount()
end

function TextLabel:testTextSize( ... )
	return self.box:testTextSize( ... )
end

function TextLabel:getTextSize( ... )
	local x0,y0,x1,y1 = self:getTextBounds( ... )
	if x0 then
		return x1-x0, y1-y0
	else
		return 0,0
	end
end

function TextLabel:drawBounds()
	if not self._entity then return end 
	GIIHelper.setVertexTransform( self._entity:getProp() )
	if self.rectLimit then
		local x1,y1, x2,y2 = self.box:getRect()	
		MOAIDraw.drawRect( x1,y1,x2,y2 )
	else
		local x1,y1, x2,y2 = self.box:getTextBounds()	
		MOAIDraw.drawRect( x1,y1,x2,y2 )
	end
end

function TextLabel:getPickingProp()
	return self.box
end

function TextLabel:inside( x, y, z, pad )
	return self.box:inside( x,y,z, pad )	
end

local FontShaderMaterialBatch = MOAIMaterialBatch.new()
FontShaderMaterialBatch:setShader( 1, getBuiltinShader( FONT_SHADER ))
local DeckShaderMaterialBatch = MOAIMaterialBatch.new()
DeckShaderMaterialBatch:setShader( 1, getBuiltinShader( DECK2D_SHADER ))

function TextLabel:useFontShader()
	self.box:setParentMaterialBatch( FontShaderMaterialBatch )
	-- self.box:setShader( getBuiltinShader(FONT_SHADER) )
end

function TextLabel:useDeckShader()
	-- self.box:setShader( getBuiltinShader(DECK2D_SHADER) )
	self.box:setParentMaterialBatch( DeckShaderMaterialBatch )
end

function TextLabel:more()
	return self.box:more()
end

function TextLabel:nextPage( reveal )
	return self.box:nextPage( reveal )
end

function TextLabel:setSpeed( spd )
	self.box:setSpeed( spd )
end

function TextLabel:spool( spooled )
	return self.box:spool( spooled )
end

function TextLabel:stopSpool()
	return self.box:stop()
end

--------------------------------------------------------------------
local defaultShader = MOAIShaderMgr.getShader( MOAIShaderMgr.DECK2D_SHADER )
function TextLabel:setShader( shaderPath )
	self.shader = shaderPath	
	if shaderPath then
		local shader = mock.loadAsset( shaderPath )
		if shader then
			local moaiShader = shader:getMoaiShader()
			return self.box:setShader( moaiShader )
		end
	end
	self.box:setShader( defaultShader )
end

function TextLabel:applyMaterial( material )
	material:applyToMoaiProp( self.box )
	-- if not material:getShader() then
	-- 	self.box:setShader( defaultShader )
	-- end
end

--------------------------------------------------------------------
--Editor
function TextLabel:onEditorInit()
	local sheet = getDefaultStyleSheet()
	self:setStyleSheet( sheet )
end


registerComponent( 'TextLabel', TextLabel )
registerEntityWithComponent( 'TextLabel', TextLabel )
wrapWithMoaiPropMethods( TextLabel, 'box' )
