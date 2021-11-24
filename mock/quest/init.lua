module 'mock'


--------------------------------------------------------------------
--signals
--------------------------------------------------------------------
registerGlobalSignals{
	'quest.state_load',
	'quest.state_change'
}


--------------------------------------------------------------------
require 'mock.quest.QuestScheme'
require 'mock.quest.QuestState'
require 'mock.quest.QuestManager'
