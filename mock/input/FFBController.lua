module 'mock'

local _RootFFBControllerGroup
local _FFBControllerGroupRegistry

--------------------------------------------------------------------
CLASS: FFBControllerGroup ()

function FFBControllerGroup:__init()
	self.name = 'group'
	self.parent = false
	self.childGroups = {}

	self.controllers = {}
	self.controllerCahce = {}
	self.dirty = true

	self.vibrationA = 0
	self.vibrationB = 0
end

-- function FFBControllerGroup:setData( a, b )
-- 	if a then self.vibrationA = a end
-- 	if b then self.vibrationB = b end
-- end

-- function FFBControllerGroup:sendData( a, b )
-- 	if a then self.vibrationA = self.vibrationA + a end
-- 	if b then self.vibrationB = self.vibrationB + b end
-- end

-- function FFBControllerGroup:flushData()
-- 	local controllerCache = self:affirmControllerCache()
-- 	for controller in pairs( controllerCache ) do
-- 		controller:setVibration( self.vibrationA, self.vibrationB )
-- 	end
-- end

function FFBControllerGroup:affirmControllerCache()
	if not self.dirty then
		return self.controllerCache
	end
	local result = table.simplecopy( self.controllers )
	for child in pairs( self.childGroups ) do
		local cache = child:affirmControllerCache()
		for controller in pairs( cache ) do
			result[ controller ] = true
		end
	end
	self.controllerCache = result
	self.dirty = false
	return result
end

function FFBControllerGroup:clear()
	--TODO
	for child in pairs( self.childGroups ) do
		child:clear()
	end
	self.childGroups = {}
	self.controllers = {}
	self.controllerCache = {}
	self.dirty = false
end

function FFBControllerGroup:markDirty()
	if self.dirty then return end
	local p = self
	while p do
		p.dirty = true
		p = p.parent
	end
end

function FFBControllerGroup:removeController( controller )
	if controller.group ~= self then
		return false
	end
	self.controllers[ controller ] = nil
	controller.group = false
	self:markDirty()
	return true
end

function FFBControllerGroup:addController( controller )
	if controller.group == self then return end
	if controller.group then
		controller.group:removeController( controller )
	end
	self.controllers[ controller ] = true
	controller.group = self
	self:markDirty()
end

function FFBControllerGroup:addChildGroup( group )
	group:setParent( self )
end

function FFBControllerGroup:setParent( parent )
	parent = parent or false
	if self.parent == parent then return end
	if self.parent then
		self.parent.childGroups[ self ] = nil
	end
	self.parent = parent
	if parent then
		parent.childGroups[ self ] = true
	end
end

function FFBControllerGroup:getParent()
	return self.parent
end

function FFBControllerGroup:getName()
	return self.name
end

function FFBControllerGroup:setName( n )
	self.name = n
end

--------------------------------------------------------------------
CLASS: FFBController ()
	:MODEL{}

function FFBController:__init( targetSensor )
	self.group = false
	self.active = true
	self.targetSensor = false
	local controlNode = MOAIScriptNode.new() 
	self.controlNode = controlNode
	self.controlNode:reserveAttrs( 4 )
	self.controlNode:setAttr( 1, 0 ) --L
	self.controlNode:setAttr( 2, 0 ) --R
	self.controlNode:setAttr( 3, 1 ) --scl
	self.controlNode:setAttr( 4, 1 ) --global Scl

	local player = getFFBPlayer()
	self.controlNode:setAttrLink( 4, player.controlNode, 1 ) --link to global scale controller
	local function _updateVibiration()
		local sensor = self.targetSensor
		if not sensor then return end
		local l = controlNode:getAttr( 1 )	
		local r = controlNode:getAttr( 2 )	
		local scl = controlNode:getAttr( 3 )
		local gscl = controlNode:getAttr( 4 )
		return sensor:setVibration( l * scl * gscl, r * scl * gscl )
	end
	controlNode:setCallback( _updateVibiration )
	self.controlNodeCallback = _updateVibiration
	if targetSensor then
		return self:setTargetSensor( targetSensor )
	end
end

function FFBController:getGroup()
	return self.group
end

function FFBController:setGroup( g )
	if type( g ) == 'string' then
		local group = _FFBControllerGroupRegistry[ g ]
		if not group then
			_error( 'no FFB controller group', g )
			return
		end
		g = group
	end
	
	if g then
		assert( g:isInstance( FFBControllerGroup ) )
		return g:addController( self )
	elseif self.group then
		return self.group:removeController( self )
	end
	
end

function FFBController:setTargetSensor( sensor )
	self.targetSensor = sensor
end

function FFBController:getTargetSensor()
	return self.targetSensor
end

function FFBController:refresh()
	if not self.targetSensor then return end
	if self.active then
		self.controlNode:setCallback( self.controlNodeCallback )
		self.controlNode:forceUpdate()
	else
		self.targetSensor:setVibration( 0, 0 )
		self.controlNode:setCallback( nil )
	end
end

function FFBController:setActive( active )
	self.active = active ~= false
	self:refresh()
end

function FFBController:getScl()
	return self.controlNode:getAttr( 3 )
end

function FFBController:setScl( scl )
	return self.controlNode:setAttr( 3, scl or 1 )
end

function FFBController:seekScl( scl, duration, easeType )
	return self.controlNode:seekAttr( 3, scl, duration, easeType )
end

function FFBController:setVibration( left, right )
	self:setVibrationL( left )
	self:setVibrationR( right )
end

function FFBController:getVibration()
	return self:getVibrationL(), self:getVibrationR()
end

function FFBController:getVibrationL()
	return self.controlNode:getAttr( 1 )
end

function FFBController:setVibrationL( l )
	return self.controlNode:setAttr( 1, l )
end

function FFBController:seekVibrationL( strength, duration, easeType )
	return self.controlNode:seekAttr( 1, strength, duration, easeType )
end

function FFBController:getVibrationR()
	return self.controlNode:getAttr( 2 )
end

function FFBController:setVibrationR( r )
	return self.controlNode:setAttr( 2, r )
end

function FFBController:seekVibrationR( strength, duration, easeType )
	return self.controlNode:seekAttr( 2, strength, duration, easeType )
end

function FFBController:getControlNode()
	return self.controlNode
end

--------------------------------------------------------------------
_FFBControllerGroupRegistry = {}

_RootFFBControllerGroup = FFBControllerGroup()
_RootFFBControllerGroup:setName( '__root' )
_FFBControllerGroupRegistry[ '__root' ] = _RootFFBControllerGroup

function getRootFFBControllerRegistry()
	return _FFBControllerGroupRegistry
end

function getRootFFBControllerGroup()
	return _RootFFBControllerGroup
end

function getFFBControllerGroup( name )
	return _FFBControllerGroupRegistry[ name ]
end

local function _assertGroupInstance( g )
	if type( g ) == 'string' then
		g = _FFBControllerGroupRegistry[ g ]
	end
	return assertInstanceOf( g, FFBControllerGroup )
end

function affirmFFBControllerGroup( name, parentGroup )
	local group = _FFBControllerGroupRegistry[ name ]
	if not group then
		group = FFBControllerGroup()
		if not parentGroup then
			parentGroup = _RootFFBControllerGroup
		end
		_assertGroupInstance( parentGroup ):addChildGroup( group )
		_FFBControllerGroupRegistry[ name ] = group
	end
	return group
end

function removeFFBControllerGroup( name )
	local g = _FFBControllerGroupRegistry[ name ]
	if g then
		_FFBControllerGroupRegistry[ name ] = nil
		g:clear()
		g:setParent( false )
	end
end

