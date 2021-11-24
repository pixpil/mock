module 'mock'

--------------------------------------------------------------------
registerGlobalSignals{
	'sq.system.resume',
	'sq.system.pause',
	'sq.start',
	'sq.stop',
	'sq.detach',
	'sq.debug.seek',
}

--------------------------------------------------------------------
require 'mock.sqscript.SQScript'

--core node types
require 'mock.sqscript.SQNodeCoroutine'
require 'mock.sqscript.SQNodeMsgCallback'
require 'mock.sqscript.SQNodeLog'
require 'mock.sqscript.SQNodeLoop'
require 'mock.sqscript.SQNodeQueue'

require 'mock.sqscript.SQNodeWait'

require 'mock.sqscript.SQNodeSignal'
require 'mock.sqscript.SQNodeMsg'

require 'mock.sqscript.SQNodeEval'
require 'mock.sqscript.SQNodeAssert'
require 'mock.sqscript.SQNodeSwitch'
require 'mock.sqscript.SQNodeIf'
require 'mock.sqscript.SQNodeCheck'
-- require 'mock.sqscript.SQNodeCondition'
require 'mock.sqscript.SQNodeRandom'

--------------------------------------------------------------------
--component
require 'mock.sqscript.SQActor'

--------------------------------------------------------------------
require 'mock.sqscript.SQCommonSupport'

--------------------------------------------------------------------
--builtin node types
require 'mock.sqscript.SQNodeAnimator'
require 'mock.sqscript.SQNodeScript'
require 'mock.sqscript.SQNodeEntity'
require 'mock.sqscript.SQNodeScene'

--------------------------------------------------------------------
require 'mock.sqscript.SQQuestSupport'
require 'mock.sqscript.SQNodeQuest'

--------------------------------------------------------------------
--debug support
require 'mock.sqscript.SQDebugHelper'

--------------------------------------------------------------------
require 'mock.sqscript.SQGlobalManager'


require 'mock.sqscript.SQScriptTool'
