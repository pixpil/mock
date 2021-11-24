module 'mock'

local insert, remove = table.insert, table.remove
local pairs, ipairs = pairs, ipairs

local function isEditorEntity( e )
	while e do
		if e.FLAG_EDITOR_OBJECT then return true end
		e = e.parent
	end
	return false
end

--------------------------------------------------------------------
--SCENE
--------------------------------------------------------------------
CLASS: Scene ( ResourceHolder )
	:MODEL{
		Field 'EntityCount' :int() :readonly() :get( 'getEntityCount' );
		Field 'comment' :string() :widget( 'textbox' );
	}

function Scene:__init( option )
	self.metadata = {}
	self.pauseLock = {}

	self.path     = false
	self.filePath = false

	self.active = false
	self.clearing = false
	self.main   = false
	self.session = false

	self.ready   = false

	self.FLAG_EDITOR_SCENE = false
	self.running = false
	self.arguments       = {}
	self.layers          = {}
	self.layersByName    = {}
	self.entities        = {}
	self.entitiesByName  = {}
	self._GUIDCache      = {}
	self.entityCount     = 0

	self.pendingStart    = {}
	self.pendingDestroy  = {}
	self.laterDestroy    = {}
	self.pendingCall     = {}
	self.pendingDetach   = {}

	self.updateListeners = {}

	self.signalChannels  = {}

	self.defaultCamera   = false
	self.option          = option

	self.throttle        = 1
	self.baseThrottle        = 1
	self.throttleFactors = {}

	self.b2world         = false
	self.b2ground        = false
	self.actionPriorityGroups = {}

	self.config          = {}

	self.rootGroups      = {}
	self.defaultRootGroup = self:addRootGroup( 'default' )
	self.defaultRootGroup._isDefault = true

	self.managers  = {}
	self.comment   = ""

	--action groups direclty attached to sceneActionRoot
	self.globalActionGroups = {} 

	self.debugDrawQueue = DebugDrawQueue()
	self.debugPropPartition = MOAIPartition.new()

	self.resourceGroupId = false
	self.preloadResourceHolder = false
	
	return self
end

function Scene:__tostring()
	return string.format( '%s%s::%s', self:__repr(), self.path or '<nil>', self:getSessionName() or "???" )
end

function Scene:getSession()
	return self.session
end

function Scene:getSessionName()
	local session = self.session
	return session and session:getName()
end

function Scene:setPreloadResourceHolder( holder )
	self.preloadResourceHolder = holder or false
end

function Scene:getPreloadResourceHolder()
	return self.preloadResourceHolder
end

function Scene:addRootGroup( name )
	local group = EntityGroup()
	group._isRoot = true
	group.scene = self
	group.name  = name
	table.insert( self.rootGroups, group )
	return group
end

function Scene:setDefaultRootGroup( group )
	if not group then
		for i, g in ipairs( self.rootGroups ) do
			if g._isDefault then
				group = g
				break
			end
		end
	end
	if self.defaultRootGroup == group then return false end
	if group.scene == self then
		self.defaultRootGroup = group
		return true
	end
	return false
end

function Scene:updateSolo( soloVis, soloOpacity, soloEdit )
	local group = self:getDefaultRootGroup()
	for i, g in ipairs( self.rootGroups ) do
		local isDefault = g == group
		local lock = false
		if soloEdit then
			lock = not isDefault
		end
		g:setEditLocked( lock )
		local vis = true
		if soloVis then
			vis = isDefault
		end
		g:setVisible( vis )
		local opa = true
		if soloOpacity then
			opa = isDefault
		end
		g:setEditOpacity( opa )
	end
end

function Scene:removeRootGroup( group )
	local idx = table.index( self.rootGroups, group )
	if idx then
		group:destroyWithChildrenNow()
		table.remove( self.rootGroups, idx )
		return true
	end
	return false
end


function Scene:isMainScene()
	return self.main
end

function Scene:getDebugPropPartition()
	return self.debugPropPartition
