module 'mock'


CLASS: EntityPool ()

function EntityPool:__init()
	local count = 0
	local maxCount = 0
	local minCount = 0
	local pool = {}

	self.push = function( _, ent )
		if count < maxCount then
			count = count + 1
			pool[ count ] = ent
			return true
		else
			return false
		end
	end

	self.pop = function( _ )
		if count > 0 then
			local e = pool[ count ]
			count = count - 1
			return e
		else
			return false
		end
	end

	self.getCount = function( _ )
		return count
	end

	self.setup = function( _, _min, _max )
		minCount = _min
		maxCount = _max
	end

	self.clean = function()
		for i = count, minCount + 1, -1 do
			pool[ i ] = false
		end	
		count = minCount
	end

end

--------------------------------------------------------------------
CLASS: Poolable ( Component )
	:MODEL{}



---------------------------------------------------------------------
CLASS: EntityPoolManager ( GlobalManager )
	:MODEL{}

function EntityPoolManager:__init()
	self.poolRegistry = {}
end

function EntityPoolManager:getRegistry( tag )
	return self.poolRegistry[ tag ]
end

function EntityPoolManager:pushEntity( ... )
	-- body
end


EntityPoolManager()
