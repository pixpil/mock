module 'mock'

local _styleNameCaches = {}
--------------------------------------------------------------------
CLASS: UIWidgetElement ( Entity )
	:MODEL{}

function UIWidgetElement:__init()
	self.FLAG_INTERNAL = true
	self.owner = false
	self.role  = false
	self.rect = false
	self.offset = { 0, 0 }
	self.zOrder = 0	
	self.styleBaseName = false
	self.styleNameCache = false
end

function UIWidgetElement:setStyleBaseName( n )
	self.styleBaseName = n
	local nameCache = _styleNameCaches[ n ]
	if not nameCache then
		nameCache = {}
		_styleNameCaches[ n ] = nameCache
	end
	self.styleNameCache = nameCache
end

function UIWidgetElement:makeStyleName( key )
	local base = self.styleBaseName
	if not key then return base end
	if not base then return key end
	-- return base ..'_' .. key
	local cache = self.styleNameCache
	local v = cache[ key ]
	if not v then
		v = base ..'_' .. key
		cache[ key ] = v
	end
	return v
end

function UIWidgetElement:getRenderer()
	return self.owner
end

function UIWidgetElement:getWidget()
	return self.owner:getWidget()
end

function UIWidgetElement:getRect()
	if self.rect then
		return unpack( self.rect )
	else
		return self:getDefaultRect()
	end
end

function UIWidgetElement:getDefaultRect()
	local role = self.role
	if role == 'content' then
		return self.owner:getInnerRect()
	else
		return self.owner:getRect()
	end
end

function UIWidgetElement:setRect( x0, y0, x1, y1 )
	assert( x0 and x0 and x1 and y1 )
	self.rect = { x0, y0, x1, y1 }
end

function UIWidgetElement:getContentRect()
	return self:getRect()
end

function UIWidgetElement:getOffset()
	return unpack( self.offset )
end

function UIWidgetElement:setOffset( x, y )
	self.offset = { x, y }
end

function UIWidgetElement:setZOrder( z )
	self.zOrder = z
end

function UIWidgetElement:getZOrder()
	return self.zOrder
end

function UIWidgetElement:getZOffset()
	return self.zOrder * 0.00001
end

function UIWidgetElement:updateStyle( widget, style )
	self:updateCommonStyle( widget, style )
	return self:onUpdateStyle( widget, style )
end

--------------------------------------------------------------------
function UIWidgetElement:updateCommonStyle( widget, style )
	--visible
	local vis = style:getBoolean( self:makeStyleName( 'visible' ), nil )
	if vis ~= nil then
		self:setVisible( vis )
	end
	--zorder?
	--scale?
end

--------------------------------------------------------------------
function UIWidgetElement:onUpdateStyle( widget, style )
end

function UIWidgetElement:onUpdateContent( widget, style )
end

function UIWidgetElement:onUpdateSize( widget, style )
end