end

function Scene:addDebugProp( prop )
	prop:setPartition( self.debugPropPartition )
end

function Scene:removeDebugProp( prop )
	prop:setPartition( nil )
end

function Scene:isEditorScene()
	return self.FLAG_EDITOR_SCENE
end

--------------------------------------------------------------------
--COMMON
--------------------------------------------------------------------
function Scene:init()
	if self.initialized then return end 
	self.initialized  = true
	self.exiting = false
	self.active  = true
	self.ready   = false
	self.userObjects = {}

	self:initLayers()
	self:initPhysics()
	self:initManagers()

	if self.onLoad then self:onLoad() end

	_stat( 'Initialize Scene' )

	if not self.FLAG_EDITOR_SCENE then
		emitSignal( 'scene.init', self )
	end
	
	self:reset()

end

function Scene:initLayers()
	local layers = {}
	local layersByName = {}
	local defaultLayer

	for i, l in ipairs( self:getLayerSources() ) do
		local layer = l:makeMoaiLayer()
		layers[i] = layer
		layersByName[ layer.name ] = layer
		if l.default then
			defaultLayer = layer
		end
	end

	if defaultLayer then
		self.defaultLayer = defaultLayer
	else
		self.defaultLayer = layers[1]
	end
	assert( self.defaultLayer )
	self.layers = layers
	self.layersByName = layersByName
end

function Scene:getLayerSources()
	return table.simplecopy( game.layers )
end

function Scene:initManagers()
	self.managers = {}
	local registry = getSceneManagerFactoryRegistry()
	for i, fac in ipairs( registry ) do
		if fac:accept( self ) then
			local manager = fac:create( self )
			if manager then
				manager._factory = fac
				manager._key = fac:getKey()
				manager:init( self )
				self.managers[ manager._key ] = manager
			end
		end
	end
	for i, globalManager in ipairs( getGlobalManagerRegistry() ) do
		globalManager:onSceneInit( self )
	end

end

function Scene:reset()
	self:resetActionRoot()
	for key, manager in pairs( self.managers ) do
		manager:reset()
	end
	for i, globalManager in ipairs( getGlobalManagerRegistry() ) do
		globalManager:onSceneReset( self )
	end
end

function Scene:notifyPreload()
	for key, manager in pairs( self.managers ) do
		manager:preLoad()
	end
	for i, globalManager in ipairs( getGlobalManagerRegistry() ) do
		globalManager:preSceneLoad( self )
	end
end

function Scene:notifyLoad()
	for key, manager in pairs( self.managers ) do
		manager:onLoad()
	end
	for i, globalManager in ipairs( getGlobalManagerRegistry() ) do
		globalManager:onSceneLoad( self )
	end
end

function Scene:getManager( key )
	return self.managers[ key ]
end

function Scene:getManagers()
	return self.managers
end

function Scene:setMetaData( key, value )
	self.metadata[ key ] = value
end

function Scene:getMetaData( key, defaultValue )
	local v = self.metadata[ key ]
	if v == nil then return defaultValue end
	return v
end

function Scene:serializeMetaData()
	return self.metadata
end

function Scene:deserializeMetaData( data )
	self.metadata = data and table.simplecopy( data ) or {}
end

function Scene:serializeConfig()
	local output = {}
	--common
	local commonData = {
		['comment'] = self.comment
	}
	output[ 'common' ] = commonData
	
	--managers
	local managerConfigData = {}
	for key, mgr in pairs( self:getManagers() ) do
		local data = mgr:serialize()
		if data then
			managerConfigData[ key ] = data
		end
	end
	output[ 'managers' ] = managerConfigData
	return output
end

function Scene:deserializeConfig( data )
	--common
	local commonConfigData = data[ 'common' ]
	if commonConfigData then
		self.comment = commonConfigData[ 'comment' ]
	end

	--managers
	local managerConfigData = data[ 'managers' ]
	if managerConfigData then
		for key, data in pairs( managerConfigData ) do
			local mgr = self:getManager( key )
			if mgr then
				mgr:deserialize( data )
			end
		end
	end
