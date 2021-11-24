module 'mock'

local MOAIGraphicsProp = MOAIGraphicsProp
local MOAITimer        = MOAITimer


local insert = table.insert
local function buildMOAIGraphicsEnum( luaToMoai )
	local enum = {}
	local enumToMoai = {}
	local enumFromMoai = {}
	for i, entry in ipairs( luaToMoai ) do
		enumName, moaiName = unpack( entry )
		insert( enum, { enumName, enumName } )
		local moaiEnumValue = MOAIGraphicsProp[ moaiName ]
		if moaiEnumValue then
			enumToMoai[ enumName ] = moaiEnumValue
			enumFromMoai[ moaiEnumValue ] = enumName
		else
			_error( 'undefined moai graphics enum', moaiName )
		end
	end
	return enum, enumToMoai, enumFromMoai
end

--------------------------------------------------------------------

EnumTextureSize = {
	{ '16',   16   },
	{ '32',   32   },
	{ '64',   64   },
	{ '128',  128  },
	{ '256',  256  },
	{ '512',  512  },
	{ '1024', 1024 },
	{ '2048', 2048 },
	{ '4096', 4096 },
	{ '8192', 8192 }
}

EnumTextureFormat = _ENUM_V{
	'auto',
	'png',
	'webp',
	'RGBA8888',
	'RGB888',
	'RGBA4444',
	'RGB565',
	'PVR-4',
	'PVR-2'
}

--------------------------------------------------------------------
EnumTextureFilter = {
	{ 'linear',    'linear'  },
	{ 'nearest',   'nearest' }
}

--------------------------------------------------------------------
EnumTextureAtlasMode = {
	{ 'none',      false },
	{ 'multiple',  'multiple' },
	{ 'single',    'single' }
}

--------------------------------------------------------------------
EnumBlendMode = {
	{ 'alpha',     'alpha'    },
	{ 'add',       'add'      },
	{ 'multiply',  'multiply' },
	{ 'normal',    'normal'   },
	{ 'solid',     'solid'    },
}

--------------------------------------------------------------------
EnumBlendFunc, EnumBlendFuncToMoai, EnumBlendFuncFromMoai = buildMOAIGraphicsEnum{
	{ 'add',              'GL_FUNC_ADD'               },
	{ 'subtract',         'GL_FUNC_SUBTRACT'          },
	{ 'reverse_subtract', 'GL_FUNC_REVERSE_SUBTRACT'  },
	{ 'min',              'GL_FUNC_MIN'               },
	{ 'max',              'GL_FUNC_MAX'	              },
}

--------------------------------------------------------------------
EnumBlendFactor, EnumBlendFactorToMoai, EnumBlendFactorFromMoai = buildMOAIGraphicsEnum{
 { 'one',	                 'GL_ONE'                 },
 { 'zero',	               'GL_ZERO'                },
 { 'dst_alpha',	           'GL_DST_ALPHA'           },
 { 'dst_color',	           'GL_DST_COLOR'           },
 { 'src_color',	           'GL_SRC_COLOR'           },
 { 'one_minus_dst_alpha',	 'GL_ONE_MINUS_DST_ALPHA' },
 { 'one_minus_dst_color',	 'GL_ONE_MINUS_DST_COLOR' },
 { 'one_minus_src_alpha',	 'GL_ONE_MINUS_SRC_ALPHA' },
 { 'one_minus_src_color',	 'GL_ONE_MINUS_SRC_COLOR' },
 { 'src_alpha',	           'GL_SRC_ALPHA'           },
 { 'src_alpha_saturate',	 'GL_SRC_ALPHA_SATURATE'  },
}

--------------------------------------------------------------------
EnumDepthTestMode, EnumDepthTestModeToMoai, EnumDepthTestModeFromMoai = buildMOAIGraphicsEnum{
	{ 'disable',       'DEPTH_TEST_DISABLE'       },
	{ 'never',         'DEPTH_TEST_NEVER'         },
	{ 'always',        'DEPTH_TEST_ALWAYS'        },
	{ 'less',          'DEPTH_TEST_LESS'          },
	{ 'less_equal',    'DEPTH_TEST_LESS_EQUAL'    },
	{ 'equal',         'DEPTH_TEST_EQUAL'         },
	{ 'not_equal',     'DEPTH_TEST_NOT_EQUAL'     },
	{ 'greater',       'DEPTH_TEST_GREATER'       },
	{ 'greater_equal', 'DEPTH_TEST_GREATER_EQUAL' },
}

