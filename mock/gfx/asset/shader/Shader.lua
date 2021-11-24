module 'mock'


local DEFAULT_ATTRIBUTE_FORMAT = {
	position = MOAIShaderProgram.ATTRIBUTE_TYPE_VEC4;
	uv       = MOAIShaderProgram.ATTRIBUTE_TYPE_VEC2;
	color    = MOAIShaderProgram.ATTRIBUTE_TYPE_RGBA8;
}

local nameToAttributeFormat = {
	vec4  = MOAIShaderProgram.ATTRIBUTE_TYPE_VEC4;
	vec3  = MOAIShaderProgram.ATTRIBUTE_TYPE_VEC3;
	vec2  = MOAIShaderProgram.ATTRIBUTE_TYPE_VEC2;
	float = MOAIShaderProgram.ATTRIBUTE_TYPE_FLOAT;
	rgba8 = MOAIShaderProgram.ATTRIBUTE_TYPE_RGBA8;
}

local getShaderGlobalId = getShaderGlobalId

local MOAIShaderProgram = MOAIShaderProgram

local UNIFORM_FLOAT = MOAIShaderProgram.UNIFORM_TYPE_FLOAT
local UNIFORM_INT   = MOAIShaderProgram.UNIFORM_TYPE_INT

local UNIFORM_WIDTH_VEC_2      = MOAIShaderProgram.UNIFORM_WIDTH_VEC_2
local UNIFORM_WIDTH_VEC_3      = MOAIShaderProgram.UNIFORM_WIDTH_VEC_3
local UNIFORM_WIDTH_VEC_4      = MOAIShaderProgram.UNIFORM_WIDTH_VEC_4
local UNIFORM_WIDTH_MATRIX_3X3 = MOAIShaderProgram.UNIFORM_WIDTH_MATRIX_3X3
local UNIFORM_WIDTH_MATRIX_4X4 = MOAIShaderProgram.UNIFORM_WIDTH_MATRIX_4X4

---------------------------------------------------------------------
local function _declareUniform( format, uid, name, utype, arraySize )
	--m2todo: initial value
	if     utype == 'float' then
		format:declareUniform( uid, name, UNIFORM_FLOAT, nil, arraySize or nil )

	elseif utype == 'int' then
		format:declareUniform( uid, name, UNIFORM_INT, nil, arraySize or nil )

	elseif utype == 'vec2' then
		format:declareUniform( uid, name, UNIFORM_FLOAT, UNIFORM_WIDTH_VEC_2, arraySize or nil )

	elseif utype == 'vec3' then
		format:declareUniform( uid, name, UNIFORM_FLOAT, UNIFORM_WIDTH_VEC_3, arraySize or nil )

	elseif utype == 'vec4' then
		format:declareUniform( uid, name, UNIFORM_FLOAT, UNIFORM_WIDTH_VEC_4, arraySize or nil )
	
	elseif utype == 'mat4' then
		format:declareUniform( uid, name, UNIFORM_FLOAT, UNIFORM_WIDTH_MATRIX_4X4, arraySize or nil )

	elseif utype == 'mat3' then
		format:declareUniform( uid, name, UNIFORM_FLOAT, UNIFORM_WIDTH_MATRIX_3X3, arraySize or nil )

	else
		error( 'undefined shader type:'..tostring( utype ) )

	end
end

--------------------------------------------------------------------

--------------------------------------------------------------------
local UniformScriptSourceRegistry = {}

function getUniformScriptSourceClass( id )
	return UniformScriptSourceRegistry[ id ]
end


--------------------------------------------------------------------
CLASS: UniformScriptSource ()

function UniformScriptSource.register( clas, name, uniformType, arraySize )
	UniformScriptSourceRegistry[ name ] = {
		class = clas,
		type  = uniformType,
		size  = arraySize or 1
	}
end

function UniformScriptSource:__init( args )
	self.args = args
	self:onInit( args )
end


