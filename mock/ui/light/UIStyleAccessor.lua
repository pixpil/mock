module 'mock'

local insert = table.insert
local format = string.format
---------------------------------------------------------------------
-- local WidgetClassNameCache = {}
-- local function getWidgetClassCache( clas )
-- 	local list = WidgetClassNameCache[ clas ] 
-- 	if not list then
-- 		list = {}
-- 		local c = clas
-- 		while true do
-- 			local name = c.__name
-- 			insert( list, 1, name )
-- 			c = c.__super
-- 			if c == UIWidget or ( not c ) then break end
-- 		end
-- 		insert( list, 1, 'UIWidget' )
-- 		WidgetClassNameCache[ clas ] = list
-- 	end
-- 	return list
-- end

local widgetAbbrIndex = 0
local widgetClassAbbr = {}

local function getWidgetClassAbbr( classname )
	-- return string.format( '{%s}', classname )
	local abbr = widgetClassAbbr[ classname ]
	if not abbr then
		widgetAbbrIndex = widgetAbbrIndex+1
		abbr = format( '{%x}', widgetAbbrIndex )
		widgetClassAbbr[ classname ] = abbr
	end
	return abbr
end



local featureAbbrIndex = 0
local widgetFeatureAbbr = {}

local function getWidgetFeatureAbbr( feature )
	-- return string.format( '{%s}', feature )
	local abbr = widgetFeatureAbbr[ feature ]
	if not abbr then
		featureAbbrIndex = featureAbbrIndex+1
		abbr = string.format( '{%x}', featureAbbrIndex )
		widgetFeatureAbbr[ feature ] = abbr
	end
	return abbr
end


local WidgetClassIDCache = {}
local function getWidgetClassID( clas )
	assert( isSubclass( clas, UIWidget ), 'wtf?' )
	local id = WidgetClassIDCache[ clas.__name ] 
	if not id then
		id = getWidgetClassAbbr( clas.__name )
		local c = clas
		while true do
			c = c.__super
			if c == UIWidgetBase or not c then break end
			id = getWidgetClassAbbr( c.__name ) .. id
		end
		id = '{' .. id .. '}'
		WidgetClassIDCache[ clas.__name ] = id
	end
	return id
end


_M._getWidgetClassAbbr = getWidgetClassAbbr
_M._getWidgetFeatureAbbr = getWidgetFeatureAbbr
_M._getWidgetClassID = getWidgetClassID
--------------------------------------------------------------------
CLASS: UIStyleAccessor ()
	:MODEL{}

function UIStyleAccessor:__init( owner )
	self.owner   = owner
	self.state   = false

	self.featureSet = {}
	self.needUpdate = true

	local clas = owner.__class
	self.widgetClassID = getWidgetClassID( clas )

	self.queryList      = false
	self.fullQuery      = false

	self.dataList = false	
	self.cachedData = false

	self.cacheMT =  {
		__index = function( t, k )
			local dataList = self.dataList
			if not dataList then return nil end
			local v
			local locale = getActiveLocale()
			local localeKey = k .. '@'.. locale
			for i = 1, #dataList do
				local block = dataList[ i ]
				--try locale value
				v = block[ localeKey ]
				if v ~= nil then break end
				v = block[ k ]
				if v ~= nil then break end
			end
			t[ k ] = v or false
			return v
		end
	}

	self.cachedFXData   = false

end

function UIStyleAccessor:setState( s )
	self.state = s
	self:markDirty()
end

function UIStyleAccessor:setFeature( f, bvalue )
	f = f:lower()
	bvalue = bvalue or nil
	local featureSet = self.featureSet
	local b0 = featureSet[ f ]
	if b0 == bvalue then return end
	featureSet[ f ] = bvalue
	self:markDirty()
end

function UIStyleAccessor:hasFeature( f )
	f = f:lower()
	return self.featureSet[ f ] and true
end

