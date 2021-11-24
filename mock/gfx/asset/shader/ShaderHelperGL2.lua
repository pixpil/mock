module 'mock'

CLASS: ShaderHelperGL2 ( ShaderHelper )
:register ( 'GL2' )

function ShaderHelperGL2:isAvailable()
	local gfxName, verMaj, verMin = getRenderManager():getGraphicsAPIName()
	if gfxName ~= 'GL' then return false end
	if verMaj > 2 then return false end
	return true
end

function ShaderHelperGL2:makeShaderSamplerDecl( shaderConfig, uniformConfig )
	return string.format( 'uniform sampler2D %s;', uniformConfig.name )
end

function ShaderHelperGL2:makeShaderUniformDecl( shaderConfig, uniformConfig )
	return string.format( 'uniform %s %s;', uniformConfig.type, uniformConfig.name )
end

function ShaderHelperGL2:makeShaderUniformBlockDecl( shaderConfig, blockConfig )
	error( 'UBO not supported in GL2' )
end

function ShaderHelperGL2:getLanaguage()
	return 'glsl'
end
