module 'mock'

--------------------------------------------------------------------
CLASS: PhysicsShapeBox ( PhysicsShape )
	:MODEL{
		Field 'w' :set('setWidth');
		Field 'h' :set('setHeight');
		Field 'rotation' :set('setRotation');
		'----';
		Field 'Match size' :action('matchSize');
	}

mock.registerComponent( 'PhysicsShapeBox', PhysicsShapeBox )

function PhysicsShapeBox:__init()
	self.w = 100
	self.h = 100
	self.rotation = 0
end

function PhysicsShapeBox:clone(original)
	local copy = PhysicsShapeBox.__super.clone(self, original)

	original = original or self
	copy.w = original.w
	copy.h = original.h
	copy.rotation = original.rotation

	return copy
end

function PhysicsShapeBox:createShape( body )	
	local w = self.w
	local h = self.h
	local x, y = self:getLoc()
	local shape = body:addRect( 
			x-w/2, y-h/2, x+w/2, y+h/2, self.rotation/180 * math.pi
		)
	return shape
end

function PhysicsShapeBox:setWidth( w )
	self.w = w
	self:updateShape()
end

function PhysicsShapeBox:setHeight( h )
	self.h = h
	self:updateShape()
end

function PhysicsShapeBox:getSize()
	return self.w, self.h
end

function PhysicsShapeBox:setSize( w, h )
	self.w = w
	self.h = h
	self:updateShape()
end

function PhysicsShapeBox:setRotation( rotation )
	self.rotation = rotation
	self:updateShape()
end

function PhysicsShapeBox:getRotation()
	return self.rotation
end

function PhysicsShapeBox:matchSize()
	local deck = self._entity:com(mock.DeckComponent)
	if deck then
		local x1,y1,z1, x2,y2,z2 = deck.prop:getBounds()

		self.w = x2 - x1
		self.h = y2 - y1

		self:setLoc((x1 + x2)/2, (y1+y2)/2)

		self:updateShape()
	end
end

function PhysicsShapeBox:getLocalVerts()
	local transform = MOAITransform.new()
	transform:setLoc( self:getLoc() )
	transform:setRot( 0,0, self.rotation )
	transform:forceUpdate()
	local x0, y0, x1, y1 = -self.w/2, -self.h/2, self.w/2, self.h/2
	local result = {}
	local x, y = transform:modelToWorld( x0, y0 )
	table.append( result, x, y )
	local x, y = transform:modelToWorld( x1, y0 )
	table.append( result, x, y )
	local x, y = transform:modelToWorld( x1, y1 )
	table.append( result, x, y )
	local x, y = transform:modelToWorld( x0, y1 )
	table.append( result, x, y )
	return result
end
