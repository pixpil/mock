module 'mock'

registerGlobalSignals{
	'gii_sync.remote_msg'
}
--------------------------------------------------------------------
require 'mock.editor.DebugEditorUI'
--------------------------------------------------------------------
require 'mock.editor.GIISync'

--------------------------------------------------------------------
-- require 'mock.editor.LocalSceneOverlay'

require 'mock.editor.DebugObjectEditor'
require 'mock.editor.DebugSceneGraphView'
require 'mock.editor.DebugMemoryView'
require 'mock.editor.DebugConsoleView'

require 'mock.editor.DebugQuestView'
require 'mock.editor.DebugSQView'

require 'mock.editor.DebugAudioView'


--------------------------------------------------------------------
require 'mock.editor.CommentItem'
require 'mock.editor.CommentItemText'

--------------------------------------------------------------------
require 'mock.editor.reloaders'