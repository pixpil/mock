module 'mock'

DEFAULT_MAX_GLOBAL_TEXTURE_COUNT = 8
DEFAULT_GLOBAL_TEXTURE_START_INDEX = 8

local _draw = MOCKHelper.draw

local function _affirmMoaiTexture( t )
	local tt = type( t )
	if tt == 'userdata' then
		return t --assume it's MOAITextureBase
	elseif tt == 'string' then
		local atype = getAssetType( t )
		if isSupportedTextureAssetType( atype ) then
			local asset = loadAsset( t )
			return asset and asset:getMoaiTexture()
		end
	elseif isInstance( t, TextureInstance ) then
		return t:getMoaiTexture()
	else
		return nil
	end
end

local _RenderManager --will be created in Game 
function getRenderManager()	
	return _RenderManager
end

--------------------------------------------------------------------
CLASS: GlobalTextureItem ()

function GlobalTextureItem:__init()
	self.name = ''
	self.index = 0
end

function GlobalTextureItem:setTexture( context, tex )
	return context:_setGlobalTextureValue( self, tex )
end

function GlobalTextureItem:getTexture( context )
	return context:_getGlobalTextureValue( self )
end

function GlobalTextureItem:getMoaiTexture( context )
	return _affirmMoaiTexture( self:getTexture( context ) )
end


----------------------------------------------------------------------
CLASS: RenderManager ()
	:MODEL{}

function RenderManager:__init( name )
	_RenderManager = self

	self.async = MOAIRenderMgr.isAsync()

	self.name = name

	self.performanceProfile = 'normal'


	self.globalTextureCount = 0
	self.globalTextureUnitStart = DEFAULT_GLOBAL_TEXTURE_START_INDEX
	self.maxGlobalTextureCount = DEFAULT_MAX_GLOBAL_TEXTURE_COUNT
	self.globalTextures = {}
	self.globalTextureMap = {}
	self.materialSwitchMasks = {}

	self.pendingRenderTasks = {}
	self.pendingPostSyncCalls = {}
	self.pendingResAffirm = {}

	self.rootRenderTable = {}

	self.rootRenderPass = createTableRenderLayer()
	self.rootRenderPass:setClearMode( MOAILayer.CLEAR_NEVER )
	self.rootRenderPass:setRenderTable( self.rootRenderTable )

	self.contexts = {}
	self.contextMap = {}
	self.shaderContext = {}
	self.defaultContext = false
	self.currentContext = false

	self.flipRenderTarget = false

	-- self.renderTriggerNode = MOAIScriptNode.new()
	connectGlobalSignalFunc( 'gfx.pre_sync_render_state', function()
		return self:preSyncRenderState()
	end )

	connectGlobalSignalFunc( 'gfx.post_sync_render_state', function()
		return self:postSyncRenderState()
	end )

end

function RenderManager:resetCurrent()
	self:setCurrentContext( self.defaultContext )
end

function RenderManager:registerContext( name, context )
	_stat( 'register render context', name, context )

	assert( not self.contexts[ context ] )
	context = context or RenderContext()
	context.name = name
	self.contexts[ context ] = true
	self.contextMap[ name ] = context
	context:onInit()
	if self.contextReady then
		context:onContextReady()
	end
	return context
end

function RenderManager:getGraphicsAPIName()
	if MOAIAppNX then
		return 'NVN', 1, 0
		
	else
		local apiName = MOAIEnvironment.GraphicsAPI
		
		if apiName == 'Metal' then
			return 'Metal', 1, 2
			
		elseif apiName == 'GL3' then
			return 'GL', 3, 1

		elseif apiName == 'Vulkan' then
			return 'Vulkan', 1, 2

		elseif apiName == 'D3D12' then
			return 'Direct3D', 12, 0

		elseif apiName == 'D3D11' then
			return 'Direct3D', 11, 0

		elseif apiName == 'D3D10' then
			return 'Direct3D', 10, 0
			
		else
			return 'GL', 3, 1
		end
	end
end

function RenderManager:getContext( name )
	return self.contextMap[ name ]
end

function RenderManager:getCurrentContext()
	return self.currentContext
end

