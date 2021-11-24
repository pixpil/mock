module 'mock'

local insert = table.insert
local sort   = table.sort
local type, pairs, ipairs = type, pairs, ipairs
local tonumber = tonumber
local tostring = tostring

local setFieldValue, getFieldValue = Field.setValue, Field.getValue
--------------------------------------------------------------------
--TODO:
--  hash table type
--  embbed compound type? eg. array of array
--  MOAI model
--------------------------------------------------------------------
local NULL = {}

local function getModel( obj )
	local class = getClass( obj )
	if not class then return nil end
	return Model.fromClass( class )	
end

local _isAtomicValueType = {
	[ 'number'    ] = true,
	[ 'int'       ] = true,
	[ 'string'    ] = true,
	[ 'boolean'   ] = true,
	[ '@enum'     ] = true,
	[ '@asset'    ] = true,
	[ 'variable'  ] = true,
} 

local _isTupleValueType = {
	[ 'vec2'  ] = true,
	[ 'vec3'  ] = true,
	[ 'vec4'  ] = true,
	[ 'color' ] = true,
} 

local function isAtomicValue( ft )
	return _isAtomicValueType[ ft ]
end

local function isTupleValue( ft )
	return _isTupleValueType[ ft ]
end


local function makeId( refId, namespace )
	return namespace and refId..':'..namespace or refId
end

local namespaceParentCache = {}
local find = string.find
local sub  = string.sub

local function findNamespaceParent( ns )
	while true do
		local idx = find( ns, ':' )
		local parent
		if idx then
			parent = sub( ns, idx+1 )
		end
		namespaceParentCache[ ns ] = parent or false
		if not parent then return end
		ns = parent
	end
end

local function makeNamespace( ns, ns0 )
	if ns0 then
		local newNS = ns..':'..ns0
		if namespaceParentCache[ newNS ] == nil then
			findNamespaceParent( newNS )
		end
		return newNS
	else
		return ns
	end
end

local function clearNamespaceCache()
	namespaceParentCache = {}
end

--------------------------------------------------------------------
CLASS: SerializeObjectMap ()
function SerializeObjectMap:__init()
	self.objectIds = {}
	self.newObjects = {}
	self.objects    = {}
	self.objectCount = {}
	self.guidObjects = {}
	self.internalObjects = {}
	self.currentId  = 10000
end

function SerializeObjectMap:mapInternal( obj, noNewRef )
	local id = self:map( obj, noNewRef )
	if not id then return nil end
	self:makeInternal( obj )
	return id
end

function SerializeObjectMap:makeInternal( obj )
	self.internalObjects[ obj ] = true
	self.newObjects[ obj ] = nil
end

function SerializeObjectMap:isInternal( obj )
	return self.internalObjects[ obj ] ~= nil
end

function SerializeObjectMap:map( obj, noNewRef )
	if not obj then return nil end
	local id = self.objects[ obj ]
	if id then
		self.objectCount[ obj ] = self.objectCount[ obj ] + 1
		return id
	end
	if noNewRef then return nil end
	if obj.__guid then
		id = obj.__guid
		self.guidObjects[ obj ] = id
	else
		id = self.currentId + 1
		self.currentId = id
		id = '!'..id
	end
	self.objectIds[ id ] = obj
	self.objects[ obj ] = id
	self.objectCount[ obj ] = 1
	self.newObjects[ obj ] = id
	return id
end

function SerializeObjectMap:flush( obj )
	local newObjects = self.newObjects
	if obj then
		if newObjects[ obj ] then
			newObjects[ obj ] = nil
			return obj
		end
	else
		self.newObjects = {}
	end
	return newObjects
end

function SerializeObjectMap:getObjectRefCount( obj )
	return self.objectCount[ obj ] or 0
end

function SerializeObjectMap:hasObject( obj )
	return self.objects[ obj ] or false
end


---------------------------------------------------------------------
local _serializeObject, _serializeField