function UniformScriptSource:bind( prog, name, blockId, uid, attrId )
	self.blockId = blockId
	self.uid  = uid
	self.attrId = attrId
	self.uname = name
	-- body
end

function UniformScriptSource:onInit( args )
end

function UniformScriptSource:getType()
	return 'float'
end

function UniformScriptSource:getDefaultValue()
	return 0
end

function UniformScriptSource:buildUniform( shader )
	local instance = self:createUniform()
	instance:init( self )
	instance:bind( shader, self.blockId, self.uid, self.attrId )
	return instance
end

function UniformScriptSource:createUniform( shader )
	return UniformScript()
end

--------------------------------------------------------------------
CLASS: UniformScript ()

function UniformScript:getSource()
	return self.source
end

function UniformScript:init( source )
	self.source = source
	self:onInit( source )
end

function UniformScript:bind( shader, blockId, uid, attrId )
	self:onBind( shader, blockId, uid, attrId )
end

function UniformScript:onInit( source )
end

function UniformScript:onBind( shader, blockId, uid, attrId )
end

--------------------------------------------------------------------
local function affirmUniformId( block )
	
end

--------------------------------------------------------------------
--Deprecated:
function buildShaderProgramFromString( vsh, fsh, variables )
	local info = debug.getinfo( 2, 'Sl' )
	local path = info.source
	local prog = ShaderProgram()
	prog:setDebugName( path )
	if variables then
		local uniforms = variables.uniforms or {}
		prog.uniforms = uniforms

		prog.globals  = variables.globals or {}

		--no blocks support
		prog.blocks   = false
		
		--affirm uid, legacy support
		local uid = 0
		if variables.globals then
			for i, entry in ipairs( variables.globals ) do
				local globalId, utype, size = getShaderGlobalId( entry.type )
				entry.global = globalId
				entry.tag = 'global'
				entry.type = utype
				table.insert( uniforms, entry )
			end
		end

		for i, entry in ipairs( uniforms ) do
			uid = uid + 1
			entry._idx = uid
			entry.uid = uid
			entry.tag = entry.tag or'uniform'
		end

	end

	prog.vsh = vsh
	prog.fsh = fsh
	prog:build()
	return prog
end

--------------------------------------------------------------------


--------------------------------------------------------------------
CLASS: ShaderProgram ()
	:MODEL{
		Field 'vsh' :asset( 'vsh' );
		Field 'fsh' :asset( 'fsh' );
	}

--------------------------------------------------------------------
CLASS: Shader ()
	:MODEL{}

--------------------------------------------------------------------
--class shader program
--------------------------------------------------------------------
local loadedShaderPrograms = {}

function getLoadedShaderPrograms()
	return loadedShaderPrograms
end


function ShaderProgram:__init()
	self.prog =  MOAIShaderProgram.new()
	self.attrIdTable = {}
	self.uniformScriptTable = {}
	self.built = false

	self.vsh = false
	self.fsh = false
	self.gsh = false
	self.tsh = false

	self.vshPath = false
	self.fshPath = false
	self.gshPath = false
	self.tshPath = false

	self.scripts    = false
	self.globals    = false
	self.attributes = false
	self.uniforms   = {}
	self.shaders    = table.weak_k()

	self.precompiled = false

	self.parentConfig = false
end

function ShaderProgram:getMoaiShaderProgram()
	return self.prog
end

function ShaderProgram:__tostring()
	return string.format( '%s<%s>', self:__repr(), self:getPath ())
end

function ShaderProgram:setDebugName( n )
	self.debugName = n
	self.prog:setDebugName( n )
end

function ShaderProgram:getDebugName()
	if self.debugName then
		return self.debugName
	else
		return self:getPath()
	end
end

function ShaderProgram:getPath()
	return self.parentConfig and self.parentConfig:getPath() or '???'
end

function ShaderProgram:getParentConfig()
	return self.parentConfig
end

function ShaderProgram:getName()
	return self.parentConfig and self.parentConfig:getName()
