module 'mock'

local MOAITimer        = MOAITimer
local MOAIEaseType     = MOAIEaseType

--------------------------------------------------------------------
EnumTimerMode = {
	{ 'normal'            , MOAITimer.NORMAL           } ,
	{ 'reverse'           , MOAITimer.REVERSE          } ,
	{ 'continue'          , MOAITimer.CONTINUE         } ,
	{ 'continue_reverse'  , MOAITimer.CONTINUE_REVERSE } ,
	{ 'loop'              , MOAITimer.LOOP             } ,
	{ 'loop_reverse'      , MOAITimer.LOOP_REVERSE     } ,
	{ 'ping_pong'         , MOAITimer.PING_PONG        } ,
}

EnumTimerModeWithDefault = {
	{ 'default'           , false                      } ,
	{ 'normal'            , MOAITimer.NORMAL           } ,
	{ 'reverse'           , MOAITimer.REVERSE          } ,
	{ 'continue'          , MOAITimer.CONTINUE         } ,
	{ 'continue_reverse'  , MOAITimer.CONTINUE_REVERSE } ,
	{ 'loop'              , MOAITimer.LOOP             } ,
	{ 'loop_reverse'      , MOAITimer.LOOP_REVERSE     } ,
	{ 'ping_pong'         , MOAITimer.PING_PONG        } ,
}


--------------------------------------------------------------------
EnumEaseType={
	{	'ease_in'		     , MOAIEaseType.EASE_IN        },
	{	'ease_out'	     , MOAIEaseType.EASE_OUT       },
	{	'flat'		       , MOAIEaseType.FLAT           },
	{	'linear'		     , MOAIEaseType.LINEAR         },
	{	'sharp_ease_in'  , MOAIEaseType.SHARP_EASE_IN  },
	{	'sharp_ease_out' , MOAIEaseType.SHARP_EASE_OUT },
	{	'sharp_smooth'   , MOAIEaseType.SHARP_SMOOTH   },
	{	'smooth'		     , MOAIEaseType.SMOOTH         },
	{	'soft_ease_in'   , MOAIEaseType.SOFT_EASE_IN   },
	{	'soft_ease_out'  , MOAIEaseType.SOFT_EASE_OUT  },
	{	'soft_smooth'	   , MOAIEaseType.SOFT_SMOOTH    },
	{	'back_in'        , MOAIEaseType.BACK_IN        },
	{	'back_out'       , MOAIEaseType.BACK_OUT       },
	{	'back_smooth'	   , MOAIEaseType.BACK_SMOOT     },
	{	'elastic_in'     , MOAIEaseType.ELASTIC_IN     },
	{	'elastic_out'    , MOAIEaseType.ELASTIC_OUT    },
	{	'elastic_smooth' , MOAIEaseType.ELASTIC_SMOOTH },
}

--------------------------------------------------------------------
EnumCameraViewportMode = _ENUM_V{
	'expanding', --expand to full screen
	'fixed',     --fixed size, in device unit
	'relative',  --relative size, in ratio
}

--------------------------------------------------------------------
EnumTextAlignment = _ENUM_V{
	'left',
	'center',
	'right',
}

--------------------------------------------------------------------
EnumTextAlignmentV = _ENUM_V{
	'top',
	'center',
	'bottom',
	'baseline',
}

--------------------------------------------------------------------
EnumAlignmentH = _ENUM_V{
	'left',
	'center',
	'right',
}

--------------------------------------------------------------------
EnumAlignmentV = _ENUM_V{
	'top',
	'center',
	'bottom'
}

--------------------------------------------------------------------
EnumOrigin = _ENUM_V{
	'top_left',
	'top_center',
	'top_right',
	'middle_left',
	'middle_center',
	'middle_right',
	'bottom_left',
	'bottom_center',
	'bottom_right',
}
--------------------------------------------------------------------
EnumPhysicsBodyType = _ENUM_V{
	'dynamic',
	'static',
	'kinematic'
}


--------------------------------------------------------------------
EnumLocales = _ENUM_V{
	'zh-CN',
	'zh-TW',
	'kr',
	'ja',
	'en',
	'fr',
	'it',
	'es',
	'de'
}

EnumLocalesWithAll = EnumLocales:__EXTEND_V {
	'all'
}
