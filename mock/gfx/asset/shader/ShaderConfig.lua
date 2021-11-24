module 'mock'

local _EmpytShaderContext = {}
local _getLuaValueAddress
if MOCKHelper and MOCKHelper.getLuaValueAddress then
	_getLuaValueAddress = MOCKHelper.getLuaValueAddress
else
	_getLuaValueAddress = function( o )
		return tonumber( tostring( o ):sub(-10 ) )
	end
end

local function affirmShaderKey( o )
	local t = type( o )
	if t == 'table' or t == 'userdata' then
		return tostring( o )
	else
		return o
	end
end

local insert, remove = table.insert, table.remove
--------------------------------------------------------------------
CLASS: ShaderConfigGroup ()
	:MODEL{}

function ShaderConfigGroup:__init()
	self.path = false
	self.subConfigs = {}
	self.dependents = {}
	self.branches = false
end

function ShaderConfigGroup:getPath()
	return self.path
end

function ShaderConfigGroup:addDependentGroup( group )
	self.dependents[ group ] = true
end

function ShaderConfigGroup:getBranches()
	return self.branches
end

function ShaderConfigGroup:getBranchSubConfig( var )
	return self.branches and self.branches[ var ]
end

function ShaderConfigGroup:getDefaultSubConfig()
	return self:getSubConfig( 'main' )
end

function ShaderConfigGroup:getSubConfig( name )
	return self.subConfigs[ name ]
end

function ShaderConfigGroup:affirmSubConfig( name, data )
	local config
	config = self.subConfigs[ name ]
	if not config then
		config = ShaderConfig()
		config.name = name
		config.parentGroup = self	
		self.subConfigs[ name ] = config
	end
	config.data = data
	config.context = table.merge( self.context, data.context or {} )
	config.defaultContext = data.defaultContext or {}
	--load when need?
	-- config:affirm()

	return config
end

function ShaderConfigGroup:affirmDefaultShader( context )
	local subConfig = self:getDefaultSubConfig()
	if not subConfig then return nil end
	return subConfig:affirmDefaultShader( context )
end

function ShaderConfigGroup:rebuild()
	for key, subConfig in pairs( self.subConfigs ) do
		subConfig:rebuildShaders()
	end
	for dep in pairs( self.dependents ) do
		dep:rebuild()
	end
end

function ShaderConfigGroup:loadConfig( data, path, reloading )

	self.path = path
	self.context = data[ 'context' ] or {}

	if not reloading then
		self.subConfigs = {}
	end

	for shaderName, shaderData in pairs( data[ 'shaders' ])  do
		self:affirmSubConfig( shaderName, shaderData )
	end

	local branches = data[ 'branches' ] or false
	if branches then
		self.branches = {}
		local renderManager = getRenderManager()
		for var, shaderName in pairs( branches ) do
			-- local mask = renderManager:getGlobalMaterialSwitchMask( var )
			-- if mask
			local config = self:getSubConfig( shaderName )
			if not config then 
				_warn( 'no sub shader defined:', shaderName, path )
			end
			self.branches[ var ] = config
		end
	else
		self.branches = false
	end

	--build hasher
	local variants = data[ 'variants' ] or false
	if variants then
		self.contextHasher = function( data )
			local testTable = {}
			for k in pairs( variants ) do
				testTable[ k ] = data[ k ] or false
			end
			return calcTableHash( testTable )
		end
		self.variants = variants
	else
		self.contextHasher = false
		self.variants = false
	end

	return true
end

function ShaderConfigGroup:fixContext( context )
	local output = {}
	if self.variants then
		for k, values in pairs( self.variants ) do
			local v = context[ k ] or false
			if v then
				local found = false
				for i = 1, #values do
					if values[ i ] == v then
						found = true
						break;
					end
				end
				if not found then v = false end
			end
			output[ k ] = v
		end
	end
	return output
end

function ShaderConfigGroup:loadFromPrecompiled( compiledPath, assetPath, reloading )	
	local configPath = compiledPath .. '/__index.json'
	local configData = loadJSONFile( configPath )
	if configData then
		self:loadConfig( configData, assetPath, reloading )
	end
	
	--load shader cache
	for name, subConfig in pairs( self.subConfigs ) do
		subConfig:loadFromPrecompiled( compiledPath, reloading )
	end

	return true
end
--------------------------------------------------------------------
CLASS: ShaderConfig ()

