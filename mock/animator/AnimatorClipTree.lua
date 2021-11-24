module 'mock'

local pairs = pairs
--------------------------------------------------------------------
local AnimatorClipTreeNodeTypeRegistry = {}
function registerAnimatorClipTreeNodeType( name, clas, override )
	assert( clas )
	if AnimatorClipTreeNodeTypeRegistry[ name ] and not( override ) then
		_warn( 'duplicated AnimatorClipTreeNode type:', name )
	end
	AnimatorClipTreeNodeTypeRegistry[ name ] = clas
end

function getAnimatorClipTreeNodeTypeRegistry()
	return AnimatorClipTreeNodeTypeRegistry
end

function getAnimatorClipTreeNodeType( name )
	return AnimatorClipTreeNodeTypeRegistry[ name ]
end

--------------------------------------------------------------------
local max = math.max
local floor = math.floor

--TODO: optimization using C++
local function mapTimeReverse( t0, length )
	return max( length - t0, 0 )
end

local function mapTimeReverseContinue( t0, length )
	return length - t0
end

local function mapTimeReverseLoop( t0, length )
	t0 = t0 % length
	return length - t0
end

local function mapTimePingPong( t0, length )
	local span = floor( t0 / length )
	t0 = t0 % length
	if span % 2 == 0 then --ping
		return t0
	else
		return length - t0
	end
end

local function mapTimeLoop( t0, length )
	return t0 % length
end

local timeMapFuncs = {
	[MOAITimer.NORMAL]           = false;
  [MOAITimer.REVERSE]          = mapTimeReverse;
  [MOAITimer.CONTINUE]         = false;
  [MOAITimer.CONTINUE_REVERSE] = mapTimeReverseContinue;
  [MOAITimer.LOOP]             = mapTimeLoop;
  [MOAITimer.LOOP_REVERSE]     = mapTimeReverseLoop;
  [MOAITimer.PING_PONG]        = mapTimePingPong;
}

--------------------------------------------------------------------
CLASS: AnimatorClipTreeState ()

function AnimatorClipTreeState:__init()
	self.animator  = false
	self.treeRoot  = false
	self.subStates = {}
	self.subStateList = false --for faster iteration
	self.nodeVarTables = {}
	self.weight    = 1
	self.throttle  = 1
	self.previewing = false
end

function AnimatorClipTreeState:loadTree( rootNode, animator )
	self.treeRoot = rootNode
	self.animator = animator
	self.treeRoot:onStateLoad( self )
	self:evaluateTree()
end

function AnimatorClipTreeState:getNodeVars( node )
	local vars = self.nodeVarTables[ node ]
	if not vars then
		vars = {}
		self.nodeVarTables[ node ] = vars
	end
	return vars
end

function AnimatorClipTreeState:evaluateTree()
	--reset
	for key, entry in pairs( self.subStates ) do
		entry.throttle = 1
		entry.weight   = 0
	end
	self.weight    = 1
	self.throttle  = 1
	return self.treeRoot:evaluateChildren( self )
end

function AnimatorClipTreeState:updateSubState( key, weight, throttle )
	local entry = self.subStates[ key ]
	entry.weight   = weight * self.weight
	entry.throttle = throttle * self.throttle
	self.subStateList = false
end

function AnimatorClipTreeState:addSubState( key, clip, mode )
	local animState = clip and self.animator:loadClip( clip, false, self.previewing ) or false
	self.subStates[ key ] = {
		state = animState,
		weight = 1,
		throttle = 1
	}
	if animState and animState.clipMode ~= 'tree' then
		animState.timeConverter = mode and timeMapFuncs[ mode ] or false
	end
	return animState
end

function AnimatorClipTreeState:apply( t )
	local list = self.subStateList
	if not list then
		list = {}
		self.subStateList = list
		local n = 1
		for key, entry in pairs( self.subStates ) do
			if entry.weight > 0 and entry.state then 
				list[ n ] = { entry.state, entry.throttle }
				n = n + 1
			end
		end
	end
	
	for i = 1, #list do
		local entry = list[ i ]
		local animState = entry[ 1 ]
		local throttle  = entry[ 2 ]
		local subTime = t * throttle
		local conv = animState.timeConverter
		if conv then
			subTime = conv( subTime, animState.clipLength )
		end
		animState:apply( subTime )
	end
end

function AnimatorClipTreeState:getVar( id )
	return self.animator.vars[ id ]
	-- return self.animator:getVar( id )
end

function AnimatorClipTreeState:clear()
	
end

-- function AnimatorClipTreeState:isPlaying()
-- end

---------------------------------------------------------------------
CLASS: AnimatorClipTreeNode ()
	:MODEL{
		Field 'parent' :type( AnimatorClipTreeNode ) :no_edit();
		Field 'children' :array( AnimatorClipTreeNode ) :ref() :no_edit();
}

function AnimatorClipTreeNode:__init()
	self.parent = false
	self.children = {}
	self.childrenCount = 0
end

function AnimatorClipTreeNode:getEditorTargetObject()
	local rootEntity, rootScene = getAnimatorEditorTarget()
	return self:getTargetObject( rootEntity, rootScene )
