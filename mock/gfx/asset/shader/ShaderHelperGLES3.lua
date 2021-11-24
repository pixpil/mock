module 'mock'

CLASS: ShaderHelperGLES3 ( ShaderHelperGL3 )
:register ( 'GLES3')

function ShaderHelperGLES3:isAvailable()
	local gfxName, verMaj, verMin = getRenderManager():getGraphicsAPIName()
	return gfxName == 'GLES3'
end

