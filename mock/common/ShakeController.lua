module 'mock'

local min, max, clamp = math.min, math.max, math.clamp

--------------------------------------------------------------------
CLASS: ShakeController ( Behaviour )
	:MODEL{
		Field 'scale';
	}
registerComponent( 'ShakeController', ShakeController )


function ShakeController:__init()
	self.shakeSources = {}
	self.scale = 1
	self.totalShakeStrength = 0
end

function ShakeController:getScale()
	return self.scale
end

function ShakeController:setScale( scl )
	self.scale = scl
end

function ShakeController:pushShakeSource( src )
	self.shakeSources[ src ] = true
	if not self.threadShaking then
		self.threadShaking = self:addRootCoroutine( 'actionShaking' )
	end
	return src
end

function ShakeController:findShakeSource( name )
	for src in pairs( self.shakeSources ) do
		if src.name == name then return src end
	end
end

function ShakeController:stopShakeSource( name )
	for src in pairs( self.shakeSources ) do
		if src.name == name then src:stop() end
	end
end

function ShakeController:stopShakeSourceGroup( g )
	for src in pairs( self.shakeSources ) do
		if src.group == g then src:stop() end
	end
end

function ShakeController:pushShakeSourceX( scale, duration )
	local src = ShakeSourceX()
	src:setScale( scale )
	src:setDuration( duration )
	return self:pushShakeSource( src )
end

function ShakeController:pushShakeSourceY( scale, duration )
	local src = ShakeSourceY()
	src:setScale( scale )
	src:setDuration( duration )
	return self:pushShakeSource( src )
end

function ShakeController:pushShakeSourceXY( scale, duration )
	local src = ShakeSourceXY()
	src:setScale( scale )
	src:setDuration( duration )
	return self:pushShakeSource( src )
end

function ShakeController:pushShakeSourceXYRot( scale, duration )
	local src = ShakeSourceXYRot()
	src:setScale( scale )
	src:setDuration( duration )
	return self:pushShakeSource( src )
end

function ShakeController:pushShakeSourceDirectional( nx, ny, nz, duration )
	local src = ShakeSourceDirectional()
	src:setScale( nx, ny, nz )
	src:setDuration( duration )
	return self:pushShakeSource( src )
end

function ShakeController:clear()
	self.shakeSources = {}
end

function ShakeController:getTotalShakeStrength()
	return self.totalShakeStrength
end

function ShakeController:actionShaking()
	local target = self:getEntity()
	local px,py,pz = target:getPiv()
	local dt = 0
	while true do
		local sources = self.shakeSources
		local stopped = {}
		local x, y, z = 0,0,0
		local scale = self.scale
		local total = 0
		for src in pairs( sources ) do
			local dx, dy, dz = src:update( dt )
			if not dx then --dead
				stopped[ src ] = true
			else
				if dx then x = x + dx * scale end
				if dy then y = y + dy * scale end
				if dz then z = z + dz * scale end
				total = total + src.strength
			end
		end
		target:setPiv( px+x,py+y,py+z )
		for s in pairs( stopped ) do
			sources[ s ] = nil
		end
		self.totalShakeStrength = total
		if not next( sources ) then break end
		dt = coroutine.yield()
	end
	target:setPiv( px, py, pz )
	self.threadShaking = false
end


--------------------------------------------------------------------
CLASS: ShakeSource ()
function ShakeSource:__init()
	self.time  = 0
	self.noise = 0.2
	self.duration = 1
	self.strength = 1
	self.active = true
	self.name = false
	self.group = false
	self.exponent = 1
end

function ShakeSource:setGroup( g )
	self.group = g
end

function ShakeSource:setName( n )
	self.name = n
end

function ShakeSource:setExponent( e )
	self.exponent = e
end

function ShakeSource:stop()
	self.active = false
end

function ShakeSource:setConstant()
	self.duration = -1
end

function ShakeSource:isConstant()
	return self.duration <= 0
end

