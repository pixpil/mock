module 'mock'

local GlobalAnimatorVarChangeListeners = {}

if getG( 'gii' ) then
	function addGlobalAnimatorVarChangeListener( l )
		GlobalAnimatorVarChangeListeners[ l ] = true
	end
end

local nameToTimerMode = {
	[ 'normal' ]          = MOAITimer.NORMAL;
	[ 'reverse' ]         = MOAITimer.REVERSE;
	[ 'continue' ]        = MOAITimer.CONTINUE;
	[ 'continue_reverse' ]= MOAITimer.CONTINUE_REVERSE;
	[ 'loop' ]            = MOAITimer.LOOP;
	[ 'loop_reverse' ]    = MOAITimer.LOOP_REVERSE;
	[ 'ping_pong' ]       = MOAITimer.PING_PONG;
}

local function _affirmMode( m, fallback )
	fallback = fallback or MOAITimer.NORMAL
	local tt = type( m )
	if tt == 'string' then
		return nameToTimerMode[ m ] or fallback
	elseif tt == 'number'then
		return m
	else
		return fallback
	end
end

--------------------------------------------------------------------
CLASS: Animator ( Component )
	:MODEL{
		Field 'data'         :asset_pre('animator_data') :getset( 'DataPath' );
		'----';
		Field 'noPooling'    :boolean();
		Field 'throttle'     :number() :range( 0 ) :meta{ step=0.1 } :getset( 'Throttle' );
		'----';
		Field 'default'      :string() :selection( 'getClipNames' );
		Field 'autoPlay'     :boolean();
		Field 'autoPlayMode' :enum( EnumTimerModeWithDefault );
	}

function Animator:__init()
	self.retainedState = false
	self.dataPath    = false
	self.data        = false
	self.default     = 'default' --default clip
	self.activeState = false
	self.throttle    = 1
	self.scale       = 1
	self.autoPlay    = true
	self.autoPlayMode= false
	self.vars        = {}
	self.varSeq      = 0
	self.states      = {}
	self.statePool   = {}
	self.noPooling = false
	self.activeStateLocked = false
	self.listeners   = {}
end



--------------------------------------------------------------------
function Animator:onAttach( entity )
end
--------------------------------------------------------------------

function Animator:setDataPath( dataPath )
	self.dataPath = dataPath
	self.data = mock.loadAsset( dataPath )
	if self.data then
		self.data:prebuildAll()
	end
	self:stop()
	self.statePool = {}
end

function Animator:getDataPath()
	return self.dataPath
end

function Animator:getData()
	return self.data
end

function Animator:getClipNames()
	local data = self.data
	if not data then return nil end
	return data:getClipNames()
end

function Animator:addListener( l )
	self.listeners[ l ] = true
end

function Animator:removeListener( l )
	self.listeners[ l ] = nil
end

--------------------------------------------------------------------
--Track access
--------------------------------------------------------------------
function Animator:getClip( clipName )
	if not self.data then return nil end
	return self.data:getClip( clipName )
end

function Animator:findTrack( clipName, trackName, trackType )
	local clip = self:getClip( clipName )
	if not clip then
		_warn('Animator has no clip', clipName)
		return nil
	end
	return clip:findTrack( trackName, trackType )
end

function Animator:findTrackByType( clipName, trackType )
	local clip = self:getClip( clipName )
	if not clip then
		_warn('Animator has no clip', clipName)
		return nil
	end
	return clip:findTrackByType( trackType )
end

--------------------------------------------------------------------
--playback
function Animator:hasClip( name )
	if not self.data then
		return false
	end
	return self.data:getClip( name ) and true or false
end

function Animator:createAnimatorState()
	return AnimatorState()
end

function Animator:_loadClip( clip, makeActive, _previewing )
	makeActive = makeActive ~= false
	local prevState = self.activeState

	if makeActive then
		self:stop()
	end

	local state
	if not _previewing then --try pool
		--avoid edge case
		local stateInPool = self:peekStateFromPool( clip )
		local reusing_updating_state = stateInPool and stateInPool._updating
		if not reusing_updating_state then
			state = self:popStateFromPool( clip )
		end
	end
	
	if not state then
		state = self:createAnimatorState()
		state.previewing = _previewing
		state:setParentThrottle( self.throttle )
		state:loadClip( self, clip )
	end

	if makeActive then
		self.activeState = state
	end
	--clear stopped state
	local states = self.states
	local stopped = false
	for state in pairs( states ) do
		if not state:isActive() then
			if not stopped then stopped = {} end
			stopped[ state ] = true
		end
	end
	if stopped then
		for state in pairs( stopped ) do
			states[ state ] = nil
		end
	end
	states[ state ] = true
	return state
end

