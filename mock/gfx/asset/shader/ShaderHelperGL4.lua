module 'mock'

CLASS: ShaderHelperGL4 ( ShaderHelperGL3 )
:register ( 'GL4' )

function ShaderHelperGL4:isAvailable()
	local gfxName, verMaj, verMin = getRenderManager():getGraphicsAPIName()
	return gfxName == 'GL' and verMaj >= 4
end

function ShaderHelperGL4:makeShaderSamplerDecl( shaderConfig, uniformConfig )
	local binding = uniformConfig.value
	if type( binding ) == 'string' then
		binding = getRenderManager():getGlobalTextureUnit( binding )
	end
	if binding then
		return string.format( "layout( binding=%d ) uniform sampler2D %s;", (binding - 1), uniformConfig.name )
	else
		return string.format( "uniform sampler2D %s; //ERROR:constant binding not defined", uniformConfig.name )
	end
end

function ShaderHelperGL4:makeShaderUniformBlockDecl( shaderConfig, blockConfig )
	local bodyString = ''
	for i, entry in ipairs( blockConfig.uniforms ) do
		local line = string.format( '%s %s; ', entry.type, entry.name )
		bodyString = bodyString .. line
	end
	return string.format( 'layout( %s ) uniform %s { %s};', blockConfig.layout, blockConfig.name, bodyString )
end
