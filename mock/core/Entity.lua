--[[ 
	Copyright (c) 2013-2018 Pixpil Games. All Rights Reserved.
	http://www.pixpil.com
]]

--------------------------------------------------------------------
-- The basic element of scenegraph.
-- @classmod Entity
--------------------------------------------------------------------

module 'mock'
--------------------------------------------------------------------
local insert, remove = table.insert, table.remove
local sort = table.sort
local pairs, ipairs  = pairs, ipairs
local unpack = unpack
local next   = next
local type   = type
local weakt  = table.weak
--------------------------------------------------------------------
----- ENTITY CLASS
--------------------------------------------------------------------

---------------------------------------------------------------------
CLASS: Entity ( Actor )
	:MODEL{
		--prefab
		Field '__prefabId':string() :no_edit();
		
		--internal
		Field '_priority' :int() :no_edit()  :set('setPriority');

		--name
		Field 'name'      :string()  :getset('Name');
		'----';
		Field 'tags'      :string()  :getset('TagString');
		Field '__gizmoIcon'  :string() :getset('Icon') :selection( 'getIconSelection' ) :label( 'Icon');
		'----';
		Field 'visible'   :boolean() :get('isLocalVisible') :set('setVisible');
		-- Field 'active'    :boolean() :get('isLocalActive')  :set('setActive');		
		Field 'layer'     :type('layer')  :getset( 'Layer' ) :no_nil() :no_sync();
		'----';
		Field 'color'     :type('color')  :getset('Color') ;
		'----';
		Field 'loc'       :type('vec3') :getset('Loc') :label('Loc'); 
		Field 'rot'       :type('vec3') :getset('Rot') :label('Rot');
		Field 'scl'       :type('vec3') :getset('Scl') :label('Scl') :meta{ step = 0.1 } :default( 1,1,1 );
		Field 'piv'       :type('vec3') :getset('Piv') :label('Piv');
		'----';
		Field 'worldLoc' :type('vec3') :get( 'getWorldLoc' ) :readonly();	

		Field '_fullname' :string() :get('getFullName') :no_edit();

		extra_size = 10;
	}
	

wrapWithMoaiPropMethods( Entity, '_prop' )
local setupMoaiTransform = setupMoaiTransform

Entity.__accept = false

-- function Entity:getWorldLoc()
-- 	-- print( self, singletraceback() )
-- 	-- return self._prop:getWorldLoc()
-- 	return self._prop:getLoc()
-- end
--------------------------------------------------------------------
-------init
--------------------------------------------------------------------
--change this to use other MOAIProp subclass as entity prop
local newProp = MOCKProp.new
function Entity:_createEntityProp()
	return newProp()
end

--create proxy object for ide editor
function Entity:_createTransformProxy()
	return false
end

local _PRIORITY = 1
function Entity:__init()
	local _prop = self:_createEntityProp()
	self._prop       = _prop

	self.__gizmoIcon  = false
	
	_PRIORITY = _PRIORITY + 1
	self._priority   = _PRIORITY

	self._maxComponentID = 0

	self.scene       = false --not loaded yet
	self.components  = {}
	self.children    = {}
	-- self.timers      = false
	self.name        = false
	
	--TODO: move this into MOCKProp
	self.active      = true
	self.localActive = true

	self.suspendCount  = 0
	self.started     = false
	
	self._entityGroup = false
	self._editLocked  = false
	self._comCache    = {}
	
	self._fullname    = false

	self._tag = false

	--lift high frequency function
	self.com = self.com
	self.isVisible = self.isVisible
	self.show = self.show
	self.hide = self.hide
	self.setVisible = self.setVisible

end

function Entity:__tostring()
	return string.format( '%s%s @%s', self:__repr(), self:getFullName() or '???', tostring(self:getSceneSessionName()) )
end

function Entity:_insertIntoScene( scene, layer )
	self.scene = assert( scene )
	local layer = layer or self.layer
	if type(layer) == 'string' then
		layer = scene:getLayer( layer )
	end
	local entityListener = scene.entityListener

	self.layer = layer
	scene.entities[ self ] = true
	scene.entityCount = scene.entityCount + 1

	if self.parent then
		self.parent:_attachChildEntity( self, layer )
	end

	--pre-added children
	if next( self.children ) then
		local children = self:getSortedChildrenList()
		for i, child in ipairs( children ) do
			if not child.scene then
				child:_insertIntoScene( scene, child.layer or layer )
			end
		end
	end

	for i, com in ipairs( self:getSortedComponentList() ) do
		if not com._entity then
			com._entity = self
			local onAttach = com.onAttach
			if onAttach then onAttach( com, self ) end
			if entityListener then
				entityListener( 'attach', self, com )
			end
		end
	end

	self:onLoad()

	if self.onUpdate then
		scene:addUpdateListener( self )
	end

	local onMsg = self.onMsg
	if onMsg then
		self:addMsgListener( function( msg, data, src )
			return onMsg( self, msg, data, src )
		end )
	end
	
	local name = self.name
	if name then
		scene:changeEntityName( self, false, name )
	end

	scene.pendingStart[ self ] = true
	
	--callback
	if entityListener then entityListener( 'add', self, nil ) end
end

function Entity:getProp( role )
	return self._prop
end

function Entity:getEntityGroup( searchParent )
	if searchParent ~= false then
		local p = self
		while p do
			local group = p._entityGroup
			if group then return group end
			p = p.parent
		end
		return false
	else
		return self._entityGroup
	end
end

--------------------------------------------------------------------
------ Destructor
--------------------------------------------------------------------

--------------------------------------------------------------------
--- Destroy the Entity if it's inserted into a scene, deferred. ( scene checking )
---------------------------------------------------------------------
function Entity:tryDestroy()
	if not self.scene then return false end
	return self:destroy()
end

--------------------------------------------------------------------
--- Destroy the Entity, deferred. ( without scene checking, unsafe )
--------------------------------------------------------------------
function Entity:destroy()
	assert( self.scene )
	local scene = self.scene
	scene.pendingDestroy[ self ] = true
	scene.pendingStart[ self ] = nil
	
	for child in pairs( self.children ) do
		child:destroy()
	end

	if self.name then
		scene:changeEntityName( self, self.name, nil )
	end

	return true
end

---------------------------------------------------------------------
-- Destroy the Entity later.
-- @p float delay delaying time to the destruction in seconds
---------------------------------------------------------------------
function Entity:destroyLater( delay )
	assert( self.scene )
	self.scene.laterDestroy[ self ]= self:getTime() + delay
end