function Animator:loadClip( clip, makeActive, _previewing )
	if not clip then return end
	makeActive = makeActive ~= false
	if self.activeStateLocked and makeActive then
		_warn( singletraceback(3) )
		_warn( 'attempt to change clip of locked animator', clip, self:getEntityName() )
		return false
	end

	if not self.data then
		_warn('Animator has no data', self )
		return false
	end

	local clipData
	if type( clip ) == 'string' then --by name
		clipData = self.data:getClip( clip )
	else
		if isInstance( clip, AnimatorClip ) then
			clipData = clip
		end
	end
	if not clipData then
		_warn( 'Animator has no clip', clip, self )
		return false
	end
	return self:_loadClip( clipData, makeActive, _previewing )
end

function Animator:getActiveState()
	return self.activeState
end

function Animator:getActiveClipName()
	local state = self.activeState
	return state and state:getClipName()
end

function Animator:onStateStart( state )
	for l in pairs( self.listeners ) do
		l( 'start', self, state )
	end
end

function Animator:onStateStop( state )
	--push into pool
	if not state.previewing then
		for l in pairs( self.listeners ) do
			l( 'stop', self, state )
		end
		self:pushStateIntoPool( state )
		-- print( 'state stopped', state, self.activeState, self.retainedState )
		if state == self.activeState then
			if self.retainedState then
				self.activeState = self.retainedState
				self.retainedState = false
				self.activeState:pause( false )
			end
		end
	end
end

local insert = table.insert
local remove = table.remove
function Animator:pushStateIntoPool( state )
	if self.noPooling then return end
	local pool = self.statePool
	if not pool then return end
	local clip = state.clip
	local list = pool[ clip ]
	if not list then
		list = {}
		pool[ clip ] = list
	end
	insert( list, state )
end

function Animator:clearStatePool()
	self.statePool = {}
end

function Animator:peekStateFromPool( clip )
	local list = self.statePool[ clip ]
	if not list then return false end
	return list[1]
end

function Animator:popStateFromPool( clip )
	local list = self.statePool[ clip ]
	if not list then return false end
	local state = remove( list, 1 )
	if state then
		state.stopping = false
		state:reset()
		return state
	end
end

function Animator:loopClip( clipName )
	return self:playClip( clipName, MOAITimer.LOOP )
end

function Animator:playClip( clip, mode, retainCurrentState )
	if retainCurrentState then
		self.retainedState = self.activeState
	else
		self.retainedState = false
	end

	local state = self:loadClip( clip )
	if state then
		state:setMode( _affirmMode( mode ) )
		state:start()
	end
	return state
end

function Animator:lockClip( locked )
	self.activeStateLocked = locked ~= false
end

function Animator:unlockClip()
	return self:lockClip( false )
end

function Animator:stop()
	if not self.activeState then return end
	if self.activeState == self.retainedState then
		self.retainedState:pause()
	else
		self.retainedState = false
		self.activeState:stop()
	end
	-- for state in pairs( self.states ) do
	-- 	state:stop()
	-- end
	-- self.states = {}
end

function Animator:pause( paused )
	if not self.activeState then return end
	self.activeState:pause( paused )
end

function Animator:resume()
	return self:pause( false )
end

function Animator:playDefaultClip()
	if self.default and self.data then
		if self.default == '' then return end
		return self:playClip( self.default, self.autoPlayMode )
	end
	return false
end

function Animator:setThrottle( th )
	self.throttle = th
	local st = self.activeState
	if st then
		return st:setParentThrottle( th )
	end
end

function Animator:getThrottle()
	return self.throttle
end

-----
function Animator:onStart( ent )	
	if self.autoPlay then
		self:playDefaultClip()
	end
end

function Animator:onSuspend( sstate )
	local states = self.states
	for s in pairs( self.states ) do
		s:stop()
	end
	self:stop()
	self.activeState = false
	self.states = {}
end

function Animator:onResurrect( sstate )
	if self.autoPlay then
		self:playDefaultClip()
	end
end

function Animator:onDetach( ent )
	self.statePool = false
	self:stop()
	for s in pairs( self.states ) do
		s:clear()
	end
	self.activeState = false
	self.states = {}
end

function Animator:onPreviewStart()
end

function Animator:onPreviewStop()
end

if getG( 'gii' ) then
	function Animator:setVar( id, value )
		local vars = self.vars
		if vars[ id ] == value then return end
		vars[ id ] = value
		self.varSeq = self.varSeq + 1
		for listener in pairs( GlobalAnimatorVarChangeListeners ) do
			listener( self, id, value )
		end
	end
else

	function Animator:setVar( id, value )
		local vars = self.vars
		if vars[ id ] == value then return end
		vars[ id ] = value
		self.varSeq = self.varSeq + 1
	end
end

function Animator:getVar( id, default )
	local v = self.vars[ id ]
	if v == nil then return default end
	return v
end

function Animator:seekVar( id, value, duration ,easeMode )
	--TODO
end

function Animator:getDepAnimators()

end

--------------------------------------------------------------------
mock.registerComponent( 'Animator', Animator )