function ShakeSource:getDuration()
	return self.duration
end

function ShakeSource:setDuration( d )
	self.duration = d
end

function ShakeSource:resetTime()
	self.time = 0
end

function ShakeSource:calcStrength()
	if self.duration <= 0 then
		return 1
	else
		local k = clamp( 1 - self.time/self.duration, 0, 1 )
		return k^self.exponent
	end
end

function ShakeSource:getStrength()
	return self.strength
end

function ShakeSource:setNoise( noise )
	self.noise = noise
end

function ShakeSource:update( dt )
	if not self.active then return false end
	self.time = self.time + dt
	self.strength = ( self:calcStrength() or 1 ) * ( 1 + noise( self.noise ) )
	if self:isDone() then return false end
	return self:onUpdate( self.time )
end

function ShakeSource:isDone()
	local duration = self.duration
	if duration <= 0 then return false end
	if not self.active then return true end
	return self.time >= duration
end

function ShakeSource:onUpdate( t )
	return nil
end


--------------------------------------------------------------------
--------------------------------------------------------------------
CLASS: ShakeSourceX ( ShakeSource )
	:MODEL{}

function ShakeSourceX:__init()
	self.scale = 5
	self.negative = false
end

function ShakeSourceX:setScale( scale )
	self.scale = scale
end

function ShakeSourceX:onUpdate( t )
	local strength = self:getStrength()
	self.negative = not self.negative
	local dx = self.scale * strength
	if self.negative then
		dx = - dx
	end
	return dx
end


--------------------------------------------------------------------
CLASS: ShakeSourceY ( ShakeSource )
	:MODEL{}

function ShakeSourceY:__init()
	self.scale = 5
	self.negative = false
end

function ShakeSourceY:setScale( scale )
	self.scale = scale
end

function ShakeSourceY:onUpdate( t )
	local strength = self:getStrength()
	self.negative = not self.negative
	local dy = self.scale * strength
	if self.negative then
		dy = - dy
	end
	return 0, dy
end

--------------------------------------------------------------------
CLASS: ShakeSourceXY ( ShakeSource )
	:MODEL{}

function ShakeSourceXY:__init()
	self.scale = 5
	self.nx = true
	self.ny = false
end

function ShakeSourceXY:setScale( scale )
	self.scale = scale
end

function ShakeSourceXY:onUpdate( t )
	local strength = self:getStrength()
	self.nx = not self.nx
	self.ny = not self.ny
	local dx = self.scale * strength
	if self.nx then
		dx = - dx
	end
	local dy = self.scale * strength
	if self.ny then
		dy = - dy
	end
	return dx, dy
end


--------------------------------------------------------------------
CLASS: ShakeSourceXYRot ( ShakeSource )
	:MODEL{}

function ShakeSourceXYRot:__init()
	self.scale = 5
	self.dir = 0
end

function ShakeSourceXYRot:setScale( scale )
	self.scale = scale
end

function ShakeSourceXYRot:onUpdate( t )
	local strength = self:getStrength()
	self.dir = self.dir + rand( 90, 180 )
	local nx, ny = math.cosd( self.dir ), math.sind( self.dir )
	
	local dx = self.scale * strength * nx
	local dy = self.scale * strength * ny
	return dx, dy
end


--------------------------------------------------------------------
CLASS: ShakeSourceDirectional ( ShakeSource )
	
function ShakeSourceDirectional:__init()
	self.negative = false
end

function ShakeSourceDirectional:setScale( x, y, z )
	self.sx = x or 0
	self.sy = y or 0
	self.sz = z or 0
end

function ShakeSourceDirectional:onUpdate( t )
	local strength = self:getStrength()
	self.negative = not self.negative
	local dx = self.sx * strength
	local dy = self.sy * strength
	local dz = self.sz * strength
	if self.negative then
		dx = -dx * 0.5
		dy = -dy * 0.5
		dz = -dz * 0.5
	end
	return dx, dy, dz
end

