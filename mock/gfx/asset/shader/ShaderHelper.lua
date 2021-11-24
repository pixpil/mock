module 'mock'

---------------------------------------------------------------------
CLASS: ShaderHelper ()
	:MODEL{}

--static
function ShaderHelper.register( clas, name )
	getShaderManager():registerHelperClass( name, clas )
end

function ShaderHelper:isAvailable()
	return false
end

function ShaderHelper:onInit()
end

function ShaderHelper:makeShaderDecl( shaderConfig, declType, body, stage )
	if declType == 'sampler' then
		local uniformConfig = shaderConfig:findUniformConfig( body )
		if uniformConfig and uniformConfig.type == 'sampler' then
			return self:makeShaderSamplerDecl( shaderConfig, uniformConfig )
		else
			return shaderConfig:_error( 'sampler not found:'..body )
		end
	end

	if declType == 'uniform' then 
		local uniformConfig = shaderConfig:findUniformConfig( body )
		if uniformConfig then
			return self:makeShaderUniformDecl( shaderConfig, uniformConfig )
		else
			return shaderConfig:_error( 'sampler not found:'..body )
		end
	end

	if declType == 'block' then
		local blockConfig = shaderConfig:findUniformConfig( body )
		if not blockConfig then
			return shaderConfig:_error( 'block config not found:'..body )
		end
		if blockConfig.tag ~= 'block' then
			return shaderConfig:_error( 'target is not block:'..body )
		end

		return self:makeShaderUniformBlockDecl( shaderConfig, blockConfig )
	end

	if declType == 'in' then
		local decls = body:split( '%s+', false )
		local name = decls[ #decls ]
		local attribConfig = shaderConfig:affirmInputAttrib( stage, name, body )
		return self:makeShaderInputDecl( shaderConfig, attribConfig, stage )
	end

	if declType == 'out' then
		local decls = body:split( '%s+', false )
		local name = decls[ #decls ]
		local attribConfig = shaderConfig:affirmOutputAttrib( stage, name, body )
		return self:makeShaderOutputDecl( shaderConfig, attribConfig, stage )
	end

	return shaderConfig:_error( 'unsupported decl template:'.. declType )
end

function ShaderHelper:makeShaderHeader( shaderConfig, stage )
	return false
end

function ShaderHelper:makeShaderSamplerDecl( shaderConfig, uniformConfig )
	return ''
end

function ShaderHelper:makeShaderUniformDecl( shaderConfig, uniformConfig )
	return ''
end

function ShaderHelper:makeShaderUniformBlockDecl( shaderConfig, blockConfig )
	return ''
end

function ShaderHelper:makeShaderInputDecl( shaderConfig, attrConfig, stage )
	local body = attrConfig[3]
	return 'in '..body ..';'
end

function ShaderHelper:makeShaderOutputDecl( shaderConfig, attrConfig, stage )
	local body = attrConfig[3]
	return 'out '..body ..';'
end


function ShaderHelper:processCodeSet( codeset )
	-- body
end

function ShaderHelper:getUBOBindingBase()
	return false
end

function ShaderHelper:getLanaguage()
	error( 'implement this')
end