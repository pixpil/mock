module 'mock'


local MOAIShaderProgram = MOAIShaderProgram
local UFLOAT  = MOAIShaderProgram.UNIFORM_TYPE_FLOAT
local UINT    = MOAIShaderProgram.UNIFORM_TYPE_INT
local UVEC2   = MOAIShaderProgram.UNIFORM_WIDTH_VEC_2
local UVEC3   = MOAIShaderProgram.UNIFORM_WIDTH_VEC_3
local UVEC4   = MOAIShaderProgram.UNIFORM_WIDTH_VEC_4
local UMAT3x3 = MOAIShaderProgram.UNIFORM_WIDTH_MATRIX_3X3
local UMAT4x4 = MOAIShaderProgram.UNIFORM_WIDTH_MATRIX_4X4


--------------------------------------------------------------------
--------------------------------------------------------------------
local UniformTypeNameInfo = {
	[ 'vec4'  ] = { UFLOAT, UVEC4   };
	[ 'vec3'  ] = { UFLOAT, UVEC3   };
	[ 'vec2'  ] = { UFLOAT, UVEC2   };
	[ 'mat4'  ] = { UFLOAT, UMAT4x4 };
	[ 'mat3'  ] = { UFLOAT, UMAT3x3 };
	[ 'int'   ] = { UINT,   1       };
	[ 'float' ] = { UFLOAT, 1       };
}

