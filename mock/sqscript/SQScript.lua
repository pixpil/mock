module 'mock'

local ccreate, cresume, cyield, cstatus
	= coroutine.create, coroutine.resume, coroutine.yield, coroutine.status

local insert, remove = table.insert, table.remove

local _globalSQNodeListeners = table.weak_v()

function addGlobalSQNodeListener( l )
	table.insert( _globalSQNodeListeners, l )
	return l
end

function removeGlobalSQNodeListener( l )
	local idx = table.index( _globalSQNodeListeners, l )
	if idx then
		table.remove( _globalSQNodeListeners, idx )
	end
end

--------------------------------------------------------------------

--FastForward
--------------------------------------------------------------------
registerGlobalSignals{
	'sq_fastforward.start',
	'sq_fastforward.stop',
}

local _SQFastForwarding = false
local _SQFastForwardingStates = {}
local _SQFastForwardingSpeed = 1

function isSQFastForwarding()
	return _SQFastForwarding
end

function getSQFastForwardingSpeed()
	return _SQFastForwardingSpeed
end

function toggleSQFastForward( key, toggle )
	local currentToggle = _SQFastForwardingStates[ key ] or false
	if toggle == nil then
		toggle = not currentToggle
	end
	if toggle then
		startSQFastForward( key )
	else
		stopSQFastForward( key )
	end
end

function resetSQFastForward()
	_SQFastForwardingStates = {}
	_SQFastForwarding = false
	emitSignal( 'sq_fastforward.stop' )
end

function startSQFastForward( key, speed )
	_SQFastForwardingStates[ key ] = true
	if _SQFastForwarding then return end
	_SQFastForwarding = true
	speed = speed or _SQFastForwardingSpeed
	_SQFastForwardingSpeed = speed
	_log( 'start sq fast forward')
	emitSignal( 'sq_fastforward.start', speed )
end

function stopSQFastForward( key )
	_SQFastForwardingStates[ key ] = nil
	if not _SQFastForwarding then return end
	if not next( _SQFastForwardingStates ) then
		_SQFastForwarding = false
		_log( 'stop sq fast forward')
		emitSignal( 'sq_fastforward.stop' )
	end
end


--------------------------------------------------------------------
CLASS: SQNode ()
CLASS: SQRoutine ()
CLASS: SQScript ()
CLASS: SQState ()


--------------------------------------------------------------------
local _globalSQEvalEnv = {}

function getGlobalSQEvalEnv()
	return _globalSQEvalEnv
end

--------------------------------------------------------------------
SQNode :MODEL{
		Field 'index'   :int() :no_edit(); 
		Field 'comment' :string() :no_edit(); 
		Field 'active'  :boolean() :no_edit(); 

		Field 'parentRoutine' :type( SQRoutine ) :no_edit();
		Field 'parentNode' :type( SQNode ) :no_edit();
		Field 'children'   :array( SQNode ) :no_edit();
}

function SQNode.register( clas, id )
	registerSQNode( id, self )
end

function SQNode:__init()
	self.parentRoutine = false
	
	self.index      = 0
	self.depth      = 0
	self.active     = true
	self.parentNode = false
	self.children   = {}

	self.comment    = ''

	self.context    = false
	self.tags       = false
	
	self.lineNumber = 0
end

function SQNode:__tostring()
	return string.format( '%s%s@%d', self:__repr(), self:getType(), self.lineNumber )
end

function SQNode:getFirstContext()
	if self.context then
		return self.context[ 1 ]
	else
		return nil
	end
end

function SQNode:getContextString()
	if not self.context then return nil end
	return string.join( ',', self.context )
end

function SQNode:hasTag( t )
	if not self.tags then return false end
	return self.tags[ t ] ~= nil
end

function SQNode:getTagStringValue( t )
	local v = self:getTag( t )
	return type( v ) == 'string' and v or nil
end

function SQNode:getTag( t )
	if not self.tags then return nil end
	return self.tags[ t ]
end

local match = string.match
function SQNode:matchTag( pattern )
	if not self.tags then return false end
	for name, value in pairs( self.tags ) do
		if match( name, pattern ) then return name, value end
	end
	return nil
end

function SQNode:findFirstTag( targets )
	if not self.tags then return false end
	for i, target in ipairs( targets ) do
		local value = self:getTag( target )
		if value ~= nil then return target, value end
	end
	return nil
end

function SQNode:matchFirstTag( targets )
	if not self.tags then return false end
	for i, target in ipairs( targets ) do
		local value = self:matchTag( target )
		if value ~= nil then return target, value end
	end
	return nil
end

function SQNode:checkBlockTag( defaultBlocking )
	if defaultBlocking then
		if self:hasTag( 'no_block' ) then
			return false
		else
			return true
		end
	else
		if self:hasTag( 'block' ) then
			return true
		else
			return false
		end
	end
end

function SQNode:getInlineDirectives()
	return self.inlineDirectives
end

function SQNode:setInlineDirectives( directives )
	self.inlineDirectives = table.simplecopy( directives )
end

local next, remove = next, table.remove
function SQNode:removeInlineDirectives( name )
	local directives = self.inlineDirectives
	if not directives then return 0 end
	local i = nil
	local count = 0
	while true do
		i, v  = next( directives, i )
		if not i then break end
		if v.name == name then 
			remove( directives, i )
			count = count + 1
		end
	end
	return count > 0 and count
