module 'mock'

local getShaderGlobalId = getShaderGlobalId

local insert = table.insert

local _uidx = 0
--------------------------------------------------------------------
local function _sortUniformEntry( a, b )
	return a._idx < b._idx
end

local function _makeBlock( layout, binding, usage, body )
	_uidx = _uidx + 1
	if body.__binding ~= nil then
		binding = body.__binding
		body.__binding = nil
	end
	return {
		tag = 'block', layout = layout, body = body, _idx = _uidx, binding = binding or false, usage = usage or false
	}
end


local function _findBlockLayout( t )
	for _, n in ipairs( t ) do
		if n == 'std140' then return n end
	end
	return false
end

local function _findBlockUsage( t )
	for _, n in ipairs( t ) do
		if n == 'static' or n == 'dynamic' or n == 'stream' then return n end
	end
	return false
end

local function blockFunc ( n, ... )
	local tt = type( n )
	
	if tt == 'table' then
		local body = n
		return _makeBlock( 'std140', false, false, body )

	elseif tt == 'string' then
		local settings = { n, ... }
		local layout = _findBlockLayout( settings ) or 'std140'
		local usage = _findBlockUsage( settings ) or false
		return function( t )
			assert( type( t ) == 'table' )
			return _makeBlock( layout, layout, usage, t )
		end

	elseif type( n ) == 'nil' then
		return blockFunc( 'std140' )

	else
		error( 'invalid block function', 2 )
		
	end
end

local _ShaderScriptLoaderEnv = {
	sampler = function ( textureName ) --unit or name to find
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'sampler', value = textureName, _idx = _uidx }
	end;

	block = blockFunc;

	global_block = function( name )
		_uidx = _uidx + 1
		return { tag = 'global_block', name = name, _idx = _uidx }
	end;

	global = function( globalId )
		_uidx = _uidx + 1
		return { tag = 'global', type = globalId, _idx = _uidx }
	end;

	float = function ( default )
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'float', value = default, _idx = _uidx }
	end;

	int = function ( default )
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'int', value = default, _idx = _uidx }
	end;

	color = function ( default )
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'color', value = default, _idx = _uidx }
	end;
	
	mat4 = function ( default )
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'mat4', value = default, _idx = _uidx }
	end;

	mat3 = function ( default )
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'mat3', value = default, _idx = _uidx }
	end;

	vec2 = function ( default )
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'vec2', value = default, _idx = _uidx }
	end;

	vec3 = function ( default )
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'vec3', value = default, _idx = _uidx }
	end;

	vec4 = function ( default )
		_uidx = _uidx + 1
		return { tag = 'uniform', type = 'vec4', value = default, _idx = _uidx }
	end;

	script = function( scriptId, args )
		_uidx = _uidx + 1
		return { tag = 'script', scriptId = scriptId, args = args, _idx = _uidx }
	end;

	boolean = function()
		return { tag = 'variant', type = 'boolean' }
	end;

	enum = function( ... )
		return { tag = 'variant', type = 'enum', values = { ... } }
	end;

	--constants
	std140 = 'std140',
	shared = 'shared',

	dynamic = 'dynamic',
	static  = 'static',
	stream  = 'stream'

}

--load global ids
for globalId, info in pairs( getShaderGlobalInfoTable() ) do
	_ShaderScriptLoaderEnv[ globalId ] = globalId
end


