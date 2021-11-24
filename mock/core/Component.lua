--------------------------------------------------------------------
-- @classmod Component

---
-- @section Members

module 'mock'
CLASS: Component ()
 	:MODEL{
 		Field '_alias' :string() :no_edit();
	}

--------------------------------------------------------------------
wrapWithMoaiPropMethods( Component, '_entity._prop' )
--------------------------------------------------------------------

--------------------------------------------------------------------
--basic
--------------------------------------------------------------------

function Component:__init()
	self.com = self.com
	self.getEntity = self.getEntity
end

function Component:onAttach( ent )
end

function Component:onDetach( ent )
end

function Component:isSuspended()
	return self._suspendState
end

function Component:onSuspend()
end

function Component:onResurrect()
end

function Component:__tostring()
	if self._entity then
		if self._alias then
			return string.format( '(%s)%s@%s @%s', self._alias, self:__repr(), tostring( self._entity:getFullName() ), self._entity:getSceneSessionName() )
		else
			return string.format( '%s@%s @%s', self:__repr(), tostring( self._entity:getFullName() ), self._entity:getSceneSessionName() or '???' )
		end
	else
		return self:__repr()
	end
end

--- Get owner entity
-- @ret Entity the owner entity
function Component:getEntity()
	return self._entity
end


--- Check if owner entity is started
-- @ret boolean started
function Component:isEntityStarted()
	local ent = self._entity
	return ent and ent.started or false
end

--- Get component alias ID
-- @ret string alias of the component
function Component:getAlias()
	return self._alias
end

--- Get the name of the owner entity
-- @ret string owner entity's name
function Component:getEntityName()
	return self._entity:getName()
end

--- Get the name of the owner entity
-- @ret string owner entity's name
function Component:getEntityFullName()
	return self._entity:getFullName()
end

--- Get the tags of the owner entity
-- @ret string owner entity's tags
function Component:getEntityTags()
	return self._entity:getTags()
end

--- Destroy the owner entity
function Component:destroyEntity()
	if self._entity then self._entity:destroy() end
end

--- Find entity by name in current scene
-- @tparam string name the name to look for
-- @ret Entity result of search
function Component:findEntity( name )
	return self._entity:findEntity( name )
end

--- Find entity in current scene by full entity 'path'
-- @p string path the entity path to look for
-- @ret Entity result of search
function Component:findEntityByPath( path )
	return self._entity:findEntityByPath( path )
end

--- Find entity by name within owner entity's children
-- @p string name the name to look for
-- @p[opt=false] bool deep should do deep-search
-- @ret Entity result of search
function Component:findChild( name, deep )
	if not self._entity then return end
	return self._entity:findChild( name, deep )
end

function Component:findSibling( name )
	return self._entity:findSibling( name )
end

--- Find child entity by relative entity 'path'
-- @p string path the entity path to look for
-- @ret Entity result of search
function Component:findChildByPath( path )
	return self._entity:findChildByPath( path )
end

--- Get parent entity of hte owner
-- @ret Entity the parent of owner entity
function Component:getParent()
	return self._entity.parent
end

--- Shortcut method to get component from a named entity, in scene-scope
-- @p string name name of the entity
-- @p string|Class component type to be looked for
-- @ret Entity the parent of owner entity
function Component:findEntityCom( name, comId )
	return self._entity:findEntityCom( name, comId )
end

--- Shortcut method to get component from a named child entity
-- @p string name name of the child entity
-- @p string|Class component type to be looked for
-- @ret Entity the parent of owner entity
function Component:findChildCom( name, comId, deep )
	return self._entity:findChildCom( name, comId, deep )
end

--- Get component of given type from owner entity
-- @p Class type of component
-- @ret Component result
function Component:getComponent( comType )
	return self._entity:getComponent( comType )
end

--- Get component of given type name from owner entity
-- @p string name of component class
-- @ret Component result
function Component:getComponentByName( comTypeName )
	return self._entity:getComponentByName( comTypeName )
end

--- Get component of given type from owner entity, either by name of by class
-- @p string|Class type of component
-- @ret Component result
function Component:com( id )
	return self._entity:com( id )
end