end

function SQNode:addInlineDirectives( name, value )
	if not self.inlineDirectives then
		self.inlineDirectives = {}
	end
	table.insert( self.inlineDirectives, { name = name, value = value } )
end

function SQNode:getInlineDirectives( name, default )
	for _, d in ipairs( self.inlineDirectives ) do
		if d.name == name then return d.value end
	end
	return default or nil
end


function SQNode:getDirective( key, default )
	if not self.directives then
		return default
	end
	local v = self.directives[ key ]
	if v == nil then return default end
	return v
end

function SQNode:hasDirective( key )
	return self:getDirective( key, nil ) ~= nil
end

function SQNode:getRoot()
	return self.parentRoutine:getRootNode()
end
         
function SQNode:getChildren()
	return self.children
end

function SQNode:getFirstChild()
	return self.children[1]
end

function SQNode:getChildrenCount()
	return #self.children
end

function SQNode:isParentOf( n )
	local p = n and n.parentNode
	while p do
		if p == self then return true end
		p = p.parentNode
	end
	return false
end

function SQNode:getParent()
	return self.parentNode
end

function SQNode:getPrevSibling()
	local p = self.parentNode
	local siblings = p and p.children
	local index = table.index( siblings, self )
	return siblings[ index - 1 ]
end

function SQNode:getNextSibling()
	local p = self.parentNode
	local siblings = p and p.children
	local index = table.index( siblings, self )
	return siblings[ index + 1 ]
end

function SQNode:getRoutine()
	return self.parentRoutine
end

function SQNode:getScript()
	return self.parentRoutine:getScript()
end

function SQNode:isGroup()
	return false
end

function SQNode:canInsert()
	return false
end

function SQNode:isBuiltin()
	return false
end

function SQNode:isExecutable()
	return true
end

function SQNode:initFromEditor()
end

function SQNode:addChild( node, idx )
	node.parentNode = self
	node.parentRoutine = assert( self.parentRoutine )
	node.depth = self.depth + 1
	if idx then
		insert( self.children, idx, node )
	else
		insert( self.children, node )
	end
	return node
end

function SQNode:indexOfChild( node )
	return table.index( self.children, node )
end

function SQNode:removeChild( node )
	local idx = table.index( self.children, node )
	if not idx then return false end
	remove( self.children, idx )
	node.parentNode = false
	node.parentRoutine = false	
	return true
end

function SQNode:getType()
	return self.__sqname
end

function SQNode:getName()
	return self.__sqname or 'node'
end

function SQNode:getDebugRepr()
	return self:getName()
end

function SQNode:getComment()
	return self.comment
end

function SQNode:getRichText()
	return 'SQNode'
end

function SQNode:getIcon()
	return false
end

function SQNode:setComment( c )
	self.comment = c
end

function SQNode:isReplayable()
	return false
end

function SQNode:onRecord( session, state, env )
end

function SQNode:onPlayback( session, state, env )
	self:enter( state, env )
end

-- function SQNode:getSourceLine()
-- 	local path = self:getSourcePath()
-- 	local asset = getAssetNode( path )
-- 	if not asset then return false end
-- 	local filePath = asset:getAbsFilePath()
-- 	local lineNumber = self.lineNumber
-- end

function SQNode:getSourcePath()
	local script = self:getScript()
	return script:getSourcePath()
end

function SQNode:getShortSourcePath()
	local script = self:getScript()
	local path = script:getSourcePath()
	local shortPath = basename_noext( path )
	return shortPath
end

function SQNode:getPosText()
	return string.format( '%s:%4d', self:getSourcePath(), self.lineNumber )
end

function SQNode:getShortPosText()
	return string.format( '%s:%3d', self:getShortSourcePath(), self.lineNumber )
end

function SQNode:findChildNodeByLine( line )
	for i, child in ipairs( self.children ) do
		local line0 = child.lineNumber
		local lineCount = child.lineCount or 1
		local line1 = line0 + lineCount - 1
		if line >= line0 and line <= line1 then
			return child
		end
		local found = child:findChildNodeByLine( line )
		if found then return found end
	end
	return false
end

function SQNode:enter( state, env )
	return true
end

function SQNode:step( state, env, dt )
	return true
end

function SQNode:exit( state, env )
	return true
end

function SQNode:pause( state, env, paused )
	return true
end

function SQNode:getContext()
	return self.context
end

function SQNode:findContextEntity( state, id )
	local actor = state:getActor()
	return actor:_findContextEntity( id )
end

function SQNode:getContextEntity( state )
	local actor = state:getActor()
	return actor:getContextEntity( self.context[1] )
end

function SQNode:getContextEntities( state )
	local actor = state:getActor()
	return actor:getContextEntities( self.context )
end

function SQNode:affirmContextEntity( state )
	local entity = self:getContextEntity( state )
	if not entity then
		local ctx = unpack( self.context )
		self:_warn( 'no context entity:', ctx )
	end
	return entity
end

function SQNode:affirmContextEntities( state )
	local entities = self:getContextEntities( state )
	if not next( entities ) then
		self:_warn( 'no context entity:', unpack( self.context ) )
	end
	return entity
end

