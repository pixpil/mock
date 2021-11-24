module 'mock'

CLASS: DebugQuestView ( DebugUIModule )
:register( 'quest' )
--------------------------------------------------------------------
function DebugQuestView:__init()
	self.sessionMap = false
	self.filterActive = false
	self.filterFinished = false
	self.filterAborted = false
	self.filterDefault = false
end

function DebugQuestView:getTitle()
	return 'Quest'
end

function DebugQuestView:onDebugGUI( gui, scn )
	if not self.sessionMap then
		self:buildQuestSessionMap()
	end
	self:subQuestState( gui, scn )
end

function DebugQuestView:buildQuestSessionEntry( session )
	local function sortName( a, b )
		if next( a.children ) then
			if not next( b.children ) then
				return false
			end
		elseif next( b.children ) then
			return true
		end
		if a.name == 'start' then
			return true
		elseif b.name == 'start' then
			return false
		end

		if a.name == 'stop' then
			return true
		elseif b.name == 'stop' then
			return false
		end

		return a.name < b.name
	end

	local function buildNodeEntry( node )
		local entry = {}
		entry.node = node
		entry.name = node:getName()
		entry.fullname = node:getFullName()
		entry.globalname = session.name .. ':' .. entry.fullname
		entry.filterAllowed = false

		local children = node:getChildren()
		if next( children ) then
			local childEntries = {}
			for _, child in ipairs( children ) do
				if not child:isCommand() then
					table.insert( childEntries, buildNodeEntry( child ) )
				end
			end
			entry.children = childEntries
			table.sort( childEntries, sortName )
		else
			entry.children = {}
		end	
		return entry
	end

	local state = session:getState()
	local roots = {}
	for _, scheme in ipairs( state:getSchemes() ) do
		local entry = buildNodeEntry( scheme:getRoot() )
		table.insert( roots, entry )
	end

	return {
		name = session:getName(),
		session = session,
		state = state,
		roots = roots
	}
end

function DebugQuestView:buildQuestSessionMap()
	local map = {}
	for i, session in ipairs( getQuestManager():getSessions() ) do
		map[ i ] = self:buildQuestSessionEntry( session )
	end
	self.sessionMap = map
end

function DebugQuestView:updateNodeFilter( nodeEntry, state )
	local childAllowed = false
	for i, childEntry in ipairs( nodeEntry.children ) do
		local allowed = self:updateNodeFilter( childEntry, state )
		childAllowed = allowed or childAllowed
	end
	local allowed = false
	if not childAllowed then
		local nodeState = state:getNodeState( nodeEntry.fullname )
		if nodeState == 'finished' and self.filterFinished then
			allowed = true
		
		elseif nodeState == 'active' and self.filterActive then
			allowed = true
		
		elseif nodeState == 'aborted' and self.filterAborted then
			allowed = true
		
		elseif nodeState == nil and self.filterDefault then
			allowed = true
		
		else
			allowed = false
		end

	else
		allowed = true
	end
	nodeEntry.filterAllowed = allowed
	return allowed
end

local state2Color = {
	finished = { hexcolor'#5A6DC7' },
	aborted  = { hexcolor'#C00613' },
	active   = { hexcolor'#B0FF00' },
	default  = { hexcolor'#9E9E9E' },
	active_paused    = { hexcolor'#FAED00' },
	default_paused   = { hexcolor'#A18F56' },
}

function DebugQuestView:subQuestNodeEntry( gui, scn, nodeEntry, state )
	-- body
	if self.filtering and not nodeEntry.filterAllowed then return end
	local node = nodeEntry.node
	local fullname = nodeEntry.fullname
	local name = nodeEntry.name
	local childEntries = nodeEntry.children
	local selected = self.selectedQuestNodeEntry == nodeEntry
	local flag = selected and MOAIImGui.TreeNodeFlags_Selected or 0
	-- flag = flag + 
	local nodeState = state:getNodeState( fullname )
	local nodeState1 = nodeState or 'default'
	local selfPaused = false
	if state:isNodePaused( fullname ) then
		if nodeState1 == 'default' then nodeState1 = 'default_paused'
		elseif nodeState1 == 'active' then nodeState1 = 'active_paused' end
		if state:isNodePaused( fullname, false ) then
			selfPaused = true
			name = name .. ' [paused]'
		end
	end
	local color = state2Color[ nodeState1 ]
	gui.PushStyleColor( MOAIImGui.Col_Text, unpack( color or state2Color['default'] ) )
	if next(childEntries) then
		flag = flag + MOAIImGui.TreeNodeFlags_OpenOnArrow
		local open = gui.TreeNodeEx( name, flag )
		if open then
			if gui.IsItemClicked() then
				self.selectedQuestNodeEntry = nodeEntry
			end
			for _, childEntry in ipairs( childEntries ) do
				self:subQuestNodeEntry( gui, scn, childEntry, state )
			end
			gui.TreePop()
		else
			if gui.IsItemClicked() then
				self.selectedQuestNodeEntry = nodeEntry
			end
		end
	else
		flag = flag + MOAIImGui.TreeNodeFlags_Leaf
		local open = gui.TreeNodeEx( name, flag )
		if open then
			if gui.IsItemClicked() then
				self.selectedQuestNodeEntry = nodeEntry
			end
			gui.TreePop()
		end
	end

	gui.PopStyleColor()
