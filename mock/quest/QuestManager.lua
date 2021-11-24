module 'mock'

--------------------------------------------------------------------
local _questManger
function getQuestManager()
	return _questManger
end

--------------------------------------------------------------------
CLASS: QuestSessionSchemeEntry ()
	:MODEL{}

function QuestSessionSchemeEntry:__init( session, path )
	self.session  = session
	self.path     = path or false
	self.valid    = true
end

function QuestSessionSchemeEntry:save()
	return {
		path = self.path;
	}
end

function QuestSessionSchemeEntry:load( data )
	self.path = data[ 'path' ]
end

--------------------------------------------------------------------
CLASS: QuestSession ()
	:MODEL{}

function QuestSession:__init()
	self.name = 'QuestSession'
	self.comment = ''
	self.schemeEntries = {}
	self.default = false

	self.state = QuestState()
	self.needRebuild = true

end

function QuestSession:getState()
	return self.state
end

function QuestSession:hasScheme( path )
	for i, entry in ipairs( self.schemeEntries ) do
		if entry.path == path then return true end
	end
	return false
end

function QuestSession:addSchemeEntry( path )
	local scheme = loadAsset( path )
	if not scheme then
		_error( 'failed loading Quest Scheme', path )
		return false
	end
	local entry = QuestSessionSchemeEntry( self, path )
	table.insert( self.schemeEntries, entry )
	self.needRebuild = true
	return entry
end

function QuestSession:removeSchemeEntry( entry )
	local idx = table.index( self.schemeEntries, entry )
	if not idx then return false end
	table.remove( self.schemeEntries, idx )
	self.needRebuild = true
	return true
end

function QuestSession:setName( name )
	self.name = name
	_questManger:resetSessionMap()
end

function QuestSession:getName()
	return self.name
end

function QuestSession:getNode( name )
	return self.state:getNode( name )
end

function QuestSession:findNode( pattern )
	return self.state:findNode( pattern )
end

function QuestSession:checkQuestState( name, value )
	return self.state:checkNodeState( name, value )	
end

function QuestSession:update()
	self.state:update()
end

function QuestSession:reset()
	self.state:reset()
end

function QuestSession:saveState()
	local state = self.state
	return state:save()
end

function QuestSession:loadState( data )
	-- self:rebuild()
	self.state.onNodeStateChange = false
	self.state:load( data )
	self.state.onNodeStateChange = function( state, nodeName, newState, oldState )
		local fullname = self.name .. ':' ..nodeName
		emitGlobalSignal( 'quest.state_change', fullname, newState, oldState )
	end

	emitGlobalSignal( 'quest.state_load', self.name )
	--TODO: check scheme matching?
	-- --validate
	-- for i, stateData in ipairs( data[ 'states' ] or {} ) do
	-- 	local name = stateData[ 'name' ]
	-- 	local state = self:getState( name )
	-- 	if not state then
	-- 		_error( 'quest state not exists', name )
	-- 		return false
	-- 	end
	-- 	if stateData[ 'scheme' ] ~= state.scheme.path then
	-- 		_error( 'quest state scheme mismatched', name, stateData[ 'scheme' ] )
	-- 		return false
	-- 	end
	-- end

	-- local hasError = false
	-- for i, stateData in ipairs( data[ 'states' ] or {} ) do
	-- 	local name = stateData[ 'name' ]
	-- 	local state = self:getState( name )
	-- 	if not state:load( stateData[ 'state' ] ) then hasError = true end
	-- end
	-- return not hasError
end

function QuestSession:rebuild()
	if not self.needRebuild then return false end
	self.needRebuild = false
	local retainedStateData = self:saveState()
	local schemes = {}
	for i, entry in ipairs( self.schemeEntries ) do
		local path = entry.path
		local scheme = mock.loadAsset( path )
		if scheme then
			table.insert( schemes, scheme )
			entry.valid = true
		else
			_error( 'failed loading quest scheme:', path )
			entry.valid = false
		end
	end
	local state = QuestState( unpack( schemes ) )
	state.session = self
	self.state = state
	self:loadState( retainedStateData )
end

function QuestSession:saveConfig()
	local entryDatas = {}
	for i, entry in ipairs( self.schemeEntries ) do
		entryDatas[i] = entry:save()
	end
	return {
		name    = self.name,
		comment = self.comment,
		default = self.default,
		entries = entryDatas,
	}