---------------------------------------------------------------------
--- Destroy the Entity immediately.
---------------------------------------------------------------------
function Entity:destroyWithChildrenNow()
	for child in pairs( self.children ) do
		child:destroyWithChildrenNow()
	end
	self:_destroyNow()
end

function Entity:destroyAllNow()
	return self:destroyWithChildrenNow()
end

function Entity:_destroyNow()
	local scene     = self.scene
	if not scene then return end

	self:disconnectAll()
	self:clearCoroutines()
	local entityListener = scene.entityListener
	
	--timers
	local timers = self.timers
	if timers then
		for timer in pairs( timers ) do
			timer:stop()
		end
	end

	self:onDestroy( self )

	local components = self.components
	for i, com in ipairs( self:getSortedComponentList( 'reversed' ) ) do
		components[ com ] = nil
		local onDetach = com.onDetach
		if entityListener then
			entityListener( 'detach', self, com )
		end
		if onDetach then
			onDetach( com, self )
		end
		com._entity = nil
	end
	
	local parent = self.parent
	if parent then
		parent:_detachChildEntity( self )
		parent.children[self] = nil
		parent = nil
	end

	if self._entityGroup then
		self._entityGroup:removeEntity( self )
	end
	
	scene:removeUpdateListener( self )
	scene.entities[ self ] = nil
	scene.entityCount = scene.entityCount - 1
	
	--callback
	if entityListener then entityListener( 'remove', self, scene ) end

	self.scene      = false
	self.components = false
	if self._tag then
		self._tag.owner = false
		self._tag = nil
	end
end

--------------------------------------------------------------------
------- Component Attach/Detach
--------------------------------------------------------------------

---------------------------------------------------------------------
--- Attach a component
-- @p Component com the component instance to be attached
-- @ret Component the component attached ( same as the input )
---------------------------------------------------------------------
function Entity:attach( com )
	local components = self.components
	if not components then 
		_error('attempt to attach component to a dead entity')
		return com
	end
	if components[ com ] then
		_log( self.name, tostring( self.__guid ), com:getClassName() )
		error( 'component already attached!!!!' )
	end
	if com.__deprecated then
		_error( 'deprecated component', com, self )
	end
	self._componentInfo = nil
	if next( self._comCache ) then
		self._comCache = {}
	end
	local maxId = self._maxComponentID + 1
	self._maxComponentID = maxId
	com._componentID = maxId
	components[ com ] = com:getClass()
	if self.scene then
		com._entity = self		
		local onAttach = com.onAttach
		if onAttach then onAttach( com, self ) end
		for otherCom in pairs( self.components ) do
			if otherCom ~= com then
				local onOtherAttach = com.onOtherAttach
				if onOtherAttach then
					onOtherAttach( otherCom, self, com )
				end
			end
		end
		local entityListener = self.scene.entityListener
		if entityListener then
			entityListener( 'attach', self, com )
		end
		if self.started then
			local onStart = com.onStart
			if onStart then onStart( com, self ) end
		end
	end

	return com
end

---------------------------------------------------------------------
--- Attach an internal component ( invisible in the editor )
-- @p Component com the component instance to be inserted
-- @ret Component the component attached ( same as the input )
---------------------------------------------------------------------
function Entity:attachInternal( com )
	com.FLAG_INTERNAL = true
	return self:attach( com )
end

---------------------------------------------------------------------
--- Attach an array of components
-- @p {Component} components an array of components to be attached
---------------------------------------------------------------------
function Entity:attachList( components )
	for i, com in ipairs( components ) do
		self:attach( com )
	end
end

---------------------------------------------------------------------
--- Detach given component
-- @p Component com component to be detached
-- @p ?string reason reason to detaching
---------------------------------------------------------------------
function Entity:detach( com, reason, _skipDisconnection )
	local components = self.components
	if not components[ com ] then return end
	components[ com ] = nil
	self._componentInfo = nil
	if next( self._comCache ) then
		self._comCache = {}
	end
	if self.scene then
		local entityListener = self.scene.entityListener
		if entityListener then
			entityListener( 'detach', self, com )
		end
		local onDetach = com.onDetach
		if not _skipDisconnection then
			self:disconnectAllForObject( com )
		end
		if onDetach then onDetach( com, self, reason ) end
		for otherCom in pairs( components ) do
			if otherCom ~= com then
				local onOtherDetach = com.onOtherDetach
				if onOtherDetach then
					onOtherDetach( otherCom, self, com )
				end
			end
		end
	end
	com._entity = nil
	com._suspendState = nil
	return com
end

--- Detach all the components
-- @p ?string reason reason to detaching
function Entity:detachAll( reason )
	local components = self.components
	while true do
		local com = next( components )
		if not com then break end
		self:detach( com, reason, true )
	end
end


---------------------------------------------------------------------
--- Detach all components of given type
-- @p string|Class comType component type to be looked for
-- @p ?string reason reason to detaching
---------------------------------------------------------------------
function Entity:detachAllOf( comType, reason )
	for i, com in ipairs( self:getAllComponentsOf( comType ) ) do
		self:detach( com, reason )
	end
end

---------------------------------------------------------------------
--- Detach all components of given type later
-- @p string|Class comType component type to be looked for
---------------------------------------------------------------------
function Entity:detachAllOfLater( comType )
	for i, com in ipairs( self:getAllComponentsOf( comType ) ) do
		self:detachLater( com )
	end
end

---------------------------------------------------------------------
--- Detach the component in next update cycle
-- @p Component com the component to be detached
---------------------------------------------------------------------
function Entity:detachLater( com )
	if self.scene then
		self.scene.pendingDetach[ com ] = true
	end
end

---------------------------------------------------------------------
--- Get the component table [ com ] = Class
-- @return the component table
---------------------------------------------------------------------
function Entity:getComponents()
	return self.components
end


local function componentSortFunc( a, b )
	return ( a._componentID or 0 ) < ( b._componentID or 0 )
end
local function componentSortFuncReversed( b, a )
	return ( a._componentID or 0 ) < ( b._componentID or 0 )
end
---------------------------------------------------------------------
--- Get the sorted component list
-- @ret {Component} the sorted component array
---------------------------------------------------------------------
function Entity:getSortedComponentList( reversed )
	local list = {}
	local i = 0
	for com in pairs( self.components ) do
		insert( list , com )
	end
	if reversed then
		sort( list, componentSortFuncReversed )
	else
		sort( list, componentSortFunc )
	end
	return list
end

---------------------------------------------------------------------
--- Get the first component of asking type
-- @p Class clas the component class to be looked for
-- @ret Component|nil
---------------------------------------------------------------------
function Entity:getComponent( clas )
	if not self.components then return nil end
	for com, comType in pairs( self.components ) do
		if comType == clas then return com end
		if isClass( comType ) and comType:isSubclass( clas ) then return com end
	end
	return nil