end

function DebugQuestView:subQuestSessionEntry( gui, scn, entry )
	if gui.TreeNodeEx( entry.name, MOAIImGui.TreeNodeFlags_Framed ) then
		gui.PushStyleColor( MOAIImGui.Col_Header, hexcolor('#0C137D') )
		gui.PushStyleColor( MOAIImGui.Col_HeaderHovered, hexcolor('#293290') )
		gui.PushStyleColor( MOAIImGui.Col_Text, hexcolor('#646464') )

		local state = entry.state
		for _, rootEntry in ipairs( entry.roots ) do
			for i, nodeEntry in ipairs( rootEntry.children ) do
				if self.filtering then
					self:updateNodeFilter( nodeEntry, state )
				end
				self:subQuestNodeEntry( gui, scn, nodeEntry, state )
			end
		end
		gui.PopStyleColor( 3 )
		gui.TreePop()
	end
end

function DebugQuestView:subQuestState( gui, scn )
	if self.selectedQuestNodeEntry then
		local globalname = self.selectedQuestNodeEntry.globalname
		local nodeState = getQuestNodeState( globalname )
		local color = state2Color[ nodeState or 'default' ]
		gui.Text( 'selected:')
		gui.SameLine()
		gui.PushStyleColor( MOAIImGui.Col_Text, unpack( color ) )
		gui.Text( globalname )		
		gui.PopStyleColor()
		gui.SameLine()
		if gui.Button( 'copy' ) then
			game:setClipboard( globalname )
		end
		
		if gui.Button( 'start' ) then
			startQuestNode( globalname )
		end
		gui.SameLine()
		if gui.Button( 'finish' ) then
			finishQuestNode( globalname )
		end
		gui.SameLine()
		if gui.Button( 'abort' ) then
			abortQuestNode( globalname )
		end
		gui.SameLine()
		if gui.Button( 'reset' ) then
			resetQuestNode( globalname )
		end
		if gui.Button( 'pause' ) then
			pauseQuestNode( globalname )
		end
		gui.SameLine()
		if gui.Button( 'resume' ) then
			resumeQuestNode( globalname )
		end
	else
		gui.Text( 'selected: NONE' )
		gui.Text( 'select quest node to manage')		
	end

	local filterChanged = false
	local change
	gui.Separator()
	gui.Text( 'FILTERS:' )
	gui.SameLine()
	gui.PushStyleColor( MOAIImGui.Col_Text, unpack( state2Color['active'] ) )
	change, self.filterActive = gui.Checkbox( 'S', self.filterActive )
	filterChanged = filterChanged or change

	gui.SameLine()
	gui.PushStyleColor( MOAIImGui.Col_Text, unpack( state2Color['finished'] ) )
	change, self.filterFinished = gui.Checkbox( 'F', self.filterFinished )
	filterChanged = filterChanged or change

	gui.SameLine()
	gui.PushStyleColor( MOAIImGui.Col_Text, unpack( state2Color['aborted'] ) )
	change, self.filterAborted = gui.Checkbox( 'A', self.filterAborted )
	filterChanged = filterChanged or change

	gui.SameLine()
	gui.PushStyleColor( MOAIImGui.Col_Text, unpack( state2Color['default'] ) )
	change, self.filterDefault = gui.Checkbox( 'D', self.filterDefault )
	filterChanged = filterChanged or change

	gui.Separator()
	gui.PopStyleColor( 4 )

	self.filtering = self.filterActive or self.filterFinished or self.filterAborted or self.filterDefault

	gui.BeginChild( "Sessions" )
		for i, entry in ipairs( self.sessionMap ) do
			self:subQuestSessionEntry( gui, scn, entry )
		end
  gui.EndChild()
end

