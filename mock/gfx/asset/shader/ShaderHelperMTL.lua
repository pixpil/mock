module 'mock'

CLASS: ShaderHelperMTL ( ShaderHelper )
:register ( 'Metal')

function ShaderHelperMTL:isAvailable()
	local gfxName, verMaj, verMin = getRenderManager():getGraphicsAPIName()
	return gfxName == 'Metal'
end

function ShaderHelperMTL:makeShaderSamplerDecl( shaderConfig, uniformConfig )
	return string.format( 'uniform sampler2D %s;', uniformConfig.name )
end

function ShaderHelperMTL:makeShaderUniformDecl( shaderConfig, uniformConfig )
	return string.format( 'uniform %s %s;', uniformConfig.type, uniformConfig.name )
end

function ShaderHelperMTL:makeShaderUniformBlockDecl( shaderConfig, blockConfig )
	return ''
end

function ShaderHelperMTL:onInit()
	local shaderScriptMeshShader = SHADER_SCRIPT [=[
    --------------------------------------------------------------------
    shader 'main' {
		    attribute = {
					'position:vec3',
					'uv',
					'color',
				};

        uniform = {
            Param    = block {
            		mtxModelToClip        = global(MODEL_TO_CLIP_MTX);
								ucolor                = global(PEN_COLOR);
            };
            __sampler__ = sampler( 1 );
        };

        program_vertex = 'vsh';
        program_fragment = 'fsh';
    }

    --------------------------------------------------------------------
    source 'vsh' [==[
      	struct VIn {
					vec4 position	[[attribute(0)]];
					vec2 uv      	[[attribute(1)]];
					vec4 color   	[[attribute(2)]];
				};

				struct Param {
					mat4 transform;
					vec4 ucolor;
				};

				struct VOut {
					vec4 position			[[position]];
					vec4 colorVarying;
					vec2 uvVarying;
				};


				vertex VOut ShaderMain (
					VIn in [[stage_in]], 
					constant Param& param [[buffer(1)]]
				){

					VOut out;
					
					out.position = param.transform * in.position;
					out.uvVarying = in.uv;
					out.colorVarying = in.color * param.ucolor;
					return out;
				}
    ]==]

    --------------------------------------------------------------------
    source 'fsh' [==[  
    	struct FIn {
				vec4 position;
				vec4 colorVarying;
				vec2 uvVarying;
			};

			fragment vec4 ShaderMain (
				FIn in [[stage_in]],
				texture2df	tex		[[texture(0)]],
				sampler		__sampler__	[[sampler(0)]]
			) {
				return tex.sample ( __sampler__, in.uvVarying ) * in.colorVarying;
			}
    ]==]

	]=]


	local shaderScriptLine3DShader = SHADER_SCRIPT [=[
    --------------------------------------------------------------------
    shader 'main' {
        uniform = {
            Param    = block {
            		mtxModelToClip        = global(MODEL_TO_CLIP_MTX);
								ucolor                = global(PEN_COLOR);
            };
        };

        attribute = {
        	'position:vec3';
					'color';
        };

        program_vertex = 'vsh';
        program_fragment = 'fsh';
    }

    --------------------------------------------------------------------
    source 'vsh' [==[
			struct VIn {
				vec4 position	[[attribute(0)]];
				vec4 color   	[[attribute(1)]];
			};

			struct Param {
				mat4 transform;
				vec4 ucolor;
			};

			struct VOut {
				vec4 position			[[position]];
				vec4 colorVarying;
			};


			vertex VOut ShaderMain (
				VIn				in		[[stage_in]],
				constant Param&	param	[[buffer(1)]]
			) {

				VOut out;

				out.position = param.transform * in.position;
				out.colorVarying = in.color * param.ucolor;
				return out;
			}
    ]==]

    --------------------------------------------------------------------
    source 'fsh' [==[  
	    struct FIn {
				vec4 position;
				vec4 colorVarying;
			};
			

			fragment vec4 ShaderMain (
				FIn in [[stage_in]] 
			) {
				
				return in.colorVarying;
			}
    ]==]

	]=]

	self.defaultMeshShader   =  assert( shaderScriptMeshShader:affirmDefaultShader() )
	self.defaultLine3DShader =  assert( shaderScriptLine3DShader:affirmDefaultShader() )

	MOAIShaderMgr.setShader( 
		MOAIShaderMgr.MESH_SHADER, self.defaultMeshShader:getMoaiShader()
	)

	MOAIShaderMgr.setShader(
		MOAIShaderMgr.LINE_SHADER_3D, self.defaultLine3DShader:getMoaiShader()
	)

end

function ShaderHelperMTL:getLanaguage()
	return 'msl'
end

function ShaderHelperMTL:getUBOBindingBase()
	return 1
end
