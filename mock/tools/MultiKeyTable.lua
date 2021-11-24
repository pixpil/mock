module 'mock'

CLASS: TwoKeyTable ()

function TwoKeyTable:__init()
	self.data = {}
	self._affirmFunc = false
end

function TwoKeyTable:get( x, y, default )
	local row = self.data[ x ]
	if not row then return default end
	local v = row[ y ]
	if v == nil then return default end
	return v
end

function TwoKeyTable:set( x, y, v )
	local data = self.data
	local row = data[ x ]
	if not row then
		row = {}
		data[ x ] = row
	end
	row[ y ] = v
	return v
end

function TwoKeyTable:setAffirmFunction( f )
	self._affirmFunc = f
end

function TwoKeyTable:affirm( x, y, default )
	local data = self.data
	local row = data[ x ]
	if not row then
		row = {}
		data[ x ] = row
	end
	local v = row[ y ]
	if v == nil then
		local affirm = self._affirmFunc
		if affirm then
			v = affirm( x, y )
			if v == nil then
				v = default
			end
		else
			v = default
		end
		row[ y ] = v
	end
	return v
end