--------------------------------------------------------------------
local function _loadShaderScript( src, filename )
	local shaderItems = {}
	local sourceItems = {}
	-- local passes
	local branches
	local variants

	----
	local function passFunc( t )
		-- passes = t
	end

	----
	local function sourceFunc( name )
		if type( name ) ~= 'string' then
			error( 'source name expected' )
		end

		local function sourceUpdater( src )
			if type( src ) ~= 'string' then
				error( 'source string expected:' .. name )
			end
			if sourceItems[ name ] then
				error( 'redefining source:' .. name )
			end
			local info = debug.getinfo( 2, 'l' )
			local currentline = info[ 'currentline' ]
			local lineCount = src:count( '\n' ) + 1
			local prefix = string.rep( '\n', currentline - lineCount - 2 )
			local output = prefix..src
			local template, err = loadpreprocess( output, filename )
			if not template then
				print( err )
				error( 'failed loading source:' .. filename )
			end 
			sourceItems[ name ] = {
				tag = 'source',
				name = name,
				data = output,
				template = template
			}
		end
		return sourceUpdater
	end

	----
	local function shaderFunc( name )
		if type( name ) ~= 'string' then
			error( 'shader name expected' )
		end
		local function shaderUpdater( data )
			if type( data ) ~= 'table' then
				error( 'table expected for shader:' .. name )
			end
			if shaderItems[ name ] then
				error( 'redefining shader:' .. name )
			end
			shaderItems[ name ] = {
				tag  = 'shader',
				name = name,
				data = data
			}
		end
		return shaderUpdater
	end

	----
	local function branchFunc( t )
		branches = t
	end

	local function variantsFunc( t )
		variants = t
	end

	local env = {
		pass       = passFunc;
		shader     = shaderFunc;
		source     = sourceFunc;
		branch     = branchFunc;
		variants   = variantsFunc;
	}

	setmetatable( env, { __index = _ShaderScriptLoaderEnv } )
	local func, err = loadstring( src, filename )
	if not func then
		_error( 'failed loading shader script', filename )
		print( err )
		print( '--source--' )
		print( src )
		print( '--end of source--' )
		return false
	end

	setfenv( func, env )
	local ok, err = pcall( func )
	if not ok then
		_error( 'failed evaluating shader script', filename )
		print( err )
		print( '--source--' )
		print( src )
		print( '--end of source--' )
		return false
	end


	--process shaderItems
	local function processSource( configData, sourceType, input )
		if type( input ) ~= 'string' then
			_warn( 'invalid shader source entry', sourceType )
			return false
		end
		local ref = input:match( '^%s*@(.*)' )
		if ref then
			if getAssetType( ref ) ~= 'glsl' and  getAssetType( ref ) ~= sourceType then
				_warn( 'invalid shader source entry', sourceType, ref )
				return false
			end
			-- local src = loadAsset( ref )
			-- if type( src ) ~= 'string' then
			-- 	_warn( 'referenced shader source not loaded', sourceType, ref )
			-- 	return false
			-- end
			configData[ sourceType ] = {
				type = 'file',
				path = ref
			}
			return true
		else
			local item = sourceItems[ input ]
			if not item then
				_warn( 'inline source not found', input )
				return false
			end
			configData[ sourceType ] = {
				type     = 'source',
				data     = item.data,
				template = item.template
			}
		end
	end

	--process uniform block declaration
	local function processBlockBody( blockId, body )
		local uniforms = {}
		local globals  = {}
		local scripts  = {}

		local allEntries = {}
		local blocks
		if blockId then
			blocks = nil
		else
			blocks = {}
		end

		local hasGlobal

		for varName, varItem in pairs( body ) do
			local tag = varItem.tag
			if not (
					type( varItem ) == 'table'
					and ( tag == 'uniform' or tag == 'global' or tag == 'script' or tag == 'block'  ) 
				)
			then
				_warn( 'invalid uniform entry', filename, varItem.name, varName )
			else
				if tag == 'block' then
					if blockId then
						_warn( 'uniform block must be put in top level' )
					else
						local entry = {
							_idx    = assert( varItem._idx ),
							tag     = tag,
							name    = varName,
							layout  = varItem.layout,
							binding = varItem.binding,
						}
						local result = processBlockBody( varName, varItem.body )
						entry.uniforms = result.uniforms
						entry.globals  = result.globals
						entry.scripts  = result.scripts
						entry.usage    = varItem.usage or result.targetUsage
						insert( blocks, entry )
					end

				elseif tag == 'uniform' then
					local entry = {
						_idx  = assert( varItem._idx ),
						tag   = tag,
						name  = varName,
						type  = varItem.type,
						value = varItem.value
					}
					insert( uniforms, entry )

				elseif tag == 'global' then
					local globalId, utype, size = getShaderGlobalId( varItem.type )
					hasGlobal = true

					local entry = {
						_idx   = assert( varItem._idx ),
						tag    = tag,
						name   = varName,
						type   = utype,
						global = globalId,
						size   = size or 1,
					}
					insert( globals, entry )
					insert( uniforms, entry )

				elseif tag == 'script' then
					local scriptId = varItem.scriptId
					local scriptData = getUniformScriptSourceClass( scriptId )
					if scriptData then
						local entry = {
							_idx   = assert( varItem._idx ),
							tag    = tag,
							name   = varName,
							type   = scriptData.type,
							size   = scriptData.size,
							script = {
								id   = scriptId,
								args = varItem.args
							}
						}

						insert( scripts, entry )
						insert( uniforms, entry )

					else
						_error( 'no script uniform defined', scriptId )
					end
				end
			end
		end

		--determine uniform index
		table.sort( uniforms, _sortUniformEntry )
		for i, entry in ipairs( uniforms ) do
			entry.uid = i
		end

		local targetUsage = 'static'
		if hasGlobal then
			targetUsage = 'stream'
		end

		return {
			uniforms = uniforms, --all uniforms
			globals  = globals,
			scripts  = scripts,
			blocks   = blocks,
			targetUsage    = targetUsage
		}

	end

	----
	local shaderDatas = {}

	for shaderName, shaderItem in pairs( shaderItems ) do
		--verify
		local shaderConfigData = {
		}
		shaderDatas[ shaderName ] = shaderConfigData

		for k, v in pairs( shaderItem.data ) do
			if k == 'attribute' then
				local attributes = {}
				for i, attrName in ipairs( v ) do
					if not type( attrName ) == 'string' then
						_warn( 'invalid attribute entry', shaderItem.name, attrName )
					else
						insert( attributes, attrName )
					end
				end
				shaderConfigData.attributes = attributes

			elseif k == 'uniform' then
				local result = processBlockBody( false, v )
				shaderConfigData.uniforms = result.uniforms

				shaderConfigData.blocks  = result.blocks

				shaderConfigData.globals = result.globals
				shaderConfigData.scripts = result.scripts


			elseif k == 'context' then
				shaderConfigData.context = v

			elseif k == 'context_default' then
				shaderConfigData.defaultContext = v

			elseif k == 'program_tessellation' then
				processSource( shaderConfigData, 'tsh', v )

			elseif k == 'program_geometry' then
				processSource( shaderConfigData, 'gsh', v )

			elseif k == 'program_vertex'   then
				processSource( shaderConfigData, 'vsh', v )

			elseif k == 'program_fragment' then
				processSource( shaderConfigData, 'fsh', v )

			else
				_warn( 'unknown shader field', tostring(k) )
			end
		end

	end

	----
	-- local branchData = {}
	-- if branches then
	-- 	for var, shaderName in pairs( branches ) do

	-- 	end
	-- end

	return {
		shaders = shaderDatas,
		branches = branches;
		variants = variants or false;
	}