function SQNode:_load( data )
	self.lineNumber = data[ 'line' ]
	self.lineCount  = data[ 'lineCount' ] or false
	self.inlineDirectives = data[ 'inlineDirectives' ] or false
	return self:load( data )
end

function SQNode:load( data )
end

function SQNode:applyNodeContext( buildContext )
	self.context = buildContext.context
	-- self.tags = buildContext.tags
	-- buildContext.tags = {}
end

function SQNode:_build( buildContext )
	self:applyNodeContext( buildContext )
	self:build( buildContext )
	self:buildChildren( buildContext )
	self.executeQueue = self:buildExecuteQueue() or {}
	-- self.executeQueue = self.children
end

function SQNode:build( buildContext )
end

function SQNode:buildChildren( buildContext )
	local context0 = buildContext.context
	for i, child in ipairs( self.children ) do
		child:_build( buildContext )
	end
	buildContext.context = context0
end

function SQNode:buildExecuteQueue()
	local queue = {}
	local index = 0
	for i, child in ipairs( self.children ) do
		if child:isExecutable() then
			index = index + 1
			child.index = index
			queue[ index ] = child
		end
	end
	return queue
end

function SQNode:acceptSubNode( name )
	return true
end

function SQNode:translate( source, ... )
	return self:translateAs( nil, source, ... )
end

function SQNode:translateAs( locale, source, ... )
	local output = self:getScript():translateAs( locale, source, ... )
	if not output then
		-- self:_warn( 'no translation' )
		return nil
	end
	return output
end

function SQNode:needI18N()
	return false
end

function SQNode:getI18NData()
	return nil
end

function SQNode:_log( ... )
	local prefix = self:getPosText() .. ' >'
	_logWithToken( 'LOG  :sq', prefix, ... )
end

function SQNode:_warn( ... )
	local prefix = self:getPosText() .. ' >'
	return _logWithToken( 'WARN :sq', prefix, ... )
end

function SQNode:_error( ... )
	local prefix = self:getPosText() .. ' >'
	_logWithToken( 'ERROR:sq', prefix, ... )
	return error( 'SQ Execution Error' )
end

--------------------------------------------------------------------
CLASS: SQNodeGroup ( SQNode )
	:MODEL{
		Field 'name' :string();
}

function SQNodeGroup:__init()
	self.name = 'group'
end

function SQNodeGroup:isGroup()
	return true
end

function SQNodeGroup:canInsert()
	return true
end

function SQNodeGroup:getRichText()
	return string.format(
		'[ <group>%s</group> ]',
		self.name
		)
end

function SQNodeGroup:getIcon()
	return 'sq_node_group'
end


--------------------------------------------------------------------
CLASS: SQNodeLabel( SQNode )
	:MODEL{
		Field 'id' :string();
}

SQNodeLabel.__sqname = 'label'

function SQNodeLabel:__init()
	self.id = 'label'
end

function SQNodeLabel:getRichText()
	return string.format(
		'<label>%s</label>',
		self.id
		)
end

function SQNodeLabel:getIcon()
	return 'sq_node_label'
end

function SQNodeLabel:build()
	local routine = self:getRoutine()
	routine:addLabel( self )
end

function SQNodeLabel:enter( state, env )
	state:onEnterLabel( self )
end

function SQNodeLabel:getDebugRepr()
	return '! ' .. self.id
end


--------------------------------------------------------------------
CLASS: SQNodeGoto( SQNode )
	:MODEL {
		Field 'label' :string();
}

function SQNodeGoto:__init()
	self.label = 'label'
end

function SQNodeGoto:load( data )
	self.label = data.args[1]
end

function SQNodeGoto:enter( state, env )
	local routine = self:getRoutine()
	local targetNode = routine:findLabelNode( self.label )
	if not targetNode then
		self:_warn( 'target label not found', self.label )
		state:setJumpTarget( false )
	else
		state:setJumpTarget( targetNode )
	end
	return 'jump'
end

function SQNodeGoto:getRichText()
	return string.format(
		'<cmd>GOTO</cmd> <label>%s</label>',
		self.label
		)
end

function SQNodeGoto:getIcon()
	return 'sq_node_goto'
end


---------------------------------------------------------------------
CLASS: SQNodeFastForward ( SQNode )
	:MODEL{
		Field 'label' :string();
	}

function SQNodeFastForward:__init()
	self.label = 'label'
end

function SQNodeFastForward:load( data )
	self.label = data.args[1] or false
end

function SQNodeFastForward:enter( state, env )
	if not game:isDeveloperMode() then return end
	
	local routine = self:getRoutine()

	local targetNode 
	if self.label then
		targetNode = routine:findLabelNode( self.label )
	else
		targetNode = 'next'
	end

	if targetNode then
		state:startFastForward( targetNode )
	else
		self:_warn( 'target label not found', self.label )
		state:startFastForward( false )
	end

end

function SQNodeFastForward:getRichText()
	return string.format(
		'<cmd>GOTO</cmd> <label>%s</label>',
		self.label
		)
end

function SQNodeFastForward:getIcon()
	return 'sq_node_goto'
end


---------------------------------------------------------------------
CLASS: SQNodeEnd( SQNode )
	:MODEL{
		Field 'stopAllRoutines' :boolean()
}

function SQNodeEnd:__init()
	self.stopAllRoutines = false
