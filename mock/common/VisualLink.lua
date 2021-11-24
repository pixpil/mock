module 'mock'

CLASS: VisualLink ( Component )
	:MODEL{
		Field 'target' :type( mock.Entity ) :getset('Target');
		Field 'linkColor' :boolean();
		Field 'linkVisibility' :boolean();
	}
mock.registerComponent( 'VisualLink', VisualLink ) 


function VisualLink:__init()
	self.linkColor = true
	self.linkVisibility = true
end

function VisualLink:onAttach( ent )
	self:applyLink()
end

function VisualLink:setTarget( t )
	self.target = t
	local ent = self._entity
	if ent and ent.started then
		self:applyLink()
	end
end

function VisualLink:getTarget()
	return self.target
end

function VisualLink:applyLink()
	if self.target then
		if self.linkColor then
			inheritColor( self._entity:getProp( 'physics' ), self.target:getProp( 'physics' ) )
		end
		if self.linkVisibility then
			inheritVisible( self._entity:getProp( 'physics' ), self.target:getProp( 'physics' ) )
		end
	end		
end