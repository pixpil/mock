module 'mock'

local EnumBlendFuncToMoai       = EnumBlendFuncToMoai
local EnumBlendFactorToMoai     = EnumBlendFactorToMoai
local EnumDepthTestModeToMoai   = EnumDepthTestModeToMoai
local EnumStencilTestModeToMoai = EnumStencilTestModeToMoai
local EnumStencilOpToMoai       = EnumStencilOpToMoai
local EnumCullingModeToMoai     = EnumCullingModeToMoai

local getMoaiBlendMode = getMoaiBlendMode



---------------------------------------------------------------------
---------------------------------------------------------------------
CLASS: RenderMaterialInstance ()
	:MODEL{}

--------------------------------------------------------------------
function RenderMaterialInstance:__init( source, key )
	self.source = source
	self.key = key
	self.shaders = {}
	self.materialBatch = false
	self.subMaterialBatches = false
	self:initMaterialBatch()
end

--------------------------------------------------------------------
function RenderMaterialInstance:__tostring()
	return string.format( '%s @ %s', self:__repr(), self.source:__tostring() )
end

--------------------------------------------------------------------
function RenderMaterialInstance:getMaterial()
	return self.source
end

--------------------------------------------------------------------
function RenderMaterialInstance:initMaterialBatch()
	local batch
	local source = self.source
	local branchInfo =  source:getBranchInfo()
	
	if not branchInfo then --single batch
		batch = MOAIMaterialBatch.new()
		local context = source.parsedShaderContext
		local shaderConfig = source:getDefaultShaderConfig()
		if shaderConfig then
			local shader = shaderConfig:affirmShader( self, context )
			batch:setShader( 1, shader:getMoaiShader() )
			self.shaders[ 'main' ] = shader
		end

	else
		batch = MOAIMaterialBatchSwitch.new()
		local branchCount = table.len( branchInfo )
		local context = source.parsedShaderContext
		batch:reserveSubBatches( branchCount )
		local idx = 0
		self.subMaterialBatches = {}
		for mask, info in pairs( branchInfo ) do
			idx = idx + 1
			local subBatch = MOAIMaterialBatch.new()
			if type( mask ) == 'string' then
				mask = getRenderManager():getGlobalMaterialSwitchMask( mask )
			end
			batch:setSubBatch( idx, subBatch, mask )
			self.subMaterialBatches[ mask ] = subBatch

			local shaderConfig = info.shader
			if shaderConfig then
				local shader = shaderConfig:affirmShader( self, context )
				assert( shader )
				local shaderName = shaderConfig.name
				subBatch:setShader( 1, shader:getMoaiShader() )
				self.shaders[ shaderName ] = shader
				-- print( 'add shader', shaderName, self )
			end
		end

	end

	batch:setParent( source.sharedMaterialBatch )
	batch.__source = self
	self.materialBatch = batch
	-- local key = self.key
	-- local source = self.source
	-- batch:setFinalizer( function()
	-- 	source:removeInstance( key )
	-- end )

end

--------------------------------------------------------------------
function RenderMaterialInstance:getMaterialBatch()
	return self.materialBatch
end

function RenderMaterialInstance:getSubMaterialBatch( batchMask )
	if not self.subMaterialBatches then return false end
	if type( batchMask ) == 'string' then
		batchMask = getRenderManager():getGlobalMaterialSwitchMask( batchMask )
	end
	return batchMask and self.subMaterialBatches[ batchMask ]
end

--------------------------------------------------------------------
function RenderMaterialInstance:update()
	local source = self.source
	--should be done in sharedMaterialBatch
	-- source:syncToMoaiMaterial( self.materialBatch )
	--build shader branches

end

--------------------------------------------------------------------
function RenderMaterialInstance:applyToMoaiProp( prop )
	local source = self.source
	source:update()

	prop:setParentMaterialBatch( self.materialBatch )
	
	--non moaimaterial settings( should be in somewhere else? )
	source:applyBillboard   ( prop )
	source:applyPriority    ( prop )

end

--------------------------------------------------------------------
function RenderMaterialInstance:getShader( name )
	name = name or 'main'
	return self.shaders[ name ]
end

function RenderMaterialInstance:getShaders()
	return self.shaders
end