end

---------------------------------------------------------------------
--- Get component by alias
-- @p string alias alias to be looked for
-- @ret Component the found component
---------------------------------------------------------------------
function Entity:getComponentByAlias( alias )
	if not self.components then return nil end
	for com, comType in pairs( self.components ) do
		if com._alias == alias then return com end
	end
	return nil
end

---------------------------------------------------------------------
--- Get component by class name
-- @p string name component class name to be looked for
-- @ret Component the found component
---------------------------------------------------------------------
function Entity:getComponentByName( name )
	if not self.components then return nil end
	for com, comType in pairs( self.components ) do
		while comType do
			if comType.__name == name then return com end		
			comType = comType.__super
		end
	end
	return nil
end

function Entity:getComponentByGUID( guid )
	if not self.components then return nil end
	for com, comType in pairs( self.components ) do
			if com.__guid == guid then return com end		
	end
	return nil
end

---------------------------------------------------------------------
--- Get component either by class name or by class
-- @p nil|string|Class id component type to be looked for, return the first component if no target specified.
-- @ret Component the found component
---------------------------------------------------------------------
function Entity:com( id )
	if not id then
		local components = self.components
		if components then
			return next( components )
		else
			return nil
		end
	end
	
	local cache = self._comCache
	local com = cache[ id ]
	if com ~= nil then
		return com
	end

	local tt = type(id)
	if tt == 'string' then
		com = self:getComponentByName( id ) or false
	elseif tt == 'table' then
		com = self:getComponent( id ) or false
	else
		_error( 'invalid component id', tostring(id) )
	end

	cache[ id ] = com
	return com
end

---------------------------------------------------------------------
--- Check if the entity has given component type
-- @p Class id component type to be looked for
-- @ret boolean result
---------------------------------------------------------------------
function Entity:hasComponent( id )
	return self:com( id ) and true or false
end

---------------------------------------------------------------------
--- Check if the entity owns given component object
-- @p Class com component object to be looked for
-- @ret boolean result
---------------------------------------------------------------------
function Entity:isOwnerOf( com )
	local components = self.components
	if not components then return nil end
	return components[ com ] and true or false
end

---------------------------------------------------------------------
--- Get all components of given type, by class or by class name
-- @p string|Class  component type to be looked for
-- @ret {Component} array of result
---------------------------------------------------------------------
function Entity:getAllComponentsOf( id, searchChildren )
	local result = {}
	local function _collect( e, typeId, result, deep )
		local components = e.components
		if components then
			local tt = type(typeId)
			if tt == 'string' then
				local clasName = typeId
				for com, comType in pairs( components ) do
					while comType do
						if comType.__name == clasName then 
							insert(result, com)
							break
						end		
						comType = comType.__super
					end
				end
			elseif tt == 'table' then
				local clasBody = typeId
				for com, comType in pairs( components ) do
					if comType == clasBody then 
						insert(result, com) 
					elseif isClass( comType ) and comType:isSubclass( clasBody ) then 
						insert(result, com) 
					end
				end
			end
		end

		if deep then
			for child in pairs( e.children ) do
				_collect( child, typeId, result, deep )
			end
		end
		return result
	end

	return _collect( self, id, {}, searchChildren )
end


---------------------------------------------------------------------
--- Create a 'each' accessor for all the attached components
-- @return a 'each' accessor
-- @usage entity:eachComponet():setActive()
---------------------------------------------------------------------
function Entity:eachComponent()
	local list = table.keys( self:getComponents() )
	return eachT( list )
end

---------------------------------------------------------------------
--- Create a 'each' accessor for all the attached components with given type
-- @p string|Class component type
-- @return a 'each' accessor
---------------------------------------------------------------------
function Entity:eachComponentOf( id )
	local list = self:getAllComponentsOf( id )
	return eachT( list )
end

---------------------------------------------------------------------
--- Print attached Components
---------------------------------------------------------------------
function Entity:printComponentClassNames()
	for com in pairs( self.components ) do
		print( com:getClassName() )
	end
end


--------------------------------------------------------------------
------- Attributes Links
--------------------------------------------------------------------
local inheritTransformColor = inheritTransformColor
local inheritTransform      = inheritTransform
local inheritColor          = inheritColor
local inheritVisible        = inheritVisible
local inheritLoc            = inheritLoc

function Entity:_attachProp( p, role )
	local _prop = self:getProp( role )
	p:setPartition( self.layer )
	inheritTransformColorVisible( p, _prop )
	linkScissorRect( p, _prop )
	return p
end

function Entity:_attachPropAttribute( p, role )
	local _prop = self:getProp( role )
	inheritTransformColorVisible( p, _prop )
	return p
end

function Entity:_attachTransform( t, role )
	local _prop = self:getProp( role )
	inheritTransform( t, _prop )
	return t
end

function Entity:_attachLoc( t, role )
	local _prop = self:getProp( role )
	inheritLoc( t, _prop )
	return t
end

function Entity:_attachColor( t, role )
	local _prop = self:getProp( role )
	inheritColor( t, _prop )
	return t
end

function Entity:_attachVisible( t, role )
	local _prop = self:getProp( role )
	inheritVisible( t, _prop )
	return t
end

function Entity:_insertPropToLayer( p )
	p:setPartition( self.layer )
	return p
end

function Entity:_detachProp( p, role )
	p:setPartition( nil )
end

function Entity:_detachVisible( t, role )
	local _prop = self:getProp( role )
	clearInheritVisible( t, _prop )
end

function Entity:_detachColor( t, role )
	local _prop = self:getProp( role )
	clearInheritColor( t, _prop )
end


--------------------------------------------------------------------
------ Child Entity
--------------------------------------------------------------------

---------------------------------------------------------------------
--- Add a sibling entity
-- @p Entity entity entity to be added
-- @p[opt] string layerName name of target layer, default is the same as _self_
---------------------------------------------------------------------
function Entity:addSibling( entity, layerName )	
	if self.parent then
		return self.parent:addChild( entity, layerName )
	else
		return self.scene:addEntity( entity, layerName )
	end
end

---------------------------------------------------------------------
--- Add a entity to same scene
-- @p Entity entity entity to be added
-- @p[opt] string layerName name of target layer, default is the same as _self_
---------------------------------------------------------------------
function Entity:addRootEntity( entity, layerName )
	return self.scene:addEntity( entity, layerName )
end