local ShaderGlobalInfo = {

	--LEGACY SUPPORT
	['GLOBAL_VIEW_PROJ'            ] = { MOAIShaderProgram.GLOBAL_WORLD_TO_CLIP_MTX,           'mat4' }, 
	['GLOBAL_WORLD'                ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_WORLD_MTX,          'mat4' }, 
	['GLOBAL_WORLD_VIEW'           ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_VIEW_MTX,           'mat4' }, 
	['GLOBAL_WORLD_VIEW_PROJ_NORM' ] = { MOAIShaderProgram.GLOBAL_NORMAL_MODEL_TO_CLIP_MTX,    'mat4' }, 
	['GLOBAL_WORLD_VIEW_PROJ'      ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_CLIP_MTX,           'mat4' }, 
	['GLOBAL_WORLD_INV'            ] = { MOAIShaderProgram.GLOBAL_WORLD_TO_MODEL_MTX,          'mat4' }, 
	['GLOBAL_WORLD_VIEW_INV'       ] = { MOAIShaderProgram.GLOBAL_VIEW_TO_MODEL_MTX,           'mat4' }, 
	['GLOBAL_WORLD_VIEW_PROJ_INV'  ] = { MOAIShaderProgram.GLOBAL_CLIP_TO_MODEL_MTX,           'mat4' }, 
	['GLOBAL_PEN_COLOR'            ] = { MOAIShaderProgram.GLOBAL_PEN_COLOR,                   'vec4' },
	['GLOBAL_VIEW_HEIGHT'          ] = { MOAIShaderProgram.GLOBAL_VIEW_HEIGHT,                 'float' },
	['GLOBAL_VIEW_WIDTH'           ] = { MOAIShaderProgram.GLOBAL_VIEW_WIDTH,                  'float' },
	['GLOBAL_VIEW_HALF_HEIGHT'     ] = { MOAIShaderProgram.GLOBAL_VIEW_HALF_HEIGHT,            'float' },
	['GLOBAL_VIEW_HALF_WIDTH'      ] = { MOAIShaderProgram.GLOBAL_VIEW_HALF_WIDTH,             'float' },

	['VIEW_PROJ'                   ] = { MOAIShaderProgram.GLOBAL_WORLD_TO_CLIP_MTX,           'mat4' }, 
	['WORLD'                       ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_WORLD_MTX,          'mat4' }, 
	['WORLD_VIEW'                  ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_VIEW_MTX,           'mat4' }, 
	['WORLD_VIEW_PROJ_NORM'        ] = { MOAIShaderProgram.GLOBAL_NORMAL_MODEL_TO_CLIP_MTX,    'mat4' }, 
	['WORLD_VIEW_PROJ'             ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_CLIP_MTX,           'mat4' }, 
	['WORLD_INV'                   ] = { MOAIShaderProgram.GLOBAL_WORLD_TO_MODEL_MTX,          'mat4' }, 
	['WORLD_VIEW_INV'              ] = { MOAIShaderProgram.GLOBAL_VIEW_TO_MODEL_MTX,           'mat4' }, 
	['WORLD_VIEW_PROJ_INV'         ] = { MOAIShaderProgram.GLOBAL_CLIP_TO_MODEL_MTX,           'mat4' }, 

	--MOAI2.0
	['CLIP_TO_DISPLAY_MTX'         ] = { MOAIShaderProgram.GLOBAL_CLIP_TO_DISPLAY_MTX,         'mat4' },
	['CLIP_TO_MODEL_MTX'           ] = { MOAIShaderProgram.GLOBAL_CLIP_TO_MODEL_MTX,           'mat4' },
	['CLIP_TO_VIEW_MTX'            ] = { MOAIShaderProgram.GLOBAL_CLIP_TO_VIEW_MTX,            'mat4' },
	['CLIP_TO_WINDOW_MTX'          ] = { MOAIShaderProgram.GLOBAL_CLIP_TO_WINDOW_MTX,          'mat4' },
	['CLIP_TO_WORLD_MTX'           ] = { MOAIShaderProgram.GLOBAL_CLIP_TO_WORLD_MTX,           'mat4' },
	['DISPLAY_TO_CLIP_MTX'         ] = { MOAIShaderProgram.GLOBAL_DISPLAY_TO_CLIP_MTX,         'mat4' },
	['DISPLAY_TO_MODEL_MTX'        ] = { MOAIShaderProgram.GLOBAL_DISPLAY_TO_MODEL_MTX,        'mat4' },
	['DISPLAY_TO_VIEW_MTX'         ] = { MOAIShaderProgram.GLOBAL_DISPLAY_TO_VIEW_MTX,         'mat4' },
	['DISPLAY_TO_WORLD_MTX'        ] = { MOAIShaderProgram.GLOBAL_DISPLAY_TO_WORLD_MTX,        'mat4' },
	['MODEL_TO_CLIP_MTX'           ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_CLIP_MTX,           'mat4' },
	['MODEL_TO_DISPLAY_MTX'        ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_DISPLAY_MTX,        'mat4' },
	['MODEL_TO_UV_MTX'             ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_UV_MTX,             'mat4' },
	['MODEL_TO_VIEW_MTX'           ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_VIEW_MTX,           'mat4' },
	['MODEL_TO_WORLD_MTX'          ] = { MOAIShaderProgram.GLOBAL_MODEL_TO_WORLD_MTX,          'mat4' },
	['NORMAL_CLIP_TO_DISPLAY_MTX'  ] = { MOAIShaderProgram.GLOBAL_NORMAL_CLIP_TO_DISPLAY_MTX,  'mat4' },
	['NORMAL_CLIP_TO_MODEL_MTX'    ] = { MOAIShaderProgram.GLOBAL_NORMAL_CLIP_TO_MODEL_MTX,    'mat4' },
	['NORMAL_CLIP_TO_VIEW_MTX'     ] = { MOAIShaderProgram.GLOBAL_NORMAL_CLIP_TO_VIEW_MTX,     'mat4' },
	['NORMAL_CLIP_TO_WINDOW_MTX'   ] = { MOAIShaderProgram.GLOBAL_NORMAL_CLIP_TO_WINDOW_MTX,   'mat4' },
	['NORMAL_CLIP_TO_WORLD_MTX'    ] = { MOAIShaderProgram.GLOBAL_NORMAL_CLIP_TO_WORLD_MTX,    'mat4' },
	['NORMAL_DISPLAY_TO_CLIP_MTX'  ] = { MOAIShaderProgram.GLOBAL_NORMAL_DISPLAY_TO_CLIP_MTX,  'mat4' },
	['NORMAL_DISPLAY_TO_MODEL_MTX' ] = { MOAIShaderProgram.GLOBAL_NORMAL_DISPLAY_TO_MODEL_MTX, 'mat4' },
	['NORMAL_DISPLAY_TO_VIEW_MTX'  ] = { MOAIShaderProgram.GLOBAL_NORMAL_DISPLAY_TO_VIEW_MTX,  'mat4' },
	['NORMAL_DISPLAY_TO_WORLD_MTX' ] = { MOAIShaderProgram.GLOBAL_NORMAL_DISPLAY_TO_WORLD_MTX, 'mat4' },
	['NORMAL_MODEL_TO_CLIP_MTX'    ] = { MOAIShaderProgram.GLOBAL_NORMAL_MODEL_TO_CLIP_MTX,    'mat4' },
	['NORMAL_MODEL_TO_DISPLAY_MTX' ] = { MOAIShaderProgram.GLOBAL_NORMAL_MODEL_TO_DISPLAY_MTX, 'mat4' },
	['NORMAL_MODEL_TO_UV_MTX'      ] = { MOAIShaderProgram.GLOBAL_NORMAL_MODEL_TO_UV_MTX,      'mat4' },
	['NORMAL_MODEL_TO_VIEW_MTX'    ] = { MOAIShaderProgram.GLOBAL_NORMAL_MODEL_TO_VIEW_MTX,    'mat4' },
	['NORMAL_MODEL_TO_WORLD_MTX'   ] = { MOAIShaderProgram.GLOBAL_NORMAL_MODEL_TO_WORLD_MTX,   'mat4' },
	['NORMAL_WORLD_TO_DISPLAY_MTX' ] = { MOAIShaderProgram.GLOBAL_NORMAL_WORLD_TO_DISPLAY_MTX, 'mat4' },
	['NORMAL_WORLD_TO_VIEW_MTX'    ] = { MOAIShaderProgram.GLOBAL_NORMAL_WORLD_TO_VIEW_MTX,    'mat4' },
	['NORMAL_UV_TO_MODEL_MTX'      ] = { MOAIShaderProgram.GLOBAL_NORMAL_UV_TO_MODEL_MTX,      'mat4' },
	['NORMAL_VIEW_TO_CLIP_MTX'     ] = { MOAIShaderProgram.GLOBAL_NORMAL_VIEW_TO_CLIP_MTX,     'mat4' },
	['NORMAL_VIEW_TO_DISPLAY_MTX'  ] = { MOAIShaderProgram.GLOBAL_NORMAL_VIEW_TO_DISPLAY_MTX,  'mat4' },
	['NORMAL_VIEW_TO_MODEL_MTX'    ] = { MOAIShaderProgram.GLOBAL_NORMAL_VIEW_TO_MODEL_MTX,    'mat4' },
	['NORMAL_VIEW_TO_WORLD_MTX'    ] = { MOAIShaderProgram.GLOBAL_NORMAL_VIEW_TO_WORLD_MTX,    'mat4' },
	['NORMAL_WINDOW_TO_CLIP_MTX'   ] = { MOAIShaderProgram.GLOBAL_NORMAL_WINDOW_TO_CLIP_MTX,   'mat4' },
	['NORMAL_WORLD_TO_CLIP_MTX'    ] = { MOAIShaderProgram.GLOBAL_NORMAL_WORLD_TO_CLIP_MTX,    'mat4' },
	['NORMAL_WORLD_TO_MODEL_MTX'   ] = { MOAIShaderProgram.GLOBAL_NORMAL_WORLD_TO_MODEL_MTX,   'mat4' },
	['PEN_COLOR'                   ] = { MOAIShaderProgram.GLOBAL_PEN_COLOR,                   'vec4' },
	['UV_TO_MODEL_MTX'             ] = { MOAIShaderProgram.GLOBAL_UV_TO_MODEL_MTX,             'mat4' },
	['VIEW_TO_CLIP_MTX'            ] = { MOAIShaderProgram.GLOBAL_VIEW_TO_CLIP_MTX,            'mat4' },
	['VIEW_TO_DISPLAY_MTX'         ] = { MOAIShaderProgram.GLOBAL_VIEW_TO_DISPLAY_MTX,         'mat4' },
	['VIEW_TO_MODEL_MTX'           ] = { MOAIShaderProgram.GLOBAL_VIEW_TO_MODEL_MTX,           'mat4' },
	['VIEW_TO_WORLD_MTX'           ] = { MOAIShaderProgram.GLOBAL_VIEW_TO_WORLD_MTX,           'mat4' },
	['WINDOW_TO_CLIP_MTX'          ] = { MOAIShaderProgram.GLOBAL_WINDOW_TO_CLIP_MTX,          'mat4' },
	['WORLD_TO_CLIP_MTX'           ] = { MOAIShaderProgram.GLOBAL_WORLD_TO_CLIP_MTX,           'mat4' },
	['WORLD_TO_DISPLAY_MTX'        ] = { MOAIShaderProgram.GLOBAL_WORLD_TO_DISPLAY_MTX,        'mat4' },
	['WORLD_TO_MODEL_MTX'          ] = { MOAIShaderProgram.GLOBAL_WORLD_TO_MODEL_MTX,          'mat4' },
	['WORLD_TO_VIEW_MTX'           ] = { MOAIShaderProgram.GLOBAL_WORLD_TO_VIEW_MTX,           'mat4' },
	['VIEW_HEIGHT'                 ] = { MOAIShaderProgram.GLOBAL_VIEW_HEIGHT,                 'float' },
	['VIEW_WIDTH'                  ] = { MOAIShaderProgram.GLOBAL_VIEW_WIDTH,                  'float' },
	['VIEW_HALF_HEIGHT'            ] = { MOAIShaderProgram.GLOBAL_VIEW_HALF_HEIGHT,            'float' },
	['VIEW_HALF_WIDTH'             ] = { MOAIShaderProgram.GLOBAL_VIEW_HALF_WIDTH,             'float' },
}