end

local insert = table.insert
function Scene:callNextFrame( f, ... )
	local t = {
		func = f,
		...
	}
	insert( self.pendingCall, t )
end

function Scene:flushPendingStart()
	if not self.running then return self end
	local pendingStart = self.pendingStart
	local newPendingStart = {}
	self.pendingStart = newPendingStart
	for entity in pairs( pendingStart ) do
		entity:start()
	end
	if next( newPendingStart ) then
		return self:flushPendingStart()
	else
		return self
	end
end

function Scene:threadMain( dt )
	setDefaultResourceHolder( self )
	
	_stat( 'entering scene main thread', self )

	for key, mgr in pairs( self:getManagers() ) do
		_stat( 'start scene manager', key, mgr )
		mgr:onStart()
	end

	for i, globalManager in ipairs( getGlobalManagerRegistry() ) do
		_stat( 'notify global manager', globalManager )
		globalManager:onSceneStart( self )
	end

	-- first run
	_stat( 'start entities', self )
	for ent in pairs( self.entities ) do
		if not ent.parent then
			ent:start()
		end
	end

	if next( self.pendingStart ) then
		self:flushPendingStart()
	end
	
	-- 
	_stat( 'post star', self )
	for key, mgr in pairs( self:getManagers() ) do
		mgr:postStart()
	end

	for i, globalManager in ipairs( getGlobalManagerRegistry() ) do
		globalManager:postSceneStart( self )
	end


	-- main loop
	_stat( 'entering scene main loop', self )
	dt = 0
	
	local firstFrame = true
	local debugDrawQueue = self.debugDrawQueue
	local lastTime = self:getTime()

	while true do	
		local nowTime = self:getTime()
		if self.active then
			-- local dt = nowTime - lastTime
			lastTime = nowTime

			if not firstFrame then
				--callNextFrame
				local pendingCall = self.pendingCall
				local count = #pendingCall
				if count > 0 then
					self.pendingCall = {}
					for i = 1, count do
						local t = pendingCall[ i ]
						local func = t.func
						if type( func ) == 'string' then --method call
							local object = t.object
							func = object[ func ]
							func( object, unpack(t) )
						else
							func( unpack(t) )
						end
					end
				end

			else

				firstFrame = false
			end

			--onUpdate
			for obj in pairs( self.updateListeners ) do
				local isActive = obj.isActive
				if not isActive or isActive( obj ) then
					obj:onUpdate( dt )
				end
			end
			
			--destroy later
			local laterDestroy = self.laterDestroy
			for entity, time in pairs( laterDestroy ) do
				if nowTime >= time then
					entity:tryDestroy()
					laterDestroy[ entity ] = nil
				end
			end

			if next( self.pendingStart ) then
				self:flushPendingStart()
			end

		--end of step update
		end
		
		--executeDestroyQueue()
		local pendingDetach = self.pendingDetach
		self.pendingDetach = {}
		for com in pairs( pendingDetach ) do
			local ent = com._entity
			if ent then
				ent:detach( com )
			end
		end

		local pendingDestroy = self.pendingDestroy
		self.pendingDestroy = {}
		for entity in pairs( pendingDestroy ) do
			if entity.scene then
				entity:destroyWithChildrenNow()
			end
		end
		
		dt = coroutine.yield()
		setDefaultResourceHolder( self )
		
		debugDrawQueue:update( dt )

		if self.exiting then 
			self:exitNow() 
		elseif self.exitingTime and self.exitingTime <= self:getTime() then
			self.exitingTime = false
			self:exitNow()
		end
	--end of main loop
	end
end

local setCurrentDebugDrawQueue = setCurrentDebugDrawQueue
function Scene:preUpdate()
	setDefaultResourceHolder( self )
	local debugDrawQueue = self.debugDrawQueue
	debugDrawQueue:clear()
	setCurrentDebugDrawQueue( debugDrawQueue )