end

function AnimatorClipTreeNode:getName()
end

function AnimatorClipTreeNode:toString()
	return 'ClipTreeNode'
end

function AnimatorClipTreeNode:getIcon()
	return 'animator_clip_tree_node'
end

function AnimatorClipTreeNode:addChild( node )
	assert( not node.parent )
	node.parent = self
	table.insert( self.children, node )
	self.childrenCount = self.childrenCount + 1
end

function AnimatorClipTreeNode:removeChild( node )
	local idx = table.index( self.children, node )
	if idx then
		table.remove( self.children, idx )
		node.parent = false
		self.childrenCount = self.childrenCount - 1
	end
end

function AnimatorClipTreeNode:getChildren()
	return self.children
end

function AnimatorClipTreeNode:getParent()
	return self.parent
end

function AnimatorClipTreeNode:getRoot()
	local p = self
	while p do
		local p1 = p.parent
		if not p1 then return p end
		p = p1
	end
end

function AnimatorClipTreeNode:getParentTree()
	local root = self:getRoot()
	return root:getParentTree()
end

function AnimatorClipTreeNode:acceptChildType( typeName )
	return false
end

function AnimatorClipTreeNode:evaluate( treeState )

end

function AnimatorClipTreeNode:evaluateChildren( treeState )
	local children = self.children
	for i = 1, self.childrenCount do
		children[i]:evaluate( treeState )
	end
end

function AnimatorClipTreeNode:onStateLoad( treeState )
	local children = self.children
	for i = 1, self.childrenCount do
		children[i]:onStateLoad( treeState )
	end
end

function AnimatorClipTreeNode:getTypeName()
	return 'AnimatorClipTreeNode'
end

function AnimatorClipTreeNode:build( context )
	self.childrenCount = #self.children
	self:onBuild( context )
	local children = self.children
	for i = 1, self.childrenCount do
		children[i]:build( context )
	end
end

function AnimatorClipTreeNode:onBuild( context )
end

function AnimatorClipTreeNode:isVirtual()
	return false
end

function AnimatorClipTreeNode:initFromEditor()
end

--------------------------------------------------------------------
CLASS: AnimatorClipTreeNodeRoot ( AnimatorClipTreeNode )
	:MODEL{}

function AnimatorClipTreeNodeRoot:__init()
	self.parentTree = false
end

function AnimatorClipTreeNodeRoot:getTypeName()
	return 'output'
end

function AnimatorClipTreeNodeRoot:toString()
	return '<root>'
end

function AnimatorClipTreeNodeRoot:acceptChildType( typeName )
	return true
end

function AnimatorClipTreeNodeRoot:getParentTree()
	return self.parentTree
end


--------------------------------------------------------------------
CLASS: AnimatorClipTreeTrack ( AnimatorTrack )

function AnimatorClipTreeTrack:__init( clipTree )
	self.parentClip = clipTree
end

function AnimatorClipTreeTrack:getPriority()
	return 1000
end

function AnimatorClipTreeTrack:build( context )
end

function AnimatorClipTreeTrack:isLoadable( state )
	return true
end

function AnimatorClipTreeTrack:isPreviewable()
	return true
end

function AnimatorClipTreeTrack:onStateLoad( state )
	state.clipMode = 'tree'
	local rootEntity, scene = state:getTargetRoot()
	local treeState = AnimatorClipTreeState()
	treeState.previewing = state.previewing
	local animator  = state.animator
	treeState:loadTree( self.parentClip.treeRoot, animator )
	local playContext = { 
		treeState = treeState,
		varSeq    = 0
	}
	state:addUpdateListenerTrack( self, playContext )
	state:setFixedMode( MOAITimer.CONTINUE )
end

function AnimatorClipTreeTrack:apply( state, playContext, t, t0 )
	local treeState = playContext.treeState
	local seq = state.animator.varSeq
	if playContext.varSeq ~= seq then
		playContext.varSeq = seq
		treeState:evaluateTree()
	end
	return treeState:apply( t )
end

function AnimatorClipTreeTrack:clear( state, playContext )
	playContext.treeState:clear()
end

--------------------------------------------------------------------
CLASS: AnimatorClipTree ( AnimatorClip )
	:MODEL{
		Field 'treeRoot' :type( 'AnimatorClipTreeNodeRoot' );
	}

function AnimatorClipTree:__init()
	self.treeRoot = AnimatorClipTreeNodeRoot()
	self.treeRoot.parentTree = self
end

function AnimatorClipTree:getTreeRoot()
	return self.treeRoot
end

function AnimatorClipTree:prebuild()
	AnimatorClipTree.__super.prebuild( self )
	self.treeRoot:build()
	local context = self.builtContext
	--build a virtual track for playback
	local track = AnimatorClipTreeTrack( self )
	context:addPlayableTrack( track )
	context:setFixedLength( 10000 )
end

function AnimatorClipTree:_postLoad()
	AnimatorClipTree.__super._postLoad( self )
	self.treeRoot.parentTree = self
end

