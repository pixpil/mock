local isInstance = isInstance
local insert, remove = table.insert, table.remove

--------------------------------------------------------------------

CLASS: ObjectPool ()
	:MODEL{}

function ObjectPool:__init( targetClass, minSize, maxSize )
	assert( isClass( targetClass ), 'Class expected' )
	local pool = {}
	
	self.pool = pool
	self.minPoolSize = minSize or 0
	self.maxPoolSize = maxSize or 64
	self.targetClass = targetClass
	--validate support API
	local support =
		type( targetClass[ 'onPoolIn' ] ) == 'function'
		and type( targetClass[ 'onPoolOut' ] ) == 'function'
	assert( support, 'no ObjectPool function found in '..tostring( targetClass ) ) 

end

function ObjectPool:push( object )
	-- assert( isInstance( object, targetClass ) )
	local size = self:getSize()
	if size >= self.maxPoolSize then
		return false
	end
	object:onPoolIn()
	insert( self.pool, 1, object )
	return true
end

function ObjectPool:pop()
	local object = remove( self.pool, 1 )
	if object then
		object:onPoolOut()
	end
	return object
end

function ObjectPool:request()
	local o = self:pop()
	if o then return o end
	o = self.targetClass()
	return o
end

function ObjectPool:getSize()
	return #self.pool
end

function ObjectPool:isEmpty()
	return self:getSize() == 0
end

function ObjectPool:isFull()
	return self:getSize() >= self.maxPoolSize
end

function ObjectPool:clear()
	self.pool = {}
end

function ObjectPool:fill( size, ... )
	if not size then --fill up to max
		size = self.minPoolSize - self:getSize()
	end
	if size <= 0 then return end
	local targetClass = self.targetClass
	for i = 1, size do
		local o = targetClass( ... )
		self:push( o )
	end
end

