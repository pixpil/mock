module 'mock'

--------------------------------------------------------------------
local function legacyShaderConfigLoader( node )
	local data = loadAssetDataTable( node:getObjectFile('def') or node:getFilePath() )
	if not data then return false end

	if data[ 'multiple' ] then
		_warn( 'multiple pass legacy shader is deprecated', node )
		local configData = {}
		local passData = {}
		local maxPass = 0
		for i, entry in ipairs( data['shaders'] or {} ) do
			local passId = entry[ 'pass' ]
			if type( passId ) == 'number' then
				maxPass = math.max( maxPass, passId )
			end
			passData[ passId ] = { 
				type = 'file', 
				path = entry['path']
			}
		end
		configData[ 'passes' ]  = passData
		configData[ 'maxPass' ] = maxPass
		configData[ 'shaders' ] = {}

		local configGroup = ShaderConfigGroup()
		configGroup:loadConfig( configData, node:getPath() )
		return configGroup
			
	else
		local configData = {}
		local mainShaderData = {
			name = 'main';
			vsh = {
				type = 'file';
				path = data[ 'vsh' ]
			};
			fsh = {
				type = 'file';
				path = data[ 'fsh' ]
			};
			attributes  = data[ 'attributes' ];
			uniforms    = data[ 'uniforms' ] or {};
			globals     = data[ 'globals' ];
		}
		
		--affirm uid, legacy support
		local uniforms = mainShaderData.uniforms
		local uid = 0
		if mainShaderData.globals then
			for i, entry in ipairs( mainShaderData.globals ) do
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
		configData[ 'shaders' ] = { [ 'main' ] = mainShaderData }

		local configGroup = ShaderConfigGroup()
		configGroup:loadConfig( configData, node:getPath() )
		return configGroup

	end

end

-- registerAssetLoader ( 'shader', legacyShaderConfigLoader, nil, { deprecated = true } )