end

local _NameToUsageHint = {
	['dynamic'] = MOAIVertexBuffer.BUFFER_USAGE_DYNAMIC_DRAW;
	['stream']  = MOAIVertexBuffer.BUFFER_USAGE_STREAM_DRAW;
	['static']  = MOAIVertexBuffer.BUFFER_USAGE_STATIC_DRAW;
}

function ShaderProgram:_buildBlock( blockId, blockName, data, attrIdTable, defaultAttrValues )

	local prog = self.prog
	
	local format = MOAIShaderUniformFormat.new()
	local uniforms = data.uniforms or {}

	local scripts  = data.scripts or {}
	local globals  = data.globals or {}
	
	local hasGlobal = #globals > 0

	local ucount = #uniforms
	format:reserveUniforms( ucount )
	if blockId > 0 then
		local layout = data.layout
		if layout == 'std140' then
			format:setMemoryLayout( MOAIShaderProgram.MEMORY_LAYOUT_STD140 )
		else
			error( 'only std140 suppored for now' )
		end
	end
	local defaultAttrValues = self.defaultAttrValues
	local attrIdTable = self.attrIdTable
	local samplers = self.samplers

	---
	for i, u in ipairs( uniforms ) do
		local uid     = u.uid
		local utype   = u.type
		local rawType = utype
		local uvalue  = u.value
		local name    = u.name
		local size    = u.size or 1

		if not uid then
			error( '???:'.. name )
		end

		if utype == 'sampler'  then
			rawType = 'int'
			if uvalue ~= 1 then --ingore default sampler
				local texUnit
				local texName = uvalue
				if type( texName ) == 'string' then
					--TODO: support material-scope named texture
					--try global named texture
					texUnit = getRenderManager():getGlobalTextureUnit( texName ) 
					assert( texUnit, 'named texture not declared', texName )
					uvalue = texUnit
				else
					assert( type( uvalue ) == 'number' )
					texUnit = uvalue
				end
				table.insert( samplers, { u, blockId, uid, texName, texUnit } )
			end
		end

		_declareUniform( format, uid, name, rawType )
		
		local attrId = prog:getAttributeID( blockId, uid, 1 )
		attrIdTable[ name ] = attrId

		if uvalue then
			if utype == 'sampler' then
				defaultAttrValues[ attrId ] = uvalue - 1 --convert to 0-index
			else
				defaultAttrValues[ attrId ] = uvalue
			end
		end

	end

	---
	for i, g in ipairs( globals ) do
		local uid = assert( g.uid )
		local globalId, utype, width = g.global
		local gid = self.currentGlobalId + 1
		self.currentGlobalId = gid
		prog:setGlobal( gid, globalId, blockId, uid, nil )
	end

	--scripts
	for i, u in ipairs( scripts ) do
		local uid = assert( u.uid )
		local name   = u.name
		local s = u.script
		local scriptData = getUniformScriptSourceClass( s.id )
		assert( scriptData )
		local scriptId     = s.id
		local scriptClas   = scriptData.class
		local scriptArgs   = s.args
		local scriptSource = scriptClas( scriptArgs )
		
		self.uniformScriptTable[ name ] = scriptSource

		local uvalue = scriptSource:getDefaultValue()

		--TODO: value type check?
		local attrId =  prog:getAttributeID( blockId, uid )
		attrIdTable[ name ] = attrId
		if uvalue then
			defaultAttrValues[ attrId ] = uvalue
		end

		scriptSource:bind( prog, name, blockId, uid, attrId )
		
	end
	
	if blockId > 0 then
		local bindingPoint = data.binding
		-- local usageHint = MOAIVertexBuffer.BUFFER_USAGE_STREAM_DRAW;
		usageHint = data.usage and _NameToUsageHint[ data.usage ] or false
		if not usageHint then
			if #globals>0 then 
				usageHint = MOAIVertexBuffer.BUFFER_USAGE_STREAM_DRAW
			else
				usageHint = MOAIVertexBuffer.BUFFER_USAGE_STATIC_DRAW
			end
		end

		if bindingPoint then
			prog:declareUniformBlock( blockId, blockName, format, bindingPoint, usageHint )
		else
			prog:declareUniformBlock( blockId, blockName, format, nil, usageHint )
		end

	else
		prog:setUniformFormat( format )
		
	end


