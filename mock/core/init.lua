module 'mock'

--------------Replace
require 'mock.core.MOAISystemReplaces'

--------------Utility modules
require 'mock.core.utils'
require 'mock.core.signal'
require 'mock.core.Class'
require 'mock.core.platform'


require 'mock.core.ClassHelpers'
require 'mock.core.ObjectPooling'


require 'mock.core.Serializer'
require 'mock.core.BinarySerializer'

require 'mock.core.ScriptHelper'

require 'mock.core.JSONHelper'
require 'mock.core.MsgPackHelper'
require 'mock.core.LuaBinsHelper'
require 'mock.core.HashHelper'

require 'mock.core.MOAIHelpers'
require 'mock.core.MOAIActionHelpers'
require 'mock.core.MOAIPropHelpers'
require 'mock.core.MOAINodeHelper'
require 'mock.core.MOAIDrawHelpers'

require 'mock.core.MOAIHack'

require 'mock.core.MOAIObjectPool'

require 'mock.core.GlobalSignals'


require 'mock.core.DebugHelper'
require 'mock.core.LogHelper'

--------------------------------------------------------------------
----Common

require 'mock.core.EnumSystem'
require 'mock.core.EnumCommon'
require 'mock.core.EnumGfx'

----------------Core Modules
require 'mock.core.env'
require 'mock.core.defaults'
require 'mock.core.Actor'


----common class
require 'mock.core.GlobalManager'

----task
require 'mock.core.task'


require 'mock.core.Palette'
require 'mock.core.LocaleManager'

----asset
require 'mock.core.AssetLibrary'
require 'mock.core.AssetScanner'
require 'mock.core.ResourceHolder'

----basic
require 'mock.core.Viewport'
require 'mock.core.RenderTarget'
require 'mock.core.TextureRenderTarget'
require 'mock.core.MRTRenderTarget'

----input
require 'mock.core.InputManager'
-- require 'mock.core.JoystickManager'
-- require 'mock.core.InputDevice'
-- require 'mock.core.InputSignal'

----debug
if not mock.__nodebug then
	require 'mock.core.ImGuiLayer'
	require 'mock.core.DebugUI'
end

require 'mock.core.TopOverlay'
require 'mock.core.DebugDrawQueue'


----audio
require 'mock.core.AudioManager'


----game
require 'mock.core.EntityTag'
require 'mock.core.EntityIcon'
require 'mock.core.EntityGroup'
require 'mock.core.Entity'
require 'mock.core.Component'
require 'mock.core.EntityPool'
require 'mock.core.Layer'
require 'mock.core.SceneManager'
require 'mock.core.Scene'
require 'mock.core.GlobalObject'
require 'mock.core.ScreenProfile'
require 'mock.core.SceneSession'
require 'mock.core.RenderManager'
require 'mock.core.RenderContext'
require 'mock.core.GameRenderContext'
require 'mock.core.Game'

----Helpers
require 'mock.core.EntityHelper'
require 'mock.core.AnimCurve'

--------------------------------------------------------------------
require 'mock.core.SceneAssetWalker'
require 'mock.core.EditorSupport'

require 'mock.core.SocketCommand'
require 'mock.core.HTTPServer'
require 'mock.core.HTTPClient'
