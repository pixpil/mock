--[[
* MOCK framework for Moai

* Copyright (C) 2012 Tommo Zhou(tommo.zhou@gmail.com).  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local setmetatable  = setmetatable
local getmetatable  = getmetatable

local rawget, rawset = rawget, rawset
local insert = table.insert
local type = type
local next = next
local format = string.format
--------------------------------------------------------------------
-- CLASS
--------------------------------------------------------------------
local newClass
local separatorField
local globalClassRegistry = setmetatable( {}, { __no_traverse = true } )
local tracingObjectMark            = 0
local tracingObjectAllocation      = false
local tracingObjectAllocationStack = false
local tracingObjectTable = setmetatable( {}, { __mode = 'kv', __no_traverse = true } )

local subclassContainerMT = { __no_traverse = true }
-- local subclassContainerMT = { __mode = 'kv', __no_traverse = true }

--------------------------------------------------------------------
-- C ext
--------------------------------------------------------------------
local _getLuaValueAddress, _newInstanceTable
_getLuaValueAddress = mock_luaext.get_value_address
_newInstanceTable = mock_luaext.new_instance_table

--------------------------------------------------------------------
--------------------------------------------------------------------
local buildInstanceBuilder

local reservedMembers = {
	['__init']  = true,
	['__name']  = true,
	['__env']   = true,
	['__model'] = true,
}

local function getDefaultValueForType( ftype )
	if ftype == 'number'   then return {0} end
	if ftype == 'int'      then return {0} end
	if ftype == 'string'   then return {''} end
	if ftype == 'boolean'  then return {false} end
	if ftype == '@asset'   then return {false} end
	if ftype == 'vec2'     then return {0,0} end
	if ftype == 'vec3'     then return {0,0,0} end
	if ftype == 'vec4'     then return {0,0,0,0} end
	if ftype == 'color'    then return {1,1,1,1} end
	return nil
end

function setTracingObjectAllocation( tracing )
	tracingObjectAllocation = tracing ~= false
end

function isTracingObjectAllocation()
	return tracingObjectAllocation
end

function getTracingObjectTable()
	return tracingObjectTable
end

function getTracingObjectCount()
	return table.len( tracingObjectTable )
end

function clearTracingTable()
	tracingObjectTable = setmetatable( {}, { __mode = 'kv', __no_traverse = true } )
end

function countTracingObject( filter, ignoreMockObject )
	local objectCounts = {}
	for o in pairs( tracingObjectTable ) do
		local name = o:getClassFullName() or '<unknown>'
		if ignoreMockObject and name:sub( 1, 4 ) == 'mock' then
			--do nothing
		elseif name == 'Model' or name == 'Field' then
			--do nothing
		elseif not filter or ( name:find( filter ) ) then
				objectCounts[ name ] = ( objectCounts[ name ] or 0 ) + 1
		end
	end
	return objectCounts
end

function reportTracingObject( filter, ignoreMockObject )
	local objectCounts = countTracingObject( filter, ignoreMockObject )
	local total  = 0
	local output = {}
	for name, count in pairs( objectCounts ) do
		insert( output, { name, count } )
	end
	table.sort( output, function( i1, i2 ) return i1[1] < i2[1] end )
	print( '--------' )
	for i, item in ipairs( output ) do
		print( format( '%9d\t%s',item[2], item[1] ) )
		total = total + item[2]
	end
	print( '-- total objects:', total )
	return objectCounts
end

function _incObjectTracingMark()
	tracingObjectMark = tracingObjectMark + 1
end

function getGlobalClassRegistry()
	return globalClassRegistry
end

--------------------------------------------------------------------
local BaseClass = {
	__subclasses  = setmetatable( {}, subclassContainerMT ),
	__signals     = false,
	__serialize   = false,
	__deserialize = false,
	__clone       = false,
}

_BASECLASS = BaseClass --use this to extract whole class tree

--Class build DSL
function BaseClass:MODEL( t )
	local m = Model( self )
	m:update( t )
	return self
end

function BaseClass:DEPRECATED( msg )
	self.__deprecated = { msg = msg }
	return self
end

function BaseClass:MEMBER( t )
	for k, v in pairs( t ) do
		self[k] = v
	end
	return self
end

function BaseClass:META( t )
	self.__meta = t
	return self
end

function BaseClass:RPC( t )
	self.__rpcs = t
	return self
end

local signalEmit = signalEmit
function BaseClass:SIGNAL( t )
	self.__signals = t
	buildInstanceBuilder( self )
	return self
end

function BaseClass:rawInstance( t )
	t.__address = _getLuaValueAddress( t )
	return setmetatable( t, self )
end

function BaseClass:isSubclass( superclass )
	local s = self.__super
	while s do
		if s == superclass then return true end
		s = s.__super
	end
	return false
end

function BaseClass:isSubclassByName( superclassName )
	local s = self.__super
	while s do
		if s.__name == superclassName then return true end
		s = s.__super
	end
	return false
end

function BaseClass:isValidClass()
	return globalClassRegistry[ self.__fullname ] == self
end


--Instance Methods
function BaseClass:getSignals( t )
	return self.__class.__signals or false
end

function BaseClass:getClass()
	return self.__class
end

function BaseClass:getClassName()
	return self.__class.__name
end

function BaseClass:getClassSourceFile()
	return self.__class.__source
end

function BaseClass:getClassFullName()
	return self.__class.__fullname
end

function BaseClass:isInstance( clas )
	if type( clas ) == 'string' then return self:isInstanceByName( clas ) end
	local c = self.__class
	if c == clas then return true end
	return c:isSubclass( clas )
end

function BaseClass:isInstanceByName( className )
	local c = self.__class
	if c.__name == className then return true end
	return c:isSubclassByName( className )
end

function BaseClass:assertInstanceOf( superclass )
	if self:isInstance( superclass ) then
		return self 
	else
		return error( 'class not match' )
	end
end

function BaseClass:cast( clas )
	if self:isInstance( clas ) then
		return self
	else
		return nil
	end
end

-- function BaseClass:__clear()
-- end
local function clearInstance( o )
	local address = o.__address
	table.clear( o )
	o.__address = address
end

function BaseClass:__clear()
	clearInstance( self )
end

function BaseClass:__repr()
	return format( '<%s:0x%08x>', self.__class.__name, self.__address or 0 )
end

function BaseClass:__tostring()
	return self:__repr()
end
----
local _methodPointerCache = setmetatable( {}, { __mode = 'kv' } )
local function _makeMethodPointer( object, methodName )
	local reg = _methodPointerCache[ object ]
	if not reg then
		reg = {}
		_methodPointerCache[ object ] = reg
	end
	local method = object.__class[ methodName ]
	if not method then
		return error( 'no method found:' .. methodName )
	end
	local mp = reg[ methodName ]
	if not mp then
		mp = function( ... )
			local func = object.__class[ methodName ]
			return func( object, ... )
		end
		reg[ methodName ] = mp
	end
	return mp
end

function BaseClass:methodPointer( methodName )
	return _makeMethodPointer( self, methodName )
end

function BaseClass:methodClosure( methodName, ... )
	assert( self[ methodName ] )
	local args = { ... }
	return function()
		local f = self[ methodName ]
		return f( self, unpack( args ) )
	end
end


--Signals

-- function BaseClass:superCall( name, ... )
-- 	local m = self[ name ]
-- 	local super = self.__super
-- 	while super do
-- 		local m1 = super[ name ]
-- 		if not m1 then break end
-- 		if m1 ~= m then return m1( self, ... ) end
-- 		super = super.__super
-- 	end
-- 	error( 'no super method: '.. name, 2 )
-- end


--------------------------------------------------------------------
local function buildInitializer(class,f)
	if not class then return f end
	local init = rawget( class, '__init' )
	
	if type( init ) == 'table' then --copy
		local t1 = init
		init = function(a)
			for k,v in pairs( t1 ) do
				a[ k ] = v
			end
		end
	end

	--use upvalue to build the initializer chain
	if init then
		if f then
			local f1 = f
			f = function( a, ... )
				init( a, ... )
				return f1( a, ... )
			end
		else
			f = init
		end
	end

	local deprecated = class.__deprecated
	if deprecated then
		local f1 = f
		f = function( a, ... )
			print( 'WARNING: using DEPRECATED class:', class.__fullname, a )
			if deprecated.msg then print( deprecated.msg ) end
			print( debug.traceback(2) )
			return f1( a, ... )
		end
	end

	return buildInitializer( class.__super, f )
end


local newSignal        = newSignal
local signalConnect    = signalConnect
local signalDisconnect = signalDisconnect

local function collectSignalInfo( class, info )
	if not class then return info end
	local signals = rawget( class, '__signals' )
	if signals then
		for id, handler in pairs( signals ) do
			if handler and handler ~= '' then
				if info[ id ] == nil then
					info[ id ] = handler
				end
			else
				info[ id ] = false
			end
		end
	end
	return collectSignalInfo( class.__super, info )
end

local function buildSignalInitializer( class, f )
	local signals = collectSignalInfo( class, {} )
	--FIXME: replace this NAIVE impl.
	if not next( signals ) then return false end
	
	local signalMethods = false
	local function init( obj )
		if not signalMethods then --collect signal methods at first instance creation
			signalMethods = {}
			for id, handler in pairs( signals ) do
				if handler and handler ~= '' and handler ~= true then
					local func = class[ handler ]
					if type( func ) ~= 'function' then
						error( 'signal handler is not a function!' )
					end
					signalMethods[ id ] = func
				else
					signalMethods[ id ] = false
				end
			end
		end

		for id, func in pairs( signalMethods ) do
			local sig = newSignal()				
			obj[ id ] = sig
			if func then
				signalConnect( sig, obj, func )
			end
		end

	end

	return init
end

function clearAllSignalConnections( owner, obj )
	for key in pairs( owner.__signals ) do
		local signal = owner[ key ]
		--assert
		signalDisconnect( signal, obj )
	end
end



local tostring = tostring
function buildInstanceBuilder( class )
	local init = buildInitializer( class )
	local initSignals = buildSignalInitializer( class )


	local newinstance_ = function ( o,... )
		setmetatable( o , class )
		if initSignals then initSignals(o,...) end
		if init then init(o,...) end
		if tracingObjectAllocation then
			tracingObjectTable[ o ] = tracingObjectMark
			if tracingObjectAllocationStack then
				o.__createtraceback = debug.traceback( 2 )
			end
		end
		return o
	end

	local newinstance_empty = function ( t, ... )
		return newinstance_( _newInstanceTable( 0, class.__field_count ), ... )
	end

	local newinstance_with = function( o, ... )
		o.__address = _getLuaValueAddress( o )
		return newinstance_( o, ... )
	end

	local mt = getmetatable( class )
	mt.__call = newinstance_empty
	class.__new = newinstance_empty
	class.__new_with = newinstance_with

	for s in pairs( class.__subclasses ) do
		buildInstanceBuilder(s)
	end
end

local keyCounts = {}

function reportKeyCount()
	table.foreach( keyCounts, print )
end

function clearKeyCount()
	keyCounts = {}
end

--------------------------------------------------------------------
function newClass( b, superclass, name  )		
	b = b or {}
	local index
	superclass = superclass or BaseClass
	b.__super  = superclass

	for k,v in pairs( superclass ) do --copy super method to reduce index time
		if not reservedMembers[k] and rawget(b,k)==nil then 
			b[k]=v
		end
	end

	superclass.__subclasses[b] = true

	-- b.__index       = function( t, k ) 
	-- 	local kk = name .. '->' .. k
	-- 	keyCounts[ kk ] = ( keyCounts[ kk ] or 0 ) + 1 
	-- 	return b[ k ] 
	-- end

	b.__index       = b
	b.__class       = b
	b.__subclasses  = setmetatable( {}, subclassContainerMT )

	b.__no_traverse = true

	b.__repr        = superclass.__repr
	b.__tostring    = superclass.__tostring
	b.__serialize   = superclass.__serialize
	b.__deserialize = superclass.__deserialize
	b.__clone       = superclass.__clone

	if not name then
		local s = superclass
		while s do
			local sname = s.__name
			if sname and sname ~= '??' then
				name = s.__name..':??'
				break
			end
			s = s.__super
		end
	end

	b.__name  = name or '??'
	b.__classdirty = false
	--TODO: automatically spread super class modification

	local newindex=function( t, k, v )
		b.__classdirty = true
		rawset( b, k, v )
		if k=='__init' then --TODO:remove duplicated initializer creation
			buildInstanceBuilder(b)
		else --spread? TODO
		end
	end
	
	setmetatable( b, {
			__newindex = newindex,
			__isclass  = true,
			__tostring = function( t )
				return format( '<class:%s>', t.__fullname )
			end
		}
	)

	buildInstanceBuilder(b)
	if superclass.__initclass then
		superclass:__initclass( b )
	end
	return b
	
end

function updateAllSubClasses( c, force )
	for s in pairs(c.__subclasses) do
		local updated = false
		for k,v in pairs(c) do
			if not reservedMembers[k] and ( force or rawget( s, k ) == nil ) then 
				updated = true
				s[k] = v
			end
		end
		if updated then updateAllSubClasses(s) end
	end
end

function isClass( c )
	local mt = getmetatable( c )
	return mt and mt.__isclass or false
end

function isSubclass( c, super )
	if c == super then return true end
	return isClass( c ) and c:isSubclass( super )
end

function isSuperclass( c, sub )
	return isClass( sub ) and sub:isSubclass( c )
end

function isClassInstance( o )
	return getClass( o ) ~= nil
end

function isInstance( o, clas )
	return isClassInstance(o) and o:isInstance( clas )
end

function castInstance( o, clas )
	return o and isInstance( o, clas ) and o or nil
end

function assertInstanceOf( o, clas )
	if isInstance( o, clas ) then return o end
	return error( 'class not match' )
end

function getClass( o )
	if type( o ) ~= 'table' then return nil end
	local clas = getmetatable( o )
	if not clas then return nil end
	local mt = getmetatable( clas )
	return mt and mt.__isclass and clas or nil
end

local classBuilder
local function affirmClass( t, id )
	if type(id) ~= 'string' then error('class name expected',2) end

	return function( a, ... )
			local superclass
			if select( '#', ... ) >= 1 then 
				superclass = ...
				if not superclass then
					error( 'invalid superclass for:' .. id, 2 )
				end
			end
			
			if a ~= classBuilder then
				error( 'Class syntax error', 2 )
			end
			if superclass and not isClass( superclass ) then
				error( 'Superclass expected, given:'..type( superclass ), 2)
			end
			local clas = newClass( {}, superclass, id )
			local env = getfenv( 2 )
			env[ id ] = clas
			local info = debug.getinfo( 2, 'S' )
			clas.__source = info.source
			if env ~= _G then
				local prefix = env._NAME or tostring( env )
				clas.__fullname = prefix .. '.' .. clas.__name
			else
				clas.__fullname = clas.__name
			end
			clas.__env = env
			clas.__field_count = 0

			clas.__definetraceback = debug.traceback( 2 )
			local clas0 = globalClassRegistry[ clas.__fullname ]
			if clas0  then
				_error( 'duplicated class:', clas.__fullname )
				print( '-->from:',clas.__definetraceback )
				print( '-->first defined here:',clas0.__definetraceback )

			end
			globalClassRegistry[ clas.__fullname ] = clas
			return clas
		end

end

classBuilder = setmetatable( {}, { __index = affirmClass } )

local function rawClass( superclass )	
	local clas = newClass( {}, superclass, '(rawclass)' )
	clas.__fullname = clas.__name
	return clas
end

--------------------------------------------------------------------
_G.CLASS     = classBuilder
_G._rawClass = rawClass

local classSearchCache = setmetatable({}, {__mode ='v'})

function clearClassSearchCache( id )
	if id then
		classSearchCache[ id ] = nil
	else
		classSearchCache = setmetatable({}, {__mode ='v'})
	end
end

function findClass( term )
	local result = classSearchCache[ term ]
	if result then return result end
	local l = #term
	local candidates = {}
	for n, clas in pairs( globalClassRegistry ) do		
		if clas.__name == term then
			insert( candidates, clas )
		end
	end
	local count = #candidates
	if count > 1 then
		_warn( 'more than one class found for name', term )
		result = candidates[ 1 ]
		classSearchCache[ term ] = result
		return result

	elseif count == 0 then
		return nil

	else
		result = candidates[ 1 ]
		classSearchCache[ term ] = result
		return result

	end
end

function getClassByName( fullname )
	return globalClassRegistry[ fullname ]
end

function validateAllClasses()
	--TODO
	return true
end

--------------------------------------------------------------------
--MODEL & Field
--------------------------------------------------------------------

CLASS: Model ()
function Model:__init( clas, clasName )
	self.__src_class = clas
	self.__name  = clas.__fullname or clasName or 'LuaObject'
	rawset( clas, '__model', self )
end

function Model:__tostring()
	return string.format( '%s%s', self:__repr(), self.__name )
end

function Model.fromObject( obj )
	local clas = getClass( obj )
	-- if not clas then return nil end
	assert( clas, 'not class object' )
	return Model.fromClass( clas )
end

function Model.fromClass( clas )
	if not isClass(clas) then
		return nil
	end
	--TODO:support moai class
	local m = rawget( clas, '__model' )
	if not m then
		-- print( 'create model for', clas.__name )
		m = Model( clas )
	end
	assert( m.__name == clas.__fullname )
	return m	
end

function Model.find( term )
	local clas = findClass( term )
	return clas and Model.fromClass( clas ) or nil
end

function Model.findName( term )
	local m = Model.find( term )
	return m and m.__name or nil
end

function Model.fromName( fullname )
	local clas = globalClassRegistry[ fullname ]
	if clas then return Model.fromClass( clas ) end
	return nil
end

function Model.forSimilarName( fullname )
	local parts = fullname:split( '.', true )
	local count = #parts
	local found = false
	for i = 1, count - 1 do
		local parts1 = table.sub( parts, i, count )
		local partname = string.join( '.', parts1 )
		for name, clas in pairs( globalClassRegistry ) do
			if name:endwith( partname ) and ( not clas.__deprecated ) then
				found = clas
				break
			end
		end
	end
	return
end

function Model:__call( body )
	self:update( body )
	return self
end

function Model:getName()
	return self.__name
end

local function _collectFieldForUpdate( model, group, fields, fieldMap, f )
	local mt = getmetatable( f )
	if mt == FieldGroup then
		for i, child in ipairs( f:getChildren() ) do
			_collectFieldForUpdate( model, nil, fields, fieldMap, child )
		end
		f.__model = model
	elseif mt == Field then
		local id = f.__id
		if fieldMap[id] then error( 'duplicated Field:'..id, 3 ) end
		fieldMap[ id ] = f
		f:__update()
		insert( fields, f )
		f.__model = model
		if group then
			group:_addChild( f )
		end
	elseif f == '----' then
		insert( fields, separatorField )
		if group then
			group:_addChild( f )
		end
	else
		error('Field/FieldGroup expected in Model, given:'..type( f ), 3)
	end
end

local function _mergeField( f, f0 )
	for k, v0 in pairs( f0 ) do
		local v = f[ k ]
		if k == '__meta' and v0 then --merge this
			f[ k ] = table.extend2( v or {}, v0 )
		elseif k == '__type' then --use former definination
			-- if v and v ~= v0 then
			-- 	_warn( 'field type mismatch from super class', f )
			-- end
			f[ k ] = v0
		elseif k == '__getter' or k == '__setter' then
			if v == true then --default? use former definiation
				f[ k ] = v0
			end
		else
			if v == nil then
				f[ k ] = v0
			end
		end
	end
end


function Model:update( body )
	local fields   = {}
	local fieldMap = {}
	local rootGroup = FieldGroup()
	
	for i = 1, #body do
		local f = body[ i ]
		_collectFieldForUpdate( self, rootGroup, fields, fieldMap, f )
	end
	self.__fields   = fields
	self.__fieldMap = fieldMap
	self.__rootGroup = rootGroup
	

	--merge fields
	local pm = self:getSuperModel()
	if pm then
		for fid, f in pairs( fieldMap ) do
			local pf = pm:getField( fid )
			if pf then
				_mergeField( f, pf )
			end
		end
		--TODO: more acurrate count
		self.__field_count = #fields + pm.__field_count
	else
		self.__field_count = #fields
	end

	if body.extra_size then
		self.__field_count = self.__field_count + body.extra_size
	end

	self.__src_class.__field_count = self.__field_count
	return self
end

function Model:getMeta()
	return rawget( self.__src_class, '__meta' )
end

function Model:getField( name, findInSuperClass )
	local fields = self.__fields
	if fields then 
		for i, f in ipairs( self.__fields ) do
			if f.__id == name then return f end
		end
	end
	if findInSuperClass ~= false then
		local superModel = self:getSuperModel()
		if superModel then return superModel:getField( name, true ) end
	end
	return nil
end

function Model:getFieldType( name, findInSuperClass )
	local field = self:getField( findInSuperClass )
	if field then
		return field:getType()
	else
		return nil
	end
end


local function _collectFields( model, includeSuperFields, list, dict )
	list = list or {}
	dict = dict or {}
	if includeSuperFields then
		local s = model:getSuperModel()
		if s then _collectFields( s, true, list, dict ) end
	end
	local fields = model.__fields
	if fields then
		for i = 1, #fields do
			local f = fields[ i ]
			local id = f.__id
			local i0 = dict[id]
			if i0 and f ~= separatorField then --override
				list[i0] = f
			else
				local n = #list
				list[ n + 1 ] = f
				dict[ id ] = n + 1
			end
		end
	end
	return list
end

function Model:getSerializableFieldList()
	local list = self._serializableFieldList
	if not list then
		local fullList = self:getFullFieldList()
		list = {}
		local n = 1
		for i = 1, #fullList do
			local f = fullList[ i ]
			if f.__spolicy then
				list[ n ] = f
				n = n + 1
			end
		end
		-- table.sort( list, function( a, b ) return a.__id < b.__id end )
		self._serializableFieldList = list
	end
	return list
end

function Model:getFullFieldList()
	if self._fullFieldList then
		return self._fullFieldList
	end
	local list = self:getFieldList( true )
	self._fullFieldList = list
	return list
end

function Model:getFieldList( includeSuperFields, sorted )
	local fields = _collectFields( self, includeSuperFields ~= false )
	if sorted then
		local reinserts = {}
		local list2 = {}
		for i = 1, #fields do
			local f = fields[ i ]
			local insert = f:getMeta( 'insert' )
			if insert then
				table.insert( reinserts, f )
			else
				table.insert( list2, f )
			end
		end

		for i = 1, #reinserts do
			local f = reinserts[ i ]
			local insert = f:getMeta( 'insert' )
			local target, pos = unpack( insert )
			local idx
			for i = 1, #list2 do
				local f1 = list2[ i ]
				if f1.__id == target then
					if pos == 'after' then
						idx = i + 1
					else
						idx = i
					end
				end
			end
			if idx then
				table.insert( list2, idx, f )
			else
				table.insert( list2, f )
			end
		end
		fields = list2
	end
	return fields
end


local function _collectMeta( clas, meta )
	meta = meta or {}
	local super = clas.__super
	if super then
		_collectMeta( super, meta )
	end
	local m = rawget( clas, '__meta' )
	if not m then return meta end
	for k, v in pairs( m ) do
		meta[ k ] = v
	end
	return meta
end

function Model:getCombinedMeta()
	return _collectMeta( self.__src_class )
end

function Model:getSuperModel()
	local superclass = self.__src_class.__super
	if not superclass then return nil end
	local m = rawget( superclass, '__model' )
	if not m then
		m = Model( superclass )
	end
	return m
end

function Model:getClass()
	return self.__src_class
end

function Model:newInstance( ... )
	local newinstance_empty = self.__src_class.__new
	return newinstance_empty( ... )
end

function Model:isInstance( obj )
	if type(obj) ~= 'table' then return false end
	local clas = getmetatable( obj )
	local clas0 = self.__src_class
	while clas do
		if clas == clas0 then return true end
		clas = rawget( clas, '__super' )
	end
	return false
end

function Model:getFieldValue( obj, name )
	if not self:isInstance( obj ) then return nil end
	local f = self:getField( name )
	if not f then return nil end
	return f:getValue( obj )
end

function Model:setFieldValue( obj, name, ... )
	if not self:isInstance( obj ) then return nil end
	local f = self:getField( name )
	if not f then return nil end
	return f:setValue( obj, ... )
end

--------------------------------------------------------------------
CLASS: Field ()
function Field:__init( id )
	self.__model    = false
	self.__id       = id
	self.__type     = 'number'
	self.__getter   = true
	self.__setter   = true
	self.__objtype  = false
	self.__group    = false
	self.__meta     = false
end

function Field:__tostring()
	return string.format( '%s%s', self:__repr(), self:getFullName() )
end

function Field:__update()
	--support info

	--serializePolicy
	local spolicy
	if self:getMeta( 'no_save', false ) or self:getType() == '@action' then
		spolicy = false
	elseif self:getMeta( 'no_sync', false ) then
		spolicy = 'no_sync'
	else
		spolicy = true
	end

	self.__spolicy = spolicy
end

function Field:getFullName()
	local model = self.__model
	if not model then
		return self.__id
	else
		return model.__name .. '.' .. self.__id
	end
end

function Field:type( t )
	self.__type = t
	return self
end

function Field:array( t ) 
	self.__type     = '@array'
	self.__itemtype = t or 'number'
	return self
end

function Field:asset_array(t)
	self:array( '@asset' )
	self.__assettype = t
	return self
end

function Field:collection( t ) 
	self.__type     = '@array'
	self.__itemtype = t or 'number'
	self:meta{ ['collection'] = true }
	return self
end

function Field:enum( t )
	self.__type  = '@enum'
	self.__enum  = t
	return self
end

function Field:selection( s )
	if not s then return self end	
	return self:meta{ selection = s }
end

function Field:table( ktype, vtype ) 
	self.__type    = v
	self.__keytype = ktype
	return self
end

function Field:asset( assetType )
	self.__type      = '@asset'
	self.__assettype = assetType
	return self
end

function Field:asset_pre( assetType )
	return self:asset( assetType ):meta{ preload = true }
end

function Field:asset_array_pre( assetType )
	return self:asset_array( assetType ):meta{ preload = true }
end

--type shortcut
function Field:number()
	return self:type('number')
end

function Field:float()
	return self:type('number')
end

function Field:boolean()
	return self:type('boolean')
end

function Field:string()
	return self:type('string')
end

function Field:int()
	return self:type('int')
end

function Field:variable() --any atomic values
	return self:type('variable')
end

function Field:action( methodName )
	self:type('@action')	
	self.__actionname = methodName
	return self
end

function Field:no_nil()
	return self:meta { no_nil = true } --will get validated against onStart
end

---
function Field:label( l )
	self.__label = l
	return self
end

function Field:desc( desc )
	return self:meta{ description = desc }
end

function Field:meta( meta )
	assert( type(meta) == 'table', 'metadata should be table' )
	local meta0 = self.__meta or {} --copy into old meta
	for k, v in pairs( meta ) do
		meta0[k] = v
	end
	self.__meta = meta0
	return self
end

function Field:sub()
	self.__objtype = 'sub'
	return self
end

function Field:ref()
	self.__objtype = 'ref'
	return self
end

function Field:no_edit() --short cut
	return self:meta{ no_edit = true, no_sync = true }
end

function Field:preload()
	return self:meta{ preload = true }
end

function Field:no_save() --short cut
	return self:meta{ no_save = true }
end

function Field:no_sync()
	return self:meta{ no_sync = true }
end

function Field:insert_before( target ) --used in reordering for inspection/serialization
	return self:meta{ insert = { target, 'before' } }
end

function Field:insert_after( target )
	return self:meta{ insert = { target, 'after' } }
end

function Field:readonly( option ) --short cut
	if type(option) == 'string' then --function
		local checkerName = option
		local checker = function( obj, ... )
			local f = obj[checkerName]
			if f then return f( obj, ... ) else error( 'readonly checker not found:'..checkerName ) end
		end
		self:meta{ readonly = checker, no_sync = true }
	elseif type(option) == 'function' then
		local checker = option
		return self:meta{ readonly = checker, no_sync = true }
	else
		return self:meta{ readonly = option ~= false, no_sync = option ~= false }
	end
end

function Field:hidden( option ) --short cut
	if type(option) == 'string' then --function
		local checkerName = option
		local checker = function( obj, ... )
			local f = obj[checkerName]
			if f then return f( obj, ... ) else error( 'hidden checker not found:'..checkerName ) end
		end
		self:meta{ hidden = checker }
	elseif type(option) == 'function' then
		return self:meta{ hidden = option }
	else
		return self:meta{ hidden = option ~= false }
	end
end

function Field:range( min, max )
	if min then self:meta{ min = min } end
	if max then self:meta{ max = max } end
	return self
end

function Field:widget( name )
	if name then self:meta{ widget = name } end
	return self
end

function Field:step( num )
	if num then self:meta{ step = num } end
	return self
end

function Field:default( ... )
	return self:meta{ default_value = {...} }
end

function Field:resetDefaultValue( obj )
	local defaultValue = self:getMeta( 'default_value', nil )
	if defaultValue == nil then
		local ftype = self:getType()
		defaultValue = getDefaultValueForType( ftype )
	end
	if defaultValue then 
		self:setValue( obj, unpack( defaultValue ) )
		return true
	else
		return false
	end
end

function Field:get( getter )
	if type(getter) == 'string' then
		local getterName = getter
		getter = function( obj )
			local f = obj[getterName]
			if f then return f( obj ) else 
				error( format( 'getter not found: %s -> %s', self.__model.__name, getterName ) )
			end
		end
	end
	self.__getter = getter
	return self
end

function Field:set( setter )
	if type(setter) == 'string' then
		local setterName = setter
		setter = function( obj, ... )
			local f = obj[setterName]
			if f then return f( obj, ... ) else 
				error( format( 'setter not found: %s -> %s', self.__model.__name, setterName ) )
			end
		end
	end
	self:_setSetterFunc( setter )
	-- self.__setter = setter
	return self
end

function Field:getset( fieldName )
	return self:get('get'..fieldName):set('set'..fieldName)
end

--use a generic tuple value getter/setter
function Field:tuple_getset( fieldId )
	self.__is_tuple = true
	local id = fieldId or self.__id
	self.__getter = function( obj )
		local k = obj[ id ]
		if k then return unpack( k ) end		
	end
	self:_setSetterFunc(
		function( obj, ... )
			obj[ id ] = { ... }		
		end
	)
	return self
end


--generic multiple fields getter/setter
function Field:fields_getset( ... )	
	self.__is_tuple = true
	local fieldList = ''
	local argList = ''
	local ids = {...}
	for i, id in ipairs( ids ) do
		assert( type( id ) == 'string' )
		if i > 1 then
			fieldList = fieldList..','
			argList    = argList..','
		end
		fieldList = fieldList..format( 'obj[%q]', id )		
		argList    = argList..('arg'..i)
	end
	---setter
	local getterCode = 'return function( obj ) return '..fieldList..'end'
	local getterFunc = loadstring( getterCode )()
	---setter	
	local setterCode = format(
		'return function( obj, %s ) %s = %s end',
		argList, fieldList, argList
	)
	local setterFunc = loadstring( setterCode )()
	---
	self.__getter = getterFunc
	self:_setSetterFunc( setterFunc )
	return self	
end


function Field:onset( methodName )	
	local setter0 = self.__setter
	if setter0 == true then --plain field setting
		local id = self.__id
		self:_setSetterFunc( function( obj, ... )
				obj[ id ] = ...
				local onset = obj[ methodName ]
				if not onset then
					error( 'onset method not found:'..methodName )
				end
				return onset( obj, ... )
			end
		)
	else
		self:_setSetterFunc( function( obj, ... )
				setter0( obj, ... )
				local onset = obj[ methodName ]
				if not onset then
					error( 'onset method not found:'..methodName )
				end
				return onset( obj, ... )
			end
		)
	end
	return self	
end

function Field:on_set( ... )
	return self:onset( ... )
end

function Field:isset( fieldName )
	return self:get('is'..fieldName):set('set'..fieldName)
end

function Field:getValue( obj )
	local getter = self.__getter
	if getter == true then 
		return obj[ self.__id ]
	elseif getter then 
		return getter( obj )
	end
	return nil
end

function Field:setValue( obj, a, ... )
	local setter = self.__setter
	if setter == true then 
		obj[ self.__id ] = a
		return
	elseif setter then
		return setter( obj, a, ... )
	end
end

function Field:_setValueRaw( obj, v )
	obj[ self.__id ] = v
end

function Field:_setValueSetter( obj, ... )
	return self.__setter( obj, ... )
end

function Field:_setValueNull( obj, v )
end

function Field:_setSetterFunc( setter )
	self.__setter = setter
	-- if setter == true then
	-- 	self.setValue = self._setValueRaw
	-- elseif setter then
	-- 	self.setValue = self._setValueSetter
	-- else
	-- 	self.setValue = self._setValueNull
	-- end
end

local function _compareTable( t, t1 )
	local n = 0
	for k, v in pairs( t ) do
		local v1 = t1[ k ]
		if v1 ~= v then return false end
		n = n + 1
	end
	local n1 = 0
	for _, v in pairs( t1 ) do
		n1 = n1 + 1
	end
	return n1 == n 
end

function Field:checkAndSetValue( obj, ... )
	local v0 = { self:getValue( obj ) }
	local v1 = { ... }
	if _compareTable( v0, v1 ) then return end
	return self:setValue( obj, ... )
end

function Field:getIndexValue( obj, idx )
	local t = self:getValue( obj )	
	return t[idx]
end

function Field:setIndexValue( obj, idx, v )
	local t = self:getValue( obj )	
	t[idx] = v
end

function Field:getId()
	return self.__id
end

function Field:getType()
	return self.__type
end

function Field:getMeta( key, default )
	local v
	if self.__meta then 
		v= self.__meta[key]
	end
	if v == nil then return default end
	return v
end

--------------------------------------------------------------------
--FieldGroup
--------------------------------------------------------------------
CLASS: FieldGroup ()	
function FieldGroup:__init( id )
	self.__id = id
	self.__children = {}
end

function FieldGroup:__call( t )
	local tt = type( t )
	if tt == 'string' then
		self.__name = t
		return self
	elseif tt == 'table' then
		local children = {}
		self.__children = children
		for i, f in ipairs( t ) do
			local mt = getmetatable( f )
			if mt == Field or mt == FieldGroup then
				insert( children, f )
				f.__group = self
			elseif f == '----' then
				insert( children, f )
			else
				error( 'Field/FieldGroup expected in Model, given:'..type( f ), 3 )
			end
		end
		return self
	else
		error( 'invalid FieldGroup usage' )
	end
end

function FieldGroup:getChildren()
	return self.__children
end

function FieldGroup:_addChild( f )
	insert( self.__children, f )
end

function FieldGroup:label( label )
	self.__label = label
end

function FieldGroup:folded()
	self.__folded = true
end

--------------------------------------------------------------------
---CLASS Replacement?
--------------------------------------------------------------------
function findClassesFromEnv( env )
	local collected = {}
	for key , clas in pairs( globalClassRegistry )  do
		if clas.__env == env then
			collected[ key ] = clas
		end
	end
	return collected
end

function releaseClassesFromEnv( env )
	local toremove = findClassesFromEnv( env )
	for key, clas in pairs( toremove ) do
		globalClassRegistry[ key ] = nil
	end
	return toremove
end


--------------------------------------------------------------------
CLASS: MoaiModel (Model)
function MoaiModel:newinstance( ... )
	return self.__src_class.new()
end

--------------------------------------------------------------------
separatorField = Field('----') :no_save() :no_edit()
--------------------------------------------------------------------

local ENUMProto = {}
function ENUMProto:__EXTEND( t )
	local t1 = table.simplecopy( self )
	for i, entry in ipairs( t ) do
		table.insert( t1, entry )	
	end
	return _ENUM( t1 )
end

function ENUMProto:__EXTEND_V( t )
	local t1 = table.simplecopy( self )
	local entries = {}
	for i, id in ipairs( t ) do
		table.insert( t1, { id, id } )	
	end
	return _ENUM( t1 )
end

function ENUMProto:__EXTEND_I( t )
	local t1 = table.simplecopy( self )
	local count = #t1
	for i, id in ipairs( t ) do
		local i1 = i + count
		t1[ i1 ] = { id, i1 }
	end
	return _ENUM( t1 )
end

local ENUM_MT = { __index = ENUMProto }

--some utils
function _ENUM( t )
	return setmetatable( t, ENUM_MT )
end

function _ENUM_I( t )
	local t1 = {}
	for i, id in ipairs( t ) do
		t1[ i ] = { id, i }
	end
	return _ENUM( t1 )
end

function _ENUM_V( t )
	local t1 = {}
	for i, id in ipairs( t ) do
		t1[ i ] = { id, id }
	end
	return _ENUM( t1 )
end

-- function _ENUM_NAME( enum, value, fallback )
-- 	for i, entry in ipairs( enum ) do
-- 		local n, v = unpack( entry )
-- 		if value == v then return n end
-- 	end
-- 	return fallback or nil
-- end
-- print( _G )