function Entity:_attachChildEntity( child, layer )
	local _prop = self._prop
	local _p1   = child._prop
	inheritTransformColorVisible( _p1, _prop )
	if not child._scissorRect then
		linkScissorRect( _p1, _prop )
	else
		local rect = self._scissorRect
		child:relinkScissorRect( rect or self:getParentScissorRect() )
		-- child:relinkScissorRect( self:getScissorRect() )
	end
end

function Entity:_detachChildEntity( child )
	local _p1   = child._prop
	clearInheritTransform( _p1 )
	clearInheritColor( _p1 )
	clearInheritVisible( _p1 )
	clearLinkScissorRect( _p1 )
end

---------------------------------------------------------------------
--- Add a child entity
-- @p Entity entity entity to be added
-- @p[opt] string layerName name of target layer, default is the same as _self_
---------------------------------------------------------------------
function Entity:addChild( entity, layerName )
	self.children[ entity ] = true
	entity.parent = self
	entity.layer = layerName or entity.layer or self.layer
	local scene = self.scene
	if scene then
		entity:_insertIntoScene( scene )
	end
	return entity
end

---------------------------------------------------------------------
--- Add a internal child entity
-- @p Entity entity entity to be added
-- @p[opt] string layerName name of target layer, default is the same as _self_
---------------------------------------------------------------------
function Entity:addInternalChild( e, layer )
	e.FLAG_INTERNAL = true
	return self:addChild( e, layer )
end

function Entity:isInternal()
	return self.FLAG_INTERNAL
end

function Entity:addSubEntity( e )
	e.FLAG_INTERNAL = true
	e.FLAG_SUBENTITY = true
	return self:addChild( e )
end

function Entity:isSubEntity()
	return self.FLAG_SUBENTITY
end


---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:isChildOf( e )
	local parent = self.parent
	while parent do
		if parent == e then return true end
		parent = parent.parent
	end
	return false
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:isParentOf( e )
	return e:isChildOf( self )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:hasChild( e )
	return e:isChildOf( self )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getChildren()
	return self.children
end

function Entity:getChildCount()
	return table.len( self.children )
end

local function entitySortFunc( a, b )
	return ( a._priority or 0 ) < ( b._priority or 0 )
end

local function entitySortFuncReversed( b, a )
	return ( a._priority or 0 ) > ( b._priority or 0 )
end
---------------------------------------------------------------------
-- ...
--@todo
---------------------------------------------------------------------
function Entity:getSortedChildrenList( reversed )
	local children = self.children
	if not children then return false end
	local l = table.keys( children )
	if reversed then
		sort( l, entitySortFuncReversed )
	else
		sort( l, entitySortFunc )
	end
	return l
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:clearChildren()
	local children = self.children
	while true do
		local child = next( children )
		if not child then return end
		children[ child ] = nil
		child:destroy()
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:clearChildrenNow()
	local children = self.children
	while true do
		local child = next( children )
		if not child then return end
		children[ child ] = nil
		child:destroyWithChildrenNow()
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getParent()
	return self.parent
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getParentOrGroup() --for editor, return parent entity or group
	return self.parent or self._entityGroup
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:reparentGroup( group )
	if self._entityGroup then
		self._entityGroup:removeEntity( self )
	end
	if group then
		group:addEntity( self )
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:reparent( entity )
	--assert this entity is already inserted
	assert( self.scene , 'invalid usage of reparent' )
	local parent0 = self.parent
	if parent0 then
		parent0.children[ self ] = nil
		parent0:_detachChildEntity( self )
	end
	self.parent = entity
	if entity then
		self:reparentGroup( nil )
		entity.children[ self ] = true
		entity:_attachChildEntity( self )
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findEntity( name )
	return self.scene:findEntity( name )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findEntityCom( entName, comId )
	local ent = self:findEntity( entName )
	if ent then return ent:com( comId ) end
	return nil
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findSibling( name )
	local parent = self.parent
	if not parent then return nil end
	for child in pairs( parent.children ) do
		if child.name == name and child ~= self then return child end
	end
	return nil
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findChildCom( name, comId, deep )
	local ent = self:findChild( name, deep )
	if ent then return ent:com( comId ) end
	return nil
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findParent( name )
	local p = self.parent
	while p do
		if p.name == name then return p end
		p = p.parent
	end
	return nil
end

function Entity:findParentOf( typeName )
	local p = self.parent
	while p do
		if p:isInstance( typeName ) then return p end
		p = p.parent
	end
	return nil
end

function Entity:findParentWithComponent( comType )
	local p = self.parent
	while p do
		if p:hasComponent( comType ) then return p end
		p = p.parent
	end
	return nil
end

function Entity:findChild( name, deep )
	for child in pairs( self.children ) do
		if child.name == name then return child end
		if deep then
			local c = child:findChild( name, deep )
			if c then return c end
		end
	end
	return nil
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findAndDestroyChild( name, deep )
	local child = self:findChild( name, deep )
	if child then
		child:destroy()
		return child
	end
end

function Entity:findAndDestroyChildNow( name, deep )
	local child = self:findChild( name, deep )
	if child then
		child:destroyAllNow()
		return child
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findChildByClass( clas, deep )
	for child in pairs( self.children ) do
		if child:isInstance( clas ) then return child end
		if deep then
			local c = child:findChildByClass( clas, deep )
			if c then return c end
		end
	end
	return nil
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findChildByPath( path )
	local e = self
	for part in string.gsplit( path, '/' ) do
		e = e:findChild( part, false )
		if not e then return nil end
	end
	return e
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:findEntityByPath( path )
	local e = false
	for part in string.gsplit( path, '/' ) do
		if not e then
			e = self:findEntity( part )
		else
			e = e:findChild( part, false )
		end
		if not e then return nil end
	end
	return e
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:foreachChild( func, deep )
	for child in pairs( self.children ) do
		local res = func( child )
		if res == 'stop' then return 'stop' end
		if res == 'out' then return end
		if deep and ( res ~= 'skip' ) then
			local res = child:foreachChild( func, true )
			if res == 'stop' then
				return 'stop'
			end
		end
	end
end

--------------------------------------------------------------------
------ Meta
--------------------------------------------------------------------

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getPriority()
	return self._priority
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setPriority( p )
	self._priority = p
	self._prop:setPriority( p )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getTime()
	return self.scene:getTime()
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setName( name )
	if not self.FLAG_INTERNAL and self.scene then
		local prevName = self.name
		self.scene:changeEntityName( self, prevName, name )
		self.name = name
	else
		self.name = name
	end
	return self
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getName()
	return self.name
end

function Entity:getEntity()
	return self
end