function ShaderConfig:__init()
	self.name = ''
	self.path = false
	self.parentGroup = false

	self.data = false
	self.loaded = false

	self.builtShaders = table.weak()
	self.dependentConfigs = table.weak_k()
	self.shaderPool = {}
	self.context = {}
	self.defaultContext = {}

	--strong?
	self.shaderProgCache = {}
	-- self.shaderProgCache = table.weak_v()
	self.inputAttribs = {}
	self.outputAttribs = {}

	self.precompiledCacheMap = false
	self.precompiledPath = false
end

function ShaderConfig:fixContext( context )
	return self.parentGroup:fixContext( context )
end

function ShaderConfig:hashContext( context )
	if self.parentGroup.contextHasher then
		return self.parentGroup.contextHasher( context )
	else
		return 'common'
	end
end

function ShaderConfig:__tostring()
	return string.format( "%s(%s @ %s)", self:__repr(), self:getName(), self:getPath() )
end

function ShaderConfig:_error( msg )
	_warn( 'shader config error:', self:getPath() )
	_warn( msg )
end

function ShaderConfig:getName()
	return self.name
end

function ShaderConfig:findUniformConfig( name )
	return self.uniformNameMap and self.uniformNameMap[ name ]
end

function ShaderConfig:resetIOAttrib()
	self.inputAttribs = {}
	self.outputAttribs = {}
end

function ShaderConfig:affirmInputAttrib( stage, name, body )
	local set = self.inputAttribs[ stage ]
	local count
	if not set then
		set = {
			__attrib_count__ = 0
		}
		self.inputAttribs[ stage ] = set
		count = 0
	else
		count = set.__attrib_count__
	end
	count = count + 1
	local idx = count
	--try get from input stage
	if stage == 'fragment' then
		local vertOut = self.outputAttribs[ 'vertex' ]
		local entry = vertOut and vertOut[ name ]
		if entry then
			idx = entry[ 1 ]
		else
			_warn( 'shader input not found', name )
		end
	end
	local attr = { idx, name, body }
	set[ name ] = attr
	set.__attrib_count__ = count
	return attr
end

function ShaderConfig:affirmOutputAttrib( stage, name, body )
	local set = self.outputAttribs[ stage ]
	local count
	if not set then
		set = {
			__attrib_count__ = 0
		}
		self.outputAttribs[ stage ] = set
		count = 0
	else
		count = set.__attrib_count__
	end
	count = count + 1
	local idx = count
	local attr = { idx, name, body }
	set[ name ] = attr
	set.__attrib_count__ = count
	return attr
end

function ShaderConfig:getShaderProgramCache()
	return self.shaderProgCache
end

function ShaderConfig:getPath()
	if self.path then return self.path end
	return self.parentGroup and self.parentGroup:getPath() or false
end

function ShaderConfig:getParentGroup()
	return self.parentGroup
end

function ShaderConfig:getShader( shaderKey )
	shaderKey = affirmShaderKey( shaderKey or 'default' )
	return self.builtShaders[ shaderKey ]
end

function ShaderConfig:affirm( shaderHelper )
	if self.loaded then return end
	self.loaded = true
	local map = {}
	self.uniformNameMap = map

	local data = self.data

	if data and data.uniforms then
		for i, entry in ipairs( data.uniforms ) do
			local name = entry.name
			if map[ name ] == entry then
				_error( 'duplicated uniform name detected', name, self )
			end
			map[ name ] = entry
		end
	end

	local uboBinding = shaderHelper:getUBOBindingBase()
	if data and data.blocks then
		for i, entry in ipairs( data.blocks ) do
			if uboBinding then
				entry.binding = uboBinding
				uboBinding = uboBinding + 1
			else
				entry.binding = false
			end
			local name = entry.name
			if map[ name ] == entry then
				_error( 'duplicated uniform name detected', name, self )
			end
			map[ name ] = entry
		end
	end

end

function ShaderConfig:reload()
end

function ShaderConfig:rebuildShaders()
	for shaderKey, shader0 in pairs( self.builtShaders ) do
		self:_buildShader( shaderKey, shader0.context, shader0 )
	end
end

function ShaderConfig:affirmDefaultShader( context )
	return self:affirmShader( 'default', context )
end

function ShaderConfig:affirmShader( shaderKey, instanceContext )
	shaderKey = affirmShaderKey( shaderKey )
	local shader = self:getShader( shaderKey )
	if not shader then 
		shader = self:_buildShader( shaderKey, instanceContext )
	end
	return shader
end

