module 'mock'

CLASS: ShaderHelperNVN ( ShaderHelperGL4 )
:register ( 'NVN')

function ShaderHelperNVN:isAvailable()
	local gfxName, verMaj, verMin = getRenderManager():getGraphicsAPIName()
	return gfxName == 'NVN'
end

