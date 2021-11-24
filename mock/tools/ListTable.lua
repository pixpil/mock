module 'mock'

local insert, remove = table.insert, table.remove
--------------------------------------------------------------------
CLASS: ListTable ()

function ListTable:__init()
	self.data = {}
end

function ListTable:lists()
	return pairs( self.data )
end

function ListTable:getList( key )
	return self.data[ key ]
end

function ListTable:affirmList( key )
	local data = self.data
	local t = data[ key ]
	if not t then
		t = {}
		data[ key ] = t
	end
	return t
end

function ListTable:insert( key, value )
	local t = self:affirmList( key )
	table.insert( t, value )
end

function ListTable:remove( key, idx )
	local t = self.data[ key ]
	if t then
		return remove( t, idx )
	end
end

function ListTable:insertUnique( key, value )
	local t = self:affirmList( key )
	if table.index( t, value ) then return end
	return table.insert( t, value )
end

function ListTable:removeValue( key, value )
	local t = self.data[ key ]
	if t then
		for i = 1, #t do
			if t[ i ] == value then
				remove( t, i )
				return value
			end
		end
	end
end