function _serializeField( obj, f, data, objMap, noNewRef, reason )
	local id = f:getId()

	local ft = f:getType()
	
	if f.__is_tuple or _isTupleValueType[ ft ] then
		local v = { getFieldValue( f, obj ) }
		data[ id ] = v
		return
	end

	if _isAtomicValueType[  ft  ] then
		local v = getFieldValue( f, obj )
		if v ~= nil then
			data[ id ] = v
		end
		return
	end

	local fieldValue = getFieldValue( f, obj )
	if not fieldValue then 
		data[ id ] = nil
		return
	end

	if ft == '@array' then --compound
		local array = {}
		if _isAtomicValueType[  f.__itemtype  ] then
			for i, item in pairs( fieldValue ) do
				array[ i ] = item
			end
		elseif f.__objtype == 'sub' then
			for i, item in pairs( fieldValue ) do
				local itemData = _serializeObject( item, objMap )
				array[ i ] = itemData
			end
		else --ref
			if reason ~= 'sync' then
				for i, item in pairs( fieldValue ) do
					array[ i ] = item and objMap:map( item, noNewRef ) or false
				end
			end
		end
		data[ id ] = array
		return
	end

	if f.__objtype == 'sub' then
		data[ id ] = _serializeObject( fieldValue, objMap, nil, nil, reason )
	else --ref
		if reason ~= 'sync' then
			data[ id ] = objMap:map( fieldValue, noNewRef )
		end
	end

end

--------------------------------------------------------------------
function _serializeObject( obj, objMap, noNewRef, partialFields, reason )
	local tt = type(obj)
	if tt == 'string' or tt == 'number' or tt == 'boolean' then
		return { model = false, body = obj }
	end

	local model = getModel( obj )
	if not model then return nil end
	local fields 

	if partialFields then
		fields = {}
		for i, key in ipairs( partialFields ) do
			local f = model:getField( key, true )
			if f then
				local sp = f.__spolicy
				if sp and not ( reason == 'sync' and sp == 'no_sync' ) then
					insert( fields, f )
				end
			end
		end
	else
		fields = model:getSerializableFieldList()	
	end

	---
	local body = {}
	if reason == 'sync' then
		for i = 1, #fields do
			local f = fields[ i ]
			if f.__spolicy ~= 'no_sync' then
				_serializeField( obj, f, body, objMap, noNewRef, reason )
			end
		end
	else
		for i = 1, #fields do
			local f = fields[ i ]
			_serializeField( obj, f, body, objMap, noNewRef, reason )
		end
	end
	----	

	local extra = nil

	local __serialize = obj.__serialize
	if __serialize then 
		extra = __serialize( obj, objMap, reason )
	end

	return {
		model = model:getName(),
		body  = body,
		extra = extra
	}
end

--------------------------------------------------------------------
local function serialize( obj, objMap )
	assert( obj, 'nil object' )
	objMap = objMap or SerializeObjectMap()
	local rootId = objMap:map( obj )
	local map = {}
	while true do
		local newObjects = objMap:flush()
		if next( newObjects ) then
			local newIds = table.values( newObjects )
			sort( newIds )
			local objectIds = objMap.objectIds
			for _, id in ipairs( newIds ) do
				local obj = objectIds[ id ]
				map[ id ] = _serializeObject( obj, objMap )
			end
		else
			break
		end
	end

	local model = getModel( obj )

	return {		
		root  = rootId,
		model = model:getName(),
		map   = map
	}
end

local find = string.find
local sub  = string.sub
local function getObjectWithNamespace( objMap, id, namespace )
	while true do
		if not namespace then return objMap[ id ] end
		local newId = makeId( id, namespace )
		local obj = objMap[ newId ]
		if obj then return obj end
		namespace = namespaceParentCache[ namespace ]
	end
	-- while true do

	-- 	local newId = makeId( id, namespace )
	-- 	local obj = objMap[ newId ]
	-- 	if obj then return obj end
		
	-- 	if not namespace then return nil end

	-- 	local idx = find( namespace, ':' )
	-- 	if idx then
	-- 		namespace = sub( namespace, idx+1 )
	-- 	else
	-- 		namespace = nil
	-- 	end
	-- 	-- return objMap[ newId ] or objMap[ id ]
	-- end
end

--------------------------------------------------------------------
local _deserializeField, _deserializeObject