function ShaderConfig:releaseShader( shaderKey )
	shaderKey = affirmShaderKey( shaderKey )
	local shader = self.builtShaders[ shaderKey ]
	if not shader then
		-- _warn( 'no shader found', shaderKey )
		return false
	end
	self.builtShaders[ shaderKey ] = nil
	if shader._poolable then
		local pool = self.shaderPool
		pool[ #pool + 1 ] = shader
		shader:clear()
	end
end


function ShaderConfig:_buildShader( shaderKey, instanceContext, rebuildingShader )
	
	shaderKey = affirmShaderKey( shaderKey or 'default' )

	local shader0 = self.builtShaders[ shaderKey ]
	assert( not shader0 or rebuildingShader == shader0 )

	if ( not instanceContext ) or (not( next( instanceContext ))) then
		instanceContext = _EmpytShaderContext
	end
	
	local shader
	if not shader then	
		if instanceContext == _EmpytShaderContext then
			shader = remove( self.shaderPool, 1 )
			if shader then
				shader:refresh()
			end
		end
	end

	if not shader then
		local builder = ShaderBuilder( self, instanceContext, rebuildingShader )
		shader = builder:build() or false
		if instanceContext == _EmpytShaderContext then
			shader._poolable = true
		end
	end

	shader._id = shaderKey
	self.builtShaders[ shaderKey ] = shader
	return shader
end

function ShaderConfig:loadFromPrecompiled( compiledPath )
	self.precompiledPath = compiledPath

	local cacheMapPath = compiledPath ..'/' .. self.name .. '.json'
	local cacheMapConfig = loadJSONFile( cacheMapPath )
	self.precompiledCacheMap = cacheMapConfig

end

--------------------------------------------------------------------
--BUILDER
--------------------------------------------------------------------
local _shaderProgramCount = 0
function getShaderProgramCount()
	return _shaderProgramCount
end
--------------------------------------------------------------------
local sharedSourceEnv = {
	math = math,
	print = print
}

--------------------------------------------------------------------
CLASS: ShaderBuilder ()
	:MODEL{}


local function _processShaderInstanceContext( context )
	local tt = type( context )
	if tt == 'table' then
		return table.simplecopy( context )

	elseif tt == 'string' then
		return parseSimpleNamedValueList( context )
	end
	return nil
end

function ShaderBuilder:__init( config, instanceContext, rebuildingShader, shaderHelper )
	self.instanceContext = _processShaderInstanceContext( instanceContext ) or {}
	self.config = config
	self.rebuildingShader = rebuildingShader
	self.shaderHelper = shaderHelper or getShaderManager():getHelper()
	config:affirm( self.shaderHelper )

end


local _stageIDToName = {
	vs  = 'vsh',
	fs  = 'fsh',
	gs  = 'gsh',
	tse = 'tse',
	tsc = 'tsc',
}

function ShaderBuilder:loadPrecompiledCode( context )
	local config = self.config
	local contextHash = config:hashContext( context )
	local targetCodeHash = config.precompiledCacheMap[ contextHash ]

	if not targetCodeHash then
		table.print( context )
		_error( 'no context hash:', contextHash )
		return nil
	end

	--load codeset
	local shaderLanguage = getShaderManager():getLanaguage()
	local codeset = false

	local configData = config.data
	local base = config.precompiledPath .. '/' .. targetCodeHash

	for stageId, stageName in pairs( _stageIDToName ) do
		if configData[ stageName ] then
			local shaderPath = string.format( '%s/%s_%s_%s', base, 'output', shaderLanguage, stageId  )
			local src = loadTextData( shaderPath )
			if not src then
				--fallback to input source
				-- print( 'fallback to raw source', config )
				src = loadTextData( string.format( '%s/%s_%s', base, 'input', stageId  ) )
			-- else
			-- 	print( 'using', self.config, shaderPath )
			end

			if src then
				if not codeset then codeset = {} end
				codeset[ stageName ] = src
			end
		end
	end

	return codeset, targetCodeHash
end

function ShaderBuilder:buildSource( context, lineFunc )
	local config = self.config
	local data = config.data
	
	local vsh, vshPath = self:processSource( data['vsh'] or '__DEFAULT_VSH', context, 'vertex', lineFunc )
	local fsh, fshPath = self:processSource( data['fsh'] or '__DEFAULT_FSH', context, 'fragment', lineFunc )
	local gsh, gshPath = self:processSource( data['gsh'] or false, context, 'geometry', lineFunc )
	local tse, tsePath = self:processSource( data['tse'] or false, context, 'tessEval', lineFunc )
	local tsc, tscPath = self:processSource( data['tsc'] or false, context, 'tessControl', lineFunc )

	--DEBUG:OUTPUT processed source
	-- print( prog.vsh )
	-- print( prog.fsh )

	local codeset = {
		vsh = vsh, vshPath = vshPath;
		fsh = fsh, fshPath = fshPath;
		gsh = gsh, gshPath = gshPath;
		tse = tse, tsePath = tsePath;
		tsc = tsc, tscPath = tscPath;
	}

	self.shaderHelper:processCodeSet( codeset )
	return codeset

end

local hashWriter = MOAIHashWriter.new()
function ShaderBuilder:buildHash( codeset )
	-- generate a key
	local hashWriter = MOAIHashWriter.new()
	hashWriter:openCRC32()
	local vsh = codeset.vsh
	local fsh = codeset.fsh
	local gsh = codeset.gsh
	local tsc = codeset.tsc
	local tse = codeset.tse
	
	if vsh then
		hashWriter:write( '@vsh')
		hashWriter:write( vsh )
		-- hashWriter:write( vshPath or '' )
	end
	if fsh then
		hashWriter:write( '@fsh')
		hashWriter:write( fsh )
		-- hashWriter:write( fshPath or '' )
	end
	if gsh then
		hashWriter:write( '@gsh')
		hashWriter:write( gsh )
		-- hashWriter:write( gshPath or '' )
	end
	if tse then
		hashWriter:write( '@tse')
		hashWriter:write( tse )
		-- hashWriter:write( tshPath or '' )
	end
	if tsc then
		hashWriter:write( '@tsc')
		hashWriter:write( tsc )
		-- hashWriter:write( tshPath or '' )
	end
	hashWriter:close()
	local hash = hashWriter:getHashHex()
	return hash
end


function ShaderBuilder:build()
	local config = self.config	
	local data = config.data

	--make final context
	local context = table.merge( config.defaultContext, self.instanceContext )
	context = table.merge( context, config.context )
	context = table.merge( context, getRenderManager():getShaderContext() )

	context = config:fixContext( context )

	local codeset
	local codeHash
	local precompiled = false

	--try precompiled cache
	if config.precompiledCacheMap then
		codeset, codeHash  = self:loadPrecompiledCode( context )
		if codeset then precompiled = true end
	end

	--fallback to source building
	if not codeset then
		_stat( 'fallback to source shader', self.config )
		codeset = self:buildSource( context )
		codeHash = self:buildHash( codeset )
	else
		-- print( 'using precompied shader' )
	end

	local cache = config:getShaderProgramCache()
	local prog
	prog = cache[ codeHash ]

	if not prog then
		prog = ShaderProgram()
		prog:setDebugName( tostring(config) )
		prog.precompiled = precompiled
		prog.vsh, prog.vshPath = codeset.vsh, codeset.vshPath
		prog.fsh, prog.fshPath = codeset.fsh, codeset.fshPath
		prog.gsh, prog.gshPath = codeset.gsh, codeset.gshPath
		prog.tse, prog.tsePath = codeset.tse, codeset.tsePath
		prog.tsc, prog.tscPath = codeset.tsc, codeset.tscPath

		prog.uniforms   = data['uniforms']   or {}
		prog.globals    = data['globals']    or {}
		prog.scripts    = data['scripts']    or {}
		prog.blocks     = data['blocks']     or {}
		prog.attributes = data['attributes'] or false

		prog.parentConfig = config
		prog:build()

		_shaderProgramCount = _shaderProgramCount + 1
		cache[ codeHash ] = prog
		prog.prog:setFinalizer( function() cache[codeHash] = nil end ) 
	end

	local shader
	local rebuilding
	if self.rebuildingShader then
		shader = self.rebuildingShader
		assert( shader.parentConfig == config )
		rebuilding = true
	else
		shader = Shader()
	end

	shader.parentConfig = config
	shader:setProgram( prog, rebuilding )
	return shader

end

function ShaderBuilder:_doPreprocessor( template, context, stage, lineFunc )
	local sourceEnv = setmetatable( {}, { __index = sharedSourceEnv } )
	sourceEnv.context = context or {}

	local processed, err 
	if template then
		processed, err = template( sourceEnv, lineFunc )
	end

	if not processed then
		_warn( 'failed processing source', self.config )
		print( err )
		return false
	end
	
	local config = self.config
	local data = config.data
	local helper = self.shaderHelper

	local print = print
	local function _declFunc( declType, body )
		return helper:makeShaderDecl( config, declType, body, stage )
	end
	
	processed = string.gsub( processed, '@(%w+)%s*([^;]*);', _declFunc )

	-- local fileInfo = string.format( '\n//file:%s', config:getPath() )
	local fileInfo = ''
	local header = helper:makeShaderHeader( config, stage )
	if header then
		return header .. '\n' .. processed .. fileInfo
	else
		return processed .. fileInfo
	end
end


function ShaderBuilder:processSource( src, context, stage, lineFunc )
	if not src then return false end
	local tt = type( src )	

	if tt == 'table' then
		local srcType = src.type
		if srcType == 'source' then
			local processed, err = self:_doPreprocessor( src.template, context, stage, lineFunc )
			return processed, false

		elseif srcType == 'file' then
			local template, node = loadAsset( src.path )

			if template then
				local processed, err = self:_doPreprocessor( template, context, stage, lineFunc )
				return processed, src.path
			else
				_warn( 'preprocess template not load?', src.path )
				return false
			end

		else
			return src.data, false

		end

	elseif tt == 'string' then --reference?
		-- local builtin = DefaultShaderSource[ src ]
		-- if builtin then return builtin end
		local sourceText = loadAsset( src )
		if sourceText then
			return sourceText, false
		end
		return src, false

	end

	_warn( 'invalid source type', tt )
	return false
end

--------------------------------------------------------------------
local insert = table.insert
local simplecopy = table.simplecopy

local function makeVariantContext( res, entry0, input, keys, from, count )
	for i = from, count do
		local k = keys[i]
		local values = input[k]
		local vcount = #values
		for vi = 1, vcount do
			local value = values[ vi ]
			local entry = entry0 and simplecopy( entry0 ) or {}
			entry[ k ] = value
			if from == count then --last row
				insert( res, entry )
			else
				makeVariantContext( res, entry, input, keys, i + 1, count )
			end
		end
	end
end


function ShaderBuilder:enumContextVariants()
	local variants = self.config.parentGroup.variants
	if not variants then
		return { {} }
	end

	local res = {}
	local configContext = self.config.context
	local keys = table.keys( variants )
	local tryingVariants = {}
	for i, k in ipairs( keys ) do
		local v0 = configContext[ k ]
		if v0 ~= nil then
			tryingVariants[ k ] = { v0 }
		else
			local t = table.simplecopy( variants[ k ] )
			tryingVariants[ k ] = t
			t[ #t+1 ] = false
		end
	end
	makeVariantContext( res, nil, tryingVariants, keys, 1, #keys )
	return res
end

--------------------------------------------------------------------
local _shaderCodeStream = MOAIFileStream.new()
function ShaderBuilder:buildSourceSetForCompilation( outputPath, lineFunc )
	MOAIFileSystem.affirmPath( outputPath )
	local config = self.config

	local variants = {}
	local builtVariants = {}
	
	local codeHasherLineFunc = function( line, text )
			return string.format( '%d;', line )
		end

	--enum context
	local contextVariants = self:enumContextVariants()
	
	for i, contextVar in ipairs( contextVariants ) do
		local contextHash = config:hashContext( contextVar )

		if not variants[ contextHash ] then 
			
			config:resetIOAttrib()
			--build 'code' for variant contextHash
			local pesudoCodeset = self:buildSource( contextVar, codeHasherLineFunc )
			local codeHash = self:buildHash( pesudoCodeset )
			variants[ contextHash ] = codeHash --context -> code hash, final shader will be loaded from [code hash] folder

			if not builtVariants[ codeHash ] then
				builtVariants[ codeHash ] = true
				local vairantPath = outputPath .. '/' .. codeHash
				MOAIFileSystem.affirmPath( vairantPath )

				local function _writeFile( stage, suffix, codeset )
					local code = codeset[ stage ]
					if not code then return end
					local filename = vairantPath .. '/input_' .. suffix
					_shaderCodeStream:open( filename, MOAIFileStream.WRITE )
					_shaderCodeStream:write( code )
					_shaderCodeStream:close()
				end

				config:resetIOAttrib()
				local codeset = self:buildSource( contextVar, lineFunc )
				_writeFile( 'vsh', 'vs',  codeset )
				_writeFile( 'fsh', 'fs',  codeset )
				_writeFile( 'gsh', 'gs',  codeset )
				_writeFile( 'tse', 'tse', codeset )
				_writeFile( 'tsc', 'tsc', codeset )
			end
		end
	end

	--write variant list

	saveJSONFile( variants, outputPath .. '/' .. config.name .. '.json' )

	return true
end