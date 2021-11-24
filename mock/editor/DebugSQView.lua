module 'mock'

CLASS: DebugSQView ( DebugUIModule )
:register( 'sq_script' )

--------------------------------------------------------------------
function DebugSQView:__init()
	--checkpoints
	self.checkpointFilter = ''

	--recording
	self.focusNext = false
	self.loopStartStep = false
	self.loopEndStep = false
	self.selectedStep = false

	
end

function DebugSQView:getTitle()
	return 'SQScript'
end


function DebugSQView:onDebugGUI( gui, scn )
	if isSQFastForwarding() then
		if gui.Button( ' Stop FF' ) then
			mock.toggleSQFastForward( 'default' )
		end
	else
		if gui.Button( 'Start FF' ) then
			mock.toggleSQFastForward( 'default' )
		end
	end
	if gui.CollapsingHeader( 'CheckPoint', MOAIImGui.TreeNodeFlags_DefaultOpen ) then
		self:subCheckpoint( gui, scn )
	end

	if gui.CollapsingHeader( 'Recording', MOAIImGui.TreeNodeFlags_DefaultOpen ) then
		self:subRecording( gui, scn )
	end
end

function DebugSQView:subCheckpoint( gui, scn )
	local debug = getSQDebugHelper()
	
	local checkpoints = debug:getCheckpoints()
	local checkpointsCount = debug:getCheckpointCount()
	if debug:hasPrevCheckpoint() then
		if gui.Button( 'Run Prev Checkpoint') then
			debug:startPrevCheckpoint()
		end
	end
	
	local changed, checkpointFilter = gui.InputText( 'filter',  self.checkpointFilter, 4096 )
	if changed then
		self.checkpointFilter = checkpointFilter
	end
	gui.Separator()
	checkpointFilter = checkpointFilter:lower()
	
	local function entryButton( gui, entry, name, node )
		gui.PushID( name )
			if gui.Button( '>>' ) then
				startSQFastForward( 'default' )
				self:startCheckpoint( entry )
			end
			gui.SameLine()
			if gui.Button( name ) then
				self:startCheckpoint( entry )
			end
		gui.PopID()
	end

	if checkpointsCount > 0 then
		local height = math.min( checkpointsCount * 20, 200 )
		gui.BeginChild( 'Checkpoints', 0, height )
			gui.PushStyleColor( MOAIImGui.Col_Button, hexcolor('#243139') )
			gui.PushStyleColor( MOAIImGui.Col_ButtonHovered, hexcolor('#2E3B48') )
			gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#6FCCAE') )
			local filtering = checkpointFilter ~= ''
			local found = false
			if filtering then
				gui.PushStyleColor( MOAIImGui.Col_ChildWindowBg, hexcolor('#450000') )
				
				for i, entry in ipairs( checkpoints ) do
					local name, node = unpack( entry )
					if name:lower():find( checkpointFilter ) then
						entryButton( gui, entry, name, node )
						found = true
					end
				end
				gui.PopStyleColor( 1 )
				if not found then
					gui.Text( 'NO Checkpoint found...' )
				end
			else
				for i, entry in ipairs( checkpoints ) do
					local name, node = unpack( entry )
					entryButton( gui, entry, name, node )
				end
			end
			gui.PopStyleColor( 3 )
		gui.EndChild()
	else
		gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#595959') )
			gui.Text( 'no checkpoint')
		gui.PopStyleColor()
	end
	gui.Separator()
end


function DebugSQView:startCheckpointByName( name )
	getSQDebugHelper():startCheckpointByName( name )
	self.selectedStep = false
end

function DebugSQView:startCheckpoint( entry, checkGroup )
	getSQDebugHelper():startCheckpoint( entry, checkGroup )
	self.selectedStep = false
end

local rotateBars = { '\\' , '-' , '/', '|', '-' }
local i = 0
local function rotateBar()
	i = ( i + 0.2 ) % 5
	return rotateBars[ math.floor(i) + 1 ]