end

---------------------------------------------------------------------
CLASS: ShaderScriptConfigGroup ( ShaderConfigGroup )

function ShaderScriptConfigGroup:__tostring()
	return string.format( '%s%s',self:__repr(), self.path or '???' )
end

function ShaderScriptConfigGroup:reload()
	local path = self.path
	local node = path and getAssetNode( path )
	print( 'reloading', self, node )
	if not node then return false end
	return self:loadFromAssetNode( node, true )
end

function ShaderScriptConfigGroup:loadFromAssetNode( node, reloading )
	if getRenderManager().useCompiledShader then
		local compiledPath = node:getObjectFile( 'compiled' )
		if compiledPath and MOAIFileSystem.checkPathExists( compiledPath ) then
			if self:loadFromPrecompiled( compiledPath, node:getPath(), reloading ) then
				return true
			end
		end
	end

	--fallback to source support
	local src
	if node:getType() == 'shader' then
		src = loadTextData( node:getObjectFile('def') )
	else
		src = loadTextData( node:getObjectFile('src') )
	end
	if not src then return false end
	return self:loadFromSource( src, '@'..node:getPath(), node:getPath(), reloading )
end

function ShaderScriptConfigGroup:loadFromSource( src, name, path, reloading )
	local configData = _loadShaderScript( src, name )
	if not configData then return false end
	return self:loadConfig( configData, path, reloading )
end

--------------------------------------------------------------------
local function ShaderScriptLoader( node )
	local configGroup = node:getCacheData( 'config' )
	if not configGroup then
		configGroup = ShaderScriptConfigGroup()
		configGroup.path = node:getPath()
		node:setCacheData( 'config', configGroup )
	end
	node:disableGC()
	if configGroup:loadFromAssetNode( node ) then
		return configGroup
	else
		return false
	end
end

local function ShaderScriptUnloader( node, asset, newCache, prevCache )
	node:setCacheData( 'config', prevCache[ 'config' ] )
end

registerAssetLoader ( 'shader_script', ShaderScriptLoader, ShaderScriptUnloader )
registerAssetLoader ( 'shader', ShaderScriptLoader, ShaderScriptUnloader )

--------------------------------------------------------------------
local function shaderSourceLoader( node )
	local source = loadTextData( node:getObjectFile('src') )
	if source then
		local template, err = loadpreprocess( source, node:getPath() )
		if template then return template end
		_log( err )
		_error( 'failed processing shader source:' .. filename )
	else
		_error( 'failed loading shader source:' .. filename )
	end
	return false
end

registerAssetLoader ( 'fsh', shaderSourceLoader )
registerAssetLoader ( 'vsh', shaderSourceLoader )
registerAssetLoader ( 'glsl', shaderSourceLoader )


--------------------------------------------------------------------
function buildMaterialFromShader( shaderPath )
	local material = RenderMaterial()
	material.shader = shaderPath
	material:init()
	return material
end

function buildMasterShader( shaderPath, id, context )
	--deprecated
	local shaderConfig = loadAsset( shaderPath )
	if shaderConfig then
		return shaderConfig:affirmShader( id or 'default', context )
	else
		_warn( 'cannot load shaderConfig', shaderPath )
		return false
	end
end

--------------------------------------------------------------------
function buildShader( shaderPath, shaderKey, context )
	return buildSubShader( shaderPath, 'main', shaderKey, context )
end

--------------------------------------------------------------------
function buildSubShader( shaderPath, subShaderName, shaderKey, context )
	subShaderName = subShaderName or 'main'
	local shaderConfigGroup = loadAsset( shaderPath )
	local shaderConfig = shaderConfigGroup and shaderConfigGroup:getSubConfig( subShaderName )
	return shaderConfig and shaderConfig:affirmShader( shaderKey, context ) or false
end


--------------------------------------------------------------------
function buildShaderScriptFromString( src, name )
	local info = debug.getinfo( 2, 'Sl' )
	local path = info.source
	local shaderConfigGroup = ShaderScriptConfigGroup()
	shaderConfigGroup:loadFromSource( src, name or '???', path )
	return shaderConfigGroup
end

_G.SHADER_SCRIPT = buildShaderScriptFromString

_M.parseShaderScript = _loadShaderScript