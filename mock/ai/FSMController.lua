module 'mock'


--------------------------------------------------------------------
local stateCollectorMT
local setmetatable=setmetatable
local insert, remove = table.insert, table.remove
local rawget,rawset=rawget,rawset
local pairs=pairs

stateCollectorMT = {
	__index = function( t, k )
		local __state = t.__state
		local __id    = t.__id
		return setmetatable({
			__state = __state and __state..'.'..k or k,
			__id    = __id and __id..'_'..k or '_FSM_'..k,
			__class = t.__class
		}	,stateCollectorMT)
	end,

	--got state method
	__newindex =function( t, action, func ) 
		local name  = t.__state
		local id    = t.__id
		local class = t.__class
		if
			action ~= 'jumpin' and action ~= 'jumpout'
			and action~='step' and action~='enter' and action~='exit' and action~='coroutine'
		then
			return error(
				string.format( 'unsupported state action: %s:%s', name, action )
			)
		end
		--NOTE:validation will be done after setting scheme to controller
		--save under fullname
		local methodName = id..'__'..action
		rawset ( class, methodName, func )
		
		class.__FSMMethods[ name..':'..action ] = func

	end

}

local function newStateMethodCollector( class )
	return setmetatable({
		__state = false,
		__id    = false,
		__class = class
	}	,stateCollectorMT )
end

--------------------------------------------------------------------
CLASS:  FSMController ( Behaviour )
	:MODEL{
		Field 'state'  :string() :readonly() :get('getState');
		Field 'scheme' :asset_pre('fsm_scheme') :getset('Scheme');
		Field 'syncEntityState' :boolean();
	}
	:META{
		category = 'behaviour'
	}
-----fsm state method collector
FSMController.fsm = newStateMethodCollector( FSMController ) 

function FSMController.__createStateMethodCollector( targetClass )
	return newStateMethodCollector( targetClass )
end

function FSMController:__initclass( subclass )
	subclass.__FSMMethods = {}
	subclass.fsm = newStateMethodCollector( subclass )
end

function FSMController:__init()
	self.stateElapsedTime = 0
	self.stateElapsedFrames = 0
	local msgBox = {}
	self.msgBox = msgBox
	self.syncEntityState = false
	local msgFilter = false
	self.msgBoxListener = function( msg, data, source )
		if msgFilter and msgFilter( msg, data, source ) == false then return end
		if msg == 'state.change' then
			self:setVar( 'entity_state', data[1] )
		end
		return insert( msgBox, { msg, data, source } )
	end
	self._msgFilterSetter = function( f ) msgFilter = f end
	self._currentStateCoroutine = false
	self.forceJumping = false

	self.vars        = {}
	self.varDirty    = true
	self.currentExprJump = false

	--lift
	self.pollMsg = self.pollMsg
end

function FSMController:setMsgFilter( func )
	return self._msgFilterSetter( func )
end

function FSMController:onAttach( entity )
	Behaviour.onAttach( self, entity )
	entity:addMsgListener( self.msgBoxListener )
end

function FSMController:onStart( entity )
	self.threadFSMUpdate = self:addDaemonCoroutine( 'onThreadFSMUpdate' )
	if self.paused then
		self.threadFSMUpdate:pause()
	end
	return Behaviour.onStart( self, entity )
end

function FSMController:onDetach( ent )
	FSMController.__super.onDetach( self, ent )
	ent:removeMsgListener( self.msgBoxListener )
end

function FSMController:pause( paused )
	self.paused = paused ~= false
	if self.threadFSMUpdate then
		self.threadFSMUpdate:pause( self.paused )
	end
end

function FSMController:isPaused()
	return self.paused
end

function FSMController:getFSMUpdateThread()
	return self.threadFSMUpdate
end

function FSMController:getState()
	return self.state
end

local function _findEqual( s, a, b, ... )
	if s == a then return a end
	if not b then return false end
	return _findEqual( s, b, ... )
end

function FSMController:inState( a, b, ... )
	local state = self:getState()
	return _findEqual( state, a, b, ... )
	-- if a == state then return a end
	-- if not b then return false end
	-- return _findEqual( s, b, ... )
end