end

function SQNodeEnd:enter( state )
	if self.stopAllRoutines then
		state:stop()
		return 'jump'
	else
		state.jumpTarget = false --jump to end
		return 'jump'
	end
end

function SQNodeEnd:getRichText()
	return string.format(
		'<end>END</end> <flag>%s</flag>',
		self.stopAllRoutines and 'All Routines' or ''
		)
end

function SQNodeEnd:getIcon()
	return 'sq_node_end'
end


--------------------------------------------------------------------
CLASS: SQNodePause ( SQNode )
function SQNodePause:__init()
	self.paused = true
end

function SQNodePause:load( data )
	self.target = data.args[ 1 ]
end

function SQNodePause:enter( state )
	local target = self.target
	local targetState
	if target then
		if target == '.parent' then
			targetState = state.parentState
		elseif target == '.root' then
			targetState = state:getRootState()
		else
			targetState = state:findInAllSubRoutineState( target )
		end
	else
		targetState = state
	end
	if targetState then
		targetState:pause( self.paused )
	else
		self:_error( 'target state not found' )
	end
end

--------------------------------------------------------------------
CLASS: SQNodeResume ( SQNodePause )
function SQNodeResume:__init()
	self.paused = false
end

--------------------------------------------------------------------
CLASS: SQNodeCheckpoint ( SQNodeGroup )
	:MODEL{}

function SQNodeCheckpoint:__init()
	self.name = false
end

function SQNodeCheckpoint:load( data )
	local function parseGroupNames( s )
		if not s then return nil end
		local parts, c = s:split( ',', true )
		return parts
	end
	self.name = data.args[1]
	--load requires
	self.groupsOn   = parseGroupNames( self:getTagStringValue( 'group_on' ) )
	self.groupsOff  = parseGroupNames( self:getTagStringValue( 'group_off' ) )
	self.groupsOnly = parseGroupNames( self:getTagStringValue( 'group_only' ) )
	if not self.name then
		self:_warn( 'checkpoint name expected!' )
		return false
	end
	self:getScript():registerCheckpoint( self )
end

function SQNodeCheckpoint:enter( state, env ) --programatic entry only
	-- return false
	if state.entryNode == self then
		state.entryNode = false
		return true
	else
		return false
	end
end

function SQNodeCheckpoint:getRepr()
	return string.format( '%s (%s)', self.name, self:getContextString() or '' )
end

function SQNodeCheckpoint:getDebugRepr()
	return ':: ' .. self.name
end


--------------------------------------------------------------------
CLASS: SQNodeRoot( SQNodeGroup )


--------------------------------------------------------------------
CLASS: SQNodeSkip( SQNode )
function SQNodeSkip:isExecutable()
	return false
end


--------------------------------------------------------------------
CLASS: SQNodeContext ( SQNode )
function SQNodeContext:__init()
	self.contextNames = {}
end

function SQNodeContext:applyNodeContext( buildContext )
	buildContext.context = self.contextNames
end

function SQNodeContext:isExecutable()
	return false
end

function SQNodeContext:load( data )
	self.contextNames = data.names
end


--------------------------------------------------------------------
CLASS: SQNodeTag ( SQNode )
function SQNodeTag:__init()
	self.tagItems = {}
end

function SQNodeTag:applyNodeContext( buildContext )
	-- buildContext.tags = table.join( buildContext.tags or {}, self.tagNames )
end

function SQNodeTag:isExecutable()
	return false
end

function SQNodeTag:load( data )
	local tagItems = {}
	for i, entry in ipairs( data.tags or {} ) do
		local tt = type( entry )
		if tt == 'table' then
			local k, v = unpack( entry )
			tagItems[ k ] = v or true
		elseif tt == 'string' then
			tagItems[ entry ] = true
		end
	end
	self.tagItems = tagItems
end


--------------------------------------------------------------------
CLASS: SQNodeDirective ( SQNode )
function SQNodeDirective:__init()
	self.name = false
	self.value = false
end

function SQNodeDirective:applyNodeContext( buildContext )
	-- buildContext.tags = table.join( buildContext.tags or {}, self.tagNames )
end

function SQNodeDirective:isExecutable()
	return false
end

function SQNodeDirective:load( data )
	self.name = data.name
	self.value = data.value or false
end


--------------------------------------------------------------------
SQRoutine :MODEL{
		Field 'name' :string();
		Field 'autoStart' :boolean();
		Field 'comment' :string();
		Field 'rootNode' :type( SQNode ) :no_edit();
		Field 'parentScript' :type( SQScript ) :no_edit();
}

function SQRoutine:__init()
	self.parentScript   = false

	self.rootNode = SQNodeRoot()	
	self.rootNode.parentRoutine = self
	self.autoStart = false

	self.name = 'unnamed'
	self.comment = ''

	self.labelNodes = {}
end

function SQRoutine:getScript()
	return self.parentScript
end

function SQRoutine:findLabelNode( id )
	for i, node in ipairs( self.labelNodes ) do
		if node.id == id then return node end
	end
	return nil
end

function SQRoutine:addLabel( labelNode )
	insert( self.labelNodes, labelNode )
end

function SQRoutine:getName()
	return self.name
end

function SQRoutine:setName( name )
	self.name = name
end

function SQRoutine:getComment()
	return self.comment
