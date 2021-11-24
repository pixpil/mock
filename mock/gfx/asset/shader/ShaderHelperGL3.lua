module 'mock'

CLASS: ShaderHelperGL3 ( ShaderHelperGL2 )
:register ( 'GL3' )

function ShaderHelperGL3:isAvailable()
	local gfxName, verMaj, verMin = getRenderManager():getGraphicsAPIName()
	return gfxName == 'GL' and verMaj >= 3
end

function ShaderHelperGL3:makeShaderUniformBlockDecl( shaderConfig, blockConfig )
	local bodyString = ''
	for i, entry in ipairs( blockConfig.uniforms ) do
		local line = string.format( '%s %s; ', entry.type, entry.name )
		bodyString = bodyString .. line
	end
	return string.format( 'layout( %s ) uniform %s { %s};', blockConfig.layout, blockConfig.name, bodyString )
end

function ShaderHelperGL3:getLanaguage()
	return 'glsl3'
end

function ShaderHelperGL3:onInit()
	local shaderScriptMeshShader = SHADER_SCRIPT [=[
    --------------------------------------------------------------------
    shader 'main' {
        uniform = {
            Param    = block {
            		mtxModelToClip        = global(MODEL_TO_CLIP_MTX);
								ucolor                = global(PEN_COLOR);
            };
            sampler = sampler( 1 );
        };

        program_vertex = 'vsh';
        program_fragment = 'fsh';
    }

    --------------------------------------------------------------------
    source 'vsh' [[
      in vec4 position;
			in vec2 uv;
			in vec4 color;
			
			@block Param;
			
			out LOWP vec4 colorVarying;
			out MEDP vec2 uvVarying;
			
			void main () {
				gl_Position = mtxModelToClip * position;
				uvVarying = uv;
				colorVarying = color * ucolor;
			}
    ]]

    --------------------------------------------------------------------
    source 'fsh' [[  
    	in vec4 colorVarying;
			in vec2 uvVarying;
			
			@sampler sampler;
			
			out vec4 FragColor;

			void main() {
				FragColor = texture ( sampler, uvVarying ) * colorVarying;
			}
    ]]

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
        	'position';
					'color';
        };

        program_vertex = 'vsh';
        program_fragment = 'fsh';
    }

    --------------------------------------------------------------------
    source 'vsh' [[
      in vec4 position;
			in vec4 color;
			
			@block Param;
			
			out LOWP vec4 colorVarying;
			
			void main () {
				gl_Position = mtxModelToClip * position;
				colorVarying = color * ucolor;
			}
    ]]

    --------------------------------------------------------------------
    source 'fsh' [[  
    	in vec4 colorVarying;
			out vec4 FragColor;

			void main() {
				FragColor = colorVarying;
			}
    ]]

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

