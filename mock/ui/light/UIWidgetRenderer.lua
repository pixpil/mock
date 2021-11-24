module 'mock'


--------------------------------------------------------------------
CLASS: UIWidgetRenderer ()
	:MODEL{}

function UIWidgetRenderer:__init()
	self.widget = false
	self.options = {}
	self.elements = {}
	self.initialized = false
	self.contentRect = false
end

function UIWidgetRenderer:addElement( element, name, role )
	assertInstanceOf( element, UIWidgetElement )
	table.insert( self.elements, element )
	element.owner = self

	element.role = role or 'content'

	if name then
		element:setName( name )
		element:setStyleBaseName( name )
	end
	if self.initialized then
		self.widget:addSubEntity( element )
		self.widget:invalidateVisual()
	end
	return element
end

function UIWidgetRenderer:getElement( name )
	for i, element in ipairs( self.elements ) do
		if element:getName() == name then return element end
	end
	return nil
end

function UIWidgetRenderer:setOptions( options )
	local options0 = self.options
	for k, v in pairs( options ) do
		options0[ k ] = v
	end
end

function UIWidgetRenderer:setOption( k, v )
	self.options[ k ] = v
end

function UIWidgetRenderer:getOption( k, default )
	local v = self.options[ k ]
	if v == nil then return default end
	return v
end

function UIWidgetRenderer:getWidget()
	return self.widget
end

function UIWidgetRenderer:getRect()
	return self.widget:getLocalRect()
end

function UIWidgetRenderer:getInnerRect()
	return self.widget:getInnerRect()
end

function UIWidgetRenderer:setContentRect( x0,y0,x1,y1 )
	if not x0 then self.contentRect = false end
	self.contentRect = {x0,y0,x1,y1}
end

function UIWidgetRenderer:getContentRect()
	if not self.contentRect then
		local r ={ self:calcElementsContentRect() }
		self.contentRect = r or { 0,0,0,0 }
	end
	return unpack( self.contentRect )
end

local min, max = math.min, math.max
function UIWidgetRenderer:getContentSize()
	local x0, y0, x1, y1 = self:getContentRect()
	if not x0 then
		return 0, 0
	end
	return max( x1-x0,0 ), max( y1-y0,0 )
end

function UIWidgetRenderer:calcElementsContentRect()
	local gx0,gy0,gx1,gy1 = false, false, false, false
	for i, element in ipairs( self.elements ) do
		if element.role == 'content' then
			local x0,y0,x1,y1 = element:getContentRect()
			if x0 then
				gx0 = gx0 and min( x0, gx0 ) or x0
				gy0 = gy0 and min( y0, gy0 ) or y0
				gx1 = gx1 and max( x1, gx1 ) or x1
				gy1 = gy1 and max( y1, gy1 ) or y1
			end
		end
	end
	if gx0 then
		return gx0, gy0, gx1, gy1
	else
		return nil
	end
end

function UIWidgetRenderer:init( widget )
	assert( not self.widget )
	self.widget = widget
	self:onInit( widget, self.options )
	for i, element in ipairs( self.elements ) do
		widget:addSubEntity( element )
	end
	self.initialized = true
end

function UIWidgetRenderer:onInit( widget )
end

function UIWidgetRenderer:update( widget, style, updateStyle, updateContent )
	local elements = self.elements
	if updateContent then
		self:onUpdateContent( widget, style )
		for i, element in ipairs( elements ) do
			element:onUpdateContent( widget, style )
		end
	end

	if updateStyle then
		self:updateCommonStyle( widget, style )
		self:onUpdateStyle( widget, style )
		for i, element in ipairs( elements ) do
			element:updateStyle( widget, style )
		end
	end

	self:onUpdateSize( widget, style )
	for i, element in ipairs( elements ) do
		element:onUpdateSize( widget, style )
	end
	self.contentRect = false

end

function UIWidgetRenderer:destroy( widget )
	self:onDestroy( widget )
	for i, element in ipairs( self.elements ) do
		--TODO: pool elements
		element:destroyAllNow()
	end
	self.elements = {}
	self.initialized = false
end

function UIWidgetRenderer:updateCommonStyle( widget, style )
	if style:has( 'color' ) then
		local color = { style:getColor( 'color', { 1,1,1,1 } ) }
		local alpha = style:getNumber( 'alpha', nil )
		if alpha then
			color[ 4 ] = alpha
		end
		widget:setColor( unpack( color ) )
	elseif style:has( 'alpha' ) then
		local alpha = style:getNumber( 'alpha', 1 )
		widget:setAlpha( alpha )
	end
end

function UIWidgetRenderer:onUpdateContent( widget, style )
end

function UIWidgetRenderer:onUpdateSize( widget, style )
end

function UIWidgetRenderer:onUpdateStyle( widget, style )
end

function UIWidgetRenderer:onDestroy( widget )
end