end

function SQRoutine:setComment( c )
	self.comment = c
end

function SQRoutine:getRootNode()
	return self.rootNode
end

function SQRoutine:addNode( node, idx )
	return self.rootNode:addChild( node, idx )
end

function SQRoutine:removeNode( node )
	return self.rootNode:removeChild( node )
end

function SQRoutine:findNodeByLine( line )
	return self.rootNode:findChildNodeByLine( line )
end

function SQRoutine:execute( state )
	return state:executeRoutine( self )
end

function SQRoutine:build()
	local context = {
		context = {},
		tags    = {}
	}
	self.rootNode:_build( context )
end


--------------------------------------------------------------------
SQScript :MODEL{
		Field 'comment';	
		Field 'routines' :array( SQRoutine ) :no_edit();
}

function SQScript:__init()
	self.checkpoints = {}
	self.routines = {}
	self.comment = ''
	self.sourcePath = '<unknown>'
	self.built = false
	self._hasActionNode = false
	self.meta = {}
end

function SQScript:getSourcePath()
	return self.sourcePath
end

function SQScript:addGlobalDirective( data )
	local name = data.name
	if name == 'exclusive_scene' then
		self.meta[ name ] = parseSimpleStringList( data.value )
		return true
	end
	return false
end

function SQScript:getMeta( key )
	return self.meta[ key ]
end

function SQScript:findNodeByLine( line )
	for i, routine in ipairs( self.routines ) do
		local found = routine:findNodeByLine( line )
		if found then return found end
	end
	return false
end

function SQScript:addRoutine( routine )
	local routine = routine or SQRoutine()
	routine.parentScript = self
	insert( self.routines, routine )
	return routine
end

function SQScript:hasActionNode()
	return self._hasActionNode
end

function SQScript:removeRoutine( routine )
	local idx = table.index( self.routines, routine )
	if not idx then return end
	routine.parentRoutine = false
	remove( self.routines, idx )
end

function SQScript:getRoutines()
	return self.routines
end

function SQScript:getComment()
	return self.comment
end

function SQScript:_postLoad( data )
end

function SQScript:build()
	if self.built then return true end
	self.built = true
	for i, routine in ipairs( self.routines ) do
		routine:build()
	end
	return true
end

function SQScript:translate( source, ... )
	local result = translateForAsset( self:getSourcePath(), source, ... )
	return result
end

function SQScript:translateAs( locale, source, ... )
	local result = translateForAssetAs( locale, self:getSourcePath(), source, ... )
	return result
end

function SQScript:registerCheckpoint( node )
	self.checkpoints[ node ] = true
end

function SQScript:getCheckpoints()
	return self.checkpoints
end

--------------------------------------------------------------------
CLASS: SQRoutineState ()
 
function SQRoutineState:__init( entryNode, enterEntryNode )
	self.routine = entryNode:getRoutine()
	self.globalState = false
	self.id = entryNode.id or false
	self.localRunning = false
	self.localPaused  = false
	self.paused       = false
	self.started = false
	self.jumpTarget = false

	self.entryNode = entryNode

	self.currentNode = false
	self.currentNodeEnv = false
	self.currentQueue = {}
	self.index = 1
	self.nodeEnvMap = {}
	self.msgListeners = {}

	self.subRoutineStates = {}
	self.FFTargets = {}

	--lift
	self.update = self.update
	
	return self:reset( enterEntryNode )
end

function SQRoutineState:getGlobalState()
	return self.globalState
end

function SQRoutineState:getActor()
	return self.globalState:getActor()
end

function SQRoutineState:getActorEntity()
	return self.globalState:getActorEntity()
end

function SQRoutineState:setLocalRunning( localRunning )
	self.localRunning = localRunning
	if self.parentState then
		return self.parentState:updateChildrenRunningState()
	end
end

function SQRoutineState:updateChildrenRunningState()
	local childrenRunning = nil
	local newStates = {}
	for i, sub in ipairs( self.subRoutineStates ) do
		if sub.localRunning then
			insert( newStates, sub )
			childrenRunning = childrenRunning == nil
		else
			childrenRunning = false
		end
	end
	self.subRoutineStates = newStates
	self.childrenRunning = childrenRunning or false
end

function SQRoutineState:start( sub )
	if self.started then return end
	self.started = true
	self:setLocalRunning( true )
	-- if not sub then
	-- 	self:registerMsgCallbacks()
	-- end
	-- self.msgListeners = table.weak_k()
	self.msgListeners = {}
end

function SQRoutineState:stop()
	for i, subState in ipairs( self.subRoutineStates ) do
		subState:stop()
	end
	self.subRoutineStates = {}
	self:unregisterMsgCallbacks()
	self.parentState:updateChildrenRunningState()
end

function SQRoutineState:pause( paused )
	self.localPaused = paused ~= false
	self:updatePauseState()
end

function SQRoutineState:calcPaused()
	if self.localPaused then return true end
	local parent = self.parentState
	while parent do
		if parent.localPaused then return true end
		parent = parent.parentState
	end
	return false
end

function SQRoutineState:updatePauseState()
	local p0 = self.paused
	local p1 = self:calcPaused()
	if p1 == p0 then return end
	self.paused = p1
	for i, subState in ipairs( self.subRoutineStates ) do
		subState:updatePauseState()
	end
	if self.currentNode then
		self.currentNode:pause( 
			self, self.currentNodeEnv, self.paused
		)
	end