--- Detach this component from owner entity
function Component:detachFromEntity()
	if self._entity then
		self._entity:detach( self )
	end
end

--------------------------------------------------------------------
--Scene
--------------------------------------------------------------------
--- Get owner entity's scene
-- @ret Scene owner scene
function Component:getScene()
	local ent = self._entity
	return ent and ent.scene
end

function Component:getUserConfig( key, default )
	if self._entity then
		return self._entity:getUserConfig( key, default )
	end
	return game:getUserConfig( key, default )
end



function Component:isSceneReady()
	local scene = self:getScene()
	return scene and scene.ready
end


--- Get owner entity's scenesession
-- @ret SceneSession owner scene sesison
function Component:getSceneSession()
	local scene = self:getScene()
	return scene and scene:getSession()
end

--- Get scene manager from owner entity's scene
-- @p string name of the scene manager
-- @ret Scene owner scene
function Component:getSceneManager( id )
	local scene = self:getScene()
	return scene and scene:getManager( id )
end

--- Get owner entity's layer name
-- @ret string layer's name
function Component:getLayer()
	local ent = self._entity
	return ent and ent:getLayer()
end

function Component:getTime()
	local ent = self._entity
	return ent and ent:getTime() or 0
end

function Component:attachGlobalAction( groupId, action )
	return self._entity:attachGlobalAction( groupId, action )
end

function Component:setActionPriority( action, priority )
	return self._entity:setActionPriority( action, priority )
end

function Component:setCurrentCoroutinePriority( priority )
	return self._entity:setCurrentCoroutinePriority( priority )
end

function Component:callNextFrame( f, ... )
	local scene = self:getScene()
	if not scene then return end
	local t = {
		func = f,
		object = self,
		...
	}
	table.insert( scene.pendingCall, t )
end


--------------------------------------------------------------------
--message & state
--------------------------------------------------------------------

--- Send message to owner entity
-- @p string msg message to be sent
-- @param data message data
-- @param source source object 
function Component:tell( ... )
	return self._entity:tell( ... )
end

function Component:tellLater( ... )
	return self._entity:tellLater( ... )
end

function Component:tellNextFrame( ... )
	return self._entity:tellNextFrame( ... )
end

function Component:tellInterval( ... )
	return self._entity:tellInterval( ... )
end
--- Send message to owner entity and oall its children entities
-- @p string msg message to be sent
-- @param data message data
-- @param source source object 
function Component:tellSelfAndChildren( ... )
	return self._entity:tellSelfAndChildren( ... )
end

--- Send message to all owner entity's children entities
-- @p string msg message to be sent
-- @param data message data
-- @param source source object 
function Component:tellChildren( ... )
	return self._entity:tellChildren( ... )
end

--- Send message to owner entity's siblings
-- @p string msg message to be sent
-- @param data message data
-- @param source source object 
function Component:tellSiblings( ... )
	return self._entity:tellSiblings( ... )
end

--- Get owner entity's current state
-- @ret string current entity state
function Component:getState()
	return self._entity:getState()
end

--- Check if entity is in one of the given states
-- @p {string,...} states state names to be checked against
-- @ret bool result
function Component:inState( ... )
	return self._entity:inState( ... )
end


--- Set owner entity's state
-- @p string state new state to be set
function Component:setState( state )
	return self._entity:setState( state )
end

--- Check if entity's current state is sub state of one of the given states
-- @p {string,...} stateGroups state group names to be checked against
-- @ret bool result
function Component:inStateGroup( ... )
	return self._entity:inStateGroup( ... )
end


--------------------------------------------------------------------
-- invokes
--------------------------------------------------------------------

function Component:invokeUpward( methodName, ... )
	return self._entity:invokeUpward( methodName, ... )
end

function Component:invokeChildren( methodName, ... )
	return self._entity:invokeChildren( methodName, ... )
end

function Component:invokeComponents( methodName, ... )
	return self._entity:invokeComponents( methodName, ... )
end

function Component:invokeOneComponent( methodName, ... )
	return self._entity:invokeOneComponent( methodName, ... )
end

--------------------------------------------------------------------
--signals
--------------------------------------------------------------------

