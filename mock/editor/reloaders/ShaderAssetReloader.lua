module 'mock'

--------------------------------------------------------------------
CLASS: ShaderAssetReloader ( AssetReloader )
:register( 'shader_reloader' )

function ShaderAssetReloader:onAssetModified( node )
	local atype = node:getType()
	local toUpdate = {}

	if atype == 'fsh' or atype == 'vsh' or atype == 'glsl' then
		local path = node:getNodePath()
		local programs = mock.getLoadedShaderPrograms()
		local toUpdate = {}
		for prog in pairs( programs ) do
			if   prog.vshPath == path 
				or prog.fshPath == path
				or prog.tshPath == path
				or prog.gshPath == path
			then
				local parentConfig = prog.parentConfig
				if parentConfig then
					toUpdate[ parentConfig ] = true
				end
			end
		end
		for config in pairs( toUpdate ) do
			config:rebuild()
		end

	elseif atype == 'shader_script' or atype == 'shader' then
		local config = node:getCacheData( 'config' )
		if config then
			config:reload()
			config:rebuild()
			
			-- for depConfig in pairs( config.dependentConfigs ) do
			-- 	depConfig:rebuild()
			-- end
			
		end

	else
		return

	end

end



