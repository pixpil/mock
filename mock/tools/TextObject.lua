module 'mock'
--UTF8 text object
local u8len     = utf8.len
local u8sub     = utf8.sub
local u8reverse = utf8.reverse
local u8char    = utf8.char
local u8unicode = utf8.unicode
local u8gensub  = utf8.gensub
local u8byte    = utf8.byte
local u8find    = utf8.find
local u8match   = utf8.match
local u8gmatch  = utf8.gmatch
local u8gsub    = utf8.gsub
local u8align   = utf8.align
local u8pos     = utf8.pos
local u8bytepos = utf8.bytepos
local u8dump    = utf8.dump
local u8format  = utf8.format
local u8lower   = utf8.lower
local u8upper   = utf8.upper
local u8rep     = utf8.rep

local u8charbytes = utf8.charbytes

--------------------------------------------------------------------
CLASS: TextObject ()

function TextObject:__init( str )
	self.str = str or ''
end

function TextObject:__tostring()
	return self.str
end

function TextObject:__eq( s )
	return self:eq( s )
end

function TextObject.__concat( a, b )
	return TextObject( tostring( a ) .. tostring( b ) )
end

function TextObject:get()
	return self.str
end

function TextObject:concat( s )
	local s1 = self.str .. tostring( s )
	return TextObject( s1 )
end

function TextObject:eq( s )
	local tt = type( s )
	if tt == 'string' then
		return self.str == s
	end
	if tt == 'table' then
		if isInstance( s, TextObject ) then
			return self.str == s.str
		end
	end
	return false
end

function TextObject:len()
	return u8len( self.str )
end

function TextObject:sub( ... )
	return u8sub( self.str, ... )
end

function TextObject:reverse()
	return u8reverse( self.str )
end

function TextObject:find( pattern, plain )
	return u8find( self.str, pattern, plain )
end

function TextObject:match( pattern )
	return u8match( self.str, pattern )
end

function TextObject:gmatch( pattern )
	return u8gmatch( self.str, pattern )
end

function TextObject:gsub( pattern, ... )
	return TextObject( u8gsub( self.str, pattern, ... ) )
end

function TextObject:pos( bpos )
	return u8pos( self.str, bpos )
end

function TextObject:format( ... )
	return TextObject( u8format( self.str, ... ) )
end

function TextObject:lower()
	return TextObject( u8lower( self.str ) )
end

function TextObject:upper()
	return TextObject( u8upper( self.str ) )
end

function TextObject:rep( n )
	return TextObject( u8rep( self.str, n ) )
end

--byte op
function TextObject:bytelen()
	return #self.str
end

function TextObject:align( bpos )
	return u8align( self.str, bpos )
end

function TextObject:bytepos( upos )
	return u8bytepos( self.str, upos )
end

--edit support
function TextObject:split( upos )
	local str = self.str
	local bpos = u8bytepos( str, upos )
	local s1 = str:sub( 1, bpos )
	local s2 = str:sub( bpos1 )
	return TextObject(s1), TextObject(s2)
end

function TextObject:set( s )
	self.str = s
end

function TextObject:clear()
	self.str = ''
end

function TextObject:prepend( s )
	self.str = tostring(s) .. self.str
end

function TextObject:append( s )
	self.str = self.str .. tostring(s)
end

function TextObject:remove( upos, usize )
	local str = self.str
	local bpos = u8bytepos( str, upos )
	local b0 = bpos
	local l = #str
	
	for i = 1, usize do
		local bsize = u8charbytes( str, bpos )
		bpos = bpos + bsize
		if bpos >= l then break end
	end
	local s1 = str:sub( 1, b0 -1 ) or ''
	local s2 = str:sub( bpos ) or ''
	self.str = s1 .. s2
end

function TextObject:insert( upos, t )
	local str = self.str
	local t = tostring( t )
	local l = self:len()
	if l == upos then --end
		self.str = self.str .. t
	else
		local b0 = u8bytepos( str, upos + 1 ) or #str
		self.str = 
			( str:sub( 1, b0 - 1  ) or '' )
			..
			t
			..
			( str:sub( b0 ) or '' )
	end
end

function TextObject:bsub( i, i )
	return self.str:sub( i, i )
end