---------------------------------------------------------------------
---------------------------------------------------------------------
--------------------------------------------------------------------
CLASS: RenderMaterial ()
	:MODEL{

		Field 'tag'              :string();
		'----';
		Field 'blend'            :enum( EnumBlendMode );
		Field 'shader'           :asset( 'shader;shader_script' );
		Field 'shaderName'       :string();
		Field 'sharedShader'     :boolean();
		Field 'shaderContext'    :string();
		Field 'branchForShader'  :boolean();
		'----';
		Field 'depthMask'        :boolean();
		Field 'depthTest'        :enum( EnumDepthTestMode ) ;
		'----';
		Field 'billboard'        :enum( EnumBillboard );
		Field 'culling'          :enum( EnumCullingMode );
		'----';
		Field 'priority'         :int();

		'----';
		Field 'stencilTest'      :enum( EnumStencilTestMode );
		Field 'stencilTestRef'   :int() :range(0,255);
		Field 'stencilTestMask'  :int() :range(0,255) :widget( 'bitmask8' );
		Field 'stencilMask'      :int() :range(0,255) :widget( 'bitmask8' );
		Field 'stencilOpSFail'   :enum( EnumStencilOp );
		Field 'stencilOpDPFail'  :enum( EnumStencilOp );
		Field 'stencilOpDPPass'  :enum( EnumStencilOp );

		'----';
		Field 'colorMaskR'       :boolean();
		Field 'colorMaskG'       :boolean();
		Field 'colorMaskB'       :boolean();
		Field 'colorMaskA'       :boolean();

	}

--------------------------------------------------------------------
local CULL_NONE            = MOAIProp. CULL_NONE
local DEPTH_TEST_ALWAYS    = MOAIProp. DEPTH_TEST_ALWAYS
local DEPTH_TEST_DISABLE   = MOAIProp. DEPTH_TEST_DISABLE
local STENCIL_TEST_DISABLE = MOAIProp. STENCIL_TEST_DISABLE
local STENCIL_OP_KEEP      = MOAIProp. STENCIL_OP_KEEP
local STENCIL_OP_KEEP      = MOAIProp. STENCIL_OP_KEEP
local STENCIL_OP_REPLACE   = MOAIProp. STENCIL_OP_REPLACE
local BILLBOARD_NONE       = MOAIProp. BILLBOARD_NONE

--------------------------------------------------------------------
function RenderMaterial:__init()
	self.tag       = ''
	self.blend     = 'solid'
	
	self.shader    = false
	self.shaderName = 'main'
	self.shaderContext = ''
	self.sharedShader = true
	
	--
	self.billboard = BILLBOARD_NONE
	self.culling   = CULL_NONE
	
	--depth test
	self.depthMask = false
	self.depthTest = DEPTH_TEST_DISABLE
	
	--stencil
	self.stencilMask      = 0xff
	self.stencilTest      = STENCIL_TEST_DISABLE
	self.stencilTestRef   = 0
	self.stencilTestMask  = 0xff
	self.stencilOpSFail   = STENCIL_OP_KEEP
	self.stencilOpDPFail  = STENCIL_OP_KEEP
	self.stencilOpDPPass  = STENCIL_OP_REPLACE

	--priority
	self.priority = 0

	--colorMask
	self.colorMaskR = true
	self.colorMaskG = true
	self.colorMaskB = true
	self.colorMaskA = true

	---Instances
	self.sharedMaterialBatch = MOAIMaterialBatch.new()
	self.instances       = table.weak_k()
	self.defaultInstance = false
	self.dirty           = true
	self.assetPath       = false

	--branch control
	self.branchForShader = true
	self.branching       = false
	self.branchInfo      = false

end

--------------------------------------------------------------------
function RenderMaterial:__tostring()
	return string.format( '%s:%s', self:__repr(), self.assetPath or '???' )
end


--------------------------------------------------------------------
function RenderMaterial:createInstance( key )
	local instance = RenderMaterialInstance( self, key )
	return instance
end

function RenderMaterial:removeInstance( key )
	self.instances[ key ] = nil
end

--------------------------------------------------------------------
function RenderMaterial:affirmDefaultInstance()
	local default = self.defaultInstance
	if not default then
		default = self:createInstance( '__default' )
		self.defaultInstance = default
	end
	return default
end

