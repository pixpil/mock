module 'mock'

local DEBUGUI_CONFIG_NAME = 'debug_ui_config.json'
local LAYOUT_SCHEME_SIZE  = 8
--------------------------------------------------------------------
CLASS: DebugUIManager ( GlobalManager )
	:MODEL{}

function DebugUIManager:__init()
	self.imgui = ImGuiLayer()
	self.imgui:setCallback( function( gui )
		return self:onGUI( gui )
	end
	)
	self.uiModuleClasses = {}
	self.uiModules = {}
	self.enabled = false
	self.nextUpdateConfigTime = false

	self.sceneFilter = false
	self.sceneList = {}
	self.selectedScene = false
	self.openingScene = false

	self.savingLayoutId = false
	self.loadingLayoutId = false
	self.renamingLayoutId = false
	self.renamingLayoutName = false
	self.savedLayout = {}
	self.savedLayoutNames = {}

end

function DebugUIManager:getRenderLayer()
	return self.imgui:getRenderLayer()
end

function DebugUIManager:init()
	_stat( 'init debug UI' )
	connectGlobalSignalMethod( 'device.resize', self, 'onDeviceResize' )
	self.imgui:init{ inputCategory = 'DebugUI' }
	self.imgui:setViewport( game:getMainRenderTarget():getMoaiViewport() )
	self:onDeviceResize( game:getDeviceResolution() )
	--global keyboard listener
	addKeyboardListener( function( ... )
			return self:onKeyEvent( ... )
		end
	 )
end

function DebugUIManager:postInit( game )
	for key, clas in pairs( self.uiModuleClasses ) do
		local m = clas()
		self.uiModules[ key ] = m
	end
	
	local debugUIConfig = game:loadSettingData( DEBUGUI_CONFIG_NAME ) or {}
	-- table.print( debugUIConfig )
	--layout
	local layoutConfig = debugUIConfig[ 'layout' ]
	if layoutConfig then
		for key, uiModule in pairs( self.uiModules ) do
			local layoutConfig = layoutConfig[ key ] or {}
			uiModule.layoutConfig = layoutConfig
		end
	end

	self.savedLayout = debugUIConfig[ 'saved_layout' ] or {}
	self.savedLayoutNames = debugUIConfig[ 'saved_layout_names' ] or {}
	for i = 1, LAYOUT_SCHEME_SIZE do
		if not self.savedLayoutNames[ i ] then
			self.savedLayoutNames[ i ] = false
		end
	end

	-- self.enabled = true
	for key, uiModule in pairs( self.uiModules ) do
		uiModule:init()
	end
end

function DebugUIManager:onStart()
	for key, uiModule in pairs( self.uiModules ) do
		uiModule:start()
	end
	self.enabled = false
	self:setEnabled( false )
end

function DebugUIManager:onKeyEvent( key, down )
	if key == '`' and down then
		if not ( isShiftDown() or isCtrlDown() or isAltDown() ) then
			game:setDebugUIEnabled( not game:isDebugUIEnabled() )
		elseif isCtrlDown() then
			game:setLogViewEnabled( not game:isLogViewEnabled() ) 
		elseif isAltDown() then
			game:clearLogView() 
		end
	end
	if not self.enabled then return end
	for _, uiModule in pairs( self.uiModules ) do
		if uiModule.visible then
			uiModule:onKeyEvent( key, down )
		end
	end
end

function DebugUIManager:getKey()
	return 'DebugUIManager'
end

function DebugUIManager:hasModule( key )
	return self.uiModules[ key ] and true or false
end

function DebugUIManager:getModule( key )
	return self.uiModules[ key ]
end

function DebugUIManager:registerModule( key, uiModule )
	uiModule.__key = key
	self.uiModuleClasses[ key ] = uiModule
end

function DebugUIManager:onDeviceResize( w, h )
	self.imgui:setSize( w, h )
	self.imgui:setLoc( w/2, -h/2 )