end

function ShaderProgram:build( force )
	if self.built and not force then return end
	loadedShaderPrograms[ self ] = true
	local prog  = self.prog

	local vshSource = self.vsh
	local fshSource = self.fsh
	local attributes = self.attributes or { 
		'position', 
		'uv', 
		'color'
	}
	
	_stat( 'building shader program', self )

	prog:purge()
	assert( 
		type( vshSource ) == 'string' and type( fshSource ) == 'string',
		'invalid shader source type:' .. tostring( self )
	)
	prog:setNoProcessor( self.precompiled )
	prog:load( vshSource, fshSource )
	prog:setDebugName( self:getDebugName() )

	prog._source = self

	local match = string.match
	--setup variables
	for i, a in ipairs(attributes) do
		local tt = type( a )
		local name, format
		if tt == 'table' then
			name, format = a[ 1 ], a[ 2 ]
		elseif tt == 'string' then
			name, format = match( a, '(%w+):(%w+)' )
			if name then
				format = assert( nameToAttributeFormat[ format ] )
				-- print( 'yeah!', name, format )
			else
				name = a
			end
		else
			error( 'wtf?')
		end
		if not format then
			format = DEFAULT_ATTRIBUTE_FORMAT[ name ]
		end
		prog:setVertexAttribute( i, name, format )
	end
	
	--uniforms
	self.attrIdTable        = {}
	self.uniformScriptTable = {}
	self.defaultAttrValues  = {}
	self.samplers           = {}

	--count globals
	self.currentGlobalId = 0
	local totalGlobals = 0
	totalGlobals = totalGlobals + ( self.globals and #self.globals or 0 )
	local blocks = self.blocks
	if blocks then
		prog:reserveUniformBlocks( #self.blocks )
		for i, block in ipairs( self.blocks ) do
			totalGlobals = totalGlobals + #block.globals
		end
	end

	prog:reserveGlobals( totalGlobals )

	--program internal block
	self:_buildBlock( 0, false, self )

	--ubos
	local blocks = self.blocks
	if blocks then
		local n = #blocks
		prog:reserveUniformBlocks( n )
		for i = 1, n do
			local block = blocks[ i ]
			self:_buildBlock( i, block.name, block )
		end
	end

	-- declare textures
	prog:reserveTextures( #self.samplers )
	for i, entry in ipairs( self.samplers ) do
		local u, blockId, uid, texName, texUnit = unpack( entry )
		assert( texUnit >= 1 )
		prog:setTexture( i, texUnit, texUnit )
	end

	self.built = true
	self:refreshShaders()

end

function ShaderProgram:refreshShaders()
	for key, shader in pairs( self.shaders ) do
		shader:setProgram( self )
	end
end

function ShaderProgram:buildShader( key )	
	_warn( 'DEPRECATED shader API' )
	if not self.built then self:build() end
	local shader = Shader()
	shader:setProgram( self )
	shader._id = key
	key = key or shader
	self.shaders[ key ] = shader
	return shader
end

function ShaderProgram:findShader( key )	
	return self.shaders[ key ]
end

function ShaderProgram:releaseShader( id )
	local shader = self.shaders[ id ]
	if not shader then
		-- _warn( 'no shader found', id )
		return false
	end
	self.shaders[ id ] = nil
end

function ShaderProgram:affirmShader( key )	
	local shader = self:findShader( key )
	if not shader then
		return self:buildShader( key )
	end
	return shader
end

function ShaderProgram:preloadInGPU()
	-- body
end


--------------------------------------------------------------------
--class shader
--------------------------------------------------------------------
local _loadedShaders = table.weak()
function _reportShader()
	_log( 'REMAINING SHADERS:')
	for shader in pairs( _loadedShaders ) do
		local id = shader._id
		_log( 'shader:', id, shader.released, shader.shader )		
	end
end

function Shader:__init()
	self.scriptUniforms = {}
	self.shader = markRenderNode( MOAIShader.new() )
	self.shader:setFinalizer( function()
		self:release()
	end )
	self.shader.parent = self
	self.prog = false
	self._id = false
	_loadedShaders[ self ] = true
end

function Shader:release()
	local config, prog = self.parentConfig, self.prog
	if config then
		config:releaseShader( self._id )
	else
		if prog then
			prog:releaseShader( self._id )
		end
	end
	
	self._id = false
	self.released = true
end

function Shader:setProgram( prog, reloading )
	if not reloading then
		assert( not self.prog )
	end
	if prog == self.prog then return end
	if self.prog then
		self.prog:releaseShader( self._id )
	end
	self.prog = prog

	local shader = self.shader
	shader:setProgram( prog:getMoaiShaderProgram() )
	self:refresh()
end

function Shader:clear()
	local shader = self.shader
	shader._id = false
	shader:clearAllLinks()

end

function Shader:refresh()
	local shader = self.shader
	local prog = self.prog
	shader:clearAllLinks()
	--load default values
	for attrId, v in pairs( prog.defaultAttrValues ) do
		shader:setAttr( attrId, v )
	end
	--init uniform scripts
	for name, scriptUniformSource in pairs( prog.uniformScriptTable ) do
		local instance = scriptUniformSource:buildUniform( self )
		self.scriptUniforms[ name ] = instance
	end
	self.released = false
end

function Shader:getProgram()
	return self.prog
end

function Shader:getName()
	return self.prog and self.prog:getName()
end

function Shader:getMoaiShader()
	return self.shader
end

function Shader:getScriptUniform( name )
	return self.scriptUniforms[ name ]
end

function Shader:getAttrId( name )	
	return self.prog.attrIdTable[ name ]
end

function Shader:hasAttr( name )
	return self:getAttrId( name ) and true or false
end

function Shader:setAttr( name, v )
	local id = self.prog.attrIdTable[ name ]
	if not id then error('undefined uniform:'..name, 2) end
	return self.shader:setAttr( id, v )
end

function Shader:setAttrById( id, v )
	return self.shader:setAttr( id, v )
end

function Shader:setAttrByIdUnsafe( id, v )
	return self.shader:setAttrUnsafe( id, v )
end

function Shader:clearAttrLink( name )
	local tt = type( name )
	local id
	if tt == 'string' then
		id = self.prog.attrIdTable[ name ]
		-- if not id then error('undefined uniform:'..name, 2) end
	elseif tt == 'number' then
		id = name
	-- else
	-- 	-- error( 'invalid attr name:'.. name )
	-- 	return
	end
	if not id then return end
	self.shader:setAttrLink( id )
end

function Shader:setAttrLink( name, node, id1 )
	local tt = type( name )
	local id
	if tt == 'string' then
		id = self.prog.attrIdTable[ name ]
		if not id then error('undefined uniform:'..name, 2) end
	elseif tt == 'number' then
		id = name
	else
		error( 'invalid attr name:'.. name )
	end
	self.shader:setAttrLink( id, node, id1 )
end

function Shader:seekAttr( name, v, duration, ease )
	--Future...
	local id = self.prog.attrIdTable[ name ]
	if not id then error('undefined uniform:'..name, 2) end
	return self.shader:seekAttr( id, v, duration, ease )
end

function Shader:moveAttr( name, v, duration, ease )
	--Future...
	local id = self.prog.attrIdTable[ name ]
	if not id then error('undefined uniform:'..name, 2) end
	return self.shader:moveAttr( id, v, duration, ease )
end