function _deserializeField( obj, f, data, objMap, namespace, reason )
	local id = f:getId()
	local fieldData = data[ id ]
	local ft = f:getType()
	
	if _isAtomicValueType[  ft  ] then
		if fieldData ~= nil then
			if reason == 'sync' then
				return f:checkAndSetValue( obj, fieldData )
			elseif reason == 'fix_type' then
				if ( ft =='number' or ft == 'int' ) then
					return setFieldValue( f, obj, tonumber( fieldData ) )
				elseif ( ft == 'string' ) then
					return setFieldValue( f, obj, tostring( fieldData ) )
				elseif ( ft == 'boolean' ) then
					return setFieldValue( f, obj, fieldData and true or false )
				else
					return setFieldValue( f, obj, fieldData )
				end
			else
				return setFieldValue( f, obj, fieldData )
			end

		else
			return
		end
	end

	if f.__is_tuple or _isTupleValueType[ ft ] then --compound
		if type( fieldData ) == 'table' then
			if reason == 'sync' then
				return f:checkAndSetValue( obj, unpack( fieldData ) )
			else
				return setFieldValue( f, obj, unpack( fieldData ) )
			end
		else
			return
		end
	end

	if ft == '@array' then --compound
		if not fieldData then return end --use default value
		local array = {}
		local itemType = f.__itemtype
		if _isAtomicValueType[  itemType  ] then
			for i, itemData in pairs( fieldData ) do
				array[ i ] = itemData
			end
		elseif f.__objtype == 'sub' then
			for i, itemData in pairs( fieldData ) do
				if type( itemData ) == 'string' then --need conversion?
					local itemTarget = getObjectWithNamespace( objMap, itemData, namespace )
					array[ i ] = itemTarget[1]
				else
					local item = _deserializeObject( nil, itemData, objMap, namespace )
					array[ i ] = item
				end
			end
		else
			for i, itemData in pairs( fieldData ) do
				local tt = type( itemData )
				if tt == 'table' then --need conversion?
					local item = _deserializeObject( nil, itemData, objMap, namespace )
					array[ i ] = item
				elseif itemData == false then --'NULL'?
					array[ i ] = false
				else
					local itemTarget = getObjectWithNamespace( objMap, itemData, namespace )
					if not itemTarget then
						_error( 'missing reference', itemData, namespace )
					else
						array[ i ] = itemTarget[1]
					end
				end
			end
		end

		return setFieldValue( f, obj, array )
	end

	if not fieldData then
		if reason == 'sync' then
			return f:checkAndSetValue( obj, nil )
		else
			return setFieldValue( f, obj, nil )
		end
	end

	if f.__objtype == 'sub' then
		setFieldValue( f, obj, _deserializeObject( nil, fieldData, objMap, namespace, reason ) )

	else --'ref'
		if reason == 'sync' then return end --don't sync ref
		if type( fieldData ) ~= 'string' then
			return _error( 'invalid refernce data type.', obj, id )
		end
		local target = getObjectWithNamespace( objMap, fieldData, namespace )
		if not target then
			_error( 'missing reference', fieldData, namespace )
			-- _error( 'target not found', fieldData, namespace )
		
			return setFieldValue( f, obj, nil )
		else
			return setFieldValue( f, obj, target[1] )
		end
	end

end

function _deserializeObject( obj, data, objMap, namespace, partialFields, reason )
	local model 
	if obj then
		model = getModel( obj )
	else
		local modelName = data['model']
		if modelName then
			model = Model.fromName( modelName )
		else --raw value
			return data['body'], objMap
		end
	end
	
	if not model then return nil end

	if not obj then
		obj = model:newInstance()
	else
		--TODO: assert obj class match
	end

	local ns = data['namespace']
	if ns then
		namespace = makeNamespace( ns, namespace )
	end

	local fields 
	if partialFields then
		fields = {}
		for i, key in ipairs( partialFields ) do
			local f = model:getField( key, true )
			local sp = f.__spolicy
			if sp and not ( reason == 'sync' and sp == 'no_sync' ) then
				insert( fields, f )
			end
		end
	else
		fields = model:getSerializableFieldList()	
	end
	
	local body   = data.body

	if reason == 'sync' then
		for i = 1, #fields do
			local f = fields[ i ]
			if f.__spolicy ~= 'no_sync' then
				_deserializeField( obj, f, body, objMap, namespace, reason )
			end
		end
	else
		for i = 1, #fields do
			local f = fields[ i ]
			_deserializeField( obj, f, body, objMap, namespace, reason )
		end
	end
	local __deserialize = obj.__deserialize
	if __deserialize then
		__deserialize( obj, data['extra'], objMap, namespace, reason )
	end

	return obj, objMap
end