--------------------------------------------------------------------
function RenderMaterial:affirmInstance( key )
	if ( not key ) or ( key == '__default' ) or ( self:isShared() ) then
		return self:affirmDefaultInstance()
	end

	local instance = self.instances[ key ]
	if not instance then
		instance = self:createInstance( key )
		self.instances[ key ] = instance
	end
	return instance
end

--------------------------------------------------------------------
function RenderMaterial:isShared()
	return self.sharedShader
end

--------------------------------------------------------------------
function RenderMaterial:getBranchInfo()
	return self.branchInfo
end

function RenderMaterial:getDefaultShaderConfig()
	return self.defaultShaderConfig
end

--------------------------------------------------------------------
function RenderMaterial:init()
	--shader context
	local parsedShaderContext = parseSimpleNamedValueList( self.shaderContext )
	parsedShaderContext[ 'material' ] = self.assetPath
	self.parsedShaderContext = parsedShaderContext

	--Branch info
	local branchInfo = self.branchInfo
	if not branchInfo then
		local branching = false
		branchInfo = {}
		local function addBranchInfo( mask )
			if not branchInfo[ mask ] then
				local entry = {}
				branchInfo[ mask ] = entry
				return entry
			end
			return branchInfo[ mask ]
		end
		--try branch on shader
		if self.branchForShader then
			local shaderPath = nonWhiteSpaceString( self.shader )
			local shaderConfigGroup = mock.loadAsset( shaderPath )
			local branches = shaderConfigGroup and shaderConfigGroup.branches
			if branches and next( branches ) then
				branching = true
				for mask, shaderSubConfig in pairs( branches ) do
					local entry = addBranchInfo( mask )
					entry.shader = shaderSubConfig
				end
			end
		end

		if branching then
			self.branchInfo = branchInfo
		else
			self.branchInfo = false
		end

	end

	if not self.branchInfo then
		_stat( 'branching material', self )
		--default shader config
		local shaderConfig = false
		local shaderPath = nonWhiteSpaceString( self.shader )
		if shaderPath then
			local shaderName = self.shaderName
			if shaderName == '' then
				shaderName = 'main'
			end
			local shaderConfigGroup = mock.loadAsset( shaderPath )
			if shaderConfigGroup then
				shaderConfig = shaderConfigGroup:getSubConfig( shaderName )
				if not shaderConfig then
					_warn( 'shader config not found:', shaderName, shaderPath )
				end
			else
				_warn( 'shader asset not found:', shaderPath )
			end
		end
		self.defaultShaderConfig = shaderConfig
		_stat( 'done branching material' )
	else
		self.defaultShaderConfig = false
	end


end

--------------------------------------------------------------------
function RenderMaterial:update()
	if not self.dirty then return end
	self:syncToMoaiMaterial( self.sharedMaterialBatch )
	for i, instance in ipairs( self.instances ) do
		instance:update()
	end
	self.dirty = false
end

--------------------------------------------------------------------
function RenderMaterial:syncToMoaiMaterial( batch, ignoreFlags )
		batch:setBlendMode( 1,	getMoaiBlendMode( self.blend ) )
		batch:setColorMask( 1, self.colorMaskR, self.colorMaskG, self.colorMaskB, self.colorMaskA )

		batch:setStencilMode( 
			1,
			self.stencilMask,
			EnumStencilTestModeToMoai[ self.stencilTest ], self.stencilTestRef, self.stencilTestMask,
			EnumStencilOpToMoai[ self.stencilOpSFail ], 
			EnumStencilOpToMoai[ self.stencilOpDPFail ], 
			EnumStencilOpToMoai[ self.stencilOpDPPass ]
		)

		batch:setCullMode( 1, EnumCullingModeToMoai[ self.culling ] )

		batch:setDepthMask( 1, self.depthMask )
		batch:setDepthTest( 1, EnumDepthTestModeToMoai[ self.depthTest ] )

		--shader setting in instance
end

--------------------------------------------------------------------
function RenderMaterial:applyToMoaiProp( prop )
	local instance = self:affirmInstance( prop )
	return instance:applyToMoaiProp( prop )
end

--------------------------------------------------------------------
function RenderMaterial:applyBillboard( prop )
	prop:setBillboard( self.billboard )	
end

--------------------------------------------------------------------
function RenderMaterial:applyPriority( prop )
	prop:setPriority( self.priority )
end

--------------------------------------------------------------------
function RenderMaterial:setBlend( blend )
	self.blend = blend
	self.dirty = true