end

function Scene:postUpdate( ... )
	-- print( 'post scene!!', self, ... )
end

--obj with onUpdate( dt ) interface
function Scene:addUpdateListener( obj )
	--assert ( type( obj.onUpdate ) == 'function' )
	self.updateListeners[ obj ] = true
end

function Scene:removeUpdateListener( obj )
	self.updateListeners[ obj ] = nil
end

function Scene:setUserObject( id, obj )
	self.userObjects[ id ] = obj
end

function Scene:getUserObject( id )
	return self.userObjects[ id ]
end

function Scene:setUserConfig( id, obj )
	self.userConfig[ id ] = obj
end

function Scene:getUserConfig( id, default )
	local v = self.userConfig[ id ]
	if v ~= nil then return v end
	return game:getUserConfig( id, default )
end

function Scene:getPath()
	return self.path or false
end

function Scene:getFilePath( subname )
	if not subname then
		return self.filePath
	else
		return self.filePath and ( self.filePath .. '/' .. subname )
	end
end

function Scene:getBaseName()
	return self.path and basename_noext( self.path ) or false
end

function Scene:getArguments()
	return self.arguments
end

function Scene:getArgument( id, default )
	local v = self.arguments[ id ]
	if v == nil then return default end
	return v
end


--------------------------------------------------------------------
--Action control
--------------------------------------------------------------------
function Scene:resetActionRoot()
	_stat( 'scene action root reset' )
	-- local prevActionRoot = self.actionRoot
	if self.actionRoot then
		self.actionRoot:setListener( MOAIAction.EVENT_ACTION_PRE_UPDATE, nil )
		self.actionRoot:setListener( MOAIAction.EVENT_ACTION_POST_UPDATE, nil )
		self.actionRoot:stop()
		self.actionRoot:clear()
		self.actionRoot = false
	end

	self.actionRoot = MOAICoroutine.new()
	self.actionRoot:setDefaultParent( true )
	self.actionRoot:run( 
		function()
			while true do
				coroutine.yield()
			end
		end	
	)
	self.actionRoot:setListener( MOAIAction.EVENT_ACTION_PRE_UPDATE, function( ... ) return self:preUpdate( ... ) end )	
	self.actionRoot:setListener( MOAIAction.EVENT_ACTION_POST_UPDATE, function( ... ) return self:postUpdate( ... ) end )	
	self.actionRoot:attach( self:getParentActionRoot() )

	_stat( 'scene timer reset ')

	if self.timer then
		self.timer:detach()
		self.timer = false
	end
	
	self.timer   = MOAITimer.new()
	self.timer:setMode( MOAITimer.CONTINUE )
	self.timer:attach( self.actionRoot )

	local root = self.actionRoot
	for i = 9, -9, -1 do
		local group = MOAIAction.new()
		group:setAutoStop( false )
		group:attach( root )
		group.priority = i
		self.actionPriorityGroups[ i ] = group
	end

end

function Scene:getActionRoot()
	return self.mainThread
end

function Scene:getParentActionRoot()
	return game:getSceneActionRoot()
end

function Scene:getGlobalActionGroup( id, affirm )
	affirm = affirm ~= false
	local group = self.globalActionGroups[ id ]
	if (not group) and affirm then
		group = MOAIAction.new()
		group:setAutoStop( false )
		group:attach( self:getParentActionRoot() )
		self.globalActionGroups[ id ] = group
	end
	return group
end

function Scene:attachGlobalAction( id, action )
	assert( type( id ) == 'string', 'invalid global action group ID' )
	local group = self:getGlobalActionGroup( id )
	action:attach( group )
	return action
end

function Scene:pauseGlobalActionGroup( id, paused )
	local group = self:getGlobalActionGroup( id, true )
	group:pause( paused )
end