function Entity:getEntityName()
	return self:getName()
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getScene()
	return self.scene
end

function Entity:isSceneReady()
	return self.scene and self.scene.ready
end

function Entity:getUserConfig( key, default )
	if self.scene then
		local v = self.scene:getUserConfig( key )
		if v ~= nil then return v end
	end
	return game:getUserConfig( key, default )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getSceneSession()
	local scene = self.scene
	return scene and scene:getSession()
end

function Entity:getSceneSessionName()
	local scene = self.scene
	return scene and scene:getSessionName()
end


---------------------------------------------------------------------
--- Get scene manager from owner entity's scene
-- @p string name of the scene manager
-- @ret Scene owner scene
--------------------------------------------------------------------
function Entity:getSceneManager( id )
	local scene = self.scene
	return scene and scene:getManager( id )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getActionRoot()
	if self.scene then return self.scene:getActionRoot() end
	return nil
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getFullName( includeGroup )
	if not self.name then return false end
	includeGroup = includeGroup~=false
	local output = self.name
	local n0 = self
	local n = n0.parent
	while n do
		output = (n.name or '<noname>')..'/'..output
		n0 = n
		n = n0.parent
	end
	if includeGroup then
		if n0._entityGroup and not n0._entityGroup:isRootGroup() then
			local groupName = n0._entityGroup:getFullName()
			return groupName..'::'..output
		end
	end
	return output
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getRootGroup()
	local g = self:getEntityGroup()
	while g do
		if g:isRootGroup() then return g end
		g = g.parent
	end
	return nil
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getRootGroupName()
	local r = self:getRootGroup()
	if r then
		return r:getName()
	else
		return nil
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getLayer()
	if not self.layer then return nil end
	if type( self.layer ) == 'string' then return self.layer end
	return self.layer.name
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setLayer( layerName )
	if self.scene then
		local layer = self.scene:getLayer( layerName )
		assert( layer, 'layer not found:' .. layerName )
		self.layer = layer
		for com in pairs( self.components ) do
			local setLayer = com.setLayer
			if setLayer then
				setLayer( com, layer )
			end
		end
	else
		self.layer = layerName --insert later
	end
end

function Entity:getPartition()
	return self.layer:getLayerPartition()
end


---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setIcon( iconName )
	self.__gizmoIcon = iconName
end

function Entity:getIcon()
	return self.__gizmoIcon
end

function Entity:getIconSelection()
	local result = {
		{ '_NONE_', false }
	}
	for key, path in pairs( getEntityIconSet() ) do
		if key ~= 'none' then
			table.insert( result, { key, key, 'icon', path } )
		end
	end
	return result
end


function Entity:onBuildGizmo()
	local iconGiz = nil
	local iconName = self.__gizmoIcon
	if iconName and iconName ~= 'none' then
		local iconSet = getEntityIconSet()
		local iconGiz = mock_edit.IconGizmo( iconSet[ iconName ] )
		-- self.__iconGiz = iconGiz
		return iconGiz
	end
end

function Entity:getTagObject()
	return self._tag
end

function Entity:hasTag( t, searchParent )
	local _tag = self._tag
	if _tag then
		return _tag:has( t, searchParent ) or false
	else
		if not searchParent then
			return false
		else
			local p = self:getParentOrGroup()
			return p:hasTag( t, true )
		end
	end
end

function Entity:affirmTagObject()
	local _tag = self._tag
	if not _tag then
		_tag = EntityTag( self )
		self._tag = _tag
	end
	return _tag
end

function Entity:setTagString( t )
	if t and t ~= '' then
		self:affirmTagObject():setString( t )
	else
		if self._tag then
			self._tag:clear()
		end
	end
end

function Entity:getTagString()
	local _tag = self._tag
	return _tag and self._tag:getString() or ''
end

function Entity:getComponentInfo()
	if self._componentInfo then
		return self._componentInfo
	else
		local info = false
		for i, com in ipairs( self:getSortedComponentList() ) do
			if com.FLAG_INTERNAL or com.FLAG_EDITOR_OBJECT then
				--do nothing
			else
				local name = com:getClassName()
				if info then
					info = info .. ',' .. name
				else
					info = name
				end
			end
		end
		self._componentInfo = info
		return info
	end
end

--------------------------------------------------------------------
---------Visibility Control
--------------------------------------------------------------------

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
local _isVisible = MOCKProp.getInterfaceTable().isVisible
local _isLocalVisible = MOCKProp.getInterfaceTable().isLocalVisible
function Entity:isVisible()
	local prop = self._prop
	return _isVisible( prop )
	-- return _isLocalVisible( prop ) and _isVisible( prop ) --FIXME: why?
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:isLocalVisible()
	return _isLocalVisible( self._prop )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setVisible( visible )
	return self._prop:setVisible( visible )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:show()
	return self:setVisible( true )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:hide()
	return self:setVisible( false )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:toggleVisible()
	return self:setVisible( not self:isLocalVisible() )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:hideChildren()
	for child in pairs( self.children ) do
		child:hide()
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:showChildren()
	for child in pairs( self.children ) do
		child:show()
	end
end

--------------------------------------------------------------------
---Edit lock control
--------------------------------------------------------------------

function Entity:isLocalEditLocked()
	return self._editLocked
end

function Entity:setEditLocked( locked )
	self._editLocked = locked
end

function Entity:isEditLocked()
	if self._editLocked then return true end
	if self.parent then return self.parent:isEditLocked() end
	if self._entityGroup then return self._entityGroup:isEditLocked() end
	return false
end

--------------------------------------------------------------------
------Suspension control
--------------------------------------------------------------------
function Entity:isSuspended()
	return self.suspendCount > 0
end

function Entity:suspend()
	local count1 = self.suspendCount + 1
	self.suspendCount = count1
	if count1 > 1 then return end

	self:onSuspend()
	for i, com in ipairs( self:getSortedComponentList() ) do
		if com._entity then
			local state = com._suspendState
			if not state then
				state = {}
				com._suspendState = state
			end
			if not com.onSuspend then print( com ) end
			com:onSuspend( state )
		end
	end

	for child in pairs( self.children ) do
		child:suspend()
	end

end

function Entity:resurrect()
	local count0 = self.suspendCount
	assert( count0 > 0 )
	local count1 = count0 - 1
	self.suspendCount = count1
	if count1 == 0 then
		self:onResurrect()
		for i, com in ipairs( self:getSortedComponentList() ) do
			if com._entity then
				com:onResurrect( com._suspendState )
			end
			com._suspendState = false
		end

		for child in pairs( self.children ) do
			child:resurrect()
		end
	end
end