end

--------------------------------------------------------------------
function RenderMaterial:setDepthTest( test )
	self.depthTest = test
	self.dirty = true
end

--------------------------------------------------------------------
function RenderMaterial:setDepthMask( mask )
	self.depthMask = mask
	self.dirty = true	
end

--------------------------------------------------------------------
function RenderMaterial:setStencilTest( func, ref, mask )
	self.stencilTest = func
	self.stencilTestRef = ref
	self.stencilTestMask = mask
	self.dirty = true
end

--------------------------------------------------------------------
function RenderMaterial:setStencilMask( mask )
	self.stencilMask = mask
	self.dirty = true
end

--------------------------------------------------------------------
function RenderMaterial:setColorMask( r, g, b, a )
	self.colorMaskR = r
	self.colorMaskG = g
	self.colorMaskB = b
	self.colorMaskA = a
	self.dirty = true
end

--------------------------------------------------------------------
function RenderMaterial:getColorMask()
	return self.colorMaskR, self.colorMaskG, self.colorMaskB, self.colorMaskA
end


---------------------------------------------------------------------
---------------------------------------------------------------------
--------------------------------------------------------------------
local DefaultMaterial = RenderMaterial()
DefaultMaterial.tag = '__DEFAULT'
DefaultMaterial:setBlend( 'alpha' )

function getDefaultRenderMaterial()
	return DefaultMaterial
end

local legacyDepthTestEnum = {
	[ 0   ] =   'disable';
	[ 37  ] =  'never';
	[ 31  ] =  'always';
	[ 33  ] =  'less';
	[ 34  ] =  'less_equal';
	[ 32  ] =  'equal';
	-- [ nil ] =  'not_equal';
	[ 36  ] =  'greater';
	[ 35  ] =  'greater_equal';
}
local legacyStencilTestEnum = {
	[ 0   ] = 'disable';
	[ 159 ] = 'never';
	[ 153 ] = 'always';
	[ 155 ] = 'less';
	[ 156 ] = 'less_equal';
	[ 154 ] = 'equal';
	-- [ nil ] = 'not_equal';
	[ 158 ] = 'greater';
	[ 157 ] = 'greater_equal';
}

local legacyStencilOpEnum = {
	[ 145 ] = 'decr';
	[ 146 ] = 'decr_wrap';
	[ 147 ] = 'incr';
	[ 148 ] = 'incr_wrap';
	[ 149 ] = 'invert';
	[ 150 ] = 'keep';
	[ 151 ] = 'replace';
	[ 152 ] = 'zero';
}

local legacyCullingEnum = {
	[ 0  ] = 'none';
	[ 28 ] = 'all';
	[ 29 ] = 'back';
	[ 30 ] = 'front';
}

local function fixLegacyRenderMaterialData( data )
	local mapData = data[ 'map' ]
	local root = data[ 'root' ]
	if mapData then
		local objData = mapData[ root ]
		local bodyData = objData and objData.body
		if bodyData and type( bodyData[ 'depthTest' ] ) == 'number' then
			bodyData[ 'depthTest'       ] = legacyDepthTestEnum   [ bodyData[ 'depthTest'       ] ]
			bodyData[ 'culling'         ] = legacyCullingEnum     [ bodyData[ 'culling'         ] ]
			bodyData[ 'stencilTest'     ] = legacyStencilTestEnum [ bodyData[ 'stencilTest'     ] ]
			bodyData[ 'stencilOpSFail'  ] = legacyStencilOpEnum   [ bodyData[ 'stencilOpSFail'  ] ]
			bodyData[ 'stencilOpDPFail' ] = legacyStencilOpEnum   [ bodyData[ 'stencilOpDPFail' ] ]
			bodyData[ 'stencilOpDPPass' ] = legacyStencilOpEnum   [ bodyData[ 'stencilOpDPPass' ] ]
		end
	end
end

--------------------------------------------------------------------
local function loadRenderMaterial( node )
	local data   = mock.loadAssetDataTable( node:getObjectFile('def') )
	if data then
		fixLegacyRenderMaterialData( data )
	end
	local config = mock.deserialize( nil, data )	
	config.assetPath = node:getPath()
	config:init()
	node:disableGC()
	return config
end

registerAssetLoader( 'material', loadRenderMaterial )