end

function SQRoutineState:isRunning()
	if self.localRunning then return true end
	if self:hasMsgCallback() then return true end
	if self:isSubRoutineRunning() then return true end
	return false
end

function SQRoutineState:isSubRoutineRunning()
	for i, subState in ipairs( self.subRoutineStates ) do
		if subState:isRunning() then return true end
	end
	return false
end

function SQRoutineState:reset( enterEntryNode )
	self.started = false
	
	self.localRunning = false
	self.jumpTarget = false

	self.subRoutineStates = {}
	self.nodeEnvMap = {}

	local entry = self.entryNode
	local env = {}
	self.currentNodeEnv = env
	self.nodeEnvMap[ entry ] = env

	if enterEntryNode then
		self.index = 0
		self.currentNode = false
		self.currentQueue = { entry }
	else
		self.index = 1
		self.currentNode = entry
		self.currentQueue = {}
	end

end

function SQRoutineState:getNodeListener()
	local rootState = self:getGlobalState()
	return rootState:getNodeListener()
end

function SQRoutineState:_sendNodeEvent( ev, node, env )
	local listener = self.globalState.nodeListener
	if listener then listener( ev, node, self, env ) end
	for _, globalListener in ipairs( _globalSQNodeListeners ) do
		globalListener( ev, node, self, env )
	end
end

function SQRoutineState:restart()
	self:reset()
	self:start()
end

function SQRoutineState:getNodeEnvTable( node )
	return self.nodeEnvMap[ node ]
end

function SQRoutineState:getGlobalNodeEnvTable( node )
	return self.globalState:getGlobalNodeEnvTable( node )
end
	
function SQRoutineState:registerMsgCallback( msg, node )
	local msgListeners = self.msgListeners
	for j, target in ipairs( node:getContextEntities( self ) ) do
		local listener = function( msgIn, data, src )
			if msgIn == msg then
				if node:hasTag( 'single' ) then
					--drop if same routine running
					for i, state in ipairs( self.subRoutineStates ) do
						if state.entryNode == node and state:isRunning() then
							return
						end
					end
					--TODO: queue mode?
					--TODO: replace mode?
				end
				return self:startSubRoutine( node )
			end
		end
		target:addMsgListener( listener )
		msgListeners[ target ] = listener
	end
	return node
end

function SQRoutineState:unregisterMsgCallbacks()
	if not self.msgListeners then return end
	for target, listener in pairs( self.msgListeners ) do
		target:removeMsgListener( listener )
	end
end

function SQRoutineState:hasMsgCallback()
	if not self.msgListeners then return false end
	if not next( self.msgListeners ) then return false end
	return true
end

function SQRoutineState:getRootState()
	local s = self
	while true do
		local p = s.parentState
		if not p then return s end
		s = p
	end
end

function SQRoutineState:findInAllSubRoutineState( name )
	return self:getRootState():findSubRoutineState( name )
end

function SQRoutineState:findSubRoutineState( name )
	for i, state in ipairs( self.subRoutineStates ) do
		if state.id == name then return state end
	end
	for i, state in ipairs( self.subRoutineStates ) do
		local result = state:findSubRoutineState( name )
		if result then return result end
	end
	return false
end

function SQRoutineState:startSubRoutine( entryNode )
	local subState = SQRoutineState( entryNode )
	subState.globalState = self.globalState
	subState.parentState = self
	insert( self.subRoutineStates, subState )
	subState:start( 'sub' )
	self:updateChildrenRunningState()
end

function SQRoutineState:getSignalCounter( id )
	return self.globalState:getSignalCounter( id )
end

function SQRoutineState:incSignalCounter( id )
	return self.globalState:incSignalCounter( id )
end

function SQRoutineState:getEnv( key, default )
	return self.globalState:getEnv( key, default )
end

function SQRoutineState:setEnv( key, value )
	return self.globalState:setEnv( key, value )
end

function SQRoutineState:getEvalEnv()
	return self.globalState.evalEnv
end


function SQRoutineState:update( dt )
	if self.paused then return end
	for i, subState in ipairs( self.subRoutineStates ) do
		subState:update( dt )
	end
	if self.paused then return end
	if self.localRunning then
		self:updateNode( dt )
	end
end

function SQRoutineState:updateNode( dt )
	local node = self.currentNode
	if node then
		local env = self.currentNodeEnv
		local res = node:step( self, env, dt )
		if res then
			if res == 'jump' then
				return self:doJump()
			end
			return self:exitNode()
		end
	else
		return self:nextNode()
	end
end

function SQRoutineState:nextNode()
	local index1 = self.index + 1
	local node1 = self.currentQueue[ index1 ]
	if not node1 then
		return self:exitGroup()
	end
	self.index = index1
	self.currentNode = node1
	if node1:isInstance( SQNodeCoroutine ) then
		self:startSubRoutine( node1 )
		return self:nextNode()
	end
	local env = {}
	self.currentNodeEnv = env
	self.nodeEnvMap[ node1 ] = env
	
	self:_sendNodeEvent( 'enter', node1, self, env )

	local res = node1:enter( self, env )
	if res == 'jump' then
		return self:doJump()
	end
	if res == false then
		return self:nextNode()
	end
	return self:updateNode( 0 )
