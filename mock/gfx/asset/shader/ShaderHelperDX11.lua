module 'mock'

CLASS: ShaderHelperDX11 ( ShaderHelper )
:register ( 'DX11')

function ShaderHelperDX11:isAvailable()
	local gfxName, verMaj, verMin = getRenderManager():getGraphicsAPIName()
	return gfxName == 'Direct3D'
end

function ShaderHelperDX11:getLanaguage()
	return 'hlsl'
end

function ShaderHelperDX11:getUBOBindingBase()
	return 1
end

-- function ShaderHelperDX11:makeShaderUniformBlockDecl( shaderConfig, blockConfig )
-- 	local bodyString = ''
-- 	for i, entry in ipairs( blockConfig.uniforms ) do
-- 		local line = string.format( '%s %s; ', entry.type, entry.name )
-- 		bodyString = bodyString .. line
-- 	end
-- 	return string.format( 'layout( %s ) uniform %s { %s};', blockConfig.layout, blockConfig.name, bodyString )
-- end

function ShaderHelperDX11:onInit()
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
								ucolor                = global(PEN_COLOR);
            		mtxModelToClip        = global(MODEL_TO_CLIP_MTX);
            };
            sampler = sampler( 1 );
        };

        program_vertex = 'vsh';
        program_fragment = 'fsh';
    }

    --------------------------------------------------------------------
    source 'vsh' [[
      cbuffer Param : register(b1)
			{
			    float4 _19_ucolor : packoffset(c0);
			    row_major float4x4 _19_mtxModelToClip : packoffset(c1);
			};


			static float4 gl_Position;
			static float4 position;
			static float2 uvVarying;
			static float2 uv;
			static float4 colorVarying;
			static float4 color;

			struct VSInput
			{
			    float4 position : POSITION;
			    float2 uv : TEXCOORD0;
			    float4 color : COLOR0;
			};

			struct PSInput
			{
			    float4 colorVarying : TEXCOORD0;
			    float2 uvVarying : TEXCOORD1;
			    float4 gl_Position : SV_Position;
			};

			void vert_main()
			{
			    gl_Position = mul(position, _19_mtxModelToClip);
			    uvVarying = uv;
			    colorVarying = color * _19_ucolor;
			}

			PSInput main(VSInput stage_input)
			{
			    position = stage_input.position;
			    uv = stage_input.uv;
			    color = stage_input.color;
			    vert_main();
			    PSInput stage_output;
			    stage_output.gl_Position = gl_Position;
			    stage_output.uvVarying = uvVarying;
			    stage_output.colorVarying = colorVarying;
			    return stage_output;
			}

    ]]

    --------------------------------------------------------------------
    source 'fsh' [[  
			Texture2D<float4> _sampler_ : register(t0);
			SamplerState __sampler__sampler : register(s0);

			static float2 uvVarying;
			static float4 colorVarying;
			static float4 FragColor;

			struct PSInput
			{
			    float4 colorVarying : TEXCOORD0;
			    float2 uvVarying : TEXCOORD1;
			};

			struct PSOutput
			{
			    float4 FragColor : SV_Target0;
			};

			void frag_main()
			{
			    float4 c = _sampler_.Sample(__sampler__sampler, uvVarying);
			    FragColor = c * colorVarying;
			}

			PSOutput main(PSInput stage_input)
			{
			    uvVarying = stage_input.uvVarying;
			    colorVarying = stage_input.colorVarying;
			    frag_main();
			    PSOutput stage_output;
			    stage_output.FragColor = FragColor;
			    return stage_output;
			}


    ]]

	]=]


	local shaderScriptLine3DShader = SHADER_SCRIPT [=[
    --------------------------------------------------------------------
    shader 'main' {
    	attribute = {
					'position:vec3',
					'color',
				};
				
        uniform = {
            Param    = block {
								ucolor                = global(PEN_COLOR);
            		mtxModelToClip        = global(MODEL_TO_CLIP_MTX);
            };
            sampler = sampler( 1 );
        };

        program_vertex = 'vsh';
        program_fragment = 'fsh';
    }

    --------------------------------------------------------------------
    source 'vsh' [[
      cbuffer Param : register(b1)
			{
			    float4 _19_ucolor : packoffset(c0);
			    row_major float4x4 _19_mtxModelToClip : packoffset(c1);
			};


			static float4 gl_Position;
			static float4 position;
			static float4 colorVarying;
			static float4 color;

			struct VSInput
			{
			    float4 position : POSITION;
			    float4 color : COLOR0;
			};

			struct PSInput
			{
			    float4 colorVarying : TEXCOORD0;
			    float4 gl_Position : SV_Position;
			};

			void vert_main()
			{
			    gl_Position = mul(position, _19_mtxModelToClip);
			    colorVarying = color * _19_ucolor;
			}

			PSInput main(VSInput stage_input)
			{
			    position = stage_input.position;
			    color = stage_input.color;
			    vert_main();
			    PSInput stage_output;
			    stage_output.gl_Position = gl_Position;
			    stage_output.colorVarying = colorVarying;
			    return stage_output;
			}

    ]]

    --------------------------------------------------------------------
    source 'fsh' [[  
			Texture2D<float4> _sampler_ : register(t0);
			SamplerState __sampler__sampler : register(s0);

			struct PSInput
			{
			    float4 colorVarying : TEXCOORD0;
			};

			struct PSOutput
			{
			    float4 FragColor : SV_Target0;
			};


			PSOutput main(PSInput stage_input)
			{
			    PSOutput stage_output;
			    stage_output.FragColor = stage_input.colorVarying;
			    return stage_output;
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