function Scene:isGlobalActionGroupPaused( id )
	local group = self:getGlobalActionGroup( id, false )
	if not group then return false end
	return group:isPaused()
end

function Scene:isClearing()
	return self.clearing
end

function Scene:isPaused()
	return self.actionRoot:isPaused()
end

function Scene:pause( paused, reason )
	reason = reason or 'default'
	paused = paused ~= false
	if paused then
		if not next( self.pauseLock ) then
			self.actionRoot:pause( true )
		end
		self.pauseLock[ reason ] = true
	else
		self.pauseLock[ reason ] = nil
		if not next( self.pauseLock ) then
			self.actionRoot:pause( false )
		end
	end
end

function Scene:updatePause()
	
end

function Scene:skipFrames( f )
	local session = self:getSession()
	if session then
		return session:skipFrames( f )
	else
		_error( 'cannot skip frames on scene no session' )
	end
end

function Scene:resume( )
	return self:pause( false )
end

function Scene:setThrottleFactor( key, factor )
	local tt = type( factor )
	assert( tt == 'number' or tt == 'nil' )
	self.throttleFactors[ key ] = factor
	self:updateThrottle()
end

function Scene:getThrottleFactor( key )
	return self.throttleFactors[ key ]
end

function Scene:updateThrottle()
	local totalFactor = 1
	for key, factor in pairs( self.throttleFactors ) do
		if factor then totalFactor = totalFactor * factor end
	end
	self.throttle = self.baseThrottle * totalFactor
	return self.actionRoot:throttle( self.throttle )
end

function Scene:seekThrottle( t1, duration )
	duration = duration or 1
	local coro = MOAICoroutine.new()
	local t0 = self.baseThrottle
	coro:run( function()
		local elapsed = 0
		while true do
			local dt = coroutine.yield()
			elapsed = elapsed + dt
			local k = math.min( elapsed/duration, 1 )
			self:setThrottle( lerp( t0, t1, k ) )
			if k >= 1 then break end
		end
	end)
	self:getParentActionRoot():addChild( coro )
	return coro
end


function Scene:seekThrottleFactor( key, f1, duration )
	duration = duration or 1
	local coro = MOAICoroutine.new()
	local f0 = self.throttleFactors[ key ] or 1
	coro:run( function()
		local elapsed = 0
		while true do
			local dt = coroutine.yield()
			elapsed = elapsed + dt
			local k = math.min( elapsed/duration, 1 )
			self:setThrottleFactor(  key, lerp( f0, f1, k ) )
			if k >= 1 then break end
		end
	end)
	self:getParentActionRoot():addChild( coro )
	return coro
end

function Scene:setThrottle(v)
	self.baseThrottle = v or 1
	self:updateThrottle()
end

function Scene:getThrottle()
	return self.throttle
end

function Scene:getBaseThrottle()
	return self.baseThrottle
end

function Scene:getActualThrottle()
	return self.throttle
end

function Scene:setActionPriority( action, priority )
	local group = self.actionPriorityGroups[ priority ]
	action:attach( group )
end


--------------------------------------------------------------------
--TIMER
--------------------------------------------------------------------
function Scene:getTime()
	--TODO: allow scene to have independent clock
	if self.timer then
		return self.timer:getTime()
	else
		return 0
	end
end

function Scene:getSceneTimer()
	return self.timer
end

