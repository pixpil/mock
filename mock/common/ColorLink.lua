module 'mock'

CLASS: ColorLink ( Component )
	:MODEL{
		Field 'target' :type( mock.Entity ) :getset('Target');
	}

mock.registerComponent( 'ColorLink', ColorLink )
--mock.registerEntityWithComponent( 'ColorLink', ColorLink )

function ColorLink:__init()
end

function ColorLink:getTarget()
	return self.target
end

function ColorLink:setTarget( t )
	self.target = t
	local ent = self._entity
	if ent and ent.started then
		self:applyLink()
	end
end

function ColorLink:onStart()
	self:applyLink()
end

function ColorLink:applyLink()
	if self.target then
		inheritColor( self._entity:getProp(), self.target:getProp() )
	end		
end