--------------------------------------------------------------------
------Active control
--------------------------------------------------------------------
function Entity:start()
	if self.started then return end
	if not self.scene then return end
	
	if self.onStart then
		self:onStart()
	end
	self.started = true

	-- local copy = {} --there might be new components attached inside component starting
	-- for com in pairs( self.components ) do
	-- 	copy[ com ] = true
	-- end
	-- for com, clas in pairs( copy ) do
	-- 	local onStart = com.onStart
	-- 	if onStart then onStart( com, self ) end
	-- end

	for i, com in ipairs( self:getSortedComponentList() ) do
		if com._entity then
			local onStart = com.onStart
			if onStart then onStart( com, self ) end
		end
	end

	for child in pairs( self.children ) do
		child:start()
	end

	if self.onThread then
		self:addCoroutine('onThread')		
	end
	
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setActive( active , selfOnly )	
	active = active or false
	if active == self.localActive then return end
	self.localActive = active
	self:_updateGlobalActive( selfOnly )
end

function Entity:_updateGlobalActive( selfOnly )
	
	local active = self.localActive
	local p = self.parent
	if p then
		active = p.active and active
		self.active = active
	else
		self.active = active
	end

	--inform components
	for com in pairs(self.components) do
		local setActive = com.setActive
		if setActive then
			setActive( com, active )
		end
	end

	--inform children
	selfOnly = selfOnly or false
	if not selfOnly then
		for o in pairs(self.children) do
			o:_updateGlobalActive()
		end
	end

	local onSetActive = self.onSetActive
	if onSetActive then
		return onSetActive( self, active )
	end
end

--------------------------------------------------------------------
function Entity:setSleep()

end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:isStarted()
	return self.started
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:isActive()
	return self.active
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:isLocalActive()
	return self.localActive
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:attachGlobalAction( groupId, action )
	return self.scene:attachGlobalAction( groupId, action )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setActionPriority( action, priority )
	return self.scene:setActionPriority( action, priority )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setCurrentCoroutinePriority( priority )
	local coro = self:getCurrentCoroutine()
	if coro then
		return self:setActionPriority( coro, priority )
	end
end

function Entity:addRootCoroutine( ... )
	local coro = self:addCoroutine( ... )
	coro:attach( self:getActionRoot() )
	return coro
end

function Entity:addRootCoroutineP( ... )
	local coro = self:addCoroutineP( ... )
	coro:attach( self:getActionRoot() )
	return coro
end

function Entity:addGameCoroutine( ... )
	local coro = self:addCoroutine( ... )
	coro:attach( game:getSceneActionRoot() )
	return coro
end

function Entity:addGameCoroutineP( ... )
	local coro = self:addCoroutineP( ... )
	coro:attach( game:getSceneActionRoot() )
	return coro
end

--------------------------------------------------------------------
--Callbacks
--------------------------------------------------------------------
function Entity:onLoad()
end

function Entity:onDestroy()
end

function Entity:onSuspend()
end

function Entity:onResurrect()
end


--------------------------------------------------------------------
------ Child/Component Method invoker
--------------------------------------------------------------------
---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------

local function _onTimerStop( t )
	local owner = t._owner
	owner.timers[ t ] = nil
end

function Entity:createTimer()
	local timers = self.timers
	if not timers then
		timers = {}
		self.timers = timers
	end

	local timer = self.scene:createTimer( _onTimerStop )
	timer._owner = self
	
	timers[ timer ] = true
	return timer
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:invokeUpward( methodname, ... )
	local parent=self.parent
	
	if parent then
		local m=parent[methodname]
		if m and type(m)=='function' then return m( parent, ... ) end
		return parent:invokeUpward( methodname, ... )
	end

end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:invokeChildren( methodname, ... )
	for o in pairs(self.children) do
		o:invokeChildren( methodname, ... )
		local m=o[methodname]
		if m and type(m)=='function' then m( o, ... ) end
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:invokeComponents( methodname, ... )
	for com in pairs(self.components) do
		local m=com[methodname]
		if m and type(m)=='function' then m( com, ... ) end
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:invokeOneComponent( methodname, ... )
	for com in pairs(self.components) do
		local m=com[methodname]
		if m and type(m)=='function' then return m( com, ... ) end
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:tellSelfAndChildren( msg, data, source )
	self:tellChildren( msg, data, source )
	return self:tell( msg, data, source )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:tellChildren( msg, data, source )
	for ent in pairs( self.children ) do
		ent:tellChildren( msg, data, source )
		ent:tell( msg, data, source )
	end
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:tellParent( msg, data, source )
	if not self.parent then return end
	return self.parent:tell( msg, data, source )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:tellSiblings( msg, data, source )
	if not self.parent then return end
	for ent in pairs( self.parent.children ) do
		if ent ~= self then
			return ent:tell( msg, data, source )
		end
	end
end

--------------------------------------------------------------------
--Function caller
--------------------------------------------------------------------

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:callNextFrame( f, ... )
	local scene = self.scene
	if not scene then return end
	local t = {
		func = f,
		object = self,
		...
	}
	insert( scene.pendingCall, t )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:callInterval( interval, func, ... )
	local timer = self:createTimer()
	local args

	if type( func ) == 'string' then
		func = self[func]
		args = { self, ... }
	else
		args = {...}
	end

	timer:setListener( MOAITimer.EVENT_TIMER_END_SPAN, 
		function()
			return func( unpack(args) )
		end
		)
	timer:setMode( MOAITimer.LOOP )
	timer:setSpan( interval )
	return timer
end

local function _callTimerFunc( t )
	return t.__func( unpack(t.__args) )
end

function Entity:callLater( time, func, ... )
	local timer = self:createTimer()
	local args

	if type( func ) == 'string' then
		func = self[func]
		args = { self, ... }
	else
		args = {...}
	end
	timer.__func = func
	timer.__args = args

	timer:setListener( MOAITimer.EVENT_STOP, _callTimerFunc )
	timer:setMode( MOAITimer.NORMAL )
	timer:setSpan( time )
	return timer
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:tellNextFrame( msg, data, source )
	return self:callNextFrame( self.tell, self, msg, data, source )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:tellInterval( interval, msg, data, source )
	return self:callInterval( interval, self.tell, self, msg, data, source )
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:tellLater( time, msg, data, source )
	return self:callLater( time, self.tell, self, msg, data, source )
end