end

function DebugUIManager:setLayoutSlotName( i, name )
	self.savedLayoutNames[ i ] = name
	self:saveConfig()
end

function DebugUIManager:getLayoutSlotName( i, noIdx )
	local name = self.savedLayoutNames[ i ]
	if noIdx then
		return name or ''
	end
	return string.format( '%d. %s', i, name  or '...' )
end

function DebugUIManager:subModuleLayout( gui )
	if self.renamingLayoutId then
		gui.OpenPopup( 'RenameLayout' )
	end

	if gui.BeginPopupModal( 'RenameLayout', nil, MOAIImGui.WindowFlags_AlwaysAutoResize ) then
		local a, text = gui.InputText( '', self.renamingLayoutName, 100 )
		if a then
			self.renamingLayoutName = text
		end
		if gui.Button( 'OK' ) then
			self:setLayoutSlotName( self.renamingLayoutId, self.renamingLayoutName )
			self.renamingLayoutId = false
			gui.CloseCurrentPopup()
		end
		gui.SameLine()
		if gui.Button( 'Cancel' ) then
			self.renamingLayoutId = false
			gui.CloseCurrentPopup()
		end		
		gui.EndPopup()
	end

	local updatingConfig = self.needingSaveConfig or ( self.savingLayoutId and true )
	self.needingSaveConfig = false
	self.updatingConfig = updatingConfig

	if not self.nextUpdateConfigTime then
		self.nextUpdateConfigTime = os.clock()

	elseif os.clock() > self.nextUpdateConfigTime  then
		updatingConfig = true
		self.nextUpdateConfigTime = os.clock() + 5
	end

	if self.savingLayoutId then
		local layoutConfig = {}
		for key, uiModule in pairs( self.uiModules ) do
			layoutConfig[ key ] = uiModule.layoutConfig
		end
		self.savedLayout[ self.savingLayoutId ] = layoutConfig
		self.savingLayoutId = false
	end

	if updatingConfig then
		self:saveConfig()
	end

	if self.loadingLayoutId then
		local layoutConfig = self.savedLayout[ self.loadingLayoutId ] or false
		if layoutConfig then
			for key, uiModule in pairs( self.uiModules ) do
				local config = layoutConfig[ key ]
				if config then
					uiModule.layoutConfig = config
					uiModule.layoutConfigLoaded = false
					uiModule.visible = true
				end
			end
		end
		self.loadingLayoutId = false
	end
end

local function buildSearchPattern( s )
	local output = ""
	for i = 1, #s do
		local c = s:sub( i, i )
		if c == '.' then
			c = '%.'
		end
		if c ~= ' ' then
			output = output .. c .. '.*'
		end
	end
	return output
end

function DebugUIManager:subOpenScene( gui )
	if self.openingScene then
		gui.OpenPopup( 'PopupOpenScene' )
	end

	if gui.BeginPopupModal( 'PopupOpenScene', nil ) then
		gui.SetWindowSize( 600, 400 )
		gui.BeginChild( 'Scenes', 580, 300 )
			local selectedScene = self.selectedScene
			for i, path in ipairs( self.sceneList ) do
				local selected = selectedScene == path
				if gui.Selectable( path, selected, MOAIImGui.SelectableFlags_AllowDoubleClick ) then
					self.selectedScene = path
					if gui.IsMouseDoubleClicked( 0 ) then
						game:scheduleOpenSceneByPath( path, false )
						self.openingScene = false
						gui.CloseCurrentPopup()
					end
				end
			end
		gui.EndChild()

		gui.Separator()

		local changed, filter = gui.InputText( 'Scene Name', self.sceneFilter or '', 1024 )
		if changed then
			self.sceneFilter = filter
			--update scenes
			local list = {}
			local filterLower = filter:lower()
			if filter ~= '' then
				local filterPattern = buildSearchPattern( filterLower )
				for k, node in pairs( getAssetLibrary() ) do
					if node:getType() == 'scene' then
						local pathLow = node:getPath():lower()
						if pathLow:find( filterPattern ) then
							local distance = levenshtein( filterLower, pathLow )
							table.insert( list, { node:getPath(), distance } )
						end
					end
				end
				table.sort( list, function( a, b ) 
						local da, db = a[2], b[2]
						if da == db then
							return a[1] < b[1]
						else
							return da < db
						end
					end
				)
			end
			local nameList = {}
			for i, entry in ipairs( list ) do
				nameList[ i ] = entry[ 1 ]
			end
			self.sceneList = nameList
		end

		gui.Separator()
		if gui.Button( 'CANCEL' ) then
			self.openingScene = false
			gui.CloseCurrentPopup()
		end

		if not gui.IsAnyItemActive() and not gui.IsMouseClicked( 0 ) then
			gui.SetKeyboardFocusHere( -2 )
		end
		gui.EndPopup()
	end