end

function QuestSession:loadConfig( data )
	self.name    = data[ 'name' ]
	self.comment = data[ 'comment' ]
	self.default = data[ 'default' ]
	local entries =  {}
	for i, entryData in ipairs( data[ 'entries' ] or {} ) do
		local entry = QuestSessionSchemeEntry( self )
		entry:load( entryData )
		table.insert( entries, entry )
	end
	self.schemeEntries = entries
	self.needRebuild = true
	self:rebuild()
end


--------------------------------------------------------------------
CLASS: QuestManager ( GlobalManager )
	:MODEL{}

function QuestManager:__init()
	self.sessions = {}
	self.sessionMap = false
	self.pendingUpdate = true
end

function QuestManager:getKey()
	return 'QuestManager'
end

function QuestManager:updateSessionMap()
	local map = {}
	for i, session in ipairs( self.sessions ) do
		local name = session.name
		if name then
			if map[ session.name ] then
				_warn( 'duplicated quest session name', name )
			else
				map[ session.name ] = session
			end
		end
	end
	self.sessionMap = map
	return map
end

function QuestManager:scheduleUpdate()
	self.pendingUpdate = true
end

function QuestManager:forceUpdate()
	return self:updateSessions()
end

function QuestManager:updateSessions()
	print( 'update queset ')
	self.pendingUpdate = false
	for _, session in ipairs( self.sessions ) do
		session:update()
	end
end

function QuestManager:resetSessionMap()
	self.sessionMap = false
end

function QuestManager:postInit( game )
	for i, provider in pairs( getQuestContextProviders() ) do
		provider:init()
	end
end

function QuestManager:onUpdate( game, dt )
	if not self.pendingUpdate then return end
	self:updateSessions()
end

function QuestManager:getDefaultSession()
	return self.defaultSession
end

function QuestManager:getSession( name )
	local map = self.sessionMap
	if not map then
		map = self:updateSessionMap()
	end
	return map and map[ name ]
end

function QuestManager:addSession()
	local session = QuestSession()
	table.insert( self.sessions, session )
	self:resetSessionMap()
	return session
end

function QuestManager:removeSession( session )
	local idx = table.index( self.sessions, session )
	if not idx then return false end
	table.remove( self.sessions, idx )
	self:resetSessionMap()
	return true
end

function QuestManager:renameSession( session, name )
	session:setName( name )
end

function QuestManager:getSessions()
	return self.sessions
end

function QuestManager:saveState()
	local data = {}
	local sessionStates = {}
	for i, session in ipairs( self.sessions ) do
		sessionStates[ i ] = {
			name  = session.name,
			state = session:saveState()
		}
	end
	return sessionStates
end

function QuestManager:resetAllSessions()
	for i, session in ipairs( self.sessions ) do
		session:reset()
	end
	self:scheduleUpdate()
end

function QuestManager:loadState( data )
	for i, sdata in ipairs( data ) do
		local name = sdata[ 'name' ]
		local session = self:getSession( name )
		_log( 'loading q state', name, sdata[ 'state' ] )
		if not session then
			_error( 'failed to get session', name )
			return false
		end
		session:loadState( assert( sdata[ 'state' ] ) )
	end
	return true
end

function QuestManager:saveConfig()
	local data = {}
	local sessionDatas = {}
	for i, session in ipairs( self.sessions ) do
		sessionDatas[ i ] = session:saveConfig()
	end
	return {
		sessions = sessionDatas
	}
end

function QuestManager:loadConfig( data )
	local sessions = {}
	local defaultSession = false
	for i, sessionData in ipairs( data[ 'sessions' ] or {} ) do
		local session = QuestSession()
		session:loadConfig( sessionData )
		sessions[ i ] = session
		if session.default then
			defaultSession = session
		end
	end
	if not defaultSession then
		local session1 = sessions[ 1 ]
		if session1 then
			session1.default = true
			defaultSession = session1
		end
	end
	self.defaultSession = defaultSession
	self.sessions = sessions
	self:updateSessionMap()
	
	self:forceUpdate()
end

local function splitSession( n, defaultSessionName )
	local a, b = n:match( '(%w+):(.*)' )
	if a then return a, b end
	return defaultSessionName, n
end

