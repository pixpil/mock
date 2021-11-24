module 'mock'

CLASS: ShaderCacheManager ( GlobalManager )
	:MODEL{}

function ShaderCacheManager:__init()
end

function ShaderCacheManager:affirmShaderData( shaderPath, context )
	local shaderConfig = mock.loadAsset( shaderPath )
	local chacheId = shaderConfig:generateCacheId( context )
	
end

function ShaderCacheManager:prebuildShaderCache()
end




ShaderCacheManager()

