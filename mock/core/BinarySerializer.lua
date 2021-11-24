module 'mock'

local isTupleValue          = isTupleValue
local isAtomicValue         = isAtomicValue
local unpack = unpack

local function getModel( obj )
	local class = getClass( obj )
	if not class then return nil end
	return Model.fromClass( class )	
end

--------------------------------------------------------------------
local _deserilizerTemplate = [[
local o, objmap, ns, reason, set, remap, recv, unpack = ...
local $vars
if remap then
	$vars = remap( recv( $vnum ) )
else
	$vars = recv( $vnum )
end
$body
local _d = o.__deserialize
local ex = recv(1)
if _d then
	_d( o, ex, objmap, ns, reason)
end
]]


local _serilizerTemplate = [[
local o, objmap, ns, reason, get, send = ...
send(
$body
)
local _s = o.__serialize
if _s then
	local ex = _s(o,objmap,reason)
	send( ex or false )
else
	send( false )
end
]]

local argListCache = {}
local function genArgList( n )
	local r = argListCache[ n ]
	if not r then
		r = ''
		for i = 1, n do
			if i == 1 then
				r = '_' .. i
			else
				r = r .. ',_' .. i
			end
		end
		argListCache[ n ] = r
	end
	return r
end

local gsub = string.gsub
local format = string.format
function _buildUnpackFunc( model )
	assert( model )
	local fields = model:getSerializableFieldList()
	table.sort( fields, function( a, b ) return a.__id < b.__id end )
	local fieldNames = {}
	local fieldCount = #fields
	local buf = newStringBuffer()
	local setters = {}
	local setterCount = 0
	for i = 1, fieldCount do
		local f = fields[ i ]
		local fid = f.__id
		local ft = f.__type
		local isTuple = f.__is_tuple or isTupleValue( ft )
		fieldNames[ i ] = fid
		local line

		if f.__setter == true then
			if isTuple then
				line = format( 'o.%s=unpack(_%d)', fid, i )
			else
				line = format( 'o.%s=_%d', fid, i )
			end
		else
			setterCount = setterCount + 1
			setters[ setterCount ] = f.__setter
			if isTuple then
				line = format( 'set[%d](o,unpack(_%d))', setterCount, i )
			else
				line = format( 'set[%d](o,_%d)', setterCount, i )
			end
		end

		-- buf( line, '\n' )
		buf( format( 'if _%d~=nil then ', i ), line, ' end --', fid, '\n' )
	end

	local replacement = {
		-- modelname = model.__name,
		vars = genArgList( fieldCount ),
		vnum = fieldCount,
		body = tostring( buf ),
	}
	local output = gsub( _deserilizerTemplate, "%$(%w+)", replacement )
	-- print( output )

	local funcName = 'Unpacker:'..model.__name
	local f, err = loadstring( output, funcName )
	if f then
		return f, setters
	end
	error( err )
end

function _buildPackFunc( model )
	assert( model )
	local fields = model:getSerializableFieldList()
	local fieldNames = {}
	local fieldCount = #fields
	
	local buf = newStringBuffer()
	local getters = {}
	local getterCount = 0

	for i = 1, fieldCount do
		local f = fields[ i ]
		local fid = f.__id
		local ft = f.__type
		fieldNames[ i ] = fid
		local var
		local getter = f.__getter
		local isTuple = f.__is_tuple or isTupleValue( ft )
		if getter == true then
			var = 'o.'..fid
		else
			getterCount = getterCount + 1
			getters[ getterCount ] = getter
			var = format( 'get[%d](o)', getterCount)
		end
		if isTuple then
			buf( '{' .. var.. '}' )
		else
			buf( var )
		end
	end

	local replacement = {
		-- vars = genArgList( fieldCount ),
		-- vnum = fieldCount,
		-- modelname = model.__name,
		body = buf:concat(',\n'),
	}
	local output = gsub( _serilizerTemplate, "%$(%w+)", replacement )
	-- print( output )

	local funcName = 'Packer:'..model.__name
	local f, err = loadstring( output, funcName )
	if f then
		return f, getters
	end
	error( err )
end

--------------------------------------------------------------------
local serializeObjectB, deserializeObjectB

--------------------------------------------------------------------
CLASS: BinaryObjectPacker ()

function BinaryObjectPacker:__init( model )
	self.model = model
	self._unpackFunc, self._setters = _buildUnpackFunc( self.model )
	self._packFunc, self._getters = _buildPackFunc( self.model )
end

function BinaryObjectPacker:pack( obj, objMap, namespace, reason, encoder )
	--ARGS: o, objmap, reason, ns, get, | send = ...
	self._packFunc(
		obj, objMap, namespace, reason, self._getters, 
		encoder
	)
	return encoder
end

function BinaryObjectPacker:unpack( obj, objMap, namespace, reason, remapper, decoder )
	--ARGS: o, objmap, ns, reason, set, | remap, | recv, unpack = ...
	self._unpackFunc( 
		obj, objMap, namespace, reason, self._setters,
		remapper, 
		decoder, unpack
	)
	return obj
end

local function affirmBinaryObjectPacker( model )
	local s = model.__binary_packer
	if not s then
		s = BinaryObjectPacker( model )
		model.__binary_packer = s
	end
	return s
end

--------------------------------------------------------------------
--Main Protocol
--------------------------------------------------------------------
function _serializeObjectB( obj, objMap, noNewRef, partialFields, reason, encoder )
	encoder = encoder or MsgPackEncoder()
	local model = getModel( obj )
	if not model then 
		error( 'non object for serialization')
	end

	----OBJECT----
	if partialFields then
		error( 'NOT SUPPORTED, use plain serializer' )
		-- fields = {}
		-- for i, key in ipairs( partialFields ) do
		-- 	local f = model:getField( key, true )
		-- 	if f then
		-- 		local sp = f.__spolicy
		-- 		if sp and not ( reason == 'sync' and sp == 'no_sync' ) then
		-- 			insert( fields, f )
		-- 		end
		-- 	end
		-- end
	else
		encoder( model.__name )
		local packer = affirmBinaryObjectPacker( model )
		packer:pack( obj, objMap, nil, reason, encoder )
	end

	return encoder
end

--------------------------------------------------------------------
function _deserializeObjectB( obj, decoder, objMap, namespace, partialFields, reason )
	local modelName = decoder( 1 )
	local model = Model.fromName( modelName )
	assert( model, 'invalid model' )

	if obj then
		local objModel = getModel( obj )
		--verify?
		assert( objModel == model )
	else
		obj = model:newInstance()
	end

	--TODO: build field remapper

	local packer = affirmBinaryObjectPacker( model )
	packer:unpack( obj, objMap, namespace, reason, nil, decoder )
	return obj, objMap
end


--------------------------------------------------------------------
local function serializeB( obj, objMap )
end

local function deserializeB( obj, data, objMap )
end

--------------------------------------------------------------------
--public API
_M.serializeB   = serialize
_M.deserializeB = deserialize
-- _M.clone       = _cloneObject

-- _M.cloneData   = _cloneData

--------------------------------------------------------------------
--interal API
_M._serializeObjectB              = _serializeObjectB
_M._deserializeObjectB            = _deserializeObjectB

