module 'mock'

--------------------------------------------------------------------
CLASS: PhysicsShape ( mock.Component )
	:MODEL{
		-- Field 'edit'     :action('editShape') :meta{ icon='edit', style='tool'};
		Field 'active'   :boolean();
		Field 'tag'       :string();
		Field 'loc'       :type('vec2') :getset('Loc') :label('Loc'); 
		Field 'material'  :asset_pre( 'physics_material' ) :getset( 'Material' );
	}
	:META{
		category = 'physics'
	}
	
function PhysicsShape:__init()
	self.active = true 
	self.tag = false
	self.materialPath = false
	self.material = false
	self.loc = { 0,0 }
	self.shape = false
	self.parentBody = false
end

function PhysicsShape:clone(original)
	original = original or self
	-- make copy from derived class
	local copy = self.__class()
	copy:setMaterial(original:getMaterial())
	copy.loc = { original.loc[1], original.loc[2] }
	return copy
end


function PhysicsShape:getTag()
	return self.tag
end

function PhysicsShape:setTag( tag )
	self.tag = tag
	if self.shape then
		self.shape.tag = self.tag
	end
end

function PhysicsShape:setLoc( x,y )
	self.loc = { x or 0, y or 0 }
	self:updateShape()
end

function PhysicsShape:getLoc()
	return unpack( self.loc )
end

function PhysicsShape:getBox2DWorld()
	return self:getScene():getBox2DWorld()
end

function PhysicsShape:findBody()
	local body = self._entity:getComponent( PhysicsBody )
	return body
end

function PhysicsShape:getBody()
	return self.parentBody
end

function PhysicsShape:getBodyTag()
	return self.parentBody:getTag()
end

function PhysicsShape:affirmMaterial()
	local material = self.material
	if not material then 
		material = self:getDefaultMaterial():clone()
		self.material = material
	end
	return material
end

function PhysicsShape:isSensor()
	if self.material then
		return self.material.isSensor
	end
	return false
end

function PhysicsShape:setSensor( sensor )
	local shape = self.shape
	if not shape then return end
	local material = self:affirmMaterial()
	material.isSensor = sensor or false
	shape:setSensor( sensor or false )
	self.parentBody:updateMass()
end


function PhysicsShape:getDensity()
	if self.material then
		return self.material.density
	end
	return false
end

function PhysicsShape:setDensity( density )
	local shape = self.shape
	if not shape then return end
	local material = self:affirmMaterial()
	material.density = density or 1
	shape:setDensity( density )
	self.parentBody:updateMass()
end


function PhysicsShape:getFriction()
	if self.material then
		return self.material.friction
	end
	return false
end

function PhysicsShape:setFriction( friction )
	local shape = self.shape
	if not shape then return end
	local material = self:affirmMaterial()
	material.friction = friction or 1
	shape:setFriction( friction )
end


function PhysicsShape:getRestitution()
	if self.material then
		return self.material.restitution
	end
	return false
end

function PhysicsShape:setRestitution( restitution )
	local shape = self.shape
	if not shape then return end
	local material = self:affirmMaterial()
	material.restitution = restitution or 1
	shape:setRestitution( restitution )
end

function PhysicsShape:getMaterial()
	return self.materialPath
end

function PhysicsShape:setMaterial( path )
	self.materialPath = path
	if path then
		local material = loadAsset( path ) 
		self.sourceMaterial = material
		self.material = material:clone()
	else
		self.material = false
	end
	self:updateMaterial()
end

function PhysicsShape:resetMaterial()
	if not self.sourceMaterial then
		self.material = false
	else
		self.material = self.sourceMaterial:clone()
	end
	return self:updateMaterial()
end

function PhysicsShape:getMaterialTag()
	return self.material and self.material.tag
end

function PhysicsShape:getDefaultMaterial()
	return self.parentBody and self.parentBody:getDefaultMaterial() or getDefaultPhysicsMaterial()
end

function PhysicsShape:updateMaterial()
	local shape = self.shape
	if not shape then return end
	local material = self:affirmMaterial()
	shape:setDensity      ( material.density )
	shape:setFriction     ( material.friction )
	shape:setRestitution  ( material.restitution )
	shape:setSensor       ( material.isSensor )
	-- print('categoryBits: ', bit.tohex(material.categoryBits), ' maskBits: ', bit.tohex(material.maskBits))
	shape:setFilter       ( 
		material.categoryBits or 1,
		material.maskBits or 0xffff,
		material.group or 0
	)
	self.parentBody:updateMass()
	shape.materialTag = material.tag
end