function QuestManager:hasQuestNode( fullname, defaultSessionName )
	local session, node = self:getQuestNode( fullname, defaultSessionName )
	return node and true or false
end

function QuestManager:getQuestNode( fullname, defaultSessionName )
	local sessionName, nodeName =  splitSession( fullname, defaultSessionName )
	local session = sessionName and self:getSession( sessionName )
	if not session then
		if sessionName then
			_warn( 'no session found', sessionName )
		else
			_warn( 'no session specified', sessionName )
		end
		return false
	end
	local node = session:getNode( nodeName )
	return session, node
end

function QuestManager:getQuestNodeState( fullname, defaultSessionName )
	local session, node = self:getQuestNode( fullname, defaultSessionName )
	if session then
		if node then
			return session:getState():getNodeState( node.fullname )
		else
			_warn( 'no quest node found', fullname )
			return false
		end
	else
		return false
	end
end

function QuestManager:isQuestNodePaused( fullname, state, defaultSessionName )
	local session, node = self:getQuestNode( fullname, defaultSessionName )
	if session then
		if node then
			return session:getState():isNodePaused( fullname )
		else
			_warn( 'no quest node found', fullname )
			return nil
		end
	else
		return nil
	end
end

function QuestManager:checkQuestNodeState( fullname, state, defaultSessionName )
	local nstate = self:getQuestNodeState( fullname, defaultSessionName )
	return nstate == state
end



--------------------------------------------------------------------
-- tool function
--------------------------------------------------------------------
function getQuestNodeState( name )
	return getQuestManager():getQuestNodeState( name )
end

function hasQuestNode( name )
	local mgr = getQuestManager()
	return mgr:hasQuestNode( name )
end

function isQuestActive ( name )
	if not hasQuestNode( name ) then return nil end
	local mgr = getQuestManager()
	return mgr:checkQuestNodeState( name, 'active' ) and ( not mgr:isQuestNodePaused( name ) )
end

function isQuestPaused ( name )
	if not hasQuestNode( name ) then return nil end
	return getQuestManager():isQuestNodePaused( name )
end

function isQuestFinished ( name )
	if not hasQuestNode( name ) then return nil end
	return getQuestManager():checkQuestNodeState( name, 'finished' )
end

function isQuestNotPlayed ( name )
	if not hasQuestNode( name ) then return nil end
	return getQuestManager():checkQuestNodeState( name, nil )
end

function isQuestPlayed ( name )
	if not hasQuestNode( name ) then return nil end
	return not getQuestManager():checkQuestNodeState( name, nil )
end

local function getQuestNodeAndState( name )
	local mgr = getQuestManager()
	local session, node = mgr:getQuestNode( name )
	if not ( node and session ) then
		_warn( 'no node/session found in quest session', name )
		return false
	end
	local questState = session:getState()
	local nodeState = questState:getNodeState( node.fullname )
	return node, nodeState, questState
end

function finishQuestNode( name )
	local node, nodeState, questState = getQuestNodeAndState( name )
	if not node then return false end
	if nodeState ~= 'active' then
		_warn( 'quest node is not active' )
	end
	node:finish( questState )
	getQuestManager():forceUpdate()
end

function abortQuestNode( name )
	local node, nodeState, questState = getQuestNodeAndState( name )
	if not node then return false end
	if nodeState ~= 'active' then
		_warn( 'quest node is not active' )
	end
	node:abort( questState )
	getQuestManager():forceUpdate()
end

function resetQuestNode( name )
	local node, nodeState, questState = getQuestNodeAndState( name )
	if not node then return false end
	node:reset( questState )
	getQuestManager():forceUpdate()
end

function pauseQuestNode( name, paused )
	local node, nodeState, questState = getQuestNodeAndState( name )
	if not node then return false end
	if paused ~= false then
		node:pause( questState )
	else
		node:resume( questState )
	end
	getQuestManager():forceUpdate()
end

function resumeQuestNode( name )
	return pauseQuestNode( name, false )
end

function startQuestNode( name )
	local node, nodeState, questState = getQuestNodeAndState( name )
	if not node then return false end
	local p = node
	while true do
		p = p:getParent()
		if not p then break end
		p:start( questState, nil, true ) --skipSubNode
	end
	node:start( questState )
	getQuestManager():forceUpdate()
end

--------------------------------------------------------------------
_questManger = QuestManager()
