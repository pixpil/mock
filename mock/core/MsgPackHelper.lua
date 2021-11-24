module 'mock'

local luastream = require 'luastream'
local insert = table.insert
local select = select
local tconcat = table.concat

local mp_pack = cmsgpack.pack
local mp_unpack = cmsgpack.unpack
local mp_unpack_one = cmsgpack.unpack_one
local mp_unpack_limit = cmsgpack.unpack_limit

local function clearNullUserdata( t )
	for k,v in pairs( t ) do
		local tt = type( v )
		if tt == 'table' then
			clearNullUserdata( v )
		elseif tt == 'userdata' then
			t[ k ] = nil
		end
	end	
end


function loadMsgPackFile( path, clearNulls )
	local stream = MOAIFileStream.new()
	stream:open( path, MOAIFileStream.READ )
	local indexString, indexSize = stream:read()
	local data = mp_unpack( indexString )
	stream:close()
	if not data then
		return nil
	end
	if clearNulls then
		clearNullUserdata( data )
	end
	return data
end


function loadLuaStreamFile( path, clearNulls )
	local stream = MOAIFileStream.new()
	stream:open( path, MOAIFileStream.READ )
	local indexString, indexSize = stream:read()
	stream:close()
	local lstream = luastream.new( indexString )
	return lstream:read()
end



--------------------------------------------------------------------
CLASS: MsgPackDecoder ()

function MsgPackDecoder:__init()
	self.inputData = false
	self.offset = 0
end

function MsgPackDecoder:open( filePath )
	local buf = MOAIDataBuffer.new()
	buf:load( filePath )
	self.inputData = buf:getString()
	return true
end

function MsgPackDecoder:setData( data )
	self.inputData = data
	self.offset = 0
end

function MsgPackDecoder:_output( off, ... )
	self.offset = off
	return ...
end

function MsgPackDecoder:seek( offset )
	self.offset = offset
end

function MsgPackDecoder:reset()
	self.offset = 0
end

function MsgPackDecoder:decode( limit )
	if limit then
		return self:_output( mp_unpack_limit( self.inputData, limit, self.offset ) )
	else
		if self.offset > 0 then
			return self:_output( mp_unpack_limit( self.inputData, 1000000, self.offset ) )
		else
			self.offset = #self.inputData
			return mp_unpack( self.inputData )
		end
	end
end

function MsgPackDecoder:decodeT( limit )
	return { self:decode( limit ) }
end

function MsgPackDecoder:decodeOne()
	local off, result = mp_unpack_one( self.inputData, self.offset )
	self.offset = off
	return result
end

MsgPackDecoder.__call = MsgPackDecoder.decode


--------------------------------------------------------------------
CLASS: MsgPackEncoder ()

function MsgPackEncoder:__init()
	self.output = {}
end

function MsgPackEncoder:addOne( v )
	local packed = mp_pack( v )
	local output = self.output
	output[#output+1] = packed
end

function MsgPackEncoder:add( ... )
	local packed = mp_pack( ... )
	local output = self.output
	output[#output+1] = packed
end

function MsgPackEncoder:getData()
	return tconcat( self.output )
end

function MsgPackEncoder:tostring()
	return self:getData()
end

function MsgPackEncoder:save( f )
	local stream = MOAIFileStream.new()
	stream:open( f, MOAIFileStream.WRITE )
	local output = self.output 
	for i = 1, #output do
		stream:write( output[ i ])
	end
	stream:close( f )
end

function MsgPackEncoder:saveAsync( f, ... )
	local buf = MOAIDataBuffer.new()
	buf:setString( self:tostring() )
	return buf:saveAsync( f, ... )
end

MsgPackEncoder.__call = MsgPackEncoder.add
