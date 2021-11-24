module 'mock'

--------------------------------------------------------------------
CLASS: EffectNode  ()
CLASS: EffectGroup ( EffectNode )
CLASS: EffectRoot  ( EffectGroup )
CLASS: EffectState ()
----------------------------------------------------------------------
--CLASS: EffectNode
--------------------------------------------------------------------
EffectNode :MODEL {
		Field 'name'     :string();
		'----';
		Field 'meta'     :string();
		'----';
		Field 'disabled' :boolean();
		Field 'delay'    :number();
		'----';
		Field 'children' :array( EffectNode ) :no_edit();
		Field 'parent'   :type( EffectNode ) :no_edit();
		Field '_hidden'  :boolean() :no_edit();
	}

function EffectNode:__init()
	self._built   = false
	self._hidden  = false
	self.disabled = false
	self.parent   = false
	self.meta     = ''
	self.delay    = 0
	self.children = {}
	self.name     = self:getDefaultName()
end

function EffectNode:getDefaultName()
	return 'effect'
end

function EffectNode:getTypeName()
	return 'node'
end

function EffectNode:getName()
	return self.name
end

function EffectNode:getFullname()
	if not self.fullname then
		if self.parent._isRoot then
			self.fullname = self:getName()
		else
			local pname = self.parent:getFullname()
			self.fullname = pname .. '/' .. self:getName()
		end
	end
	return self.fullname
end

function EffectNode:setName( n )
	self.name = n
end

function EffectNode:getDelay()
	return self.delay
end

function EffectNode:findChildByFullname( name, deep )
	for i, c in pairs( self.children ) do
		if c:getFullname() == name then return c end
	end
	if deep then
		for i, c in pairs( self.children ) do
			local found = c:findChildByFullname( name, true )
			if found then return found end
		end
	end
	return nil
end

function EffectNode:findChild( name, deep )
	for i, c in pairs( self.children ) do
		if c:getName() == name then return c end
	end
	if deep then
		for i, c in pairs( self.children ) do
			local found = c:findChild( name, true )
			if found then return found end
		end
	end
	return nil
end

function EffectNode:foreachChild( func, userdata )
	for i, child in pairs( self.children ) do
		if func( child, userdata ) == false then return false end
	end
	for i, child in pairs( self.children ) do
		if child:foreachChild( func, userdata ) == false then return false end
	end	
	return true
end

function EffectNode:addChild( n, idx )
	if n.parent then
		n.parent:removeChild( n )
	end
	if idx then
		table.insert( self.children, idx, n )
	else
		table.insert( self.children, n )
	end
	n.parent = self
	return n
end

function EffectNode:removeChild( n )	
	for i, c in ipairs( self.children ) do
		if c == n then
			table.remove( self.children, i )
			n.parent = false
			return
		end
	end
end

function EffectNode:getParent()
	return self.parent
end

function EffectNode:build( state )
	if self.disabled then return true end
	-- print('building', self:getClassName() )
	self:onBuild( state )
	for i, child in pairs( self.children ) do
		child:build( state )
	end
	self:postBuild( state )
	self._built = true
	return true
end

function EffectNode:onBuild( state )
end

function EffectNode:postBuild( state )
end

function EffectNode:loadIntoState( state )
	if self.disabled then return end
	if not self._built then	self:build() end
	self:onLoad( state )	
	for i, child in pairs( self.children ) do
		child:loadIntoState( state )
	end
	state:addActiveNode( self )
end

function EffectNode:onLoad( state )
end

function EffectNode:onStop( state )
end

function EffectNode:getTransformNode( fxState )
	return self:getProp( fxState )
end

function EffectNode:getColorNode( fxState )
	return self:getProp( fxState )
end

function EffectNode:getProp( fxState )
	return fxState[ self ]
end

function EffectNode:setActive( fxState, active )
end

function EffectNode:setVisible( fxState, visible )
end

function EffectNode:sendCommand( fxState, cmd, ... )
	return false
end

function EffectNode:getResource( fxState, id )
	return nil
end


----------------------------------------------------------------------
--CLASS: EffectGroup
--------------------------------------------------------------------
function EffectGroup:__init()
end

function EffectGroup:getDefaultName()
	return 'group'
end

function EffectGroup:getTypeName()
	return 'group'
end

function EffectGroup:build( state )
	for i, child in pairs( self.children ) do
		child:build( state )
	end
end

function EffectGroup:loadIntoState( state )
	for i, child in pairs( self.children ) do
		child:loadIntoState( state )
	end
end

--------------------------------------------------------------------
--CLASS: EffectRoot
--------------------------------------------------------------------
EnumActionOnStop = _ENUM_V{
	'detach',
	'destroy',
	'none'
}