--- Connect signal with method of this instance
-- @p Signal sig target signal
-- @p string methodName name of the slot method
function Component:connect( sig, methodName )	
	return self._entity:connectForObject( self, sig, methodName )
end

--- Disconnect signal with method of this instance
-- @p Signal sig target signal
function Component:disconnect( sig )	
	return self._entity:disconnectForObject( self, sig )
end

-- function Component:disconnectAll()  ---DONE by entity

--------------------------------------------------------------------
-- Wait wrapping
--------------------------------------------------------------------
function Component:waitStateEnter(...)
	return self._entity:waitStateEnter(...)
end

function Component:waitStateExit(s)
	return self._entity:waitStateExit(s)
end

function Component:waitStateChange()
	return self._entity:waitStateChange()
end

function Component:waitFieldEqual( name, v )
	return self._entity:waitFieldEqual( name, v )
end

function Component:waitFieldNotEqual( name, v )
	return self._entity:waitFieldNotEqual( name, v )
end

function Component:waitFieldTrue( name )
	return self._entity:waitFieldTrue( name )
end

function Component:waitFieldFalse( name )
	return self._entity:waitFieldFalse( name )
end

function Component:waitGlobalSignal(signame)
	return self._entity:waitGlobalSignal( signame )
end

function Component:waitSignal(sig)
	return self._entity:waitSignal(sig)
end

function Component:waitFrames(f)
	return self._entity:waitFrames(f)
end

function Component:waitTime(t)
	return self._entity:waitTime(t)
end

function Component:pauseThisThread( noyield )
	return self._entity:pauseThisThread( noyield )
end

function Component:wait( a )
	return self._entity:wait( a )
end

function Component:skip( duration )
	return self._entity:skip( duration )
end

--------------------------------------------------------------------
---------coroutine control
--------------------------------------------------------------------

function Component:_weakHoldCoroutine( newCoro )
	local coroutines = self.coroutines
	if not coroutines then
		coroutines = { 
			[newCoro] = true
		}
		self.coroutines = coroutines
		return newCoro
	end
	--remove dead ones
	local dead = {}
	for coro in pairs( coroutines ) do
		if coro:isDone() then
			dead[ coro ] = true
		end
	end
	for coro in pairs( dead ) do
		coro._func = nil
		coroutines[ coro ] = nil
	end
	coroutines[ newCoro ] = true
	return newCoro	
end

function Component:getCurrentCoroutine()
	return MOAICoroutine.currentThread()
end

function Component:getActionRoot()
	return self._entity:getActionRoot()
end

function Component:addCoroutine( func, ... )
	if not self._entity then return end
	local coro = self._entity:addCoroutineFor( self, func, ... )
	return self:_weakHoldCoroutine( coro )
end

function Component:addCoroutineP( func, ... )
	local coro = self._entity:addCoroutinePFor( self, func, ... )
	return self:_weakHoldCoroutine( coro )
end

function Component:addRootCoroutine( ... )
	local coro = self:addCoroutine( ... )
	coro:attach( self:getActionRoot() )
	return coro
end

function Component:addRootCoroutineP( ... )
	local coro = self:addCoroutineP( ... )
	coro:attach( self:getActionRoot() )
	return coro
end

function Component:addGameCoroutine( ... )
	local coro = self:addCoroutine( ... )
	coro:attach( game:getSceneActionRoot() )
	return coro
end

function Component:addGameCoroutineP( ... )
	local coro = self:addCoroutineP( ... )
	coro:attach( game:getSceneActionRoot() )
	return coro
end

function Component:addDaemonCoroutine( func, ... )
	local coro = self._entity:addDaemonCoroutineFor( self, func, ... )
	return self:_weakHoldCoroutine( coro )
end

function Component:clearCoroutines()
	if not self.coroutines then return end
	for coro in pairs( self.coroutines ) do
		coro:stop()
		coro._func = nil
	end
	self.coroutines = nil
end

function Component:findCoroutine( method )
	if not self.coroutines then return end
	for coro in pairs( self.coroutines ) do
		if coro._func == method and (not coro:isDone()) then
			return coro
		end
	end
	return nil
end