function RenderManager:setCurrentContext( context )
	if type( context ) == 'string' then
		context = self.contextMap[ context ]
		assert( context )
	end

	local context0 = self.currentContext
	if context0 == context then return end
	if context0 then
		context0.current = false
		context0:onDeactivate()
	end
	self.currentContext = context
	if context then
		context.current = true
		context:onActivate()
	end

	self.rootRenderTable[ 1 ] = context and context:getRenderRoot()
	
end

function RenderManager:onInit()

	local api, majorVer, minorVer = self:getGraphicsAPIName()
	_log( 'init RenderManager!!', api, majorVer, minorVer )

	self.useCompiledShader = false
	self.flipRenderTarget = false
	setPropUsingRenderState( false )

	if api == 'Metal' then
		self.useCompiledShader = true
		self.flipRenderTarget = true
		setGrabFramebufferFlip( false )
		setPropUsingRenderState( true )

	elseif api == 'Direct3D' then
		self.useCompiledShader = true
		self.flipRenderTarget = true
		setGrabFramebufferFlip( false )
		setPropUsingRenderState( true )
	end

	self.useSDF = false
	if game:getPlatformName() == 'NS' then
		self.useSDF = false
	else
		self.useSDF = true
	end
	self:setShaderContextValue( 'SDF', self.useSDF )

end


function RenderManager:onContextReady()
	_stat( 'context ready!!' )
	
	--load config
	--todo
	
	self.rootRenderPass:setFrameBuffer( MOAIGfxMgr.getFrameBuffer() )
	MOAIRenderMgr.setRender( self.rootRenderPass )

	self.contextReady = true
	for context in pairs( self.contexts ) do
		context:onContextReady()
	end
	self:initGlobalTextures()

	emitGlobalSignal( 'gfx.render_manager_ready' )
end

function RenderManager:initGlobalTextures()
	local maxTexUnit = MOAIGfxMgr.getMaxTextureUnits()
	assert( maxTexUnit > 0 )
	-- self.globalTextureUnitStart = maxTexUnit - self.maxGlobalTextureCount
	for context in pairs( self.contexts ) do
		context:updateGlobalTextures()
	end
end


function RenderManager:declareGlobalTexture( name )
	local idx = self.globalTextureCount + 1
	if idx > self.maxGlobalTextureCount then 
		_fatal( 'global texture count exceed limit', self.maxGlobalTextureCount )
	end
	local item = GlobalTextureItem()
	item.index = idx
	item.name = name

	local map = self.globalTextureMap
	if map[ name ] then
		_fatal( 'duplicated global texture name', name )
	end
	map[ name ] = item

	_log( 'declared global texture', name, item.index )
	self.globalTextureCount  = self.globalTextureCount + 1
	self.globalTextures[ idx ] = item

end

function RenderManager:getGlobalTextureItems()
	return self.globalTextures
end

function RenderManager:getGlobalTextureItem( name )
	return self.globalTextureMap[ name ]		
end

function RenderManager:getGlobalTextureUnit( name ) -- 1-base index
	local item = self:getGlobalTextureItem( name )
	if not item then
		_error( 'global texture not found', name )
		return false
	end
	return self.globalTextureUnitStart + item.index
end

function RenderManager:getGlobalTexture( name )
	local context = self.currentContext
	if context then
		return context:getGlobalTexture( name )
	end
	return nil
end


function RenderManager:setGlobalTextures( t )
	if not self.currentContext then return end
	return self.currentContext:setGlobalTextures( t )	
end

function RenderManager:setGlobalTexture( name, tex )
	if not self.currentContext then return end
	return self.currentContext:setGlobalTexture( name, tex )
end

function RenderManager:getRootRenderPass()
	return self.rootRenderPass
end

function RenderManager:_setMaterialSwitchMask( mask )
	return MOAIRenderMgr.setMaterialBatchSwitchMask( mask )
end

function RenderManager:setGlobalMaterialSwitchMask( name )
	if not name then
		return self:_setMaterialSwitchMask()
	end

	local mask = self.materialSwitchMasks[ name ]
	assert( mask )
	if mask then
		return self:_setMaterialSwitchMask( mask )
	end

end