end

function DebugUIManager:subMenuGame( gui )
	if gui.BeginMenu( 'Game' ) then
		if gui.MenuItem( 'Open ...' ) then
			self.openingScene = true
		end

		if gui.MenuItem( 'Re-open Scene' ) then
			game:scheduleReopenMainScene()
		end

		gui.Separator()
		local pauseOnBlur = game:getUserObject( 'pause_engine_on_focus_lost' )
		if gui.MenuItem( 'Pause on blur', nil, pauseOnBlur ) then
			game:setUserObject( 'pause_engine_on_focus_lost', not pauseOnBlur )
		end

		gui.Separator()
		if gui.MenuItem( 'Exit' ) then
			game:stop()
			os.exit()
		end

		gui.EndMenu()
	end
end

function DebugUIManager:subMenuLog( gui )
	if gui.BeginMenu( 'Logging' ) then
		if gui.BeginMenu( 'level' ) then
			local level = getLogLevel()
			if gui.MenuItem( 'NONE',    nil, level == 'none'    ) then
				setLogLevel( 'none' )
			end
			if gui.MenuItem( 'STATUS',  nil, level == 'status'  ) then
				setLogLevel( 'status' )
			end
			if gui.MenuItem( 'WARNING', nil, level == 'warning' ) then
				setLogLevel( 'warning' )
			end
			if gui.MenuItem( 'ERROR',   nil, level == 'error'   ) then
				setLogLevel( 'error' )
			end
			gui.EndMenu()
		end

		gui.EndMenu()
	end
end

function DebugUIManager:subMenuAsset( gui )
	if gui.BeginMenu( 'Asset' ) then
		if gui.MenuItem( 'Reload Lua Script' ) then
			local reloadManager = game:getGlobalManager( 'AssetReloaderManager' )
			if reloadManager:isLuaScriptModified() then
				reloadManager:updateLuaScript()
				game:scheduleReopenMainScene()
			else
				_warn( 'NO Lua script modified!' )
			end
		end
		gui.EndMenu()
	end
end

function DebugUIManager:subMenuModules( gui )
	if gui.BeginMenu( 'Modules' ) then
			for key, uiModule in pairs( self.uiModules ) do
				local action = gui.MenuItem( uiModule:getTitle(), nil, uiModule.visible )
				if action then
					uiModule:setVisible( not uiModule.visible )
					self.needingSaveConfig = true
				end
			end
		gui.EndMenu()
	end
end