local stringfind=string.find
local function  _isStartWith(a,b,b1,...)
	if not a then return false end
	if stringfind(a,b)==1 then return true end --a:startWith(b)
	if b1 then return _isStartWith(a,b1,...) end
	return false
end

function FSMController:inStateGroup( s1, ... )
	return _isStartWith( self:getState(), s1, ... )
end

function FSMController:acceptStateChange( s )
	return true
end

function FSMController:setState( state )
	self.state = state
	self.stateElapsedTime = 0
	self.stateElapsedFrames = 0
	if self._entity and self.syncEntityState then
		self._entity:setState( state )
	end
	self:updateExprJump()
end

function FSMController:getEntityState()
	return self._entity and self._entity:getState()
end

function FSMController:forceState( state, msg, args )
	self.forceJumping = { state, msg or '__forced', args or {} }
end

function FSMController:forceRefreshState()
	return self:forceState( self:getState() )
end

function FSMController:clearMsgBox()
	table.clear( self.msgBox )
end

function FSMController:pushTopMsg( msg, data, source )
	return insert( self.msgBox, 1, { msg, data, source } )
end

function FSMController:appendMsg( msg, data, source )
	return insert( self.msgBox, { msg, data, source } )
end

function FSMController:pollMsg()
	local m = remove( self.msgBox, 1 )
	if m then return m[1], m[2], m[3] end
	return nil
end

function FSMController:peekMsg( id )
	id = id or 1
	local m = self.msgBox[ id ]
	if m then return m[1],m[2],m[3] end
	return nil
end

function FSMController:hasMsgInBox( msg )
	for i, m in ipairs( self.msgBox ) do
		if m[1] == msg then return true end
	end
	return false
end

function FSMController:updateFSM( dt )
	local func = self.currentStateFunc
	if func then
		return func( self, dt, 0 )
	end
end

function FSMController:setScheme( schemePath )
	self.schemePath = schemePath
	local scheme = loadAsset( schemePath )
	self.scheme = scheme
	if scheme then
		self.currentStateFunc = scheme[0]
		self:validateStateMethods()
	else
		self.currentStateFunc = nil
	end	
end

function FSMController:validateStateMethods()
	--todo
end

function FSMController:getScheme()
	return self.schemePath
end

function FSMController:onThreadFSMUpdate()
	local dt = 0
	while true do
		self.stateElapsedTime = self.stateElapsedTime + dt
		self.stateElapsedFrames = self.stateElapsedFrames + 1
		if self.varDirty then
			self:updateExprJump()
		end
		-- self:updateFSM( dt )
		local func = self.currentStateFunc
		if func then
			func( self, dt, 0 )
		end
		dt = coroutine.yield()
	end
end

function FSMController:getStateElapsedTime()
	return self.stateElapsedTime
end

function FSMController:getStateElapsedFrames()
	return self.stateElapsedFrames
end

----
function FSMController:setVar( key, value )
	local v0 = self.vars[ key ]
	if v0 == value then
		return
	end
	self.vars[ key ] = value
	self.varDirty = true
end

function FSMController:getVar( key, default )
	local v = self.vars[ key ]
	if v == nil then return default end
	return v
end

function FSMController:getEvalEnv()
	return self.vars
end

function FSMController:updateExprJump()
	self.varDirty = false
	local exprJump = self.currentExprJump
	if not exprJump then return end
	local env = self:getEvalEnv()
	for msg, exprFunc in pairs( exprJump ) do
		local ok, value = exprFunc( env )
		if ok and value then
			self:tell( exprFunc )
		end
	end
end

function FSMController:_startFSMStateCoroutine( func, ... )
	assert( not self._currentStateCoroutine )
	self._currentStateCoroutine = self:addCoroutine( function( this, ... )
		local result = func( this, ... )
		this._currentStateCoroutine = false
		if result == nil then result = true end
		this._currentStateCoroutineResult = result
	end, self, ... )
end

function FSMController:_terminateFSMStateCoroutine()
	self._currentStateCoroutine:stop()
	self._currentStateCoroutine = false
	self._currentStateCoroutineResult = false
end

registerComponent( 'FSMController', FSMController )
