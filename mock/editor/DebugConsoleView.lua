module 'mock'

local insert = table.insert

CLASS: DebugConsoleView ( mock.DebugUIModule )
:register( 'console' )

--------------------------------------------------------------------
function DebugConsoleView:__init()
	self.buffer = {}
	self.inputBuffer = {}
	self.mode = 'lua'
	self.currentInput = ''
end

function DebugConsoleView:getTitle()
	return 'Console'
end

function DebugConsoleView:onDebugGUI( gui, scn )
	local changed, newValue = gui.InputTextMultiline( '##source',  self.currentInput, 4096 )
end