local function _prepareObjectMap( map, objMap, objIgnored, rootId, rootObj )
	objMap = objMap or {}
	objIgnored = objIgnored or false
	local objAliases = {}
	local ids = {}
	local idCount = 0
	if objIgnored then
		for id, _ in pairs( map ) do
			if not objIgnored[ id ] then
				idCount = idCount + 1
				ids[ idCount ] = id
			end
		end
	else
		for id, _ in pairs( map ) do
			idCount = idCount + 1
			ids[ idCount ] = id
		end
	end
	sort( ids )
	for i = 1, idCount do
		local id = ids[ i ]
		local objData = map[ id ]
		local modelName = objData.model
		if not modelName then --alias/raw
			local alias = objData['alias']
			if alias then
				local ns0 = objData['namespace']
				if ns0 then alias = makeId( alias, ns0 ) end
				objAliases[ id ] = alias
				objMap[ id ] = alias
			else
				objMap[ id ] = { objData.body, objData }
			end
		else
			local model = Model.fromName( modelName )
			if not model then
				error( 'model not found for '.. objData.model )
			end
			local instance 
			if rootObj and id == rootId then
				instance = rootObj
			else
				instance = model:newInstance()
			end
			objMap[ id ] = { instance, objData }
		end
	end

	for id, alias in pairs( objAliases ) do
		local origin
		while alias do
			origin = objMap[ alias ]
			if type( origin ) == 'string' then
				alias = origin
			else
				break
			end
		end
		if not origin then
			table.print( objMap )
			_error( 'alias not found', id, alias )
			error()
		end
		objMap[ id ] = origin
	end
	return objMap
end

local function _deserializeObjectMapData( objMap, objIgnored )
	for id, item in pairs( objMap ) do
		if not ( objIgnored and objIgnored[ id ] ) then
			local deserialized = item[3]
			if not deserialized then
				item[3] = true --deserialized
				local obj     = item[1]
				local objData = item[2]
				_deserializeObject( obj, objData, objMap )
			end
		end
	end
	return objMap
end

local function _deserializeObjectMap( map, objMap, objIgnored, rootId, rootObj )
	objMap     = objMap or {}
	objIgnored = objIgnored or {}
	_prepareObjectMap( map, objMap, objIgnored, rootId, rootObj )
	_deserializeObjectMapData( objMap )
	return objMap
end

local function deserialize( obj, data, objMap )
	-- local t0 = os.clock()
	objMap = objMap or {}
	if not data then return obj end
	
	local map = data.map or {}
	local rootId = data.root
	if not rootId then return nil end

	objMap = _deserializeObjectMap( map, objMap, false, rootId, obj )

	local rootTarget = objMap[ rootId ]
	-- _statf( 'deserialize (%.2f) -> %s', ( os.clock() - t0 )*1000, tostring( rootTarget ) )
	return rootTarget[1]
end



--------------------------------------------------------------------
local deflate = false

function serializeToString( obj, compact )
	local data = serialize( obj )
	local str  = encodeJSON( data, compact or false )
	return str	
end

function deserializeFromString( obj, str, objMap )
	local data = MOAIJsonParser.decode( str )
	obj = deserialize( obj, data, objMap )
	return obj
end

function serializeToFile( obj, path, compact )
	local str = serializeToString( obj, compact )	
	if deflate then
		str  = MOAIDataBuffer.deflate( str, 0 )
	end
	local file = io.open( path, 'wb' )
	if file then
		file:write( str )
		file:close()
	else
		_error( 'can not write to file', path )
	end
	return true
end

function deserializeFromFile( obj, path, objMap )
	assert( path, 'no input for deserialization' )
	local stream = MOAIFileStream.new()
	if stream:open( path, MOAIFileStream.READ ) then
		local data, size = stream:read()
		stream:close()
		if deflate then
			data  = MOAIDataBuffer.inflate( data )
		end
		obj = deserializeFromString( obj, data, objMap )
	else
		_error( 'file not found', path )
	end
	return obj
end

--------------------------------------------------------------------

local _cloneObject, _cloneField, _cloneData, _cloneDataField