local NewMOAITimer = MOAITimer.new
local EVENT_START = MOAIAction.EVENT_START
local EVENT_STOP  = MOAIAction.EVENT_STOP
local EVENT_POST_STOP  = MOAIAction.EVENT_POST_STOP
local clearMOAIObject = clearMOAIObject
local _timerPool = {}
local function _sceneTimerStopFunc( t )
	local _onStop = t._onStop
	if _onStop then
		_onStop( t )
	end
	clearMOAIObject( t )
	t:setTime( 0 )
	t:pause( false )
	_timerPool[ #_timerPool + 1 ] = t
end

function Scene:createTimer( onStop )
	local timer = remove( _timerPool, 1 )
	if not timer then
		timer = NewMOAITimer()
		timer:setListener( EVENT_POST_STOP, _sceneTimerStopFunc )
	end
	timer._onStop = onStop or false
	timer:attach( self:getActionRoot() )
	return timer
end


--------------------------------------------------------------------
--Flow Control
--------------------------------------------------------------------
function Scene:start()
	_stat( 'scene start', self )
	if self.running then return end
	if not self.initialized then self:init() end
	self.active = true
	self.running = true
	self.mainThread = MOAICoroutine.new()
	-- self.mainThread:setDefaultParent( true )
	self.mainThread:run( function()
		return self:threadMain()
	end)
	self.mainThread:attach( self:getParentActionRoot() )

	_stat( 'mainthread scene start' )
	self:setActionPriority( self.mainThread, 0 )
	
	_stat( 'box2d scene start' )
	self:setActionPriority( self.b2world, 1 )

	local onStart = self.onStart
	if onStart then onStart( self ) end
	_stat( 'scene start ... done' )

	self:pauseBox2DWorld( false )
end


function Scene:stop()
	if not self.running then return end
	emitSignal( 'scene.stop', self )	
	if self:isMainScene() then
		emitGlobalSignal( 'mainscene.stop' )
	end

	for key, mgr in pairs( self:getManagers() ) do
		mgr:onStop()
	end
	
	self.running = false

	self.mainThread:stop()
	self.mainThread:clear()
	self.mainThread = false
	
	self.timer:stop()
	self.timer:clear()
	self.timer = false

	self.actionRoot:stop()
	self.actionRoot:clear()

end

function Scene:isRunning()
	return self.running
end

function Scene:exitLater(time)
	self.exitingTime = game:getTime() + time
end

function Scene:exit()
	_stat( 'scene exit' )
	self.exiting = true	
end

function Scene:exitNow()
	_codemark('Exit Scene: %s',self.name)
	self:stop()
	self.active  = false
	self.exiting = false
	if self.onExit then self.onExit() end
	self:clear()	
end


--------------------------------------------------------------------
--Layer control
--------------------------------------------------------------------
--[[
	Layer in scene is only for placeholder/ viewport transform
	Real layers for render is inside Camera, which supports multiple viewport render
]]


function Scene:getLayer( name )
	if not name then return self.defaultLayer end
	return self.layersByName[ name ]
end


--------------------------------------------------------------------
--Entity Control
--------------------------------------------------------------------
function Scene:setEntityListener( func )
	self.entityListener = func or false
end

function Scene:addEntity( entity, layer, group )
	assert( entity )
	
	layer = layer or entity.layer or self.defaultLayer
	if type(layer) == 'string' then 
		local layerName = layer
		layer = self:getLayer( layerName )
		if not layer then 
			_error( 'layer not found:', layerName )			
			layer = self.defaultLayer
		end 
	end

	assert( layer )
	group = group or entity._entityGroup or self:getRootGroup()
	group:addEntity( entity )
	entity:_insertIntoScene( self, layer )

	return entity
end


function Scene:addInternalEntity( entity, layer, group )
	entity.FLAG_INTERNAL = true
	return self:addEntity( entity, layer, group )
end


function Scene:addEntities( list, layer )
	for k, entity in pairs( list ) do
		self:addEntity( entity, layer )
		if type( k ) == 'string' then
			entity:setName( k )
		end
	end
end

function Scene:findEntity( name )
	local e = self.entitiesByName[ name ]
	if e then
		if e.scene == self then
			return e
		else
			self.entitiesByName[ name ] = nil
			return nil
		end
	else
		return nil
	end
end

function Scene:findEntityCom( entName, comId )
	local ent = self:findEntity( entName )
	if ent then return ent:com( comId ) end
	return nil
end

function Scene:findEntityOrGroupByGUID( guid )
	return self:findEntityByGUID( guid ) or self:findEntityGroupByGUID( guid )
end

function Scene:findEntityGroupByGUID( guid )
	for i, group in ipairs( self.rootGroups ) do
		local result = group:findGroupByGUID( guid )
		if result then return result end
	end
	return nil
end

function Scene:findEntityByGUID( guid )
	if not guid then return nil end
	local cache = self._GUIDCache
	local v = cache[ guid ]
	if v ~= nil then return v end
	for ent in pairs( self.entities ) do
		if ent.__guid == guid then
			cache[ guid ] = ent
			return ent
		end
	end
	cache[ guid ] = false
	return false
end

local function collectComponent( entity, typeId, collection, allowInternal )
	if isEditorEntity( entity ) then return end
	
	local allowed = allowInternal or ( not entity.FLAG_INTERNAL ) 
	if not allowed then return end

	for com in pairs( entity.components ) do
		local allowed = allowInternal or ( not com.FLAG_INTERNAL ) 
		if allowed and isInstance( com, typeId ) then
			collection[ com ] = true
		end
	end
	for child in pairs( entity.children ) do
		collectComponent( child, typeId, collection, allowInternal )
	end
end

local function collectEntityGroup( group, collection )
	if isEditorEntity( group ) then return end
	collection[ group ] = true 
	for child in pairs( group.childGroups ) do
		collectEntityGroup( child, collection )
	end
end

function Scene:collectEntityGroups()
	local collection = {}	
	for i, group in ipairs( self.rootGroups ) do
		collectEntityGroup( group, collection )
	end
	return collection
end

-- function Scene:collectEntities( typeId, allowInternal )
-- 	local collection = {}
-- 	for e in pairs( self.entities ) do
-- 		if isEditorEntity( e ) then return end
-- 		local allowed = e.FLAG_INTERNAL and ( not allowInternal )
-- 		if allowed and isInstance( e, typeId ) then
-- 			collection[ e ] = true
-- 		end
-- 	end
-- 	return collection
-- end

function Scene:collectComponents( typeId, allowInternal )
	local collection = {}	
	for e in pairs( self.entities ) do
		if not e.parent then --root entity
			collectComponent( e, typeId, collection, allowInternal )
		end
	end
	return collection
end


function Scene:changeEntityName( entity, oldName, newName )
	local entitiesByName = self.entitiesByName
	if oldName then
		if entity == entitiesByName[ oldName ] then
			entitiesByName[ oldName ]=nil
		end
	end
	if newName then
		if not entitiesByName[ newName ] then
			entitiesByName[ newName ] = entity
		end
	end
end


function Scene:clear( keepEditorEntity )
	self.clearing = true
	self.path = false
	
	_stat( 'clearing scene' )
	for key, manager in pairs( self.managers ) do
		manager:preClear()
	end
	self._GUIDCache = {}
	local entityListener = self.entityListener
	if entityListener then
		self.entityListener = false
		entityListener( 'clear', keepEditorEntity )
	end

	local toRemove = {}
	_stat( 'pre clear', table.len( self.entities ) )
	for e in pairs( self.entities ) do
		if not e.parent then --only root entities
			if not ( keepEditorEntity and e.FLAG_EDITOR_OBJECT ) then
				toRemove[ e ] = true
			end
		end
	end
	
	for e in pairs( toRemove ) do
		e:destroyWithChildrenNow()
	end

	_stat( 'post clear', table.len( self.entities ) )
	
	--layers in Scene is not in render stack, just let it go
	self.laterDestroy    = {}
	self.pendDestroy     = {}
	self.pendingCall     = {}
	self.entitiesByName  = {}
	self.pendingStart    = {}
	self.updateListeners = {}
	self.rootGroups      = {}
	
	self.defaultRootGroup = self:addRootGroup( 'default' )
	self.defaultRootGroup._isDefault = true

	self.defaultCamera   = false
	self.entityListener = entityListener
	self.arguments = {}
	self.userObjects = {}
	self.userConfig = {}
	
	_stat( 'global action group reset' )
	for id, gg in pairs( self.globalActionGroups ) do
		_stat( 'stop globalActionGroup', gg )
		gg:clear()
		gg:stop()
	end
	self.globalActionGroups = {}

	_stat( 'scene action priority group reset' )
	for i, g in pairs( self.actionPriorityGroups ) do
		g:clear()
		g:stop()
	end
	self.actionPriorityGroups = {}

	for key, manager in pairs( self.managers ) do
		manager:clear()
	end

	for i, globalManager in ipairs( getGlobalManagerRegistry() ) do
		globalManager:onSceneClear( self )
	end

	if not self.FLAG_EDITOR_SCENE then
		emitSignal( 'scene.clear', self )
	end

	self:releaseAllAssets()
	self.metadata = {}
	self.ready = false
	self.clearing = false
end

function Scene:destroy()
	self:stop()
	self:clear()
end

function Scene:getRootGroup( name )
	if name then
		for i, group in ipairs( self.rootGroups ) do
			if group.name == name then return group end
		end
		return nil
	else
		return self.defaultRootGroup
	end
end

function Scene:getDefaultRootGroup()
	return self.defaultRootGroup
end

function Scene:getRootGroups()
	return self.rootGroups
end

function Scene:renameGroup( group, name )
	local name0 = group.name
	local group0 = self.rootGroups[ name0 ]
	if group0 == group then
		self.rootGroups[ name0 ] = nil
		self.rootgroups[ name ] = group
		return true
	end
	return false
end



Scene.add = Scene.addEntity

--------------------------------------------------------------------
--PHYSICS
--------------------------------------------------------------------

function Scene:initPhysics()
	local option = game and game.physicsOption or table.simplecopy( DefaultPhysicsWorldOption )

	local world
	if option.world and _G[ option.world ] then
		local worldClass = rawget( _G, option.world )
		world = worldClass.new()
	else
		world = MOAIBox2DWorld.new()
	end

	if option.gravity then
		world:setGravity ( unpack(option.gravity) )
	end
	
	if option.unitsToMeters then
		world:setUnitsToMeters ( option.unitsToMeters )
	end
	
	local velocityIterations, positionIterations = option.velocityIterations, option.positionIterations
	velocityIterations = velocityIterations
	positionIterations = positionIterations
	world:setIterations ( velocityIterations, positionIterations )

	world:setAutoClearForces       ( option.autoClearForces )
	-- world:setTimeToSleep           ( option.timeToSleep )
	-- world:setAngularSleepTolerance ( option.angularSleepTolerance )
	-- world:setLinearSleepTolerance  ( option.linearSleepTolerance )
	self.b2world = world

	local ground = world:addBody( MOAIBox2DBody.STATIC )
	self.b2ground = ground

	world:setDebugDrawEnabled( true )
	
	return world
end

function Scene:getBox2DWorld()
	return self.b2world
end

function Scene:getBox2DWorldGround()
	return self.b2ground
end

function Scene:pauseBox2DWorld( paused )
	self.b2world:pause( paused )
end

function Scene:getDebugDrawQueue()
	return self.debugDrawQueue
end

function Scene:getEntities()
	return self.entities
end

function Scene:getEntityCount()
	return table.len( self.entities )
end

function Scene:getEditorInputDevice()
	return getDefaultInputDevice()
end

function Scene:getMainRenderContext()
	return game:getMainRenderContext()
end

function Scene:getMainRenderTarget()
	return self:getMainRenderContext():getRenderTarget()
end

function Scene:getGUID()
	return self.__guid
end

function Scene:deviceToContext( x, y )
	return self:getMainRenderContext():deviceToContext( x, y )
end

function Scene:contextToDevice( x, y )
	return self:getMainRenderContext():contextToDevice( x, y )
end

function Scene:foreachEntity( func )
	for key, group in pairs( self.rootGroups ) do
		group:foreachEntity( func, true )
	end
end