end

function SQRoutineState:exitNode( fromGroup )
	local node = self.currentNode
	if node:isGroup() then --Enter group
		self.index = 0
		self.currentQueue = node.executeQueue
	else
		self:_sendNodeEvent( 'exit', node, self, nil )
		
		local res = node:exit( self, self.currentNodeEnv )
		if res == 'jump' then
			return self:doJump()
		end
	end
	return self:nextNode()
end

function SQRoutineState:exitGroup()
	--exit group node
	local groupNode
	if self.index == 0 and self.currentNode:isGroup() then
		groupNode = self.currentNode
	else
		groupNode = self.currentNode.parentNode
	end

	if not groupNode then
		self.FFTargets = {}
		stopSQFastForward( self )
		self:setLocalRunning( false )
		return true
	end

	local nodeEnv = self.nodeEnvMap[ groupNode ] or {}

	self:_sendNodeEvent( 'exit', groupNode, self, nodeEnv )

	local res = groupNode:exit( self, nodeEnv )

	if res == 'jump' then
		return self:doJump()
	elseif res == 'loop' then
		self.index = 0
	elseif res == 'end' then
		self:setLocalRunning( false )
		return true
	else
		local parentNode = groupNode.parentNode
		if (not parentNode) then
			self:setLocalRunning( false )
			return true
		end
		self.currentNode  = groupNode
		self.currentQueue = parentNode.executeQueue
		self.index = groupNode.index
	end
	return self:nextNode()
end

function SQRoutineState:setJumpTarget( node )
	self.jumpTarget = node
end

function SQRoutineState:doJump()
	local target = self.jumpTarget
	if not target then
		self.localRunning = false
		return false
	end

	self.jumpTarget = false
	self.currentNode  = false
	local parentNode = target.parentNode
	self.currentQueue = parentNode.executeQueue
	self.index = target.index - 1
	
	return self:nextNode()
end

function SQRoutineState:startFastForward( node )
	if not node then return end
	if not next( self.FFTargets ) then
		startSQFastForward( self )
	end
	self.FFTargets[ node ] = true
end

function SQRoutineState:stopFastForward()
	if next( self.FFTargets ) then
		self.FFTargets = {}
		stopSQFastForward( self )
	end
end

function SQRoutineState:onEnterLabel( labelNode )
	local FFTargets = self.FFTargets
	FFTargets[ labelNode ] = nil
	FFTargets[ 'next' ] = nil
	if not next( self.FFTargets ) then
		stopSQFastForward( self )
	end
end


--------------------------------------------------------------------
SQState :MODEL{
	
}

function SQState:__init()
	self.script  = false
	self.paused  = false

	self.routineStates = {}
	self.coroutines = {}
	self.signalCounters = {}
	self.env = {}
	self.globalNodeEnvMap = {}
	self.evalEnv = false

	self.nodeListener = false 
end

function SQState:getNodeListener()
	return self.nodeListener
end

function SQState:setNodeListener( l ) --sig: event, node, routineState, env
	self.nodeListener = l
end

function SQState:getEnv( key, default )
	local v = self.env[ key ]
	if v == nil then return default end
	return v
end

function SQState:setEnv( key, value )
	self.env[ key ] = value
end

function SQState:getActor()
	return self.env['actor']
end

function SQState:getActorEntity()
	return self.env['entity']
end

function SQState:getSignalCounter( id )
	return self.signalCounters[ id ] or 0
end

function SQState:incSignalCounter( id )
	local v = ( self.signalCounters[ id ] or 0 ) + 1
	self.signalCounters[ id ] = v
	return v
end

function SQState:initEvalEnv( actor )
	local mt = {}
	local env = setmetatable( {}, mt )
	function mt.__index( t, k )
		local v = _globalSQEvalEnv[ k ]
		if v == nil then
			return actor:getEnvVar( k )
		else
			return v
		end
	end
	env['_'] = env --local variable namespance
	self.evalEnv = env
end

function SQState:getEvalEnv()
	return self.evalEnv
end

function SQState:isPaused()
	return self.paused
end

function SQState:pause( paused )
	self.paused = paused ~= false
end

function SQState:isRunning()
	local states = self.routineStates
	for i = 1, #states do
		local routineState = states[ i ]
		if routineState:isRunning() then return true end
	end
	return false
end

function SQState:stop()
	for i, routineState in ipairs( self.routineStates ) do
		routineState:stop()
	end
end

function SQState:loadScript( script )
	script:build()
	self.script = script
	for i, routine in ipairs( script.routines ) do
		local routineState = self:addRoutineState( routine:getRootNode() )
		if routine.autoStart then
			routineState:start()
		end
	end
end

function SQState:addRoutineState( entryNode, enterEntryNode )
	local routineState = SQRoutineState( entryNode, enterEntryNode )
	routineState.globalState = self
	routineState.parentState = false
	insert( self.routineStates, routineState )
	return routineState
end

function SQState:update( dt )
	if self.paused then return end
	local states = self.routineStates
	for i = 1, #states do
		local routineState = states[ i ]
		routineState:update( dt )
	end
	return true
end

function SQState:findRoutineState( name )
	for i, routineState in ipairs( self.routineStates ) do
		if routineState.routine.name == name then return routineState end
	end
	return nil