EffectRoot :MODEL {
	Field 'duration' :range( 0 );
	Field 'loop'     :boolean();	
	Field 'followEmitter' :boolean();
	Field 'actionOnStop'  :enum(EnumActionOnStop)
}

function EffectRoot:__init()
	self.duration = 0
	self.loop = false
	self.followEmitter = false
	self.actionOnStop  = 'none'
	self._isRoot = true
end

function EffectRoot:getDefaultName()
	return 'effect'
end

function EffectRoot:getTransformNode( fxState )
	return fxState:getTransformNode()
end

function EffectRoot:getColorNode( fxState )
	return fxState:getColorNode( )
end

function EffectRoot:getProp( fxState )
	return fxState:getProp( )
end
--------------------------------------------------------------------
updateAllSubClasses( EffectNode )
--------------------------------------------------------------------

CLASS: EffectConfig ()
	:MODEL{
		Field '_root' :type( EffectRoot ) :no_edit();
		Field 'meta' :string();
	}

function EffectConfig:__init()
	self._root = EffectRoot()
	self.meta = ''
	self.nodeNameCache = {}
end

function EffectConfig:getRootNode()
	return self._root
end

function EffectConfig:findNode( name )
	local node = self.nodeNameCache[ name ]
	if not node then
		node = self._root:findChildByFullname( name, true )
		if node then self.nodeNameCache[ name ] = node end
	end
	return node
end

function EffectConfig:loadIntoState( state )
	self._root:loadIntoState( state )
end

local effectNodeTypeRegistry = {}
--------------------------------------------------------------------
function registerEffectNodeType( name, clas, childTypes, topEffectNode )
	--TODO: reload on modification??	
	if type( childTypes ) == 'string' then
		childTypes = { childTypes }
	end	
	local t1 = {}
	local all = false
	if childTypes then
		for i, k in ipairs( childTypes ) do
			if k == '*' then all = true break end
			t1[ k ] = true
		end
		local _, c = next( childTypes )
		assert( type( c ) == 'string', 'child types should be specified in strings.' )
	end

	effectNodeTypeRegistry[ name ] = {
		clas          = clas,
		childTypes    = all and '*' or t1,
		topEffectNode = topEffectNode and true or false
	}

	clas.__effectName = name
end

function registerTopEffectNodeType( name, clas, childTypes )
	return registerEffectNodeType( name, clas, childTypes, true )
end

function getAvailSubEffectNodeTypes( etypeName )
	if not etypeName then etypeName = 'root' end	
	local res = { 'script' }
	-- if etypeName == 'script' then --should script on script be supported?
	-- end
	if etypeName == 'root' then
		for name, r1 in pairs( effectNodeTypeRegistry ) do
			if name ~= 'script' then
				if r1.topEffectNode then
					table.insert( res, name )
				end
			end
		end
		return res
	else --non root
		local r = effectNodeTypeRegistry[ etypeName ]
		if not r then
			_warn( 'no effect type defined', etypeName )
			return 
		end
		for name, r1 in pairs( effectNodeTypeRegistry ) do
			if name ~= 'script' then
				if r.childTypes == '*' or r.childTypes[ name ] then
					table.insert( res, name )
				end
			end
		end
		return res
	end
end

function getEffectNodeType( name )
	local entry = effectNodeTypeRegistry[ name ]
	if not entry then
		_warn( 'no effect type defined', name )
		return 
	end
	return entry.clas
end

--------------------------------------------------------------------
--Effect State
--------------------------------------------------------------------
EffectState	:MODEL{}

function EffectState:__init( emitter, config )
	--TODO: refactor this out...
	local trans = MOAITransform.new() 
	local prop  = emitter.prop
	self._emitter = emitter
	self._emitterProp  = prop
	self._trans  =  trans 
	self._config = config
	self._updateListeners = {}
	self._delayedUpdateListeners = {}
	self._activeNodes = {}

	local root = config:getRootNode()
	self._followEmitter = root.followEmitter
	if root.followEmitter then
		inheritTransform( trans, prop )
	else
		prop:forceUpdate()
		-- inheritTransform( trans, prop )
		trans:setLoc( prop:getWorldLoc() )
		trans:setScl( prop:getScl() )
		trans:setRot( prop:getRot() )
		-- trans:setRot( prop:getWorldRot() )
		trans:forceUpdate()
	end
	local duration = root.duration or -1
	self.elapsed = 0
	if duration <= 0 then
		self.duration = false
	else
		self.duration = duration
	end
	self.timer = MOAIManualTimer.new()
	self.timer:setMode( MOAITimer.CONTINUE )
end

function EffectState:getTransformNode()
	return self._trans
end

function EffectState:getColorNode()
	return false
end

function EffectState:getProp()
	return self._trans
end

function EffectState:getEmitter()
	return self._emitter
