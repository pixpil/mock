module 'mock'
--------------------------------------------------------------------
--SOUND Listener
--------------------------------------------------------------------
--TODO: add multiple listener support (need host works) ?
CLASS: SoundListener ( Component )
:MODEL{
	Field 'idx'            :int();
	'----';
	Field 'weight'         :number()  :getset( 'Weight' );
	'----';
	Field 'forward'        :type('vec3') :getset('VectorForward');
	Field 'up'             :type('vec3') :getset('VectorUp') ;
	Field 'syncRot'        :boolean();
	Field 'updateVelocity' :boolean();
}
:META{
	category = 'audio'
}
wrapWithMoaiTransformMethods( SoundListener, '_listener' )

function SoundListener:__init()
	self.idx = 1
	self._listener = false
	self.syncRot = true

	self.weight = 1
	self.updateVelocity = false
	self:setVectorForward( 0,0,-1 )
	self:setVectorUp( 0,1,0 )
	self.active = true
end

function SoundListener:onAttach( entity )
	self:updateBinding()
end

function SoundListener:setIndex( idx )
	if idx == self.idx then return end
	self.idx = idx
	self:updateBinding()
end

function SoundListener:getIndex()
	return self.idx
end

function SoundListener:updateBinding()
	if not self._entity then return end

	local audioManager = AudioManager.get()
	local listener0 = self._listener
	local listener = audioManager:getListener( self.idx )
	if listener0 == listener then return end
	
	if listener0 then
		listener0:setWeight( 0 )
		clearInheritTransform( listener0 )
		clearInheritLoc( listener0 )
	end

	if not listener then
		_warn( 'failed to get system sound listener' )
		return
	end
	self._listener = listener

	local entity = self:getEntity()
	local listener = self._listener
	local targetProp = entity:getProp( 'physics' )
	if self.syncRot then
		inheritTransform( listener, targetProp )
	else
		inheritLoc( listener, targetProp )
	end

	listener:setLoc( 0,0,0 )
	listener:forceUpdate()

	if self.updateVelocity then
		self:affirmCoroutine( 'actionUpdateVelocity' )
	else
		self:findAndStopCoroutine( 'actionUpdateVelocity' )
	end

	self:updateVectors()
	self:updateWeight()
end

function SoundListener:setActive( active )
	self.active = active
	self:updateWeight()
end

function SoundListener:isActive()
	return self.active
end

function SoundListener:getWeight()
	return self.weight
end

function SoundListener:setWeight( weight )
	self.weight = weight
	self:updateWeight()
end

function SoundListener:updateWeight()
	local listener = self._listener
	if not listener then return end
	if self.active then
		listener:setWeight( 
			self.weight
		)
	else
		listener:setWeight( 
			0
		)
	end
end

function SoundListener:updateVectors()
	local _listener = self._listener
	if not _listener then return end
	local x, y, z = unpack( self.forward )
	_listener:setVectorForward( x,y,z )
	local x, y, z = unpack( self.up )
	_listener:setVectorUp( x,y,z )
end

function SoundListener:onDetach( entity )
	local listener0 = self._listener
	if listener0 then
		listener0:setWeight( 0 )
		clearInheritTransform( listener0 )
		clearInheritLoc( listener0 )
	end
end

function SoundListener:getVectorForward()
	return unpack( self.forward )
end

function SoundListener:setVectorForward( x,y,z )
	self.forward = { x,y,z }
	self:updateVectors()
end

function SoundListener:getVectorUp()
	return unpack( self.up )
end

function SoundListener:setVectorUp( x,y,z )
	self.up = { x,y,z }
	self:updateVectors()
end

function SoundListener:actionUpdateVelocity()
	local ent = self:getEntity()
	local x, y, z = ent:getWorldLoc()
	local _listener = self._listener
	while true do
		local dt = coroutine.yield()
		ent:forceUpdate()
		local x1, y1, z1 = ent:getWorldLoc()
		if dt > 0 then
			local vx = (x1 - x)/dt
			local vy = (y1 - y)/dt
			local vz = (z1 - z)/dt
			_listener:setVelocity( vx, vy, vz )
		end
	end
end

registerComponent( 'SoundListener', SoundListener )