end

function SQState:stopRoutine( name )
	local rc = self:findRoutineState( name )
	if rc then
		rc:stop()
		return true
	end
end

function SQState:startRoutine( name )
	local rc = self:findRoutineState( name )
	if rc then
		rc:start()
		return true
	end
end

function SQState:restartRoutine( name )
	local rc = self:findRoutineState( name )
	if rc then
		rc:restart()
		return true
	end
end

function SQState:isRoutineRunning( name )
	local rc = self:findRoutineState( name )
	if rc then 
		return rc:isRunning()
	end
	return nil
end

function SQState:startAllRoutines()
	for i, routineState in ipairs( self.routineStates ) do
		if not routineState.started then
			routineState:start()
		end
	end
	return true
end

function SQState:getGlobalNodeEnvTable( node )
	local env = self.globalNodeEnvMap[ node ]
	if not env then
		env = {}
		self.globalNodeEnvMap[ node ] = env
	end
	return env
end

--------------------------------------------------------------------
local SQNodeRegistry = {}
local defaultOptions = {}
function registerSQNode( name, clas, overwrite, info )
	assert( clas, 'nil class?' .. name )
	info = info or {}
	local entry0 = SQNodeRegistry[ name ]
	if entry0 then
		local clas0 = entry0.clas
		if clas0.__fullname ~= clas.__fullname then
			if not overwrite then
				_warn( 'duplicated SQNode:', name )
				return false
			else
				_log( 'overwrite SQNode:', name )
			end
		end
	end
	clas.__sqname = name
	SQNodeRegistry[ name ] = {
		clas     = clas,
		info     = info
	}
end

function findInSQNodeRegistry( name )
	return SQNodeRegistry[ name ]
end

function getSQNodeRegistry()
	return SQNodeRegistry
end


--------------------------------------------------------------------
local function loadSQNode( data, parentNode, tags, directives )
	local node
	if not data then return false end
	
	local t = data.type
	if t == 'action' then
		--find action node factory
		local isSub = data['sub']
		local actionName = data['name']
		local entry = SQNodeRegistry[ actionName ]
		if not entry then
			local dummy = SQNode()
			_error( string.format( '%s:%3d >', 
				parentNode:getScript():getSourcePath(), data[ 'line' ]
			), 'unkown action node type', actionName )
			return dummy
		end
		local clas = entry.clas
		node = clas()
		parentNode:addChild( node )
		if tags then
			node.tags = tags
		else
			node.tags = {}
		end

		if directives then
			node.directives = directives
		else
			node.directives = false
		end

		node:_load( data )
		parentNode:getScript()._hasActionNode = true

	elseif t == 'context' then
		node = SQNodeContext()
		parentNode:addChild( node )
		node:_load( data )

	elseif t == 'tag'     then
		node = SQNodeTag()
		parentNode:addChild( node )
		node:_load( data )

	elseif t == 'directive' then
		--check global directive
		if parentNode:getScript():addGlobalDirective( data ) then
			return false
		end

		node = SQNodeDirective()
		parentNode:addChild( node )
		node:_load( data )

	elseif t == 'label'   then
		local labelNode = SQNodeLabel()
		labelNode.id = data.id
		parentNode:addChild( labelNode )
		return labelNode


	elseif t == 'root' then
		--pass
		node = parentNode

	else
		--error
		error( 'wtf?', t )
	end

	local tags = false
	local directives = false
	local children = data.children
	for i = 1, #children do
		local childData = children[ i ]
		local childNode = loadSQNode( childData, node, tags, directives )
		local t = childData.type
		if t == 'tag' then
			tags = table.merge( tags or {}, childNode.tagItems )

		elseif t == 'directive' and childNode then
			if not directives then directives = {} end
			local key = childNode.name
			local value = childNode.value
			if directives[ key ] then
				childNode:_warn( 'duplicated directive, overwriting:', key )
			end
			directives[ key ] = value

		elseif t == 'context' then

		else
			tags = false
			directives = false
			
		end

	end

	return node

end

--------------------------------------------------------------------
function loadSQScript( node )
	local data
	local packedDataFile = node:getObjectFile('packed_data')
	if packedDataFile then
		data = loadMsgPackFile( packedDataFile )
	else
		data = mock.loadAssetDataTable( node:getObjectFile('data') )
	end
	
	local script = SQScript()
	script.sourcePath = node:getNodePath()
	local routine = script:addRoutine()
	routine.name = 'main'
	routine.autoStart = true
	loadSQNode( data, routine.rootNode )
	script:build()
	return script
end

--------------------------------------------------------------------
registerSQNode( 'group',   SQNodeGroup   )
registerSQNode( 'do',      SQNodeGroup   )
registerSQNode( 'end',     SQNodeEnd     )
registerSQNode( 'goto',    SQNodeGoto    )
registerSQNode( 'skip',    SQNodeSkip    )
registerSQNode( 'pause',   SQNodePause   )
registerSQNode( 'resume',  SQNodeResume  )

registerSQNode( 'checkpoint',  SQNodeCheckpoint  )

registerSQNode( 'FF',  SQNodeFastForward  )


--------------------------------------------------------------------
mock.registerAssetLoader( 'sq_script', loadSQScript )