function RenderManager:getGlobalMaterialSwitchMask( name )
	return self.materialSwitchMasks[ name ]
end

local function BIT( n )
	return bit.lshift( 1, n )
end
function RenderManager:declareMaterialSwitchBit( name, bit )
	return self:declareMaterialSwitchMask( name, BIT( bit ) )
end

function RenderManager:declareMaterialSwitchMask( name, mask )
	assert( not self.materialSwitchMasks[ name ] )
	self.materialSwitchMasks[ name ] = mask
end

function RenderManager:addPostSyncRenderCall( func, ... )
	if self.async then
		table.insert( self.pendingPostSyncCalls, { func, { ... } } )
	else
		return func( ... )
	end
end

function RenderManager:affirmGfxResource( res )
	if self.async then
		table.insert( self.pendingResAffirm, res )
	else
		return res:affirm()
	end
end

function RenderManager:addRenderTask( layer, callback, data )
	local pending = self.async
		 -- and ( not game:isSyncingRenderState() )

	if pending then
		table.insert( self.pendingRenderTasks, { layer, callback, data } )

	else
		-- layer:draw()
		_draw( layer )
		if callback then return callback( data ) end
	end
end

function RenderManager:updateGfxResource()
	MOCKHelper.updateResourceMgr()
end


function RenderManager:addRenderTaskClearFramebuffer( fb, clearColor, clearDepth, clearStencil )
	local clearRenderCommand = MOAILayer.new()
	clearRenderCommand:setFrameBuffer( fb )
	if clearColor then
		clearRenderCommand:setClearColor( unpack(clearColor) )
	end
	if clearDepth ~= false then
		clearRenderCommand:setClearDepth( true )
	end
	if clearStencil ~= false then
		clearRenderCommand:setClearStencil( true )
	end
	clearRenderCommand:setClearMode( MOAILayer.CLEAR_ALWAYS )
	return self:addRenderTask( clearRenderCommand )
end


function RenderManager:preSyncRenderState()

end

function RenderManager:postSyncRenderState()
	local pendingRes = self.pendingResAffirm
	local count = #pendingRes 
	if count > 0 then
		for i = 1, count do
			local res = pendingRes[ i ]
			res:affirm()
		end
		self.pendingResAffirm = table.cleared( self.pendingResAffirm )
	end

	local pendingCalls = self.pendingPostSyncCalls
	local count = #pendingCalls 
	if count > 0 then
		for i = 1, count do
			local call = pendingCalls[ i ]
			local func, args = call[ 1 ], call[ 2 ]
			func( unpack( args ) )
		end
		self.pendingPostSyncCalls = table.cleared( self.pendingPostSyncCalls )
	end

	local pending = self.pendingRenderTasks
	local count = #pending 
	if count > 0 then
		for i = 1, count do
			local task = pending[ i ]
			local layer, callback, data = task[ 1 ], task[ 2 ], task[ 3 ]
			_draw( layer )
			if callback then callback( data ) end
		end
		self.pendingRenderTasks = table.cleared( self.pendingRenderTasks )
	end

end

function RenderManager:setPerformanceProfile( profile )
	self.performanceProfile = profile
	emitGlobalSignal( 'gfx.performance_profile.change', profile )
	self:setShaderContextValue( 'performance_profile', profile )
end

function RenderManager:getPerformanceProfile()
	return self.performanceProfile
end

function RenderManager:setShaderContextValue( k, v )
	self.shaderContext[ k ] = v
end

function RenderManager:getShaderContextValue( k )
	return self.shaderContext[ k ]
end

function RenderManager:getShaderContext()
	return self.shaderContext
end

--------------------------------------------------------------------
function createTableRenderLayer()
	local layer = MOAITableLayer.new()
	layer:setClearMode( MOAILayer.CLEAR_NEVER )
	return layer
end

function createTableViewRenderLayer()
	local layer = MOAITableViewLayer.new()
	layer:setClearMode( MOAILayer.CLEAR_NEVER )
	return layer
end

function createPartitionRenderLayer()
	local layer = MOAIPartitionViewLayer.new()
	layer:setClearMode( MOAILayer.CLEAR_NEVER )
	markRenderNode( layer )
	return layer
end