function DebugUIManager:subMenuLayout( gui )
	if gui.BeginMenu( 'Layout' ) then
		for i = 1, LAYOUT_SCHEME_SIZE do
			local slotName = self:getLayoutSlotName( i )
			if gui.MenuItem( slotName ) then
				self.loadingLayoutId = i
			end
		end
		gui.Separator()
		if gui.BeginMenu( 'Save Layout'  ) then
			for i = 1, LAYOUT_SCHEME_SIZE do
				local slotName = self:getLayoutSlotName( i )
				if gui.MenuItem( slotName ) then
					self.savingLayoutId = i
				end
			end
			gui.EndMenu()
		end
		if gui.BeginMenu( 'Rename'  ) then
			for i = 1, LAYOUT_SCHEME_SIZE do
				local slotName = self:getLayoutSlotName( i )
				if gui.MenuItem( slotName ) then
					self.renamingLayoutId = i
					self.renamingLayoutName = self:getLayoutSlotName( i, true )
				end
			end
			gui.EndMenu()
		end
		gui.EndMenu()
	end
end

function DebugUIManager:subMenuAbout( gui )
	if gui.BeginMenu( 'About' ) then
		gui.Text( 'MOCK v'..MOCK_VERSION )
		gui.EndMenu()
	end
end

function DebugUIManager:subMainMenu( gui )
	--main menu
	gui.BeginMainMenuBar()
		gui.PushStyleColor( MOAIImGui.Col_Text, HSL( wave(.1,0,360),1,0.7 ) )
		gui.Text( '::MOCK Debug UI::')
		gui.PopStyleColor(1)
		gui.SameLine()
		
		self:subMenuGame( gui )
		self:subMenuLog( gui )
		self:subMenuAsset( gui )
		self:subMenuModules( gui )
		self:subMenuLayout( gui )
		self:subMenuAbout( gui )

	gui.EndMainMenuBar()
end

function DebugUIManager:onGUI( gui )
	if not self.enabled then return end

	self:subMainMenu( gui )
	self:subModuleLayout( gui )
	self:subOpenScene( gui )

	local scn = game:getMainScene()
	for key, uiModule in pairs( self.uiModules ) do
		uiModule:updateDebugGUI( gui, scn, self.updatingConfig )
	end
	self.updatingConfig = false
end

function DebugUIManager:saveConfig()
	if game:isEditorMode() then return end
	local layoutConfig = {}
	for key, uiModule in pairs( self.uiModules ) do
		layoutConfig[ key ] = uiModule.layoutConfig
	end
	local config = {}
	config[ 'layout' ] = layoutConfig
	config[ 'saved_layout' ] = self.savedLayout
	config[ 'saved_layout_names' ] = self.savedLayoutNames
	game:saveSettingData( config, DEBUGUI_CONFIG_NAME )
end

function DebugUIManager:setEnabled( enabled )
	if mock.__nodebug then return end
	enabled = enabled ~= false
	if enabled == self.enabled then return end
	self.enabled = enabled
	
	setInputListenerCategoryActive( 'DebugUI', enabled )
	self.imgui:setEnabled( enabled )

	if enabled then
		game:showSystemCursor( 'DebugUI' )
	else
		game:hideSystemCursor( 'DebugUI' )
	end

	if enabled then
		for key, uiModule in pairs( self.uiModules ) do
			uiModule:onEnabled()
		end
	else
		for key, uiModule in pairs( self.uiModules ) do
			uiModule:onDisabled()
		end
	end
end

function DebugUIManager:isEnabled()
	return self.enabled
end

--------------------------------------------------------------------
CLASS: DebugUISubModule ()

function DebugUISubModule:getName()
	return 'sub'
end

function DebugUISubModule:preDebugGUI( gui, scn )

end

function DebugUISubModule:onDebugGUI( gui, scn )

end

function DebugUISubModule:postDebugGUI( gui, scn )

end

---------------------------------------------------------------------
CLASS: DebugUIModule ()

function DebugUIModule.register( clas, key )
	getDebugUIManager():registerModule( key, clas )
end

function DebugUIModule:__init()
	self.name = ""
	self.visible = true
	self.layoutConfig = {}
	self.layoutConfigLoaded = false
	self.subModules = {}
end

function DebugUIModule:init()
end

function DebugUIModule:start()
end