function UIStyleAccessor:setFeatures( f )
	local t = {}
	if f then
		for i, k in ipairs( f ) do
			k = k:trim():lower()
			if k ~= '' then
				t[ k ] = true
			end
		end
	end
	self.featureSet = t
	self:markDirty()
end

function UIStyleAccessor:getFeatures()
	local t = {}
	return table.keys( self.featureSet )
end

function UIStyleAccessor:markDirty()
	self.cachedData     = false
	self.cachedFXData   = false
	self.queryList      = false
	local owner = self.owner
	owner.styleModified = true
	owner:invalidateVisual()
end

function UIStyleAccessor:getStyleSheet()
	return self.owner:getStyleSheetObject() or getBaseStyleSheet()
end

function UIStyleAccessor:update()
	if self.cachedData then return end
	local styleSheet = self:getStyleSheet()
	self.dataList = styleSheet:query( self )
	self.cachedData = setmetatable( {}, self.cacheMT )
	self.cachedFXData   = false
end

function UIStyleAccessor:getQueryList()
	local list, fullQuery, hasFeatureQuery = self.queryList, self.fullQuery, self.hasFeatureQuery
	if list then return list, fullQuery end
	return self:buildQueryList()
end

function UIStyleAccessor:buildQueryList()
	local owner = self.owner
	local sheet = self:getStyleSheet()
	--update suffix
	local features = table.keys( self.featureSet )
	table.sort( features )
	local state = self.state
	local statePart = state and ( ':'..state ) or ''
	local featurePart = ''
	for i, f in ipairs( features ) do
		featurePart = featurePart.. '.'..getWidgetFeatureAbbr( f )
	end

	local hasFeatureQuery = featurePart ~= ''

	local suffix = statePart..featurePart
	local prefix = self.widgetClassID

	local tagName = self.owner.__class.__name
	self.localFullQuery = tagName .. suffix

	local baseList = self.localQueryBaseList
	local localQueryName = prefix .. suffix
	local localQuery = { tagName, localQueryName, 1 }
	local fullQuery = self.localFullQuery
	local queryList = {}

	local maxPathSize = sheet.maxPathSize
	local parent = owner:getParentWidget()

	-- local visited
	if parent and not( parent:isRootWidget() ) then
		local pacc = parent.styleAcc
		local plist, pFullQuery = pacc:getQueryList()
		for i, parentQuery in ipairs( plist ) do
			local query = parentQuery[2] .. '>' .. localQueryName
			local level = parentQuery[3]
			insert( queryList, { tagName, query, level + 1 } )
		end
		fullQuery =  pFullQuery .. '>'.. fullQuery
		if pacc.hasFeatureQuery then hasFeatureQuery = true end
	else
		queryList = { localQuery }
	end

	self.queryList = queryList
	self.fullQuery = fullQuery
	self.hasFeatureQuery = hasFeatureQuery
	return queryList, fullQuery, hasFeatureQuery
end

function UIStyleAccessor:get( key, default )
	local v = self.cachedData[ key ]
	if v == nil then return default end
	return v
end

function UIStyleAccessor:hasFX()
	local fxData = self.cachedFXData
	if not fxData then
		self:updateFXDataCache()
	end
	return self.cachedFXData ~= 'none'
end

function UIStyleAccessor:updateFXDataCache()
	local data = self.cachedData
	local fxData = false
	for k, v in pairs( data ) do
		local fxname = k:match( 'fx_(%w+)' )
		if fxname then
			if not fxData then
				fxData = {}
			end
			fxData[ fxname ] = v
		end
	end
	if fxData then
		self.cachedFXData = fxData
	else
		self.cachedFXData = 'none'
	end
end

local FXKeyCache = TwoKeyTable()
FXKeyCache:setAffirmFunction( function( a, b )
		return a .. '_' .. b 
	end 
)

function UIStyleAccessor:getFX( fxname, key, default )
	local data = self.cachedFXData
	if ( not data ) or data == 'none' then return nil end
	local n = FXKeyCache:affirm( fxname, key )
	local v = data[ n ]
	if v == nil then return default end
	return v
