module 'mock'

CLASS: BufferedTable ()

function BufferedTable:__init( size, isize, hsize ) --todo: table.create
	size = size or 2
	self.size = size
	self.cursor = 1
	for i = 1, size do
		self[ i ] = {}
	end
end

function BufferedTable:table()
	return self[ self.cursor ]
end

function BufferedTable:get( k )
	local t = self[ self.cursor ]
	return t[ k ]
end

function BufferedTable:set( k, v )
	local t = self[ self.cursor ]
	t[ k ] = v
end

function BufferedTable:swap( clear )
	local c0 = self.cursor
	if clear then
		table.clear( self[ c0 ] )
	end
	local c1 = c0 % self.size + 1
	self.cursor = c1
	return self[ c1 ]
end

function BufferedTable:clear()
	for i = 1, self.size do
		table.clear( self[ i ] )
	end
end
