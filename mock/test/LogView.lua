module 'mock'

CLASS: LogViewManager ( GlobalManager )

function LogViewManager:__init()
	self.lineCount = 0
	self.lines = {}
	self.enabled = true
end

function LogViewManager:getKey()
	return 'LogViewManager'
end

function LogViewManager:init()
	connectGlobalSignalMethod( 'device.resize', self, 'onDeviceResize' )
	local layer = MOAITableViewLayer.new()
	local viewport = MOAIViewport.new ()
	layer:setViewport( viewport )
	layer:setClearMode( MOAILayer.CLEAR_NEVER )
	self.viewport = viewport

	local textBox = markRenderNode( MOAITextLabel.new() )
	textBox:setStyle( getFallbackTextStyle() )
	textBox:setYFlip( true )
	textBox:setAlignment( MOAITextLabel.LEFT_JUSTIFY, MOAITextLabel.BOTTOM_JUSTIFY )
	textBox:setRectLimits( false, false )

	self.textBox = textBox
	self.text = ''
	self.renderLayer = layer 

	layer:setRenderTable{ textBox }
	-- local renderCommand = createTableRenderLayer()
	-- renderCommand:setClearColor()
	-- renderCommand:setFrameBuffer( game:getMainFrameBuffer() )
	-- renderCommand:setRenderTable( {
	-- 	layer
	-- } )
	self.renderCommand = layer
	self.textBox:setText( '' )
	self:updateViewport()

	addLogListener( function( ... )
			return self:onLog( ... )
		end
	)

end

function LogViewManager:setEnabled( enabled )
	if mock.__nodebug then return end
	enabled = enabled~=false
	self.enabled = enabled
	if self.renderLayer then	self.renderLayer:setVisible( enabled ) end
end

function LogViewManager:isEnabled()
	return self.enabled
end

function LogViewManager:clear()
	self.lines = {}
	self.textBox:setText( '' )
end

function LogViewManager:updateViewport()
	local w, h = game:getDeviceResolution()
	self.viewport:setSize ( w,h )
	self.viewport:setScale ( w,h )
	self.textBox:setLoc( -w/2 + 5, -h/2 + 5 )
end

function LogViewManager:onDeviceResize( w, h )
	self:updateViewport()
end

function LogViewManager:getRenderLayer()
	return self.renderLayer
end

function LogViewManager:_insertLine( l, color )
	if color then
		l = string.format( '<c:%s>%s</>', color, l )
		l = l:gsub( '\t', '    ' )
	end

	local lines = self.lines
	table.insert( lines, l )
	local count = #lines
	if count > 10 then
		table.remove( lines, 1 )
	end
	self.textBox:setText( string.join( '\n', lines ) )
end

function LogViewManager:onLog( token, msg, text )
	if token:startwith( 'ERROR' ) then
		self:_insertLine( msg, 'f00' )
	-- elseif token:startwith( 'WARN' ) then
	-- 	self:_insertLine( msg, 'fa0' )
	end
end

--------------------------------------------------------------------
local _logViewManager = LogViewManager()
function getLogViewManager()
	return _logViewManager
end

function addLogOnScreen( msg, color )
	return _logViewManager:_insertLine( msg, color )
end
