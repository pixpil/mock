module 'mock'

local function buildBloomShader()
	local vsh = [[
		in vec4 position;
		in vec2 uv;
		in vec4 color;

		out LOWP vec4 colorVarying;
		out MEDP vec2 uvVarying;

		void main () {
			gl_Position = position;
			uvVarying = uv;
			colorVarying = color;
		}
	]]

	local fsh = [[	
		in LOWP vec4 colorVarying;
		in MEDP vec2 uvVarying;

		out vec4 FragColor;

		uniform sampler2D sampler;
		uniform float viewWidth;
		uniform float viewHeight;

		void main () {
			float du = 1.0/viewWidth  * 2.0;
			float dv = 1.0/viewHeight * 2.0;
			FragColor = texture ( sampler, uvVarying ) * 0.8;
			FragColor += texture ( sampler, uvVarying + vec2( 0.0,  dv ) ) * 0.06;
			FragColor += texture ( sampler, uvVarying + vec2( 0.0, -dv ) ) * 0.06;
			FragColor += texture ( sampler, uvVarying + vec2(  du, 0.0 ) ) * 0.06;
			FragColor += texture ( sampler, uvVarying + vec2( -du, 0.0 ) ) * 0.06;
			FragColor += texture ( sampler, uvVarying + vec2(  du,  dv ) ) * 0.03;
			FragColor += texture ( sampler, uvVarying + vec2(  du, -dv ) ) * 0.03;
			FragColor += texture ( sampler, uvVarying + vec2( -du,  dv ) ) * 0.03;
			FragColor += texture ( sampler, uvVarying + vec2( -du, -dv ) ) * 0.03;
		}
	]]

	local prog = buildShaderProgramFromString( vsh, fsh, {
		uniforms = {
			{
				name = "sampler",
				type = "sampler",
				value = 1
			},
			{
				name = "time",
				type = "float",
				value = 0
			},
			{
				name = "intensity",
				type = "float",
				value = 2
			}
		},
		globals = {
			{
				name = 'viewWidth',
				type = 'GLOBAL_VIEW_WIDTH',
			},
			{
				name = 'viewHeight',
				type = 'GLOBAL_VIEW_HEIGHT',
			}
		}
	} )
	return prog:buildShader():getMoaiShader()
end

--------------------------------------------------------------------
CLASS: CameraImageEffectBloom ( CameraImageEffect )
	:MODEL{}

function CameraImageEffectBloom:onBuild( prop, layer )
	prop:setShader( assert( buildBloomShader() ) )
end


mock.registerComponent( 'CameraImageEffectBloom', CameraImageEffectBloom )