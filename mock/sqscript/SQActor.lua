module 'mock'

local _SQSystemPaused = false
function pauseSQSystem( paused )
	local p = paused ~= false
	if p == _SQSystemPaused then return end
	_SQSystemPaused = p
	if p then
		emitGlobalSignal( 'sq.system.pause' )
	else
		emitGlobalSignal( 'sq.system.resume' )
	end
end

function isSQSystemPaused()
	return _SQSystemPaused
end

---------------------------------------------------------------------
CLASS: SQContextProvider ()
	:MODEL{}

function SQContextProvider:init()
end

function SQContextProvider:getContextEntity( actor, contextId )
	return nil
end

function SQContextProvider:getEnvVar( actor, key )
	return nil
end


local SQContextProviders = {}
function registerSQContextProvider( id, provider )
	SQContextProviders[ id ] = provider
end

function getSQContextProviders()
	return SQContextProviders
end

function getSQActorsInScene( scene )
	local actorRegistry = scene:getUserObject( 'SQActors' )
	if not actorRegistry then
		actorRegistry = setmetatable( {}, { __no_traverse = true } )
		scene:setUserObject( 'SQActors', actorRegistry )
	end
	return actorRegistry
end

--------------------------------------------------------------------
CLASS: SQActor ( Behaviour )
	:MODEL{
		Field 'name'     :string();
		Field 'script' :asset( 'sq_script' ) :getset( 'Script' );
		Field 'autoStart' :boolean();
}

function SQActor:__init()
	self.name         = ''
	self.activeState  = false
	self.autoStart    = true
	self.allowRecording = true
	self.threadExecution = false
end

function SQActor:onStart( ent )
	SQActor.__super.onStart( self, ent )
	if self.autoStart then
		self:startScript()
	end
end

function SQActor:onAttach( ent )
	SQActor.__super.onAttach( self, ent )
	local scene = ent:getScene()
	local actorRegistry = getSQActorsInScene( scene )
	actorRegistry[ self ] = true
	self:loadScript()
end

function SQActor:onDetach( ent )
	SQActor.__super.onDetach( self, ent )
	local actorRegistry = getSQActorsInScene( ent:getScene() )
	actorRegistry[ self ] = nil
	emitGlobalSignal( 'sq.detach', self )
end

function SQActor:getState()
	return self.activeState
end

function SQActor:findActorByName( name )
	local scene = self:getScene()
	local actorRegistry = scene:getUserObject( 'SQActors' )
	for actor in pairs( actorRegistry ) do
		if actor.name == name then return actor end
	end
	return nil
end

function SQActor:getScript()
	return self.scriptPath
end

function SQActor:setScript( path )
	self.scriptPath = path
	self.script = false
	self:loadScript()
end

function SQActor:loadScript()
	if not self._entity then return end
	self.activeState = SQState()
	local script = loadAsset( self.scriptPath )
	self.script = script
end

function SQActor:startScript()
	if not self.script then return end
	self.activeState:setEnv( 'actor',  self )
	self.activeState:setEnv( 'entity', self:getEntity() )
	self.activeState:loadScript( self.script )
	self.activeState:initEvalEnv( self )
	
	emitGlobalSignal( 'sq.start', self, self.activeState )
	-- if not _SQSystemPaused then
		-- self.activeState:update( 0 )
	-- end
	self:restartExcutionThread()
end

function SQActor:restartExcutionThread()
	if self.threadExecution then
		self.threadExecution:stop()
		self.threadExecution = false
	end
	self.threadExecution = self:addCoroutine( 'actionExecution' )
	-- self.threadExecution:setDefaultParent( true )
	return self.threadExecution
end

function SQActor:getThreadExecution()
	return self.threadExecution
end


function SQActor:stopScript()
	if not self.activeState then return end
	emitGlobalSignal( 'sq.stop', self, self.activeState )
	self.activeState:stop()
	if self.threadExecution then
		self.threadExecution:stop()
		self.threadExecution = false
	end
end

function SQActor:actionExecution()
	local state = self.activeState
	if not state then return end
	local dt = 0
	while true do		
			if not _SQSystemPaused then
				state:update( dt )
			end
		if not state:isRunning() then break end
		--TODO: stop this coroutine if NO child actions running. ( need Host support )
		dt = coroutine.yield()
	end
	--stopped when sq is ended and no msg callback
end

function SQActor:findRoutineContext( name )
	if not self.activeState then return end
	return self.activeState:findRoutineContext( name )
end

function SQActor:stopRoutine( name )
	if not self.activeState then return end
	return self.activeState:stopRoutine( name )
end

function SQActor:startRoutine( name )
	if not self.activeState then return end
	return self.activeState:startRoutine( name )
end

function SQActor:restartRoutine( name )
	if not self.activeState then return end
	return self.activeState:restartRoutine( name )
end

function SQActor:isRoutineRunning( name )
	if not self.activeState then return end
	return self.activeState:isRoutineRunning( name )
end

function SQActor:startAllRoutines()
	if not self.activeState then return end
	return self.activeState:startAllRoutines()
end

function SQActor:getStateEnv( key, default )
	if not self.activeState then return nil end
	local v = self.activeState.evalEnv[ key ]
	if v == nil then return default end
	return v
end

function SQActor:getEnvVar( varKey )
	local globalEnv = getGlobalSQEvalEnv()
	local value = globalEnv[ varKey ]
	if value ~= nil then return value end
	for key, provider in pairs( SQContextProviders ) do
		local value = provider:getEnvVar( self, varKey )
		if value ~= nil then return value end
	end
	return self:getDefaultEnvVar( varKey )
end

function SQActor:getDefaultEnvVar( varKey )
	return nil
end

function SQActor:_findContextEntity( id )
	for key, provider in pairs( SQContextProviders ) do
		local ent = provider:getContextEntity( self, id )
		if ent then return ent end
	end
	return nil
end

function SQActor:getContextEntity( contextId )
	if not contextId or contextId == 'self' then
		return self:getEntity()
	end
	return self:_findContextEntity( contextId )
end

function SQActor:getContextEntities( contexts )
	local result = {}
	local n = #contexts
	if n == 0 then
		return { self:getEntity() }
	end
	for i, id in ipairs( contexts ) do
		local ent
		if id == 'self' then
			ent = self:getEntity()
		else
			ent = self:_findContextEntity( id )
		end
		if ent then
			table.insert( result, ent )
		end
	end
	return result
end

function SQActor:incSignalCounter( id )
	if self.activeState then
		return self.actionState:incSignalCounter( id )
	end
end


--------------------------------------------------------------------
mock.registerComponent( 'SQActor', SQActor )
