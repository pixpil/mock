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


--------------------------------------------------------------------
local insert = table.insert
local setmetatable = setmetatable

local staticHolder = {}

local signalProto = {}
local signalMT = {
	__index = signalProto
}
local weakMT = {
	-- __mode  = 'v',
}

local function isSignal( sig )
	return getmetatable( sig ) == signalMT
end

local function newSignal()
	local signal =  setmetatable( { 
			seq   = 0,
			filters = false,
			slots = setmetatable( {}, weakMT ) 
		}, 
		signalMT
		)
	return signal
end

local function signalConnect( sig, obj, func )
	sig.slots[ obj ] = func
	return obj, func
end

local function signalConnectMethod( sig, obj, methodId )
	local method = assert( obj[ methodId ], 'method not found' )
	return signalConnect( sig, obj, method )
end

local function signalConnectFunc( sig, func )
	sig.slots[ func ] = staticHolder
	return func
end

local function signalDisconnect( sig, obj )
	sig.slots[ obj ] = nil
end

local function signalDisconnectAll( sig )
	sig.slots = {}
end

local function signalEmit( sig, ... )
	sig.seq = sig.seq + 1
	local filters = sig.filters
	if filters then
		for i, filter in ipairs( filters ) do
			local filtered = filter( sig, ... )
			if filtered then return end --intercepted
		end
	end
	local slots = sig.slots
	for obj, func in pairs( slots ) do
		if func == staticHolder then
			obj( ... )
		else
			func( obj, ... )
		end
	end
end

signalMT.__call = signalEmit

function signalProto:clearAndConnect( a, b )
	self:disconnectAll()
	return self:connect( a, b )
end

function signalProto:connect( a, b )
	if (not b) and ( type( a ) == 'function' ) then --function connection
		return signalConnectFunc( self, a )
	elseif type( b ) == 'string' then
		func = a[ b ]
		return signalConnect( self, a, func )
	else
		return signalConnect( self, a, b )
	end
end

function signalProto:disconnect( a )
	return signalDisconnect( self, a )
end

function signalProto:disconnectAll()
	return signalDisconnectAll( self )
end

function signalProto:emit( ... )
	return signalEmit( self, ... )
end

function signalProto:addFilter( filter, append )
	if not self.filters then
		self.filters = { filter }
	else
		if append then
			return insert( self.filters, filter )
		else
			return insert( self.filters, 1, filter )
		end
	end
end

function signalProto:removeFilter( filter )
	local filters = self.filters
	if filters then
		table.removevalue( filters, filter )
	end
end

function signalProto:getSeq()
	return self.seq
end

local function _getFuncInfo( f )
	local info = debug.getinfo( f, 'S' )
	return string.format( '%s:%d', info['source'], info['linedefined'] )
end

function signalProto:printConnections()
	for obj, func in pairs( self.slots ) do
		if func == staticHolder then
			print( _getFuncInfo( obj ) )
		else
			print( obj, _getFuncInfo( func ) )
		end
	end
end

--------------------------------------------------------------------
--GLOBAL SIGALS
--------------------------------------------------------------------
local globalSignalTable = setmetatable( {}, { __no_traverse = true } )

local function registerGlobalSignal( sigName )
	--TODO: add module info for unregistration
	assert( type(sigName) == 'string', 'signal name should be string' )
	local sig = globalSignalTable[sigName]
	if sig then 
		_warn('duplicated signal name:'..sigName)
	end
	sig = newSignal()
	globalSignalTable[sigName] = sig
	return sig
end

local function registerGlobalSignals( sigTable )
	for i,k in ipairs( sigTable ) do
		registerGlobalSignal( k )
		--TODO: add module info for unregistration
	end	
end

local function getGlobalSignal( sigName )
	local sig = globalSignalTable[ sigName ]
	if not sig then 
		return error( 'signal not found:'..sigName )
	end
	return sig
end

local function connectGlobalSignalFunc( sigName, func )
	local sig = getGlobalSignal( sigName )
	signalConnectFunc( sig, func )
	return sig
end

local function connectGlobalSignalMethod( sigName, obj, methodname )
	local sig = getGlobalSignal(sigName)
	local method = assert( obj[ methodname ], 'method not found' )
	signalConnect( sig, obj, method )
	return sig
end

local function disconnectGlobalSignal( sigName, obj )
	local sig = getGlobalSignal(sigName)
	signalDisconnect( sig, obj )
end

local function emitGlobalSignal( sigName, ... )
	local sig = getGlobalSignal( sigName )
	return signalEmit( sig, ... )
end

local function getGlobalSignalSeq( sigName )
	local sig = getGlobalSignal( sigName )
	return sig and sig.seq
end

--------------------------------------------------------------------
--EXPORT
--------------------------------------------------------------------

_G.newSignal             = newSignal
_G.isSignal              = isSignal
_G.signalConnect         = signalConnect
_G.signalConnectMethod   = signalConnectMethod
_G.signalConnectFunc     = signalConnectFunc
_G.signalEmit            = signalEmit
_G.signalDisconnect      = signalDisconnect

--------------------------------------------------------------------
_G.registerSignal        = registerGlobalSignal
_G.registerGlobalSignal  = registerGlobalSignal
_G.registerSignals       = registerGlobalSignals
_G.registerGlobalSignals = registerGlobalSignals

_G.getSignal             = getGlobalSignal
_G.connectSignalFunc     = connectGlobalSignalFunc
_G.connectSignalMethod   = connectGlobalSignalMethod
_G.disconnectSignal      = disconnectGlobalSignal
_G.emitSignal            = emitGlobalSignal

_G.getGlobalSignal             = getGlobalSignal
_G.getGlobalSignalSeq          = getGlobalSignalSeq
_G.connectGlobalSignal         = connectGlobalSignalFunc
_G.connectGlobalSignalFunc     = connectGlobalSignalFunc
_G.connectGlobalSignalMethod   = connectGlobalSignalMethod
_G.disconnectGlobalSignal      = disconnectGlobalSignal
_G.emitGlobalSignal            = emitGlobalSignal