end
--------------------------------------------------------------------
function DebugSQView:subRecording( gui, scn )
	local debug = getSQGlobalManager():getDebugHelper()
	--show recorded
	gui.NewLine()
	gui.BeginGroup()
		gui.SameLine()
		if isSQSystemPaused() then
			if gui.Button( 'RESUME GAME SQ' ) then
				pauseSQSystem( false )
			end
		else
			if gui.Button( 'PAUSE GAME SQ' ) then
				pauseSQSystem()
			end
		end

		gui.SameLine()
		if gui.Button( 'Clear Record' ) then
			debug:getSession():clear()
			self.selectedStep = false
		end

	gui.EndGroup()
	gui.Separator()

	if self.selectedStep then
		if gui.Button( 'Locate' ) then
			self:locateSQ()
		end
	end
	gui.SameLine()
	if debug:getSession().paused then
		if gui.Button( 'Step' ) then
			self:stepInSQ()
		end
	else
		gui.TextDisabled( 'Step' )
	end

	gui.SameLine()
	if debug:getSession().paused then
		if gui.Button( ' Play > ' ) then
			self:playbackSQ()
		end
	else
		if gui.Button( 'Stop Play' ) then
			self:pausePlaybackSQ()
		end
	end

	gui.Separator()

	local w = gui.GetWindowWidth()
	local contextWidth = w - math.clamp( w - 120, 0, 150 )
	gui.BeginChild( 'steps' )
		gui.PushStyleColor( MOAIImGui.Col_Header, hexcolor('#0C137D') )
		gui.PushStyleColor( MOAIImGui.Col_HeaderHovered, hexcolor('#293290') )
		gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#646464') )
		local session = debug:getSession()
		local currentEnterStep = session.currentEnterStep
		local selectedStep = self.selectedStep

		for i, step in ipairs( session.steps ) do
			local stepId, ev, node, state, env = unpack( step )
			if ev == 'enter' then
				local actor = state:getActor()
				local replayable = node:isReplayable()
				gui.PushID( tostring( stepId ) )
				local isCurrent = step == currentEnterStep
				
				if replayable then
					if isCurrent then
						if session.paused then
							gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#FF3534') )
							gui.Text( '>' )
							if self.focusNext then
								self.focusNext = false
								gui.SetScrollHere()
							end
						else
							self.selectedStep = step
							gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#2DE90D') )
							gui.Text( rotateBar() )
							gui.SetScrollHere()
						end
						gui.SameLine()
					else
						gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#E4E4E4') )
					end
				else
					if node:isInstance( SQNodeLabel ) then
						gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#9252AA') )
					elseif node:isInstance( SQNodeCheckpoint ) then
						gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#57FFBA') )
					else
						gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#808080') )
					end
					if isCurrent then
						gui.Text( '>' )
						gui.SameLine()
						if self.focusNext then
							self.focusNext = false
							self.selectedStep = step
							gui.SetScrollHere()
						end
					end
				end

				local selected = selectedStep == step
				local nodeId, nodeArg = node:getDebugRepr()
				if gui.Selectable( nodeId, selected, MOAIImGui.SelectableFlags_AllowDoubleClick + MOAIImGui.SelectableFlags_SpanAllColumns) then
					self.selectedStep = step
					if gui.IsMouseDoubleClicked( 0 ) then
						self:locateSQ()
					else
						if isCtrlDown() then
							self:seekSQ()
						else
							self:seekSQ()
							self:stepInSQ()
						end
					end
				end

				gui.PopStyleColor( 1 )

				if nodeArg then
					gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#867059') )
					gui.SameLine()
					gui.Text( nodeArg )
					gui.PopStyleColor( 1 )
				end
				
				gui.SameLine( contextWidth )
				gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#5C5B92') )
					gui.Text( node:getContextString() or '' )
				gui.PopStyleColor( 1 )

				gui.PopID()
			end
		end
		gui.PopStyleColor( 3 )
	gui.EndChild()
	
end

function DebugSQView:locateSQ()
	local step = self.selectedStep
	if not step then return end
	local id, ev, node, state, env, ts = unpack( step )
	local sourcePath = node:getSourcePath()
	local asset = mock.getAssetNode( sourcePath )
	local filePath = asset:getAbsFilePath()
	local lineNumber = node.lineNumber
	GIISync.openFileInSublime( filePath, lineNumber )
end


function DebugSQView:pausePlaybackSQ()
	local debug = getSQDebugHelper()
	debug:getSession():pause()
end

function DebugSQView:playbackSQ()
	local debug = getSQDebugHelper()
	debug:getSession().pauseOnNewFrame = false
	debug:getSession():pause( false )
end


function DebugSQView:stepInSQ()
	local debug = getSQDebugHelper()
	debug:getSession().pauseOnNewFrame = true
	debug:getSession():pause( false )
	self.focusNext = true
end

function DebugSQView:seekSQ()
	local step = self.selectedStep
	if not step then return end
	local debug = getSQDebugHelper()

	debug:getSession():pause()
	debug:getSession():seek( step )
end

function DebugSQView:onKeyEvent( key, down )
	if key == 'return' and down then
		local debug = getSQDebugHelper()
		if isShiftDown() then
			if debug:getSession().paused then
				self:playbackSQ()
				emitGlobalSignal( 'sq.debug.seek' )
			else
				self:pausePlaybackSQ()
			end
		elseif isCtrlDown() then
			self.selectedStep = debug:getSession().currentEnterStep
			self:locateSQ()
		else
			if debug:getSession().paused then
				self:seekSQ()
				self:stepInSQ()
				emitGlobalSignal( 'sq.debug.seek' )
			else
				self:pausePlaybackSQ()
			end
		end

	elseif key == 'up'   and down and isCtrlDown() then
		self:selectPrevStep()

	elseif key == 'down' and down and isCtrlDown() then
		self:selectNextStep()

	end
end

function DebugSQView:getSelectedStepIndex()
	if not self.selectedStep then return false end
	local session = getSQDebugHelper():getSession()
	local steps = session.steps
	return table.index( steps, self.selectedStep )
end

function DebugSQView:selectPrevStep()
	local idx = self:getSelectedStepIndex()
	if not idx then 
		idx = 1
	else
		idx = idx - 1
	end
	local session = getSQDebugHelper():getSession()
	local steps = session.steps
	while true do
		local step = steps[ idx ]
		if not step then return end
		if step[ 2 ] == 'enter' then
			self.selectedStep = step
			self:seekSQ()
			self:stepInSQ()
			self.focusNext = true
			return
		end
		idx = idx - 1
	end
end

function DebugSQView:selectNextStep()
	local idx = self:getSelectedStepIndex()
	if not idx then 
		idx = 1
	else
		idx = idx + 1
	end
	local session = getSQDebugHelper():getSession()
	local steps = session.steps
	while true do
		local step = steps[ idx ]
		if not step then return end
		if step[ 2 ] == 'enter' then
			self.selectedStep = step
			self:seekSQ()
			self:stepInSQ()
			self.focusNext = true
			return
		end
		idx = idx + 1
	end
end

