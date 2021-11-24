module 'mock'

--------------------------------------------------------------------
CLASS: DataSheetAccessor ()
	:MODEL{}

function DataSheetAccessor:__init( data, meta, assetPath )
	self._data = data or {}
	self._meta = meta or {}
	self.assetPath = assetPath
end

function DataSheetAccessor:getData()
	return self._data
end

function DataSheetAccessor:getMeta()
	return self._meta
end

function DataSheetAccessor:getPath()
	return self.assetPath
end

function DataSheetAccessor:translateAs( locale, source, fallback )
	local res,valid = translateForAssetAs( locale, self.assetPath, source, fallback )
	return res,valid
end

function DataSheetAccessor:translate( source, fallback )
	return translateForAsset( self.assetPath, source, fallback )
end


--------------------------------------------------------------------
CLASS: DataSheetDictAccessor ( DataSheetAccessor )
	:MODEL{}
	
function DataSheetDictAccessor:get( key, default )
	local v = self._data[ key ]
	if v == nil then return default end
	return v
end

function DataSheetDictAccessor:getTranslated( key, default )
	local v0 = self._data[ key ]
	if v0 == nil then return default or key end
	local translatedValue, valid = self:translate( key )
	return translatedValue or v0 or key, valid
end

function DataSheetDictAccessor:getKeySequence()
	local meta = self:getMeta()
	return meta and meta[ 'sequence' ]
end

function DataSheetDictAccessor:getRows()
	if self._rows then return self._rows end
	local data = self._data
	local seq = self:getKeySequence()
	local row = {}
	if seq then
		for i, key in ipairs( seq ) do
			row[ i ] = { key, data[ key ] }
		end
		self._rows = row
	else
		for key, value in pairs( data ) do
			table.insert( row, { key, value } )
		end
		self._rows = row
	end
	return row
end

--------------------------------------------------------------------
CLASS: DataSheetListAccessor ( DataSheetAccessor )
	:MODEL{}

function DataSheetListAccessor:__init()
	self._idMap = false
	self._idKey = false
	self:_affirmIdMap()
	self.rowAccessors = {}
end

function DataSheetListAccessor:_affirmIdMap()
	local map = self._idMap
	local idxMap = self._idToIndex
	if not map then
		map = {}
		idxMap = {}
		self._idMap = map
		self._idToIndex = idxMap
		local keys = self._meta[ 'keys' ]
		if table.index( keys, 'id' ) then
			self._idKey = 'id'
			for i, row in self:rows() do
				local id = row[ 'id' ]
				if id then
					map[ id ] = row
					idxMap[ id ] = i
				end
			end
		end
	end
	return map, idxMap
end

function DataSheetListAccessor:getKey( idx )
	local keys = self._meta[ 'keys' ]
	return keys[ idx ]
end

function DataSheetListAccessor:getRow( idx )
	return self._data[ idx ]
end

function DataSheetListAccessor:getRowById( id )
	local map = self:_affirmIdMap()
	return map[ id ]
end

function DataSheetListAccessor:getByIndex( idx, key, default )
	local row = self:getRow( idx )
	local v = row and row[ key ]
	if v == nil then return default end
	return v
end

function DataSheetListAccessor:getById( id, key, default )
	local row = self:getRowById( id )
	local v = row and row[ key ]
	if v == nil then return default end
	return v
end

function DataSheetListAccessor:_getByRowTranslated( row, key )
	return self:_getByRowTranslatedAs( nil, row, key )
end

function DataSheetListAccessor:_getByRowTranslatedAs( locale, row, key )
	local idKey = self._idKey
	if idKey then
		local idbase = row[ idKey ]
		local iid = string.format( '%s::%s', key, idbase )
		local translatedValue, valid = self:translateAs( locale, iid )
		if translatedValue then
			return translatedValue, valid
		end
		return row[ key ], false
	else
		local v = row[ key ]
		if v then
			local translated, valid = self:translateAs( locale, v )
			if translated then
				return translated, valid
			end
			return v, false
		end
		return nil
	end
end

function DataSheetListAccessor:getByIndexTranslated( idx, key )
	local row = self:getRow( idx )
	if not row then return nil end
	return self:_getByRowTranslated( row, key )
end

function DataSheetListAccessor:getByIdTranslated( id, key )
	local row = self:getRowById( id )
	if not row then return nil end
	return self:_getByRowTranslated( row, key )
end


function DataSheetListAccessor:getByIndexTranslatedAs( locale, idx, key )
	local row = self:getRow( idx )
	if not row then return nil end
	return self:_getByRowTranslatedAs( locale, row, key )
end

function DataSheetListAccessor:getByIdTranslatedAs( locale, id, key )
	local row = self:getRowById( id )
	if not row then return nil end
	return self:_getByRowTranslatedAs( locale, row, key )
end

function DataSheetListAccessor:findRow( key, value )
	for i, row in self:rows() do
		local v = row[ key ]
		if v~=nil and key:match( value ) then
			return row
		end
	end
	return nil
end

function DataSheetListAccessor:getRowCount()
	return #self._data
end

function DataSheetListAccessor:rows()
	return ipairs( self._data )
end

function DataSheetListAccessor:getRowAccessor( index )
	local acc = self.rowAccessors[ index ]
	local acc = DataSheetListRowAccessor( self, index )
	return acc
end

function DataSheetListAccessor:getRowAccessorById( id )
	local map, idxMap = self:_affirmIdMap()
	local index = idxMap[ id ]
	return index and self:getRowAccessor( index )
end

--------------------------------------------------------------------
CLASS: DataSheetListRowAccessor ()
function DataSheetListRowAccessor:__init( sheet, index )
	self._sheet = sheet
	self._index = index
end

function DataSheetListRowAccessor:getIndex()
	return self._index
end

function DataSheetListRowAccessor:getSheet()
	return self._sheet
end

function DataSheetListRowAccessor:get( key, default )
	return self._sheet:getByIndex( self._index, key, default )
end

function DataSheetListRowAccessor:getTranslated( key, default )
	return self._sheet:getByIndexTranslated( self._index, key, default )
end

--------------------------------------------------------------------
local function XLSDataLoader( node )
	local path = node:getObjectFile( 'data' )
	local metaPath = node:getObjectFile( 'meta_data' )
	local data = loadJSONFile( path, true )
	if metaPath then
		local metaData = loadJSONFile( metaPath, true )
		node:setCacheData( 'meta', metaData )
	end
	return data
end

local function DataSheetLoader( node )
	local data, pnode = loadAsset( node.parent )
	local meta = pnode:getCacheData( 'meta' )
	local name = node:getName()
	local sheetData = data[ name ]
	local sheetMetaData = meta and meta[ name ] or {}
	local t = sheetMetaData[ 'type' ] or 'raw'
	if t == 'list' then
		local acc = DataSheetListAccessor( sheetData, sheetMetaData, node:getPath() )
		return acc
	elseif t == 'dict' then
		local acc = DataSheetDictAccessor( sheetData, sheetMetaData, node:getPath() )
		return acc
	else
		_warn( 'deprecated data sheet type')
		return sheetData
	end
end

registerAssetLoader( 'data_xls',    XLSDataLoader )
registerAssetLoader( 'data_sheet',  DataSheetLoader )