local lshift  = bit.lshift
local rshift  = bit.rshift
local band    = bit.band
local bor     = bit.bor
local bxor    = bit.bxor
local bnot    = bit.bnot
function PhysicsShape:setFilterGroup( group1 )
	local shape = self.shape
	if not shape then return end
	local category, mask, group = shape:getFilter()
	return shape:setFilter( category, mask, group1 )
end

function PhysicsShape:setFilterMaskBit( bitId, value )
	local shape = self.shape
	if not shape then return end
	local category, mask, group = shape:getFilter()
	if value then
		mask = bor( mask, lshift( 1, bitId ) )
	else
		mask = band( mask, bnot( lshift( 1, bitId ) ) )
	end
	return shape:setFilter( category, mask, group )
end

function PhysicsShape:setFilterCategoryBit( bitId, value )
	local shape = self.shape
	if not shape then return end
	local category, mask, group = shape:getFilter()
	if value then
		category = bor( category, lshift( 1, bitId ) )
	else
		category = band( category, bnot( lshift( 1, bitId ) ) )
	end
	return shape:setFilter( category, mask, group )
end

function PhysicsShape:getFilter()
	local material = self:affirmMaterial()
	return material.categoryBits, material.maskBits, material.group
end

function PhysicsShape:setFilter( categoryBits, maskBits, group )
	local shape = self.shape
	if not shape then return end
	local material = self:affirmMaterial()
	
	shape:setSensor       ( material.isSensor )
	shape:setFilter(
		categoryBits or material.categoryBits or 1,
		maskBits or material.maskBits or 0xff,
		group or material.group or 0 )

	-- update owned copy of material as well
	material.categoryBits = categoryBits
	material.maskBits     = maskBits
	material.group        = group
end

function PhysicsShape:resetFilter()
	local sourceMaterial = self.sourceMaterial
	if sourceMaterial then
		self:setFilter( 
			sourceMaterial.categoryBits or 1, 
			sourceMaterial.maskBits or 0xffff,
			sourceMaterial.group or 0
		)
	end
end

function PhysicsShape:onAttach( entity )
	if not self.parentBody then
		for com in pairs( entity:getComponents() ) do
			if isInstance( com, PhysicsBody ) then
				if com.body then
					self:updateParentBody( com )
				end
				break
			end
		end		
	end
end

function PhysicsShape:onDetach( entity )
	if not self.shape then return end
	if self.parentBody and self.parentBody.body then
		self.shape:destroy()
		self.shape.component = nil
		self.shape = false
	end
end

function PhysicsShape:updateParentBody( body )
	self.parentBody = body
	self:updateShape()
end

function PhysicsShape:getParentBody()
	return self.parentBody
end

function PhysicsShape:updateShape()
	if not self.active then return end
	local shape = self.shape
	if shape then 
		shape.component = nil
		shape:destroy()
		self.shape = false
	end

	local parentBody = self.parentBody
	if not parentBody then return end
	local body = parentBody.body
	shape = self:createShape( body )
	-- back reference to the component
	shape.component = self
	self.shape = shape
	shape.tag = self.tag
	--apply material
	--TODO
	self:updateMaterial()
	self:updateCollisionHandler()
end

function PhysicsShape:createShape( body )
	local shape = body:addCircle( 0,0, 100 )
	return shape
end

function PhysicsShape:setCollisionHandler(handler, phaseMask, categoryMask)
	self.handlerData = {
		func         = handler,
		phaseMask    = phaseMask,
		categoryMask = categoryMask
	}
	return self:updateCollisionHandler()
end

function PhysicsShape:updateCollisionHandler()
	if not self.shape then return end
	if not self.handlerData then return end
	self.shape:setCollisionHandler(
		self.handlerData.func,
		self.handlerData.phaseMask,
		self.handlerData.categoryMask
	)
end

function PhysicsShape:getCollisionHandler()
	if self.handlerData then
		return self.handlerData.func, self.handlerData.phaseMask, self.handlerData.categoryMask
	end
end

function PhysicsShape:getLocalVerts( steps )
	return {}
end

function PhysicsShape:getGlobalVerts( steps )
	local localVerts = self:getLocalVerts( steps )
	local globalVerts = {}
	local ent = self:getEntity()
	local count = #localVerts/2
	ent:forceUpdate()
	for i = 0, count - 1 do
		local x = localVerts[ i * 2 + 1 ]
		local y = localVerts[ i * 2 + 2 ]
		local x, y = ent:modelToWorld( x, y )
		table.append( globalVerts, x, y )
	end
	return globalVerts
end