function DebugUIModule:addSubModule( m )
	table.insert( self.subModules, m )
end

function DebugUIModule:getSubModule( name )
	for i, m in ipairs( self.subModules ) do
		if m:getName() == name then return m end
	end
end

function DebugUIModule:removeSubModule( m )
	if type( m ) == 'name' then
		m = self:getSubModule( m )
	end
	if isInstance( m, DebugUISubModule ) then
		local idx = table.index( self.subModules, m )
		if idx then
			table.remove( self.subModules, idx )
			return true
		end
	end
	return false
end


function DebugUIModule:isVisible()
	return self.visible
end

function DebugUIModule:setVisible( v )
	self.visible = v
end

function DebugUIModule:updateDebugGUI( gui, scn, saveConfig )
	if not self.visible then return end
	self:preDebugGUI( gui, scn, saveConfig )
	----
	self:onDebugGUI( gui, scn )
	for i, m in ipairs( self.subModules ) do
		m:onDebugGUI( gui, scn )
	end
	----
	self:postDebugGUI( gui, scn, saveConfig )

end

function DebugUIModule:getTitle()
	return self.__key
end

function DebugUIModule:saveLayoutConfig( gui )
	local layoutConfig = {
		loc  = { gui.GetWindowPos() };
		size = { gui.GetWindowSize() };
		collapsed = gui.IsWindowCollapsed();
		visible = self.visible;
	}
	return layoutConfig
end

function DebugUIModule:loadLayoutConfig( gui, data )
	if data.loc then gui.SetWindowPos( unpack( data.loc ) ) end
	if data.size then
		gui.SetWindowSize( unpack( data.size ) )
	else
		gui.SetWindowSize( 100, 100 )
	end
	if data.collapsed ~= nil then gui.SetWindowCollapsed( data.collapsed ) end
	if data.visible ~= nil then self.visible = data.visible end

end

function DebugUIModule:preDebugGUI( gui, scn, saveConfig )
	local title = self:getTitle()
	local visible = self.visible
	local collapsed, visible1 = gui.Begin( title, visible, MOAIImGui.WindowFlags_NoCollapse )
	if visible ~= visible1 then
		self.visible = visible1
		self.layoutConfig = self:saveLayoutConfig( gui )
		getDebugUIManager():saveConfig()
	end
	if not self.layoutConfigLoaded then
		self.layoutConfigLoaded = true
		self:loadLayoutConfig( gui, self.layoutConfig )
	end
	for i, m in ipairs( self.subModules ) do
		m:preDebugGUI( gui, scn )
	end
end

function DebugUIModule:onDebugGUI( gui, scn )
end

function DebugUIModule:postDebugGUI( gui, scn, saveConfig )
	if saveConfig then
		self.layoutConfig = self:saveLayoutConfig( gui )
	end
	for i, m in ipairs( self.subModules ) do
		m:postDebugGUI( gui, scn )
	end
	gui.End()
end

function DebugUIModule:onEnabled()
end

function DebugUIModule:onDisabled()
end

function DebugUIModule:onKeyEvent( key, down )
end

--------------------------------------------------------------------

--------------------------------------------------------------------
CLASS: DebugUIListenerModule ()
	:MODEL{}

function DebugUIListenerModule:__init( owner )
	self.owner = owner
	self.callback = owner.onDebugGUI or false
end

function DebugUIListenerModule:onDebugGUI( gui, scn )
	if not self.callback then return end
	self.callback( self.owner, gui, scn )
end

--------------------------------------------------------------------
local _debugUIManager = DebugUIManager()
function getDebugUIManager()
	return _debugUIManager
end

function getDebugUIModule( key )
	return _debugUIManager:getModule( key )
end


function addDebugUIModule( key, module )
	_debugUIManager:registerModule( key, module )
end

function setDebugUIEnabled( enabled )
	_debugUIManager:setEnabled( enabled )
end