--------------------------------------------------------------------
EnumStencilTestMode, EnumStencilTestModeToMoai, EnumStencilTestModeFromMoai = buildMOAIGraphicsEnum{
	{ 'disable',       'STENCIL_TEST_DISABLE'       },
	{ 'never',         'STENCIL_TEST_NEVER'         },
	{ 'always',        'STENCIL_TEST_ALWAYS'        },
	{ 'less',          'STENCIL_TEST_LESS'          },
	{ 'less_equal',    'STENCIL_TEST_LESS_EQUAL'    },
	{ 'equal',         'STENCIL_TEST_EQUAL'         },
	{ 'not_equal',     'STENCIL_TEST_NOT_EQUAL'     },
	{ 'greater',       'STENCIL_TEST_GREATER'       },
	{ 'greater_equal', 'STENCIL_TEST_GREATER_EQUAL' },
}

--------------------------------------------------------------------
EnumStencilOp, EnumStencilOpToMoai, EnumStencilOpFromMoai = buildMOAIGraphicsEnum{
	{ 'decr',       'STENCIL_OP_DECR'       },
	{ 'decr_wrap',  'STENCIL_OP_DECR_WRAP'  },
	{ 'incr',       'STENCIL_OP_INCR'       },
	{ 'incr_wrap',  'STENCIL_OP_INCR_WRAP'  },
	{ 'invert',     'STENCIL_OP_INVERT'     },
	{ 'keep',       'STENCIL_OP_KEEP'       },
	{ 'replace',    'STENCIL_OP_REPLACE'    },
	{ 'zero',       'STENCIL_OP_ZERO'       },
}

--------------------------------------------------------------------
EnumCullingMode, EnumCullingModeToMoai, EnumCullingModeFromMoai = buildMOAIGraphicsEnum{
	{ 'none',   'CULL_NONE'   },
	{ 'all',    'CULL_ALL'    },
	{ 'back',   'CULL_BACK'   },
	{ 'front',  'CULL_FRONT'  },
}

--------------------------------------------------------------------
--------------------------------------------------------------------
EnumBillboard = {
	{ 'none',    MOAIGraphicsProp. BILLBOARD_NONE    },
	{ 'normal',  MOAIGraphicsProp. BILLBOARD_NORMAL  },
	{ 'ortho',   MOAIGraphicsProp. BILLBOARD_ORTHO   },
	{ 'compass', MOAIGraphicsProp. BILLBOARD_COMPASS },
}

--------------------------------------------------------------------
EnumLayerSortMode = {
	{ "none"                , false },
	{ "iso"                 , 'iso'                  },
	{ "priority_ascending"  , 'priority_ascending'   },
	{ "priority_descending" , 'priority_descending'  },
	{ "x_ascending"         , 'x_ascending'          },
	{ "x_descending"        , 'x_descending'         },
	{ "y_ascending"         , 'y_ascending'          },
	{ "y_descending"        , 'y_descending'         },
	{ "z_ascending"         , 'z_ascending'          },
	{ "z_descending"        , 'z_descending'         },
	{ "vector_ascending"    , 'vector_ascending'     },
	{ "vector_descending"   , 'vector_descending'    },
}


--------------------------------------------------------------------
-- EnumTextWordBreak = _ENUM_V{
-- 	'break-char',
-- 	'break-none'
-- 	WORD_BREAK_CHAR
-- }

--------------------------------------------------------------------
EnumParticleForceType = {
	{ 'force',   MOAIParticleForce. FORCE   },
	{ 'gravity', MOAIParticleForce. GRAVITY },
	{ 'offset',  MOAIParticleForce. OFFSET  },
}