local NewMOAIAction = MOAIAction.new
local EVENT_START = MOAIAction.EVENT_START
local EVENT_STOP  = MOAIAction.EVENT_STOP
---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
local _callActionPool = {}
local function _callActionFunc( act )
	_callActionPool[ #_callActionPool + 1 ] = act
	local f = act.__func
	act.__func = false
	return f()
end

local function popCallAction()
	local action = remove( _callActionPool, 1 )
	if not action then
		action = NewMOAIAction()
		action:setListener( EVENT_STOP, _callActionFunc )
	end
	return action
end

function Entity:callAsAction( func )
	local action = popCallAction()
	action.__func = func
	return action
end

function Entity:_callAsActionPlain( func )
	local action = NewMOAIAction()
	action:setListener( EVENT_STOP, func )
	return action
end

--------------------------------------------------------------------
--Color
--------------------------------------------------------------------

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getColor()
	return self._prop:getColor()
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:getFinalColor()
	return self._prop:getFinalColor()
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function Entity:setColor( r,g,b,a )
	return self._prop:setColor( r or 1, g or 1, b or 1, a or 1 )
end

--------------------------------------------------------------------
----------Transform Conversion
--------------------------------------------------------------------
function Entity:setWorldLoc( x,y,z )
	return self._prop:setWorldLoc( x, y, z )
end

function Entity:setWorldRot( dir )
	return self._prop:setWorldRot( dir )
end

function Entity:wndToWorld( x, y, z )
	local scene = self.scene
	if scene then
			x, y = scene:deviceToContext( x, y )
	end
	return self.layer:wndToWorld( x, y, z )
end

function Entity:worldToWnd( x, y ,z )	
	x, y = self.layer:worldToWnd( x, y ,z )
	local scene = self.scene
	if scene then
		x, y = scene:contextToDevice( x, y )
	end
	return x, y
end

function Entity:worldToProj( x, y ,z )
	return self.layer:worldToProj( x, y ,z )
end

function Entity:worldToView( x, y ,z )
	return self.layer:worldToView( x, y ,z )
end

function Entity:worldToModel( x, y ,z )
	return self._prop:worldToModel( x, y ,z )
end

function Entity:physicsToRender( x, y ,z )
	return x, y, z
end

function Entity:modelToWorld( x, y ,z )
	return self._prop:modelToWorld( x, y ,z )
end

function Entity:wndToModel( x, y, z )
	return self._prop:worldToModel( self.layer:wndToWorld( x, y, z ) )
end

function Entity:modelToWnd( x, y ,z )
	return self.layer:worldToWnd( self._prop:modelToWorld( x, y ,z ) )
end

function Entity:modelToProj( x, y ,z )
	return self.layer:worldToProj( self._prop:modelToWorld( x, y ,z ) )
end

function Entity:modelToView( x, y ,z )
	return self.layer:worldToView( self._prop:modelToWorld( x, y ,z ) )
end

function Entity:modelRectToWorld(x0,y0,x1,y1)
	x0,y0 = self:modelToWorld(x0,y0)
	x1,y1 = self:modelToWorld(x1,y1)
	return x0,y0,x1,y1
end

function Entity:worldRectToModel(x0,y0,x1,y1)
	x0,y0 = self:worldToModel(x0,y0)
	x1,y1 = self:worldToModel(x1,y1)
	return x0,y0,x1,y1
end

function Entity:removeScissorRect()
	local rect = self._scissorRect
	if not rect then return end
	self._scissorRect = false
	local prop = self._prop
	local pp = self.parent and self.parent._prop
	if pp then	
		linkScissorRect( prop, pp )
	else
		prop:setScissorRect( nil )
	end
	--TODO:rebuild scissor link
	return self:relinkScissorRect( self:getParentScissorRect() )
end

function Entity:setScissorRect( x1,y1,x2,y2, noFollow )
	if not x1 then return self:removeScissorRect() end

	local prop = self._prop
	local rect = self._scissorRect
	--affirm
	if not rect then
		clearLinkScissorRect( prop ) 
		rect = MOAIScissorRect.new()
		self._scissorRect = rect
		prop:setScissorRect( rect )
		self:relinkScissorRect( self:getParentScissorRect() )
	end
	--update
	rect:setRect( x1, y2, x2, y1 )
	if noFollow then 
		clearInheritTransform( rect )
	else
		self:_attachTransform( rect )
	end

end


function Entity:relinkScissorRect( parentRect )
	self._prop:forceUpdate()
	local rect = self._scissorRect
	if rect then
		rect:setScissorRect( parentRect or nil )
	end
	local currentRect = rect or parentRect
	for child in pairs( self.children ) do
		child:relinkScissorRect( currentRect )
	end
end

function Entity:getParentScissorRect()
	local p = self.parent
	while p do
		local parentRect = p._scissorRect
		if parentRect then
			return parentRect
		end
		p = p.parent
	end
	return false
end

local _getScissorRect = MOCKProp.getInterfaceTable().getScissorRect
function Entity:getScissorRect()
	return _getScissorRect( self._prop )
end



--------------------------------------------------------------------
----------other prop wrapper
--------------------------------------------------------------------
function Entity:inside( x, y, z, pad, checkChildren )
	for com in pairs(self.components) do
		local inside = com.inside
		if inside then
			if inside( com, x, y, z, pad ) then return true end
		end
	end

	if checkChildren~=false then
		for child in pairs(self.children) do
			if child:inside(x,y,z,pad) then
				return true
			end
		end
	end
	
	return false
end

function Entity:pick( x, y, z, pad )
	if self.FLAG_EDITOR_OBJECT or self.FLAG_INTERNAL then return nil end
	for child in pairs(self.children) do
		local e = child:pick(x,y,z,pad)
		if e then return e end
	end

	for com in pairs(self.components) do
		local inside = com.inside
		if inside then
			if inside( com, x, y, z, pad ) then return self end
		end
	end
	
	return nil
end

local min = math.min
local max = math.max
function Entity:getBounds( reason )
	local bx0, by0, bz0, bx1, by1, bz1
	for com in pairs( self.components ) do
		local getBounds = com.getBounds
		if getBounds then
			local x0,y0,z0, x1,y1,z1 = getBounds( com, reason )
			if x0 then
				x0,y0,z0, x1,y1,z1 = x0 or 0,y0 or 0,z0 or 0, x1 or 0,y1 or 0,z1 or 0
				bx0 = bx0 and min( x0, bx0 ) or x0
				by0 = by0 and min( y0, by0 ) or y0
				bz0 = bz0 and min( z0, bz0 ) or z0
				bx1 = bx1 and max( x1, bx1 ) or x1
				by1 = by1 and max( y1, by1 ) or y1
				bz1 = bz1 and max( z1, bz1 ) or z1
			end
		end
	end
	return bx0 or 0, by0 or 0, bz0 or 0, bx1 or 0, by1 or 0, bz1 or 0
end

function Entity:getWorldBounds( reason )
	local bx0, by0, bz0, bx1, by1, bz1
	for com in pairs( self.components ) do
		local getWorldBounds = com.getWorldBounds
		if getWorldBounds then
			local x0,y0,z0, x1,y1,z1 = getWorldBounds( com, reason )
			if x0 then
				x0,y0,z0, x1,y1,z1 = x0 or 0,y0 or 0,z0 or 0, x1 or 0,y1 or 0,z1 or 0
				bx0 = bx0 and min( x0, bx0 ) or x0
				by0 = by0 and min( y0, by0 ) or y0
				bz0 = bz0 and min( z0, bz0 ) or z0
				bx1 = bx1 and max( x1, bx1 ) or x1
				by1 = by1 and max( y1, by1 ) or y1
				bz1 = bz1 and max( z1, bz1 ) or z1
			end
		end
	end
	return bx0 or 0, by0 or 0, bz0 or 0, bx1 or 0, by1 or 0, bz1 or 0
end

--bounds include children objects
function Entity:getFullBounds( reason )
	local bx0, by0, bz0, bx1, by1, bz1 = self:getWorldBounds( reason )
	for child in pairs( self.children ) do
		local x0,y0,z0, x1,y1,z1 = child:getFullBounds( reason )
		bx0 = bx0 and min( x0, bx0 ) or x0
		by0 = by0 and min( y0, by0 ) or y0
		bz0 = bz0 and min( z0, bz0 ) or z0
		bx1 = bx1 and max( x1, bx1 ) or x1
		by1 = by1 and max( y1, by1 ) or y1
		bz1 = bz1 and max( z1, bz1 ) or z1
	end
	return bx0, by0, bz0, bx1, by1, bz1
end


function Entity:resetTransform()
	self:setLoc( 0, 0, 0 )
	self:setRot( 0, 0, 0 )
	self:setScl( 1, 1, 1 )
	self:setPiv( 0, 0, 0 )
end

function Entity:copyTransform( target )
	self:setLoc( target:getLoc() )
	self:setScl( target:getScl() )
	self:setRot( target:getRot() )
	self:setPiv( target:getPiv() )
end

function Entity:saveTransform()
	local t = {}
	t.loc = { self:getLoc() }
	t.scl = { self:getScl() }
	t.rot = { self:getRot() }
	t.piv = { self:getPiv() }
	return t
end

function Entity:loadTransform( data )
	if not data then return end
	self:setLoc( unpack( data.loc or {} ) )
	self:setRot( unpack( data.rot or {} ) )
	self:setScl( unpack( data.scl or {} ) )
	self:setPiv( unpack( data.piv or {} ) )
end


function Entity:setHexColor( hex, alpha )
	return self:setColor( hexcolor( hex, alpha ) )
end

function Entity:seekHexColor( hex, alpha, duration, easeType )
	local r,g,b = hexcolor( hex )
	return self:seekColor( r,g,b, alpha, duration ,easeType )
end

function Entity:getHexColor()
	local r,g,b,a = self:getColor() 
	local hex = colorhex( r,g,b )
	return hex, a
end
-- function Entity:onEditorPick( x, y, z, pad )
-- 	for child in pairs(self.children) do
-- 		local e = child:onEditorPick(x,y,z,pad)
-- 		if e then return e end
-- 	end

-- 	for com in pairs(self.components) do
-- 		local inside = com.inside
-- 		if inside then
-- 			if inside( com, x, y, z, pad ) then return self end
-- 		end
-- 	end
-- 	return nil
-- end

--增加这个，是为了防止爆炸的时候碰到这个Entity而调用不存在的函数
function Entity:getDistanceToObj( o )
	local x0,y0 = self:getWorldLoc()
	local x1,y1 = o:getWorldLoc()
	return distance( x0,y0, x1,y1 )
end

--------------------------------------------------------------------
--- asset
--------------------------------------------------------------------
function Entity:loadAsset( path, option )
	return loadAndHoldAsset( self.scene, path, option )
end

--------------------------------------------------------------------
--- Registry
--------------------------------------------------------------------

local entityTypeRegistry = setmetatable( {}, { __no_traverse = true } )
function registerEntity( name, creator )
	if not creator then
		return _error( 'no entity to register', name )
	end

	if not name then
		return _error( 'no entity name specified' )
	end
	-- assert( name and creator, 'nil name or entity creator' )
	-- assert( not entityTypeRegistry[ name ], 'duplicated entity type:'..name )
	_stat( 'register entity type', name )
	entityTypeRegistry[ name ] = creator
end

function getEntityRegistry()
	return entityTypeRegistry
end

function getEntityType( name )
	return entityTypeRegistry[ name ]
end

function buildEntityCategories()
	local categories = {}
	local unsorted   = {}
	for name, entClass in pairs( getEntityRegistry() ) do
		local model = Model.fromClass( entClass )
		local category
		if model then
			local meta = model:getCombinedMeta()
			category = meta[ 'category' ]
		end
		local entry = { name, entClass, category }
		if not category then
			table.insert( unsorted, entry )
		else
			local catTable = categories[ category ]
			if not catTable then
				catTable = {}
				categories[ category ] = catTable
			end
			table.insert( catTable, entry )
		end
	end
	categories[ '__unsorted__' ] = unsorted
	return categories
end


--------------------------------------------------------------------
registerEntity( 'Entity', Entity )


--------------------------------------------------------------------
--Serializer Related
--------------------------------------------------------------------
local function _cloneEntity( src, cloneComponents, cloneChildren, objMap, ensureComponentOrder )
	local objMap = {}
	local dst = clone( src, nil, objMap )
	dst.layer = src.layer
	if cloneComponents ~= false then
		if ensureComponentOrder then
			for i, com in ipairs( src:getSortedComponentList() ) do
				if not com.FLAG_INTERNAL then
					local com1 = clone( com, nil, objMap )
					dst:attach( com1 )
				end
			end
		else
			for com in pairs( src.components ) do
				if not com.FLAG_INTERNAL then
					local com1 = clone( com, nil, objMap )
					dst:attach( com1 )
				end
			end
		end
	end
	if cloneChildren ~= false then
		for child in pairs( src.children ) do
			if not child.FLAG_INTERNAL then
				local child1 = _cloneEntity( child, cloneComponents, cloneChildren, objMap, ensureComponentOrder )
				dst:addChild( child1 )
			end
		end
	end
	return dst
end

function cloneEntity( src, ensureComponentOrder )
	return _cloneEntity( src, true, true, nil, ensureComponentOrder )
end

