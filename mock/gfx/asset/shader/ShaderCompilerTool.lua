module 'mock'

local SHADER_DEFINE = [[
#version 450 core
#define LOWP
#define MEDP
#define HIGHP
precision mediump float;

]]

--------------------------------------------------------------------
CLASS: ShaderHelperGLSLCC ( mock.ShaderHelperGL4 )

function ShaderHelperGLSLCC:processCodeSet( codeset )
	if codeset.vsh then
		codeset.vsh = SHADER_DEFINE..codeset.vsh
	end
	if codeset.fsh then
		codeset.fsh = SHADER_DEFINE..codeset.fsh
	end
	if codeset.gsh then
		codeset.gsh = SHADER_DEFINE..codeset.gsh
	end
	if codeset.tsc then
		codeset.tsc = SHADER_DEFINE..codeset.tsc
	end
	if codeset.tse then
		codeset.tse = SHADER_DEFINE..codeset.tse
	end
end

local defaultSemantics = {
	position = 'POSITION',
	uv = 'TEXCOORD0',
	color = 'COLOR0',
	normal = 'NORMAL0'
}

function ShaderHelperGLSLCC:makeShaderInputDecl( shaderConfig, attrConfig, stage )
	local idx = attrConfig[1]
	local body = attrConfig[3]
	-- if stage == 'vertex' then
	-- 	local t, n = body:match( '(%w+)%s+(%w+)')
	-- 	local semantic = defaultSemantics[ n ] or "TEXCOORD"
	-- 	return string.format( 'layout( location=%s ) in %s;', semantic, body )
	-- else
	return string.format( 'layout( location=%d ) in %s;', idx - 1, body )
	-- end
end

function ShaderHelperGLSLCC:makeShaderOutputDecl( shaderConfig, attrConfig, stage )
	local idx = attrConfig[1]
	local body = attrConfig[3]
	return string.format( 'layout( location=%d ) out %s;', idx - 1, body )
end

function ShaderHelperGLSLCC:makeShaderUniformBlockDecl( shaderConfig, blockConfig )
	local bodyString = ''
	for i, entry in ipairs( blockConfig.uniforms ) do
		local line = string.format( '%s %s; ', entry.type, entry.name )
		bodyString = bodyString .. line
	end

	local baseUBOBinding = self:getUBOBindingBase() --0 is reserved for vertex buffer
	return string.format( 'layout( %s, binding=%d ) uniform %s { %s };', blockConfig.layout, blockConfig.binding, blockConfig.name, bodyString )
end

function ShaderHelperGLSLCC:getUBOBindingBase()
	return 1
end

local stages = {
	'vsh',
	'fsh',
	'gsh',
	'tse',
	'tsc',
}
--------------------------------------------------------------------
function generateShaderSourceFiles( sourcePath, outputPath )
	MOAIFileSystem.affirmPath( outputPath )

	local source = mock.loadTextData( sourcePath )
	local configData = mock.parseShaderScript( source, sourcePath )

	local shaderConfigGroup = SHADER_SCRIPT( source )
	local shaderHelper = ShaderHelperGLSLCC()


	local l0 = false
	local format = string.format
	local function lineFunc( line, text )
		local out
		if ( not l0 ) or ( line - l0 > 1 ) then
			out = format( '#line %d\n%s\n', line, text )
		else
			out = text..'\n'
		end
		l0 = line
		return out
	end

	for key, config in pairs( shaderConfigGroup.subConfigs ) do
		l0 = false
		local builder = mock.ShaderBuilder( config, nil, nil, shaderHelper )
		builder:buildSourceSetForCompilation( outputPath, lineFunc )
	end

	--
	for key, shaderData in pairs( configData.shaders ) do		
		for _, stage in ipairs( stages ) do
			local itemData = shaderData[ stage ]
			if itemData then
				itemData[ 'data' ] = false
				itemData[ 'template' ] = false
			end		
		end
	end
	
	saveJSONFile( configData, outputPath .. '/__index.json' )
end

