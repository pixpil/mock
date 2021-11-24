module 'mock'

CLASS: UpdateListener ( Component )
	:MODEL{
		Field 'active' :boolean() :isset('Active');
	}

function UpdateListener:__init()
	self.active = true
	self.isActive = function()
		return self.active
	end
end

function UpdateListener:isActive()
	return self.active
end

function UpdateListener:setActive( a )
	self.active = a ~= false
end

function UpdateListener:onStart()
	self:start( true )
end

function UpdateListener:onDetach( entity )
	self:stop()
end

function UpdateListener:onUpdate( dt )
end

function UpdateListener:start( initialStarting )
	self._entity.scene:addUpdateListener( self )
end

function UpdateListener:stop()
	self._entity.scene:removeUpdateListener( self )
end