function Component:findAllCoroutines( method )
	if not self.coroutines then return end
	local found = {}
	for coro in pairs( self.coroutines ) do
		if coro._func == method and (not coro:isDone()) then
			table.insert( found, coro )
		end
	end
	return found
end

function Component:findAndStopCoroutine( method )
	if not self.coroutines then return end
	for coro in pairs( self.coroutines ) do
		if coro._func == method and (not coro:isDone()) then
			coro:stop()
			coro._func = nil
		end
	end
end

function Component:replaceCoroutine( method, ... )
	self:findAndStopCoroutine( method )
	return self:addCoroutine( method, ... )
end

function Component:replaceCoroutineP( method, ... )
	self:findAndStopCoroutine( method )
	return self:addCoroutineP( method, ... )
end

function Component:affirmCoroutine( method, ... )
	local coro = self:findCoroutine( method )
	if coro and coro:isBusy() then return coro end
	return self:addCoroutine( method, ... )
end

function Component:affirmCoroutineP( method, ... )
	local coro = self:findCoroutine( method )
	if coro and coro:isBusy() then return coro end
	return self:addCoroutineP( method, ... )
end

function Component:loadAsset( path, option )
	return loadAndHoldAsset( self:getScene(), path, option )
end

--------------------------------------------------------------------
-------Component management
--------------------------------------------------------------------
local componentRegistry = setmetatable( {}, { __no_traverse = true } )

function registerComponent( name, clas )
	if (not clas) and isSubclass( name, Component ) then
		clas = name
		name = clas.__name
	else
		if not clas:isSubclass( Component ) then
			_error( 'invalid component class:', name )
		end
		-- assert( not componentRegistry[ name ], 'duplicated component type:'..name )
		if not clas then
			_error( 'no component to register', name )
		end
		if not isClass( clas ) then
			_error( 'attempt to register non-class component', name )
		end
	end
	componentRegistry[ name ] = clas
end

function registerEntityWithComponent( name, ... )
	local comClasses = {...}
	local creator = function( ... )
		local e = Entity()
		for i, comClass in ipairs( comClasses ) do
			local com = comClass()
			e:attach( com )
		end
		return e
	end
	return registerEntity( name, creator )
end

function getComponentRegistry()
	return componentRegistry
end

function getComponentType( name )
	return componentRegistry[ name ]
end

function buildComponentCategories()
	local categories = {}
	local unsorted   = {}
	for name, comClass in pairs( getComponentRegistry() ) do
		local model = Model.fromClass( comClass )
		local category
		if model then
			local meta = model:getCombinedMeta()
			category = meta[ 'category' ]
		end
		local entry = { name, comClass, category }
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
-----------convert MOAIProp into attachable components
--------------------------------------------------------------------

local onAttachProp = function( self, entity )
	return entity:_attachProp( self )
end

local onDetachProp = function( self, entity )
	return entity:_detachProp( self )
end

function injectMoaiPropComponentMethod( clas )
	injectMoaiClass( clas, {
		onAttach       = onAttachProp,
		onDetach       = onDetachProp,
		})
end

injectMoaiPropComponentMethod( MOAIProp )
injectMoaiPropComponentMethod( MOAITextLabel )
injectMoaiPropComponentMethod( MOAIParticleSystem )



--------------------------------------------------------------------
local function affirmComponentClass( t, id )
	if type(id) ~= 'string' then error('component class name expected',2) end
	local classCreator = CLASS[ id ]
	local f = function( a, ... )		
		local clas = classCreator( CLASS, ... )
		mock.registerComponent( id, clas )
		return clas
	end
	setfenv( f, getfenv( 2 ) )
	return f
end

_G.COMPONENT = setmetatable( {}, { __index = affirmComponentClass } )

--------------------------------------------------------------------

local function affirmEntityClass( t, id )
	if type(id) ~= 'string' then error('entity class name expected',2) end
	local classCreator = CLASS[ id ]
	local f = function( a, superclass, ... )
		if not superclass then
			superclass = Entity
		end
		local clas = classCreator( CLASS, superclass, ... )
		mock.registerEntity( id, clas )
		return clas
	end
	setfenv( f, getfenv( 2 ) )
	return f
end

_G.ENTITY = setmetatable( {}, { __index = affirmEntityClass } )
