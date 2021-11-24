module 'mock'

-- local function _treeNode( gui, entityNode )
-- 	for i, child in ipairs( entityNode:getChildList()) do
-- 	end
-- end

-- function DebugEditorUI.DebugSceneGraphView( gui, root )

-- end

local function sortByName( a, b )
	return ( a.name or '' ) < ( b.name or '' )
end
local keys = table.keys
local sort = table.sort
local next = next

--------------------------------------------------------------------
CLASS: DebugInspectorView ( DebugUIModule )
:register( 'inspector' )

function DebugInspectorView:__init()
	self.target = false
	self.targetType = false
end

function DebugInspectorView:getTitle()
	return 'Inspector'
end

function DebugInspectorView:onDebugGUI( gui, scn )
	if not self.target then
		gui.Text( 'No Object Selected' )
		return
	end
	
	if gui.Button( 'Pull' ) then
		--TODO: pull data from Gii
	end
	
	gui.SameLine()
	
	if gui.Button( 'Push' ) then
		--TODO: push data from Gii
	end

	gui.Separator()
	gui.BeginChild( 'DataArea' )
		local targetType = self.targetType
		if targetType == 'entity' then
			self:subEntity( gui, scn )
		else
			self:subObject( gui, scn )
		end
	gui.EndChild()
end

function DebugInspectorView:makeObjectEditor( object, gui, scn, open )
	local title = object:__repr()
	local flags = 0
	if open ~= false then
		flags = MOAIImGui.TreeNodeFlags_DefaultOpen
	end
	if gui.CollapsingHeader( title, flags ) then
		DebugEditorUI.ObjectEditor( gui, object )
	end
end

function DebugInspectorView:subObject( gui,scn )
	self:makeObjectEditor( self.target, gui, scn )
end

function DebugInspectorView:subEntity( gui,scn )
	local target = self.target
	self:makeObjectEditor( target, gui, scn )
	for i, com in ipairs( target:getSortedComponentList() ) do
		self:makeObjectEditor( com, gui, scn, false )
	end
end

function DebugInspectorView:setTarget( target )
	self.target = target
	if not target then
		self.targetType = false
	else
		if isInstance( target, Entity ) then
			self.targetType = 'entity'
		else
			self.targetType = 'object'
		end
	end
end

--------------------------------------------------------------------
CLASS: DebugSceneGraphView ( DebugUIModule )
:register( 'scene_graph' )

function DebugSceneGraphView:__init()
	self.groupSelections = {}
	self.sessionSelections = {}
	self.groupIndex = {}

	self.currentRootGroup = false
	self.currentRootGroupIndex = 0
	self.selectedObject = false

	self.currentSession = 'main'
	self.currentSessionIndex = 0

	connectGlobalSignalFunc( 'scene.start', function( scn )
		self:onSceneStart( scn )
	end )

	connectGlobalSignalFunc( 'scene_session.add', function()
		self:refreshSceneSessionIndex()
	end )

	self:refreshSceneSessionIndex()
end

function DebugSceneGraphView:getTitle()
	return 'SceneGraph'
end

function DebugSceneGraphView:getCurrentSceneSession()
	return game:getSceneSession( self.currentSession )
end

function DebugSceneGraphView:getCurrentScene()
	return game:getScene( self.currentSession )
end

function DebugSceneGraphView:refreshSceneSessionIndex()
	local sessionNames = {}
	local index = 0
	for i, session in ipairs( game.sceneSessions ) do
		sessionNames[ i ] = session.name
		if self.currentSession == session.name then
			index = i
		end
	end
	self.sessionSelections = sessionNames
	self.currentSessionIndex = index
	--TODO: update current view
end

function DebugSceneGraphView:onSceneStart( scn )
	if scn:getSessionName() == self.currentSession then
		self:refreshView()
	end
end

function DebugSceneGraphView:refreshView()
	local scn = self:getCurrentScene()
	if not scn then return end
	local selections = {}
	local groups = {}	
	for k, group in pairs( scn:getRootGroups() ) do
		table.insert( selections, group.name )
		table.insert( groups, group )
	end	
	self.groupSelections = selections
	self.groupIndex = groups
	self.currentRootGroup = groups[1]
	self.currentRootGroupIndex = 1
	self:selectObject( false )
end

function DebugSceneGraphView:selectObject( obj )
	self.selectedObject = obj or false
	getDebugUIModule( 'inspector' ):setTarget( self.selectedObject )
end

