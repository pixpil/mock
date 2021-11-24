module 'mock'

require 'luabins'
local lbin_load_values = luabins.load_values
local lbin_save_values = luabins.save_values


--------------------------------------------------------------------
CLASS: LuaBinsDecoder ()

function LuaBinsDecoder:__init()
	self.inputData = false
	self.offset = 0
end

function LuaBinsDecoder:open( filePath )
	local buf = MOAIDataBuffer.new()
	buf:load( filePath )
	self.inputData = buf:getString()
	return true
end

function LuaBinsDecoder:setData( data )
	self.inputData = data
	self.offset = 0
end

function LuaBinsDecoder:_output( succ, off, ... )
	if succ then
		self.offset = off
		return ...
	else
		error( 'decoder error', succ )
	end
end

function LuaBinsDecoder:seek( offset )
	self.offset = offset
end

function LuaBinsDecoder:reset()
	self.offset = 0
end

function LuaBinsDecoder:decode( count )
	if count then
		return self:_output( lbin_load_values( self.inputData, self.offset, count ) )
	else
		error( 'todo' )
		if self.offset > 0 then
			return self:_output( lbin_load_values( self.inputData, self.offset, 1000000 ) )
		else
			self.offset = #self.inputData
			return mp_unpack( self.inputData )
		end
	end
end

function LuaBinsDecoder:decodeT( count )
	return { self:decode( count ) }
end

LuaBinsDecoder.__call = LuaBinsDecoder.decode

--------------------------------------------------------------------
CLASS: LuaBinsEncoder ()

function LuaBinsEncoder:__init()
	self.output = {}
end

function LuaBinsEncoder:addOne( v )
	local packed = lbin_save_values( v )
	local output = self.output
	output[#output+1] = packed
end

function LuaBinsEncoder:add( ... )
	local packed = lbin_save_values( ... )
	local output = self.output
	output[#output+1] = packed
end

function LuaBinsEncoder:getData()
	return table.concat( self.output )
end

function LuaBinsEncoder:tostring()
	return self:getData()
end

function LuaBinsEncoder:save( f )
	local stream = MOAIFileStream.new()
	stream:open( f, MOAIFileStream.WRITE )
	local output = self.output 
	for i = 1, #output do
		stream:write( output[ i ])
	end
	stream:close( f )
end

function LuaBinsEncoder:saveAsync( f, ... )
	local buf = MOAIDataBuffer.new()
	buf:setString( self:tostring() )
	return buf:saveAsync( f, ... )
end

LuaBinsEncoder.__call = LuaBinsEncoder.add