end

function UIStyleAccessor:has( key )
	return self.cachedData[ key ] ~= nil
end

function UIStyleAccessor:getColor( key, default )
	local data, tt = self:expandCachedData( key )
	if tt == 'string' then
		if data == 'none' then
			return 0,0,0,0
		end
		if data:startwith( '#' ) then
			return hexcolor( data )
		else
			local hex = getNamedColorHex( data )
			if hex then
				return hexcolor( hex )
			end
		end
	elseif tt == 'table' then
		local r,g,b,a = unpack( data )
		return r or 1, g or 1, b or 1, a or 1
	end

	if default then
		return unpack( default )
	else
		return nil
	end
end

function UIStyleAccessor:getSize( prefix, default )
	local data = self.cachedData
	--try 'size'
	local w, h
	local tsize = data[ prefix ..'_size' ]
	if tsize then
		w, h = unpack( tsize )
	else
		w = data[ prefix .. '_width' ]
		h = data[ prefix .. '_height' ]
	end
	if default then
		local w0, h0 = unpack( default )
		return tonumber(w) or tonumber(w0), tonumber(h) or tonumber(h0)
	else
		return tonumber(w), tonumber(h)
	end
end

function UIStyleAccessor:getVec2( key, default )
	local data, tt = self:expandCachedData( key )
	if tt == 'number' then
		return data, data
	elseif tt == 'table' then
		local a,b = unpack( data )
		return a or 0, b or 0
	end
	if default then
		return unpack( default )
	else
		return nil
	end
end

function UIStyleAccessor:getVec3( key, default )
	local data, tt = self:expandCachedData( key )
	if tt == 'number' then
		return data, data, data
	elseif tt == 'table' then
		local a,b,c,d = unpack( data )
		return a or 0, b or 0, c or 0
	end
	if default then
		return unpack( default )
	else
		return nil
	end
end

function UIStyleAccessor:getVec4( key, default )
	local data, tt = self:expandCachedData( key )
	if tt == 'number' then
		return data, data, data, data
	elseif tt == 'table' then
		local a,b,c,d = unpack( data )
		return a or 0, b or 0, c or 0, d or 0
	end
	if default then
		return unpack( default )
	else
		return nil
	end
end

function UIStyleAccessor:getString( key, default )
	local data, tt = self:expandCachedData( key )
	return tt == 'string' and data or default
end

function UIStyleAccessor:getFloat( key, default )
	return self:getNumber( key, default )
end

function UIStyleAccessor:getInt( key, default )
	local n = self:getNumber( key, default )
	return n and math.floor( n )
end

function UIStyleAccessor:getNumber( key, default )
	local data, tt = self:expandCachedData( key )
	return tt == 'number' and data or default
end

function UIStyleAccessor:expandCachedData( key )
	local data = self.cachedData[ key ]
	local tt = type( data )
	if tt == 'table' and data.tag == 'localized' then
		local locale = getActiveLocale()
		local inner = data.data
		data = inner[locale]
		if data == nil then
			data = inner[ 'default' ]
		end
		tt = type(data)
	end
	return data, tt
end

function UIStyleAccessor:getBoolean( key, default )
	local data, tt = self:expandCachedData( key )
	if tt == 'boolean' then
		return data
	else
		return default
	end
end

function UIStyleAccessor:getAsset( key, default )
	local data, tt = self:expandCachedData( key )
	local owner = self.owner

	if tt == 'table' then
		if data.tag == 'asset' then return data.asset end
		if data.tag == 'object' then return data.object end

	elseif tt == 'string' then
		return data
		
	end
	return default
end

function UIStyleAccessor:getBox( key, default ) --l-t-r-b
	local data = self.cachedData[ key ]
	if data == nil then
		data = default
	end
	local tt = type( data )
	if tt == 'table' then
		return data
	elseif tt == 'number' then
		return { data, data, data, data }
	end
end