function getShaderGlobalId( globalName )
	local info = ShaderGlobalInfo[ globalName ]
	if not info then
		_error( 'undefined shader global', globalName )
		return false
	end
	return unpack( info )
end

function getShaderGlobalInfoTable()
	return ShaderGlobalInfo
end

--------------------------------------------------------------------
--------------------------------------------------------------------
local DefaultShaderSource = {}

DefaultShaderSource.__DEFAULT_VSH = [[
	in vec4 position;
	in vec2 uv;
	in vec4 color;

	out MEDP vec2 uvVarying;
	void main () {
		gl_Position = position;
		uvVarying = uv;
	}
]]

DefaultShaderSource.__DEFAULT_FSH = [[
	in MEDP vec2 uvVarying;
	uniform sampler2D sampler;
	out vec4 FragColor;
	void main () {
		FragColor = texture ( sampler, uvVarying );
	}
]]


function getDefaultShaderSource( name )
	return DefaultShaderSource[ name ]
end

function createUniformFormat( body )
	local format = MOAIShaderUniformFormat.new()
	format:reserveUniforms( #body )
	for i, entry in ipairs( body ) do
		local t = entry.type or 'float'
		local count = entry.count or 1
		if t == 'float' then
			format:declareUniform( i, entry.name, UFLOAT, 1, count )
		elseif t == 'int' then
			format:declareUniform( i, entry.name, UINT, 1, count )
		elseif t == 'vec2' then
			format:declareUniform( i, entry.name, UFLOAT, UVEC2, count )
		elseif t == 'vec3' then
			format:declareUniform( i, entry.name, UFLOAT, UVEC3, count )
		elseif t == 'vec4' then
			format:declareUniform( i, entry.name, UFLOAT, UVEC4, count )
		elseif t == 'mat4' then
			format:declareUniform( i, entry.name, UFLOAT, UMAT4x4, count )
		elseif t == 'mat3' then
			format:declareUniform( i, entry.name, UFLOAT, UMAT3x3, count )
		else
			error()
		end
	end
	return format
end
