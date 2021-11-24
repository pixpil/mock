module 'mock'

CLASS: TransformShear ( mock.Component )
	:MODEL{
		Field 'shearByX' :type( 'vec2' ) :getset( 'ShearByX' );
		Field 'shearByY' :type( 'vec2' ) :getset( 'ShearByY' );
		Field 'shearByZ' :type( 'vec2' ) :getset( 'ShearByZ' );
}

mock.registerComponent( 'TransformShear', TransformShear )

function TransformShear:__init()
	self.sx1, self.sx2 = 0, 0
	self.sy1, self.sy2 = 0, 0
	self.sz1, self.sz2 = 0, 0
end

function TransformShear:onAttach( ent )
	self:updateShear()
end

function TransformShear:onDetach( ent )
	ent:setShearByX( 0, 0 )
	ent:setShearByY( 0, 0 )
	ent:setShearByZ( 0, 0 )
end

function TransformShear:getShearByX()
	return self.sx1, self.sx2
end

function TransformShear:setShearByX( a, b )
	self.sx1, self.sx2 = a, b
	self:updateShear()
end

function TransformShear:getShearByY()
	return self.sy1, self.sy2
end

function TransformShear:setShearByY( a, b )
	self.sy1, self.sy2 = a, b
	self:updateShear()
end

function TransformShear:getShearByZ()
	return self.sz1, self.sz2
end

function TransformShear:setShearByZ( a, b )
	self.sz1, self.sz2 = a, b
	self:updateShear()
end

function TransformShear:updateShear()
	local ent = self._entity
	if not ent then return end
	ent:setShearByX( self.sx1, self.sx2 )
	ent:setShearByY( self.sy1, self.sy2 )
	ent:setShearByZ( self.sz1, self.sz2 )
end