function _cloneField( obj, dst, f, objMap )
	local id = f:getId()

	local ft = f:getType()
	if _isAtomicValueType[  ft  ] or _isTupleValueType[ ft ] then
		setFieldValue( f, dst, getFieldValue( f, obj ) )
		return
	end

	local fieldValue = getFieldValue( f, obj )
	if not fieldValue then 
		setFieldValue( f, dst, fieldValue )
		return
	end

	if ft == '@array' then --compound
		local array = {}
		if _isAtomicValueType[  f.__itemtype  ] then
			for i, item in pairs( fieldValue ) do
				array[ i ] = item
			end
		elseif f.__objtype == 'sub' then
			for i, item in pairs( fieldValue ) do
				array[ i ] = _cloneObject( item, nil, objMap )
			end
		else --ref
			for i, item in pairs( fieldValue ) do
				array[ i ] = objMap[ item ] or item
			end
		end
		setFieldValue( f, dst, array )
		return
	end

	if f.__objtype == 'sub' then
		setFieldValue( f, dst, _cloneObject( fieldValue, nil, objMap ) )
	else --ref					
		setFieldValue( f, dst, objMap[ fieldValue ] or fieldValue )
	end

end


--------------------------------------------------------------------
function _cloneDataField( obj, dst, f )
	local id = f:getId()

	local ft = f:getType()
	if _isAtomicValueType[  ft  ] or _isTupleValueType[ ft ] then
		setFieldValue( f, dst, getFieldValue( f, obj ) )
		return
	end

	local fieldValue = getFieldValue( f, obj )
	if not fieldValue then 
		setFieldValue( f, dst, fieldValue )
		return
	end

	if ft == '@array' then --compound
		local array = {}
		if _isAtomicValueType[  f.__itemtype  ] then
			for i, item in pairs( fieldValue ) do
				array[ i ] = item
			end
		elseif f.__objtype == 'sub' then
			for i, item in pairs( fieldValue ) do
				array[ i ] = _cloneData( item, nil )
			end
		end
		setFieldValue( f, dst, array )
		return
	end

	if f.__objtype == 'sub' then
		setFieldValue( f, dst, _cloneData( fieldValue, nil ) )
	end

end

--------------------------------------------------------------------
function _cloneObject( obj, dst, objMap )
	local model = getModel( obj )
	if not model then return nil end
	if dst then
		local dstModel = getModel( dst )
		-- assert( dstModel == model )
	else
		dst = model:newInstance()
	end
	objMap = objMap or {}
	objMap[ obj ] = dst

	local fields = model:getSerializableFieldList()
	---
	for _, f in ipairs( fields ) do
		_cloneField( obj, dst, f, objMap )
	end
	----	
	local __clone = dst.__clone
	if __clone then
		__clone( dst, obj, objMap )
	end
	return dst
end

--------------------------------------------------------------------
function _cloneData( obj, dst )
	local model = getModel( obj )
	if not model then return nil end
	if dst then
		local dstModel = getModel( dst )
		-- assert( dstModel == model )
	else
		dst = model:newInstance()
	end

	local fields = model:getSerializableFieldList()
	---
	for _, f in ipairs( fields ) do
		_cloneDataField( obj, dst, f )
	end
	return dst
end

--------------------------------------------------------------------

function checkSerializationFile( path, modelName )
	local file=io.open( path, 'rb' )
	if file then
		local str = file:read('*a')
		if deflate then
			str  = MOAIDataBuffer.inflate( str )
		end
		local data = MOAIJsonParser.decode( str )
		if not data then return false end		
		return data['model'] == modelName
	else
		return false
	end	
end

function createEmptySerialization( path, modelName )
	local model = Model.fromName( modelName )
	if not model then return false end
	local target = model:newInstance() 
	if not target then return false end
	serializeToFile( target, path )
	return true
end


--------------------------------------------------------------------
--public API
_M.serialize   = serialize
_M.deserialize = deserialize
_M.clone       = _cloneObject

_M.cloneData   = _cloneData

--internal API
_M._serializeObject             = _serializeObject
_M._cloneObject                 = _cloneObject
_M._deserializeObject           = _deserializeObject
_M._prepareObjectMap            = _prepareObjectMap
_M._deserializeObjectMapData    = _deserializeObjectMapData
_M._deserializeObjectMap        = _deserializeObjectMap

_M._deserializeField     = _deserializeField
_M._serializeField       = _serializeField

_M.isTupleValue          = isTupleValue
_M.isAtomicValue         = isAtomicValue

_M.makeNameSpacedId      = makeId
_M.makeNameSpace         = makeNamespace
_M.clearNamespaceCache   = clearNamespaceCache

_M._NULL = NULL