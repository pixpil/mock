module 'mock'

CLASS: WrapList ()

function WrapList:__init( capacity )
	self.capacity = capacity or 32

	local body = {}
	self.body = body

	local seq = 0
	local function _push( data )
		seq = seq + 1
		local i = seq % capacity
		body[ i + 1 ] = data
	end

	local function _get( idx )
		local i = (seq - (idx - 1)) % capacity
		return body[ i + 1 ]
	end

	local function _clear()
		seq = 0
		body = {}
		self.body = body
	end

	local function _seq()
		return seq
	end

	self._push = _push
	self._get  = _get
	self._seq  = _seq
	self._clear = _clear
end

function WrapList:get( idx )
	return self._get( idx or 1 )
end
	
function WrapList:push( data )
	return self._push( data )
end

function WrapList:clear()
	return self._clear()
end

function WrapList:getCapacity()
	return self.capacity
end

function WrapList:getSeq()
	return self._seq()
end

function WrapList:getSize()
	local seq = self._seq()
	return math.min( seq, self.capacity )
end

function WrapList:data()
	local size = self:getSize()
	local output = {}
	local _get = self._get
	for i = 1, size do
		output[ i ] = _get( i )
	end
	return output
end