end

function EffectState:linkPartition( prop )
	inheritPartition( prop, self._emitterProp )
	return prop
end

function EffectState:linkTransform( trans )
	inheritTransform( trans, self._trans )	
	trans:forceUpdate()
	return trans
end

function EffectState:linkVisible( prop )
	inheritVisible( prop, self._emitterProp )
	return prop
end

function EffectState:linkColor( prop )
	inheritColor( prop, self._emitterProp )
	return prop
end

function EffectState:unlinkPartition( prop )
	clearLinkPartition( prop )
	prop:setPartition( nil )
	prop:forceUpdate()
end

function EffectState:getTimer()
	return self.timer
end

local function _delayTimerCallback( timer )
	local parent = timer.parentAction
	if parent and parent:isActive() then
		parent:addChild( timer.nextAction )
	else
		timer.nextAction:start()
	end
end

local function makeDelayAction( parent, delay, action )
	local timer = MOAITimer.new()
	timer:setSpan( delay )
	timer.parentAction = parent or false
	timer.nextAction   = action
	timer:setListener( MOAIAction.EVENT_STOP, _delayTimerCallback )
	if parent then
		parent:addChild( timer )
	end
end

function EffectState:attachAction( action, delay )
	if delay and delay > 0 then
		delayedAction = makeDelayAction( self.timer, delay, action )
	else
		self.timer:addChild( action )
	end
	return action
end

function EffectState:getEffectConfig()
	return self._config
end

function EffectState:load()
	if self._loaded then return true end
	if not self._config then return false end
	self._config:loadIntoState( self )
	self._loaded = true
	return true
end

function EffectState:start( parentAction )
	self:load()
	if parentAction then
		self.timer:attach( parentAction )
	else
		self.timer:start()
	end
end

function EffectState:isPlaying()
	return self.timer:isBusy()
end

function EffectState:stop()	
	for node in pairs( self._activeNodes ) do
		node:onStop( self )
	end
	self._activeNodes = nil
	self.timer:stop()
end

function EffectState:_removeActiveNode( node, removeChildren )
	self._activeNodes[ node ] = nil
	self[ node ] = nil
	if removeChildren then
		if not self.children then return end
		for i, child in pairs( self.children ) do
			self:_removeActiveNode( child, true )
		end
	end
end

function EffectState:removeActiveNode( node, removeChildren )
	self:_removeActiveNode( node, removeChildren ~= false )
	if not next( self._activeNodes ) then
		return self:stop()
	end
end

function EffectState:addActiveNode( node )
	self._activeNodes[ node ] = true
end

function EffectState:addUpdateListener( node )
	local delay = node:getDelay()
	if delay and delay > 0 then
		self._delayedUpdateListeners[ node ] = delay
	else
		self._updateListeners[ node ] = true
	end
end

function EffectState:removeUpdatingListener( node )
	self._updateListeners[ node ] = nil
	self._delayedUpdateListeners[ node ] = nil
end

function EffectState:forceUpdateTimer( dt )
	self.timer:doStep( dt )
	self.timer:forceUpdate()
end

function EffectState:update( dt )
	local elapsed = self.elapsed + dt 
	self.elapsed = elapsed
	for node, delay in pairs( self._delayedUpdateListeners ) do
		if delay and elapsed > delay then
			self._updateListeners[ node ] = true
			self._delayedUpdateListeners[ node ] = false --NIL?
		end
	end
	for node in pairs( self._updateListeners ) do
		node:onUpdate( self, dt, elapsed )
	end
	if self.duration then
		if self.elapsed >= self.duration then
			return self:stop()
		end
	end	
end

function EffectState:setDuration( duration )
	self.duration = duration or false
end

function EffectState:findNode( name )
	local config = self._config
	return config:findNode( name )
end

function EffectState:findResource( path, id )
	local node = self:findNode( path )
	if not node then return nil end
	return node:getResource( self, id or 'default' )
end

function EffectState:sendNodeCommand( path, cmd, ... )
	local node = self:findNode( path )
	if not node then
		_error( 'no effect node found', path )
		return false
	end
	if node:sendCommand( self, cmd, ... ) == false then
		_error( 'node command not supported', path, cmd )
		return false
	end
	return true
end

function EffectState:foreachNode( func, ud )
	local innerCall = function( node, ud )
		return func( self, node, ud )
	end
	self._config._root:foreachChild( innerCall, ud )
end

--------------------------------------------------------------------
-- Asset Loader
--------------------------------------------------------------------
function loadEffectConfig( node )
	local defData   = loadAssetDataTable( node:getObjectFile('def') )
	local config = deserialize( nil, defData )
	config._path = node:getNodePath()
	return config
end

registerAssetLoader( 'effect', loadEffectConfig )