local PushID = false
local PopID = false
function DebugSceneGraphView:onDebugGUI( gui, scn )
	local reloadManager = game:getGlobalManager( 'AssetReloaderManager' )
	local change, autoReload = gui.Checkbox( 'Auto-Reload Script', reloadManager.autoReloadScript )
	if change then
		reloadManager:setAutoReloadScript( autoReload )
	end
	gui.Separator()
	local a, idx = gui.Combo( 'Sessions', self.currentSessionIndex, self.sessionSelections, #self.sessionSelections)
	if a then
		self.currentSessionIndex = idx
		self.currentSession = self.sessionSelections[ idx ] or false
		self:refreshView()
	end
	if gui.Button( 'Reload Scene' ) then
		local session = self:getCurrentSceneSession()
		if session then
			session:scheduleReopenScene()
			return
		end
	end

	local scene = self:getCurrentScene()
	if not scene then
		gui.Text( 'No Target Scene' )
		return
	end

	if not scene.running then
		gui.Text( 'Target Scene not ready' ) 
		return
	end
	gui.Separator()
	PushID = gui.PushID
	PopID = gui.PopID
	local a, idx = gui.Combo( 'Groups', self.currentRootGroupIndex, self.groupSelections, #self.groupSelections)
	if a then
		self.currentRootGroupIndex = idx
		self.currentRootGroup = self.groupIndex[ idx ] or false
	end
	gui.Separator()
	gui.BeginChild( 'Entities' )
		local group = self.currentRootGroup
		if group then
			local childGroupList = keys( group.childGroups )
			sort( childGroupList, sortByName )
			for i, g in ipairs( childGroupList ) do
				self:subEntityGroup( g, gui, scn )
			end
			local entitieList = keys( group.entities )
			sort( entitieList, sortByName )
			for i, e in ipairs( entitieList ) do
				self:subEntity( e, gui, scn )
			end
		end
	gui.EndChild()
	PushID = nil
	PopID = nil
end

function DebugSceneGraphView:subEntityGroup( group, gui, scn )
	local selected = self.selectedObject == group
	local flag = selected and MOAIImGui.TreeNodeFlags_Selected or 0
	local title = '['..(group:getName() or '???')..']'
	local empty = group:isEmpty()
	if not empty then
		flag = flag + MOAIImGui.TreeNodeFlags_OpenOnArrow
	else
		flag = flag + MOAIImGui.TreeNodeFlags_Leaf
	end
	PushID( group.__address )
	if not group:isVisible() then
		gui.PushStyleColor( MOAIImGui.Col_Text, .5,.4,.3,1  )
	else
		gui.PushStyleColor( MOAIImGui.Col_Text, .9,.8,.5,1  )
	end
	if gui.TreeNodeEx( title, flag ) then
		if gui.IsItemClicked() then
			self:selectObject( group )
		end
		if not empty then
			local childGroupList = keys( group.childGroups )
			sort( childGroupList, sortByName )
			for i, g in ipairs( childGroupList ) do
				self:subEntityGroup( g, gui, scn )
			end
			local entitieList = keys( group.entities )
			sort( entitieList, sortByName )
			for i, e in ipairs( entitieList ) do
				self:subEntity( e, gui, scn )
			end
		end
		gui.TreePop()
	else
		if gui.IsItemClicked() then
			self:selectObject( group )
		end
	end
	PopID()
	gui.PopStyleColor()
	
end

function DebugSceneGraphView:subEntity( entity, gui, scn )
	local selected = self.selectedObject == entity
	local flag = selected and MOAIImGui.TreeNodeFlags_Selected or 0
	local children = entity.children
	local empty = not ( children and next( children ) )
	if not empty then
		flag = flag + MOAIImGui.TreeNodeFlags_OpenOnArrow
	else
		flag = flag + MOAIImGui.TreeNodeFlags_Leaf
	end
	PushID( entity.__address )
	local title = entity:getName() or '<???>'
	if not entity.FLAG_INTERNAL then
		if not entity:isVisible() then
			gui.PushStyleColor( MOAIImGui.Col_Text, .4,.4,.4,1  )
		else
			gui.PushStyleColor( MOAIImGui.Col_Text, .8,.8,.8,1  )
		end
	else
		title = '*' .. title
		if not entity:isVisible() then
			gui.PushStyleColor( MOAIImGui.Col_Text, .3,.3,.6,1  )
		else
			gui.PushStyleColor( MOAIImGui.Col_Text, .6,.5,.8,1  )
		end
	end
	if gui.TreeNodeEx( title, flag ) then
		if gui.IsItemClicked() then
			self:selectObject( entity )
		end
		if not empty then
			local childrenList = keys( children )
			sort( childrenList, sortByName )
			for i, e in ipairs( childrenList ) do
				self:subEntity( e, gui, scn )
			end
		end
		gui.TreePop()
	else
		if gui.IsItemClicked() then
			self:selectObject( entity )
		end
	end
	PopID()
	gui.PopStyleColor()
end
