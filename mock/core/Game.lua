--[[
* MOCK framework for Moai

* Copyright (C) 2012 Tommo Zhou(tommo.zhou@gmail.com).  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

--------------------------------------------------------------------
-- The game object.
-- It's the singleton for the main application control.
-- @classmod Game
--------------------------------------------------------------------

module 'mock'

local gii = rawget( _G, 'gii' )
local collectgarbage = collectgarbage
local pairs,ipairs,setmetatable,unpack=pairs,ipairs,setmetatable,unpack

--------------------------------------------------------------------
----GAME MODULES
--------------------------------------------------------------------

require 'GameModule'
function loadAllGameModules( scriptLibrary, scriptLibraryPatch )
	if scriptLibrary then
		local data = game:loadJSONData( scriptLibrary )
		if data then 
			local export = data.export or data
			local source = data.source or data
			for mname, path in pairs( export ) do
				local srcPath = source[ mname ]
				local patchedPath
				if scriptLibraryPatch then
					patchedPath = scriptLibraryPatch[ mname ]
				end
				GameModule.addGameModuleMapping( mname, patchedPath or path, srcPath )
			end
		end
	end

	for k, node in pairs( getAssetLibrary() ) do
		if node.type == 'lua' then
			local modulePath = k:gsub( '/', '.' )
			modulePath = modulePath:sub( 1, #modulePath - 4 )
			GameModule.loadGameModule( modulePath )
		end
	end

	local errors = GameModule.getErrorInfo()
	if errors then
		print( 'Errors in loading game modules' )
		print( '------------------------------' )
		for i, info in ipairs( errors ) do
			if info.errtype == 'compile' then
				printf( 'error in compiling %s', info.fullpath )
			elseif info.errtype == 'load' then
				printf( 'error in loading %s', info.fullpath )
			end
			print( info.msg )
			print()
		end
		print( '------------------------------' )
		os.exit( -1 )
	end
	validateAllClasses()
end

--------------------------------------------------------------------
local _SimLoopFlagNames = {
	[ 'force_step' ] = MOAISim.SIM_LOOP_FORCE_STEP  ;
	[ 'allow_boost'] = MOAISim.SIM_LOOP_ALLOW_BOOST ;
	[ 'allow_spin' ] = MOAISim.SIM_LOOP_ALLOW_SPIN  ;
	[ 'no_deficit' ] = MOAISim.SIM_LOOP_NO_DEFICIT  ;
	[ 'no_surplus' ] = MOAISim.SIM_LOOP_NO_SURPLUS  ;
	-- [ 'reset_clock'] = MOAISim.SIM_LOOP_RESET_CLOCK ;
	[ 'allow_soak' ] = MOAISim.SIM_LOOP_ALLOW_SOAK  ;
	[ 'long_delay' ] = MOAISim.SIM_LOOP_LONG_DELAY  ;
}

--------------------------------------------------------------------
local _defaultSystemOption = {
	loop_flags = {};
	-- loop_flags = { 'force_step' };
	-- loop_flags = { 'allow_boost', 'no_deficit' };
	-- loop_flags         = { 'allow_spin', 'allow_boost' } ;
	-- loop_flags         = { 'allow_boost', 'allow_soak' } ;
	
	long_delay_threshold = 40;
	boost_threshold    = 5;

	update_rate        = 60;
	render_rate        = 60;

	gc_step            = 20;
	gc_step_limit      = 0;
	gc_pause           = 150;
	gc_stepmul         = 100;
	cpu_budget         = 2;
}

--------------------------------------------------------------------
local _defaultEnvironment = {
	region = 'us',
	locale = 'en'
}


--------------------------------------------------------------------
CLASS: Game () 
	
--------------------------------------------------------------------
function Game:__init() --INITIALIZATION
	self.overridedOption      = {}
	self.initialized          = false
	self.boostLoadLock        = 0
	self.graphicsInitialized  = false
	self.started              = false
	self.focused              = false
	self.scenePaused          = false
	self.graphicsContextReady = getG( 'MOCK_GRAPHICS_CONTEXT_READY', false )
	self.currentRenderContext = 'game'    -- for editor integration
	self.syncingRenderState   = true

	self.pendingCall          = {}

	self.debugLevels          = {}
	self.prevUpdateTime = 0
	self.prevClock = 0

	self.timer = false

	self.forceStep = false
	self.loopFlags = 0
	self.skipFrame = false
	self.skippedFrame = 0

	self.version = ""
	self.config        = {}

	self.editorMode = false
	self.developerMode = false
	self.namedSceneMap = {}
	self.layers        = {}
	self.gfx           = { w = 640, h = 480, viewportRect = {0,0,640,480} }
	self.time          = 0
	self.frame 				 = 0

	local l = self:addLayer( 'main' )
	l.default = true
	self.defaultLayer = l

	self.showSystemCursorReasons = {}
	self.relativeMouseMode = false

	self.userObjects    = {}
	self.userConfig     = {}
	self.sceneSessions  = {}
	self.sceneSessionCount = 0
	self.sceneSessionMap = {}
	self.globalManagers = {}

	self.renderManager = RenderManager()
	self.preRenderTable = {}
	self.postRenderTable = {}

	self.fullscreen = false
	self.fullscreenScale = 1

	self.textInputLockCounter = 0

	self.throttleFactors = {}
	self.updateGlobalManagerFunc = function() end

	self.boostLoading = false
end

--------------------------------------------------------------------
-- load game configuration from file
--------------------------------------------------------------------
function Game:loadConfig( path, fromEditor, extra )
	extra = extra or {}
	_stat( 'loading game config from :', path )
	local data = self:loadJSONData( path )
	if not data then
		_error( 'game configuration not parsed:', path )
		return
	end

	return self:init( data, fromEditor, extra )
end

function Game:init( config, fromEditor, extra )
	
	self.taskManager = getTaskManager()

	self:startBoostLoading()
	assert( not self.initialized )

	extra = extra or {}
	
	_stat( '...init game' )
		
	self.editorMode  = fromEditor and true or false
	self.developerMode = fromEditor and true or MOCK_DEVELOPER_MODE
	
	MOAILogMgr.setTypeCheckLuaParams( false )
	
	if self.editorMode then
		setDeveloperMode()
		setDefaultProtoInstanceIDGenerator( MOAIEnvironment.generateGUID )
	else
		setDefaultProtoInstanceIDGenerator( false ) --use simple id generator
	end

	config = table.simplecopy( config )
	
	local overridedConfig = extra[ 'overrided_config' ] 
	if overridedConfig then
		table.extend( config, overridedConfig )
	end

	self.config  = config

	--META
	self.name    = config['name'] or 'GAME'
	self.vendor  = config['vendor'] or 'GiiProject'
	self.userId  = false
	self.version = config['version'] or '0.0.1'
	self.title   = config['title'] or self.name
	self.displayTitles = config[ 'display_title' ] or {}

	self.defaultLocale = config['default_locale'] or 'en'

	getLocaleManager():setActiveLocale( self.defaultLocale )

	if getG( 'MOCK_PRE_GAME_INIT' ) then
		local func = getG( 'MOCK_PRE_GAME_INIT' )
		func()
	end

	--Systems
	local noGraphics = extra[ 'no_graphics' ]

	if not noGraphics then
		self:initGraphics   ( config, fromEditor )
		self:initCursor()
		self:initDebugUI()
	end


	if not game:getUserObject( 'no_game' ) then
		self:initAsset       ( config, fromEditor )
	end

	if not noGraphics then
		-- MOAISim.raiseWindow()
		-- MOAISim.stopTextInput()
	end
	
	
	self:initSystem      ( config, fromEditor )

	self.mainSceneSession = self:affirmSceneSession( 'main' )
	self.mainSceneSession.main = true
	self.mainScene        = self.mainSceneSession:getScene()
	self.mainScene.main   = true

	--postInit
	if not fromEditor then --initCommonData will get called after scanning asset modifications
		self:initCommonData( config, fromEditor )
		self.initialized = true
	end

	getPlatformSupport():onInit()
	-- MOAISim.forceGC(1)

	self:stopBoostLoading()
	
	
end


function Game:initSystem( config, fromEditor )
	_stat( '...init systems' )
	-------Setup Action Root
	_stat( '...setting up action root' )
	self.time     = 0
	self.throttle = 1
	self.isPaused = false
	self.timer    = MOAITimer.new()
	self.timer:setMode( MOAITimer.CONTINUE )

	local yield = coroutine.yield
	self.rootUpdateCoroutine = MOAICoroutine.new()
	self.rootUpdateCoroutine:run( function()
			local onRootUpdate = self.onRootUpdate
			while true do
				local dt = yield()
				onRootUpdate( self, dt )
			end
		end
	)

	self.actionRoot = MOAIAction.new()
	self.actionRoot:setAutoStop( false )
	self.actionRoot:start()

	-- MOAISim.getActionMgr():getRoot():attach(  )
	self.actionRoot:setListener( MOAIAction.EVENT_ACTION_PRE_UPDATE, function()
		return self:preRootUpdate()
	end )

	local sysRoot = MOAISim.getActionMgr():getRoot()
	sysRoot:setListener( MOAIAction.EVENT_ACTION_PRE_UPDATE, function()
		return self:preSysRootUpdate()
	end )

	self.sysActionRoot = sysRoot

	self.sceneActionRoot = MOAICoroutine.new()
	self.sceneActionRoot:setDefaultParent( true )
	self.sceneActionRoot:run( function()
			local onSceneRootUpdate = self.onSceneRootUpdate
			while true do
				local dt = yield()
				onSceneRootUpdate( self, dt ) --delta time get passed in
			end
		end
	)

	self.timer:attach( self.actionRoot )
	self.rootUpdateCoroutine:attach( self.timer )
	self.sceneActionRoot:attach( self.timer )

	MOAINodeMgr.setMaxIterations( 1 )

	self.actionRoot:setListener( MOAIAction.EVENT_ACTION_POST_UPDATE, function()
		return self:postRootUpdate()
	end )

	self.actionRoot:pause( true )

	self:setThrottle( 1 )

	-------Setup Callbacks
	_stat( '...setting up session callbacks' )
	if rawget( _G, 'MOAIApp' ) then
		MOAIApp.setListener(
			MOAIApp.SESSION_END, 
			function() return emitSignal('app.end') end 
			)
		MOAIApp.setListener(
			MOAIApp.SESSION_START,
			function(resume) return emitSignal( resume and 'app.resume' or 'app.start' ) end 
			)
	end

	----extra
	_stat( '...extra init' )


	local systemOption = self.systemOption or {}
	local function _getSystemOption( key, default )
		local v = systemOption[ key ]
		if v == nil then
			if default == nil then
				return _defaultSystemOption[ key ]
			else
				return default
			end
		end
		return v
	end

	MOAISim.clearLoopFlags()

	local loopFlagNames = _getSystemOption( 'loop_flags' )
	local loopFlags = 0
	local bor     = bit.bor
	for i, n in ipairs( loopFlagNames ) do
		local v = _SimLoopFlagNames[ n ]
		if v then
			loopFlags = bor( loopFlags, v )
		end
	end
	
	self.initialLoopFlags = loopFlags
	self:setLoopFlags( loopFlags )
	
	MOAISim.setLongDelayThreshold( _getSystemOption( 'long_delay_threshold' ) )
	MOAISim.setBoostThreshold( _getSystemOption( 'boost_threshold' ) )		
	MOAISim.setCpuBudget ( _getSystemOption( 'cpu_budget' ) )

	MOAISim.setGCStep    ( _getSystemOption( 'gc_step' ) )
	MOAISim.setGCStepLimit   ( _getSystemOption( 'gc_step_limit' ) )

	MOAISim.setTimerError( 0.2 )

	self:setRenderRate( _getSystemOption( 'render_rate' ) )
	self:setUpdateRate( _getSystemOption( 'update_rate' ) )

	if fromEditor then
		collectgarbage( 'setpause',   150  )
		collectgarbage( 'setstepmul', 200 )	
	else
		-- collectgarbage( 'setpause',   _getSystemOption( 'gc_pause' )  )
		-- collectgarbage( 'setstepmul', _getSystemOption( 'gc_stepmul' ) )	
		collectgarbage( 'setpause',   80 )
		collectgarbage( 'setstepmul', 100 )	
	end

	-- MOAILuaRuntime.setDeferDeletion ( 100 )
	-- self:setStepMultiplier( 1 )
	self:setGCStepLimit( 100 )
end

function Game:resetSimTime()
	MOAISim.setLoopFlags( MOAISim.SIM_LOOP_RESET_CLOCK )
end

function Game:initSubSystems( config, fromEditor )
	--make inputs work
	_stat( 'init input handlers' )
	initDefaultInputEventHandlers()
	if not getJoystickManager() then
		DummyJoystickManager()
	end

	--audio
	_stat( 'init audio' )
	self.audioOption = table.simplecopy( DefaultAudioOption )
	if config['audio'] then
		table.extend( self.audioOption, config['audio'] )
	end
	local audioManager = AudioManager.get()
	if audioManager then
		if not audioManager:init( self.audioOption ) then
			_warn( 'failed to initialize audio system' )
		end
	else
		_warn( 'no audio manager registered' )
	end

	--physics
	_stat( 'init physics' )
	--config for default physics world
	self.physicsOption = table.simplecopy( DefaultPhysicsWorldOption )
	if config['physics'] then
		table.extend( self.physicsOption, config['physics'] )
	end

	--
	self.globalManagers = getGlobalManagerRegistry()
	for i, manager in ipairs( self.globalManagers ) do
		manager:onInit( self )
	end

	local managerConfigs = config[ 'global_managers' ] or {}
	for i, manager in ipairs( self.globalManagers ) do
		local key = manager:getKey()
		local managerConfig = managerConfigs[ key ] or {}
		manager:loadConfig( managerConfig )
	end

	--input
	_stat( 'init input' )
	self.inputOption = table.simplecopy( DefaultInputOption )
	getDefaultInputDevice().allowTouchSimulation = self.inputOption[ 'allowTouchSimulation' ]

	self:initDefaultInputCommand()

end

function Game:initDefaultInputCommand()
	local keyUIMapping = {
		up              = { 'up'     },
		down            = { 'down'   },
		left            = { 'left'   },
		right           = { 'right'  },
		cancel          = { 'escape' },
		confirm         = { 'space', 'enter', 'return' },
	}

	local joyUIMapping = {
		up              = { 'up',    'L-up'    },
		down            = { 'down',  'L-down'  },
		left            = { 'left',  'L-left'  },
		right           = { 'right', 'L-right' },
		cancel          = { 'b' },
		confirm         = { 'x', 'a' },
	}

	defaultUIMappingConfig = {
		mappings = {
			keyboard = keyUIMapping,
			joystick = joyUIMapping,
		}
	} 
	
	local defaultUIMapping = mock.getInputCommandMappingManager():affirmMapping( 'defaultUI' )
	defaultUIMapping:load( defaultUIMappingConfig )

end

function Game:initLayers( config, fromEditor )
	--load layers
	_stat( '...setting up layers' )
	for i, data  in ipairs( config['layers'] or {} ) do
		local layer 

		if data['default'] then
			layer = self.defaultLayer
			layer.name = data['name']
		else
			layer = self:addLayer( data['name'] )
		end
		
		layer:setSortMode( data['sort'] )
		layer:setVisible( data['visible'] ~= false )
		layer:setEditorVisible( data['editor_visible'] ~= false )
		layer.parallax = data['parallax'] or {1,1}
		layer.priority = i
		layer:setLocked( data['locked'] )
	end

	table.sort( self.layers, 
		function( a, b )
			local pa = a.priority or 0
			local pb = b.priority or 0
			return pa < pb
		end )
	
	if fromEditor then
		local layer = self:addLayer( '_GII_EDITOR_LAYER' )
		layer.sortMode = 'priority_ascending'
		layer.priority = 1000000
	end
end

function Game:initAsset( config, fromEditor )
	
	self.assetLibraryIndex   = config['asset_library']
	self.textureLibraryIndex = config['texture_library']
	self.assetTagGroupList = config[ 'asset_tag_groups' ] or {}

	--misc
	setTextureThreadTaskGroupSize( 8 )
	
	--tag group
	for i, tag in ipairs( self.assetTagGroupList ) do
		registerAssetTagGroup( tag )
	end

	--assetlibrary
	_stat( '...loading asset library' )
	io.stdout:setvbuf("no")
	
	if self.assetLibraryIndex then
		if not MOAIFileSystem.checkFileExists( self.assetLibraryIndex ) then
			if fromEditor then
				--create empty asset-json
				_error( 'no asset table, create empty' )
				saveJSONFile( {}, self.assetLibraryIndex )
			end
		end
	
		if not loadAssetLibrary( self.assetLibraryIndex, not fromEditor ) then
			error( 'failed loading asset library' )
		end

	end

	if self.textureLibraryIndex then
		loadTextureLibrary( self.textureLibraryIndex )
	end
	
	--scriptlibrary
	_stat( '...loading game modules' )
	local scriptPatch = getG( 'MOCK_SCRIPT_LIBRARY_PATCH' ) or false
	loadAllGameModules( config['script_library'] or false, scriptPatch )
	-- MOAISim.forceGC( 1 )

	emitSignal( 'asset.init' )
	
end

function Game:initCommonDataFromEditor()
	local res = self:initCommonData( self.config, true )
	self.initialized = true
	return res
end

function Game:initCommonData( config, fromEditor )
	--load envrionment config
	_stat( '...loading envrionment configuration' )
	self:initEnvConfig()
	
	--
	self.globalManagers = getGlobalManagerRegistry()
	for i, manager in ipairs( self.globalManagers ) do
		manager:preInit( self )
	end

	self:initUserDataPath()
	
	--init asset
	self:initSubSystems ( config, fromEditor )
	
	--init layers
	self:initLayers     ( config, fromEditor )

	--load setting data
	_stat( '...loading setting data' )
	self.settingFileName = config['setting_file'] or 'setting'
	
	_log( '...use user data path:', self.userDataPath )
	local settingData = self:loadSettingData( self.settingFileName )
	self.settingData  = settingData or {}

	--init global objects
	_stat( '...loading global game objects' )
	self.globalObjectLibrary = getGlobalObjectLibrary()
	self.globalObjectLibrary:load( config['global_objects'] )

	--some post-processing for asset
	-- getTextureLibrary():clearEmptyNodes()

	--ask other systems to initialize
	emitSignal( 'game.init', config )


	--load scenes
	if config['scenes'] then
		for alias, scnPath in pairs( config['scenes'] ) do
			self.namedSceneMap[ alias ] = scnPath
		end
	end

	self.entryScene = config['entry_scene']
	self.initialScene = false

	_stat( '...init game done!' )
	

	--init scenes
	for i, sceneSession in ipairs( self.sceneSessions ) do
		sceneSession:init()
	end

	for i, manager in ipairs( self.globalManagers ) do
		manager:postInit( self )
	end

	if getG( 'MOCK_ON_GAME_INIT' ) then
		local func = getG( 'MOCK_ON_GAME_INIT' )
		func()
	end

	emitSignal( 'game.ready' )

	if getG('MOCK_ON_GAME_RESET') then
		local func = getG( 'MOCK_ON_GAME_RESET' )
		func()
	end
end

--------------------------------------------------------------------
function Game:getPlatformType()
	return getPlatformSupport():getType()
end

function Game:isPlatformType( ... )
	local t = getPlatformSupport():getType()
	for _, test in ipairs( {...} ) do
		if test == t then return true end
	end
	return false
end

function Game:getPlatformName()
	return getPlatformSupport():getName()
end

function Game:getPlatformSupport()
	return getPlatformSupport()
end

function Game:getPlatformCap( key, default )
	local v = self:getPlatformSupport():getCap( key )
	if v == nil then
		return default
	else
		return v
	end
end

--------------------------------------------------------------------
function Game:initUserDataPath()
	if MOCK_DEVELOPER_MODE then
		self.userDataPath = MOAIEnvironment.documentDirectory
	else
		local platform = getPlatformSupport()
		if self.name then
			self.userDataPath = platform:affirmAppDir( self.name, self.vendor, self.userId )
		end	
	end
	assert( self.userDataPath )

	if not ( MOCK_DEVELOPER_MODE or self.developerMode ) then
		if not MOCK_DISABLE_LOG then
			if self:getPlatformType() == 'desktop' then
				local logFileName = MOCK_LOG_FILE_NAME or 'game.log'
				mock.openLogFile( self:getUserDataPath( logFileName ) )
			end
		end
	end

end

--------------------------------------------------------------------
function Game:initEnvConfig()
	local env = table.simplecopy( _defaultEnvironment )
	local function _indexMOAIEnv( t, k )
		return MOAIEnvironment[ k ]
	end
	setmetatable( env, { __index = _indexMOAIEnv } )
	self.envConfig = env
	--load from setting
	local ENV_CONFIG_NAME = 'env.settings'
	if MOAIFileSystem.checkFileExists( ENV_CONFIG_NAME ) then
		_log( 'load envrionment setting from', ENV_CONFIG_NAME )
		local data = self:loadJSONData( ENV_CONFIG_NAME )
		if data then self:updateEnvConfig( data ) end
	end
end

function Game:updateEnvConfig( data )
	if type( data ) ~= 'table' then return end
	for k,v in pairs( data ) do
		self.envConfig[ k ] = v
	end
end

function Game:hasEnvConfig( key )
	local v = self.envConfig[ key ]
	return v ~= nil
end

function Game:getEnvConfig( key, default )
	local v = self.envConfig[ key ]
	if v == nil then return default end
	return v
end

function Game:setEnvConfig( key, v )
	self.envConfig[ key ] = v
end

--------------------------------------------------------------------
function Game:saveConfigToTable()
	--save layer configs
	local layerConfigs = {}
	for i,l in pairs( self.layers ) do
		if l.name ~= '_GII_EDITOR_LAYER'  then
			layerConfigs[i] = {
				name     = l.name,
				sort     = l.sortMode,
				visible  = l.visible,
				default  = l.default,
				locked   = l.locked,
				parallax = l.parallax,
				editor_visible  = l.editorVisible,
			}
		end
	end

	--save global manager configs
	local globalManagerConfigs = {}
	for i, manager in ipairs( getGlobalManagerRegistry() ) do
		local key = manager:getKey()
		local data = manager:saveConfig()
		if data then
			globalManagerConfigs[ key ] = data
		end
	end

	local data = {
		name           = self.name,
		vendor         = self.vendor,

		version        = self.version,
		title          = self.title,
		display_title  = self.displayTitles,
		default_locale = self.defaultLocale,
		
		asset_library  = self.assetLibraryIndex,
		asset_tag_groups  = self.assetTagGroupList,
		texture_library = self.textureLibraryIndex,

		graphics       = self.graphicsOption,
		physics        = self.physicsOption,
		audio          = self.audioOption,
		input          = self.inputOption,
		system         = self.systemOption,
		layers         = layerConfigs,
		
		scenes         = self.namedSceneMap,
		entry_scene    = self.entryScene,

		global_managers = globalManagerConfigs,
		global_objects  = self.globalObjectLibrary:save(),

	}

	emitSignal( 'game_config.save', data )
	return data
end

function Game:saveConfigToString()
	local data = self:saveConfigToTable()
	return encodeJSON( data )
end

function Game:saveConfigToFile( path )
	local data = self:saveConfigToTable()
	return self:saveJSONData( data, path, 'game config' )
end

function Game:loadGameConfig()
end

function Game:saveGameConfig()
	
end

function Game:saveJSONData( data, path, dataInfo )
	dataInfo = dataInfo or 'json'
	local output = encodeJSON( data )
	local file = io.open( path, 'w' )
	if file then
		file:write(output)
		file:close()
		_stat( dataInfo, 'saved to', path )
	else
		_error( 'can not save ', dataInfo , 'to' , path )
	end
end

function Game:loadJSONData( path, dataInfo )
	local file = io.open( path, 'rb' )
	if file then
		local str = file:read('*a')
		-- local str = MOAIDataBuffer.inflate( str )
		local data = MOAIJsonParser.decode( str )
		if data then
			_stat( dataInfo, 'loaded from', path )
			return data
		end
		_error( 'invalid json data for ', dataInfo , 'at' , path )
	else
		_error( 'file not found for ', dataInfo , 'at' , path )
	end
end

--------------------------------------------------------------------
-- get global manager by key
-- @p string key the name of global manager to find
-- @ret GlobalManager manager
--------------------------------------------------------------------
function Game:getGlobalManager( key )
	for i, manager in ipairs( self.globalManagers ) do
		if manager:getKey() == key then return manager end
	end
	return nil
end

--------------------------------------------------------------------
--------Graphics related
--------------------------------------------------------------------
function Game:initGraphics( option, fromEditor )
	assert( not self.graphicsInitialized )
	_stat( 'init graphics' )
	

	self.systemOption   = option['system'] or {}
	self.graphicsOption = option['graphics'] or {}
	
	local gfxOption = self.graphicsOption
	self.deviceRenderTarget = DeviceRenderTarget( MOAIGfxMgr.getFrameBuffer(), 1, 1 )
	self.deviceRenderTarget:setDebugName( "rawDeviceRT" )

	--TODO
	local w, h  = gfxOption['device_width'] or 0, gfxOption['device_height'] or 0
	if w * h == 0 then
		w, h = getDeviceResolution()
	end

	if w * h == 0 then
		_warn( 'no device size specified!' )
		w, h = 400, 300
	end

	self.targetDeviceWidth  = w
	self.targetDeviceHeight = h
	
	self.deviceRenderTarget:setPixelSize( w, h )

	self.width   = self.overridedOption[ 'width' ] or  gfxOption['width']  or w
	self.height  = self.overridedOption[ 'height' ] or  gfxOption['height'] or h
	self.initialFullscreen = gfxOption['fullscreen'] or false	

	_stat( 'setting up window callbacks' )
	MOAISim.setListener(
		MOAISim.EVENT_FOCUS_GET, 
		function()
			self:onFocusChanged( true )
		end
	)

	MOAISim.setListener(
		MOAISim.EVENT_FOCUS_LOST, 
		function()
			self:onFocusChanged( false )
		end
	)

	MOAIGfxMgr.setListener (
		MOAIGfxMgr.EVENT_RESIZE,
		function( width, height )	
			return self:onDeviceResize( width, height )
		end
	)

	MOAIGfxMgr.setListener ( 
		MOAIGfxMgr.EVENT_CONTEXT_DETECT, 
		function()
			return self:onGraphicsContextDetected()
		end
	)
	
	MOAIRenderMgr.setListener(
		MOAIRenderMgr.EVENT_PRE_SYNC_RENDER_STATE,
		function ()
			return self:preSyncRenderState()
		end
	)

	MOAIRenderMgr.setListener(
		MOAIRenderMgr.EVENT_POST_SYNC_RENDER_STATE,
		function ()
			return self:postSyncRenderState()
		end
	)


	local title = self:getDisplayTitle()
	_stat( 'opening window', title, w, h )

	self.focused = true
	
	if not fromEditor then
		--FIXME: crash here if no canvas shown up yet
		if self.graphicsContextReady then
			emitGlobalSignal( 'gfx.context_ready' )
		else
			MOAISim.openWindow( title, w, h  )
		end
		if self.initialFullscreen then
			self:enterFullscreenMode()
		end
	end

	self.renderManager:onInit()
	
	if MOAIAppNX then
		self.scaleFramebuffer = false
	else
		self.scaleFramebuffer = gfxOption[ 'scaled_output' ] ~= false
		-- self.scaleFramebuffer = false
	end

	if fromEditor then
		self.scaleFramebuffer = false
	end

	local baseClearRenderPass = createTableRenderLayer()
	if fromEditor then
		baseClearRenderPass:setClearColor( 0.1, 0.1, 0.1, 1 )
	else
		baseClearRenderPass:setClearColor( 0, 0, 0, 1 )
	end

	if self:getPlatformType() == 'console' then
		baseClearRenderPass:setClearMode( assert( MOAILayer.CLEAR_ONCE_TRIPLE ) )
	else
		baseClearRenderPass:setClearMode( MOAILayer.CLEAR_ALWAYS )
	end

	baseClearRenderPass:setFrameBuffer( MOAIGfxMgr.getFrameBuffer() )
	self.baseClearRenderPass = baseClearRenderPass
	-- self.clearingBase = 2

	self.graphicsInitialized = true
	self:hideSystemCursor()

	--create default render context
	self.gameRenderContext = GameRenderContext()
	self.gameRenderContext:setContentSize( self.width, self.height )
	self.gameRenderContext:setSize( self.width, self.height )

	if self.scaleFramebuffer then
		self.gameRenderContext:setOutputMode( 'scaled' )
	else
		self.gameRenderContext:setOutputMode( 'direct' )
	end

	self.renderManager:registerContext( 'game', self.gameRenderContext )

	--and graphicsInitialized
	if fromEditor then
		--context already created
		self:onGraphicsContextDetected()
	else
		if self.graphicsContextReady then
			return self:onRenderManagerReady()
		end
	end

	if self.pendingResize then
		_log( 'send pending resize' )
		pendingResize = self.pendingResize
		self.pendingResize = nil
		self:onDeviceResize( unpack( pendingResize ) )
	end

end

function Game:isGraphicsInitialized()
	return self.graphicsInitialized
end

function Game:setWindowSize( w, h )
	if self.editorMode then return end
	local title = self:getDisplayTitle()
	MOAISim.openWindow( title, w, h )
end

function Game:getRenderManager()
	return self.renderManager
end

function Game:initDebugUI()
	if mock.__nodebug then return end
	_stat( 'init debug ui' )
	local debugUIManager = getDebugUIManager()
	debugUIManager:init()
	debugUIManager:setEnabled( false )
	getLogViewManager():init()
	game:setDebugUIEnabled( true )
end

function Game:initCursor()
	_stat( 'init cursor manager' )
	getUICursorManager():init()
end

function Game:hasDebugLevel( key, default )
	local v = self:getDebugLevel( key, nil )
	if v == nil then
		return default or false
	end
	return v > 0
end

function Game:getDebugLevel( key, default )
	local v = self.debugLevels[ key ]
	if v == nil then return default end
	return v
end

function Game:setDebugLevel( key, level )
	if self.debugLevels[ key ] ~= level then
		assert( type( level ) == 'number' )
		self.debugLevels[ key ] = level
		emitGlobalSignal( 'game.debug_level_change', key, level )
	end
end

function Game:setDebugUIEnabled( enabled )
	if mock.__nodebug then return end
	getDebugUIManager():setEnabled( enabled )
end

function Game:isDebugUIEnabled()
	if mock.__nodebug then return false end
	return getDebugUIManager():isEnabled()
end

function Game:setLogViewEnabled( enabled )
	getLogViewManager():setEnabled( enabled )
end

function Game:isLogViewEnabled()
	return getLogViewManager():isEnabled()
end

function Game:clearLogView()
	getLogViewManager():clear()
end

function Game:setDeviceSize( w, h )
	if self.deviceWidth == w and self.deviceHeight == h then return end
	self.deviceWidth = w
	self.deviceHeight = h 
	_log( 'device.resize', w, h )
	self.deviceRenderTarget:setPixelSize( w, h )
	-- self.gameRenderContext:setContentSize( w, h )
	self.gameRenderContext:setSize( w, h )
	emitSignal( 'device.resize', self.width, self.height )
end

function Game:getDeviceResolution( )
	return self.deviceRenderTarget:getPixelSize()
end

function Game:getContentResolution()
	return self.gameRenderContext:getContentSize()
end

function Game:getTargetDeviceResolution()
	return self.targetDeviceWidth, self.targetDeviceHeight
end

function Game:getDeviceRenderTarget()
	return self.deviceRenderTarget
end

function Game:getOutputViewport()
	return self.gameRenderContext:getOutputViewport()
end

function Game:getMainRenderTarget()
	return self.gameRenderContext:getRenderTarget()
end

function Game:getDeviceFrameBuffer()
	return self.deviceRenderTarget:getFrameBuffer()
end

function Game:getMainFrameBuffer()
	return self:getMainRenderTarget():getFrameBuffer()
end

function Game:onDeviceResize( w, h )
	self:callOnSyncingRenderState( function()
		if not self.graphicsInitialized then
			self.pendingResize = { w, h }
			return
		end	
		self:setDeviceSize( w, h )
		self:clearDeviceBufferBase()
	end )
end

function Game:onGraphicsContextDetected()
	_stat( 'system graphics context ready!' )
	--deferred graphics activation
	emitGlobalSignal( 'gfx.context_ready' )
	self.graphicsContextReady = true
	if self.graphicsInitialized then
		return self:onRenderManagerReady()
	end
end

function Game:isSyncingRenderState()
	if MOAIRenderMgr.isAsync() then
		return self.syncingRenderState
	else
		return true
	end
end

function Game:callOnSyncingRenderState( f, ... )
	if self:isSyncingRenderState() then
		return f( ... )
	else
		return getRenderManager():addPostSyncRenderCall( f, ... )
	end
end

function Game:preSyncRenderState()
	if MOAIRenderMgr.isAsync() then
		self.taskManager:onUpdate()
		self:postRender()
	end
	self.syncingRenderState = true
	emitGlobalSignal( 'gfx.pre_sync_render_state' )
end

function Game:postSyncRenderState()
	emitGlobalSignal( 'gfx.post_sync_render_state' )
	self:updateSceneSessions()
	self.syncingRenderState = false
end

function Game:onRenderManagerReady()
	self.renderManager:onContextReady()
	self.gameRenderContext:makeCurrent()
end

function Game:onFocusChanged( focused )
	self.focused = focused or false
	emitSignal( 'app.focus_change', self.focused )
end

function Game:getPreRenderTable()
	return self.preRenderTable
end

function Game:getPostRenderTable()
	return self.postRenderTable
end

--------------------------------------------------------------------
------Scene Sessions
--------------------------------------------------------------------
function Game:getSceneSession( key )
	return self.sceneSessionMap[ key ]
end

function Game:affirmSceneSession( key, initialScene )
	local session = self.sceneSessionMap[ key ]
	if not session then
		session = SceneSession()
		session.name = key
		self.sceneSessionMap[ key ] = session
		table.insert( self.sceneSessions, session )
		self.sceneSessionCount = #self.sceneSessions
		if self.initialized then
			session:init()
		end
		if self.started then
			session:start()
		end
		emitGlobalSignal( 'scene_session.add', key )
	end

	if initialScene and not session:isSceneReady() then
		session:openSceneByPathNow( initialScene )
	end

	return session
end

function Game:getScene( key )
	local session = self:getSceneSession( key )
	return session and session:getScene()
end

function Game:getMainSceneSession()
	return self:getSceneSession( 'main' )
end

function Game:getMainSceneManager( key )
	local mainScene = self:getMainScene()
	if mainScene then
		return mainScene:getManager( key )
	end
	return nil
end

function Game:removeSceneSession( key )
	local session = self:getSceneSession( key )
	if not session then
		_error( 'no scene session found', key )
		return false
	end
	session:stop()
	session:clear()
	self.sceneSessionMap[ key ] = nil
	emitGlobalSignal( 'scene_session.remove', key )
	local idx = table.index( self.sceneSessions, session )
	table.remove( self.sceneSessions, idx )
	self.sceneSessionCount = #self.sceneSessions
	--TODO: clear
	return true

end

--------------------------------------------------------------------
------Scene control
--------------------------------------------------------------------
function Game:openEntryScene()
	if self.entryScene then
		self:openSceneByPath( self.entryScene )
		self:start()
	end
end

function Game:openScene( id, additive, arguments, autostart )
	local scnPath = self.namedSceneMap[ id ]
	if not scnPath then
		return _error( 'scene not defined', id )
	end
	return self:openSceneByPath( scnPath, additive, arguments, autostart )
end

function Game:scheduleOpenScene( id, additive, arguments, autostart )
	local scnPath = self.namedSceneMap[ id ]
	if not scnPath then
		return _error( 'scene not defined', id )
	end	
	return self:scheduleOpenSceneByPath( scnPath, additive, arguments, autostart ) 
end

--------------------------------------------------------------------
function Game:openSceneByPath( scnPath, additive, arguments, autostart )
	return self:getMainSceneSession():openSceneByPath( scnPath, additive, arguments, autostart ) 
end

function Game:openSceneByPathNow( scnPath, additive, arguments, autostart )
	return self:getMainSceneSession():openSceneByPathNow( scnPath, additive, arguments, autostart ) 
end

function Game:scheduleOpenSceneByPath( scnPath, additive, arguments, autostart )
	return self:getMainSceneSession():scheduleOpenSceneByPath( scnPath, additive, arguments, autostart ) 
end

function Game:getPendingSceneData()
	return self:getMainSceneSession():getPendingSceneData()
end

function Game:getMainScene()
	return self.mainScene
end

function Game:reopenMainScene( arguments )
	return self:getMainSceneSession():reopenScene( arguments )
end

function Game:scheduleReopenMainScene( arguments )
	return self:getMainSceneSession():scheduleReopenScene( arguments )
end

--------------------------------------------------------------------
------Layer Control
--------------------------------------------------------------------
function Game:addLayer( name, addPos )
	addPos = addPos or 'last'
	local l = Layer( name )
	
	if addPos == 'last' then
		local s = #self.layers
		local last = s > 0 and self.layers[ s ]
		if last and last.name == '_GII_EDITOR_LAYER' then
			table.insert( self.layers, s, l )
		else
			table.insert( self.layers, l )
		end
	else
		table.insert( self.layers, 1, l )
	end
	return l
end

function Game:removeLayer( layer )
	local i = table.index( self.layers, layer )
	if not i then return end
	table.remove( self.layers, i )
end

function Game:getLayer( name )
	for i, l in ipairs( self.layers ) do
		if l.name == name then return l end
	end
	return nil
end

function Game:getLayers()
	return self.layers
end

--------------------------------------------------------------------
------Action related
--------------------------------------------------------------------

--------------------------------------------------------------------
-- get game clock
-- @ret float time in seconds
--------------------------------------------------------------------
function Game:getTime()
	return self.time
end

function Game:getTimer()
	return self.timer
end

function Game:getRenderDuration()
	if MOCKHelper then
		return MOCKHelper.getRenderDuration()
	else
		return -1
	end
end

function Game:getRenderSyncDuration()
	if MOCKHelper then
		return MOCKHelper.getRenderSyncDuration()
	else
		return -1
	end
end

function Game:getSimDuration()
	if MOCKHelper then
		return MOCKHelper.getSimDuration()
	else
		return -1
	end
end

--------------------------------------------------------------------
-- get total frame count
-- @ret int frame count
--------------------------------------------------------------------
function Game:getFrame()
	return self.frame
end

function Game:preSyncRender( )
	self:preSyncRenderState()
end

function Game:postRender( )
	self:postSyncRenderState()
	-- if self.clearingBase then
	-- 	self.clearingBase = self.clearingBase - 1
	-- 	if self.clearingBase <= 0 then
	-- 		self.clearingBase = false
	-- 		self.baseClearRenderPass:setEnabled( false )
	-- 	end
	-- else
		-- if self.skipFrame then
		-- 	MOAIRenderMgr.setRenderDisabled( true )
		-- end
	-- end
end

function Game:newSubClock()
	return newClock(function()
		return self.time
	end)
end

local clock = MOAISim.getDeviceTime
function Game:preRootUpdate()
	local t = clock()
	self.prevClock = t
	self._preUpdateClock = clock()

	local pendingCall = self.pendingCall
	if #pendingCall > 0 then
		self.pendingCall = {}
		for i, t in ipairs( pendingCall ) do
			local func = t.func
			if type( func ) == 'string' then --method call
				local object = t.object
				func = object[ func ]
				func( object, unpack(t) )
			else
				func( unpack(t) )
			end
		end
	end
	
end

function Game:preSysRootUpdate()
	local f = self.updateSystemGlobalManagerFunc
	if f then
		f()
	end
end

function Game:postRootUpdate()
	local t1 = clock()
	self.prevUpdateTime = t1 - self._preUpdateClock
end

local boostCountdown = 0
function Game:onRootUpdate( delta )
	self.time = self.time + delta
	self.frame = self.frame + 1
	local skipFrame = self.skipFrame
	if skipFrame then
		self.skippedFrame = self.skippedFrame + 1
		if self.skippedFrame > skipFrame then
			self.skippedFrame = 0
			MOAIRenderMgr.setRenderDisabled( false )
		else
			MOAIRenderMgr.setRenderDisabled( true )
		end
	end


	self.updateGlobalManagerFunc( delta )
	-- print( '--------------------------------------------------------------------')
	-- print( 'NEWFRAME' )
	-- print( '--------------------------------------------------------------------')

	--deferred boost loading stop
	local boosting = self.boostLoadLock > 0
	if boosting ~= self.boostLoading then
		if boostCountdown > 0 then
			boostCountdown = boostCountdown - 1
		else
			self.boostLoading = boosting
			if MOAIAppNX then
				MOAIAppNX.setCpuBoostMode( 
					boosting and MOAIAppNX.CPU_BOOST_MODE_FASTLOAD or MOAIAppNX.CPU_BOOST_MODE_NORMAL
				)
			end
			boostCountdown = 4
		end
	end

	if self.pendingCommitSaveData then
		--wait if save_data busy
		if not isTaskGroupBusy( 'save_data' ) then
			self:getPlatformSupport():commitSaveData()
			self.pendingCommitSaveData = false
		end
	end
	
end

function Game:onSceneRootUpdate( delta )
	if not MOAIRenderMgr.isAsync() then
		self:updateSceneSessions( delta )
	end
end

function Game:updateSceneSessions( delta )
	local sessions = self.sceneSessions
	for i = 1, self.sceneSessionCount do
		sessions[ i ]:update( delta )
	end
end

function Game:resetClock()
	self.time = 0
end

function Game:setUpdateRate( rate )
	self.updateRate = rate
	self.updateStep = 1/rate
	MOAISim.setStep( self.updateStep )
end

function Game:setRenderRate( rate )
	self.renderRate = rate
	MOAIRenderMgr.setRenderRate( rate )
end

function Game:getRenderRate()
	return self.renderRate
end

function Game:resume()
	if not self.paused then return end
	self.paused = false
	self.actionRoot:pause( false )
	emitSignal( 'game.resume', self )
end

function Game:pause( p )
	if p == false then
		return self:resume()
	end
	if self.paused then return end 
	self.paused = true
	self.actionRoot:pause()
	emitSignal( 'game.pause', self )
end

function Game:resumeSceneRoot( p )
	if not self.scenePaused then return end 
	self.scenePaused = false
	self.sceneActionRoot:pause( false )
	emitSignal( 'scene_root.resume', self )
end

function Game:pauseSceneRoot( p )
	if p == false then return self:resumeSceneRoot() end
	if self.scenePaused then return end 
	self.scenePaused = true
	self.sceneActionRoot:pause( true  )
	emitSignal( 'scene_root.pause', self )
end

function Game:stopApplication()
	MOAISim.stop()
end

function Game:stop()
	_stat( 'game stop' )
	for i, manager in ipairs( self.globalManagers ) do
		manager:onStop( self )
	end
	for i, session in ipairs( self.sceneSessions ) do
		session:stop()
		session:clear( true )
	end
	getAudioManager():stop() 
	self:resetClock()
	emitSignal( 'game.stop', self )
	_stat( 'game stopped' )
	self.started = false
end

function Game:start()
	self:startBoostLoading()
	assert( not self.started )
	_stat( 'game start' )
	self.started = true
	
	local updatingGlobalManagers = {}
	local updatingSystemGlobalManagers = {}
	for i, manager in ipairs( self.globalManagers ) do
		manager:onStart( self )
		if manager.onUpdate then
			manager.onUpdate = manager.onUpdate
			table.insert( updatingGlobalManagers, manager )
		end

		if manager.onSysUpdate then
			manager.onSysUpdate = manager.onSysUpdate
			table.insert( updatingSystemGlobalManagers, manager )
		end
	end

	local async = MOAIRenderMgr.isAsync()
	local updatingGlobalManagersCount = #updatingGlobalManagers
	self.updateGlobalManagerFunc = function( dt )
		for i = 1, updatingGlobalManagersCount do
			updatingGlobalManagers[ i ]:onUpdate( self, dt )
		end
	end

	local updatingSystemGlobalManagersCount = #updatingSystemGlobalManagers
	self.updateSystemGlobalManagerFunc = function()
		for i = 1, updatingSystemGlobalManagersCount do
			updatingSystemGlobalManagers[ i ]:onSysUpdate( self )
		end
		if not async then
			self.taskManager:onUpdate()
		end
	end

	self.paused = false
	for i, session in ipairs( self.sceneSessions ) do
		session:start()
	end
	if self.paused then
		emitSignal( 'game.resume', self )
	else
		emitSignal( 'game.start', self )
	end
	_stat( 'game started' )

	if getG( 'MOCK_ON_GAME_START' ) then
		local func = getG( 'MOCK_ON_GAME_START' )
		func()
	end

	self:getActionRoot():pause( false )


	for i, manager in ipairs( self.globalManagers ) do
		manager:postStart( self )
	end

	MOAIEnvironment.setListener( MOAIEnvironment.EVENT_VALUE_CHANGED, function( key, value )
		return self:onEnvChange( key, value )
	end )

	self:resetSimTime()
	self:stopBoostLoading()
end

function Game:isInitialized()
	return self.initialized
end

function Game:isPaused()
	return self.paused
end

local insert = table.insert
function Game:callNextFrame( f, ... )
	local t = {
		func = f,
		...
	}
	insert( self.pendingCall, t )
end

function Game:getActionRoot()
	return self.actionRoot
end

function Game:getSceneActionRoot()
	return self.sceneActionRoot
end

function Game:addCoroutine( func, ... )
	local routine = MOAICoroutine.new()
	routine:run( func, ... )
	routine:attach( self:getActionRoot() )
	return routine
end

function Game:setThrottleFactor( key, factor )
	local tt = type( factor )
	assert( tt == 'number' or tt == 'nil' )
	self.throttleFactors[ key ] = factor
	self:updateThrottle()
end

function Game:getThrottleFactor( key )
	return self.throttleFactors[ key ]
end

function Game:setThrottle(v)
	self.baseThrottle = v
	self:updateThrottle()
end

function Game:getActualThrottle()
	return self.throttle
end

function Game:updateThrottle()
	local totalFactor = 1
	for key, factor in pairs( self.throttleFactors ) do
		if factor then totalFactor = totalFactor * factor end
	end
	self.throttle = self.baseThrottle * totalFactor
	return self.actionRoot:throttle( self.throttle )
end

function Game:setLoopFlags( flags )
	MOAISim.clearLoopFlags()
	self.loopFlags = flags
	return MOAISim.setLoopFlags( flags )
end

function Game:getStepMultiplier( multiplier )
	return self.stepMultiplier
end

function Game:setStepMultiplier( multiplier )
	multiplier = multiplier or 1
	self.stepMultiplier = multiplier
	if self.forceStep then return end
	MOAISim.setStepMultiplier( multiplier )	
end

function Game:startForceStep( multiplier )
	if self.forceStep then return end
	self.forceStep = true
	self.forceStepMultiplier = multiplier or self.stepMultiplier
	MOAISim.setLoopFlags( MOAISim.SIM_LOOP_FORCE_STEP )
	MOAISim.setStepMultiplier( self.forceStepMultiplier )	
end

function Game:stopForceStep()
	if not self.forceStep then return end
	self.forceStep = false
	MOAISim.setLoopFlags( self.loopFlags )
	MOAISim.setStepMultiplier( self.stepMultiplier )	
end

function Game:setSkipFrame( skip )
	if skip == false then
		skip = false
	elseif type( skip ) == 'number' then
		if skip <= 0 then
			skip = false
		end
	else
		return
	end
	if not skip then
		self.skipFrame = false
	else
		self.skipFrame = skip
	end
	MOAIRenderMgr.setRenderDisabled( false )
end

function Game:forceUpdate()
	
end

--------------------------------------------------------------------
---------Global object( config? )
--------------------------------------------------------------------

function Game:getGlobalObjectLibrary()
	return self.globalObjectLibrary
end

function Game:getGlobalObject( path )
	return self.globalObjectLibrary:get( path )
end

---------------------------------------------------------------------
--------------------------------------------------------------------
function Game:getConfig( key, default )
	local data = self.config[ key ]
	if data == nil then return default end
	return data
end

function Game:setConfig( key, value ) --for test purpose mostly
	self.config[ key ] = value
end

function Game:getInfo()
	return {
		title   = self:getConfig( 'title' ),
		version = self:getConfig( 'version' ),
		locale  = getActiveLocale(),
	}
end

function Game:getDisplayTitle()
	local locale = getActiveLocale()
	local title
	title = self.displayTitles[ locale ] or self.title
	return title
end

--------------------------------------------------------------------
---------Data settings
--------------------------------------------------------------------
function Game:updateSetting( key, data, persistLater )
	self.settingData[key]=data
	if not persistLater then
		self:saveSettingData( self.settingData, self.settingFileName )
	end
end

function Game:getSetting(key)
	return self.settingData[key]
end

function Game:getUserDataPath( path )
	if not path then return self.userDataPath end
	return self.userDataPath .. '/' ..path
end

function Game:affirmUserDataPath( path, isfile )
	if not MOAIFileSystem.checkPathExists( self.userDataPath ) then 
		_error( 'user data path not exists', self.userDataPath )
		return false
	end
	local dir = isfile and dirname( path ) or path
	local fullPath = self.userDataPath .. '/' .. path
	local fullDir = self.userDataPath .. '/' .. dir

	if MOAIFileSystem.checkPathExists( fullDir ) then
		return fullPath
	else
		--FIXME: workaround for ???
		MOAIFileSystem.affirmPath( fullDir )
		if MOAIFileSystem.checkPathExists( fullDir ) then
			return fullPath
		else
			return false
		end
	end
end

function Game:affirmUserDataFilePath( filename )
	return self:affirmUserDataPath( filename, true )
end


function Game:checkUserDataExists( path )
	local fullPath = self:getUserDataPath( path )
	return MOAIFileSystem.checkFileExists( fullPath )
end

function Game:copyUserData( src, dst )
	local pSrc, pDst = self:getUserDataPath( src ), self:getUserDataPath( dst )
	if MOAIFileSystem.checkFileExists( pSrc ) then
		local data = MOAIFileSystem.loadFile ( pSrc )
		return MOAIFileSystem.saveFile ( pDst, data )
		-- return MOAIFileSystem.copy( pSrc, pDst )
	end
	return false
end

function Game:renameUserData( src, dst )
	local pSrc, pDst = self:getUserDataPath( src ), self:getUserDataPath( dst )
	if MOAIFileSystem.checkFileExists( pSrc ) then
		return MOAIFileSystem.rename( pSrc, pDst )
	end
	return false
end

function Game:removeUserData( path )
	local fullPath = self:getUserDataPath( path )
	if MOAIFileSystem.checkFileExists( fullPath ) then
		MOAIFileSystem.deleteFile( fullPath )
		return true
	elseif MOAIFileSystem.checkPathExists( fullPath ) then
		MOAIFileSystem.deleteDirectory( fullPath, true )
		return true
	end
	return false
end	

function Game:commitSaveData()
	self.pendingCommitSaveData = true
	emitSignal( 'game.commit_savedata' )
end

function Game:saveSettingData( data, filename )
	local raw  = encodeJSON( data )
	local filepath = self:affirmUserDataFilePath( filename )
	if not filepath then return false end

	AsyncDataSaveTask( raw, filepath ):start()
	-- local db = MOAIDataBuffer.new()
	-- db:setString( raw )
	-- db:save( filepath )

	-- local file = io.open( filepath, 'wb' )
	-- if not file then
	-- 	_error( 'cannot write to file', filepath )
	-- 	return false
	-- end
	-- file:write( raw )
	-- file:close()
	--todo: exceptions?
	return true
end

function Game:addUserDataPath(  )
	-- body
end

function Game:tryLoadSettingData( filename )
	local path = self:getUserDataPath( filename )
	if not MOAIFileSystem.checkFileExists( path ) then return false end
	return self:loadSettingData( filename )
end

function Game:loadSettingData( filename )
	_stat( '...reading setting data from:', filename )
	local file = io.open( self:getUserDataPath( filename ) , 'rb' )
	if file then
		local raw = file:read('*a')
		file:close()
		-- local str = MOAIDataBuffer.inflate( raw )
		return MOAIJsonParser.decode( raw )
	else
		return nil
	end
end

local function _getHash( raw, key )
	local hashWriter = MOAIHashWriter.new()
	hashWriter:openWhirlpool()
	hashWriter:write( raw )
	if key then hashWriter:write( key ) end
	hashWriter:close()
	local hash = hashWriter:getHash()
	return hash
end

function Game:packSettinData( data, dataFormat )
	local str
	if dataFormat == 'msgpack' then
		str = MOAIMsgPackParser.encode( data )
	else
		str  = encodeJSON( data )
	end
	return MOAIDataBuffer.deflate( str )
end

function Game:packSafeSettingData( data, safekey, dataFormat )
	local raw = self:packSettinData( data, dataFormat )
	local hash = _getHash( raw, safekey )
	return hash .. raw
end

function Game:saveSafeSettingDataToPath( data, fullPath, key, dataFormat )
	local raw = self:packSafeSettingData( data, key, dataFormat )
	AsyncDataSaveTask( raw, fullPath ):start()
	-- local buf = MOAIDataBuffer.new() 
	-- buf:setString( raw )
	-- buf:save( fullPath )

	-- local file = io.open( fullPath, 'wb' )
	-- file:write( raw )
	-- file:close()
	return true
end

function Game:saveSafeSettingData( data, filename, key, dataFormat )
	local fullPath = self:affirmUserDataFilePath( filename )
	return self:saveSafeSettingDataToPath( data, fullPath, key, dataFormat )	
end

function Game:tryLoadSafeSettingData( filename, key, dataFormat )
	local path = self:getUserDataPath( filename )
	if not MOAIFileSystem.checkFileExists( path ) then return false end
	return self:loadSafeSettingData( filename, key, dataFormat )
end

function Game:loadSafeSettingDataPacked( packedData, key, dataFormat )
	local hash = packedData:sub( 1, 64 )
	local raw  = packedData:sub( 65, -1 )
	local str  = MOAIDataBuffer.inflate( raw )
	if not str then
		_warn( 'cannot extract data' )
		return nil
	end

	local hash1 = _getHash( raw, key )
	local match = hash == hash1
	local data
	if dataFormat == 'msgpack' then
		data = MOAIMsgPackParser.decode( str )
	else
		data = MOAIJsonParser.decode( str )
	end
	return data, match
end

function Game:loadSafeSettingData( filename, key, dataFormat )
	_stat( '...reading setting data from:', filename )
	local path = self:getUserDataPath( filename )
	return self:loadSafeSettingDataFromPath( path, key, dataFormat )
end 

function Game:tryLoadSafeSettingDataFromPath( fullPath, key, dataFormat )
	if not MOAIFileSystem.checkFileExists( fullPath ) then return false end
	return self:loadSafeSettingDataFromPath( fullPath, key, dataFormat )
end

function Game:loadSafeSettingDataFromPath( fullPath, key, dataFormat )
	local stream = MOAIFileStream.new()
	if stream:open( fullPath, MOAIFileStream.READ ) then
		local hash = stream:read( 64 )
		local raw  = stream:read()
		local str  = MOAIDataBuffer.inflate( raw )
		stream:close()
		if not str then
			_warn( 'cannot extract data', fullPath )
			return nil
		end
		local hash1 = _getHash( raw, key )
		local match = hash == hash1
		local data
		local ok
		if dataFormat == 'msgpack' then
			ok, data = pcall( MOAIMsgPackParser.decode, str )
		else
			ok, data = pcall( MOAIJsonParser.decode, str )
		end
		return data, match
	else
		_warn( 'no file to open', fullPath )
		return nil
	end
end


--------------------------------------------------------------------
-- get user defined object
-- @p string key key to the userdata
-- @p value default default return value if no userdata is found
-- @ret value
--------------------------------------------------------------------
function Game:getUserObject( key, default )
	local v = self.userObjects[ key ]
	if v == nil then return default end
	return v
end

function Game:setUserObject( key , v )
	self.userObjects[ key ] = v
end

function Game:getUserConfig( key, default )
	local v = self.userConfig[ key ]
	if v == nil then return default end
	return v
end

function Game:setUserConfig( key , v )
	self.userConfig[ key ] = v
end

-------------------------
function Game:setDebugEnabled( enabled )
	if mock.__nodebug then return end
	--todo
end

--------------------------------------------------------------------
--Context Related
--------------------------------------------------------------------
function Game:getMainRenderContext()
	return self.gameRenderContext
end

function Game:clearDeviceBufferBase()	
	if self.baseClearRenderPass then
		if self:getPlatformType() == 'console' then
			_log( 'clearing device buffer' )
			self.baseClearRenderPass:setClearMode( assert( MOAILayer.CLEAR_ONCE_TRIPLE ) )
		else
			self.baseClearRenderPass:setClearMode( MOAILayer.CLEAR_ALWAYS )
		end
	end
end

function Game:setCurrentRenderContext( key )
	self.currentRenderContext = key or 'game'
end

function Game:getCurrentRenderContext()
	return self.currentRenderContext or 'game'
end

function Game:isDeveloperMode()
	return self.developerMode
end

function Game:isEditorMode()
	return self.editorMode
end

function Game:setGCStep( step )
	return MOAISim.setGCStep( step )
end

function Game:setGCStepLimit( limit )
	return MOAISim.setGCStepLimit( limit )
end

function Game:addGCExtraStep( step )
	return MOAISim.addGCExtraStep( step )
end

function Game:collectgarbage( ... )
	collectgarbage( ... )
end

function Game:getOutputScale()
	if self.fullscreen then
		return 1/self.fullscreenScale
	else
		return 1
	end
end

function Game:setFullscreenScale( scl )
	self.fullscreenScale = scl
	self:updateFullscreenScale()
end

function Game:updateFullscreenScale()
	local scl = 1
	if self.fullscreen then
		scl = self.fullscreenScale
	end
	if self:getMainRenderContext() then
		self:getMainRenderContext():setOutputScale( scl )
		self:clearDeviceBufferBase()
		getUICursorManager():updateViewport()
	end
end

function Game:setFullscreen( fullscreen )
	if not self.graphicsInitialized then return end
	if fullscreen then
		self:enterFullscreenMode()
	else
		self:exitFullscreenMode()
	end
end

function Game:isFullscreenMode()
	return self.fullscreen
end

function Game:enterFullscreenMode()
	if self.fullscreen then return end
	if self:isEditorMode() then return end
	MOAISim.enterFullscreenMode()
	self.fullscreen = true
	self:updateFullscreenScale()
	emitGlobalSignal( 'gfx.fullscreen_change', true )

end

function Game:exitFullscreenMode()
	if not self.fullscreen then return end
	if self:isEditorMode() then return end
	MOAISim.exitFullscreenMode()
	self.fullscreen = false
	self:updateFullscreenScale()
	emitGlobalSignal( 'gfx.fullscreen_change', false )
	
end

function Game:hideCursor( reason )
	return getUICursorManager():hide( reason )
end

function Game:showCursor( reason )
	if MOAIEnvironment.osBrand == 'NS' then return end
	return getUICursorManager():show( reason )
end

function Game:hideSystemCursor( reason )
	reason = reason or 'default'
	self.showSystemCursorReasons[ reason ] = nil
	if not next( self.showSystemCursorReasons ) then
		MOAISim.hideCursor()
	end
end

function Game:showSystemCursor( reason )
	reason = reason or 'default'
	self.showSystemCursorReasons[ reason ] = true
	MOAISim.showCursor()
end

function Game:isRelativeMouseMode()
	return self.relativeMouseMode
end

function Game:setRelativeMouseMode( enabled )
	if MOAISim.setRelativeMouseMode then
		self.relativeMouseMode = enabled ~= false	
		MOAISim.setRelativeMouseMode( self.relativeMouseMode )
		getUICursorManager():setRelativeMouseMode( self.relativeMouseMode )
		emitGlobalSignal( 'input.mouse.mode_change', self.relativeMouseMode )
	else
		_error( 'realtiveMouseMode not supported' )
		self.realtiveMouseMode = false

	end
end

function Game:getClipboard()
	return MOAISim.getClipboard()
end

function Game:setClipboard( text )
	return MOAISim.setClipboard( text )
end

function Game:startTextInput()
	local c0 = self.textInputLockCounter
	self.textInputLockCounter = c0 + 1
	if c0 <= 0 then
		_warn( 'START text input' )
		-- print( debug.traceback() )
		return MOAISim.startTextInput()
	end
end

function Game:stopTextInput()
	local c0 = self.textInputLockCounter
	self.textInputLockCounter = c0 + 1
	if self.textInputLockCounter <= 0 then
		return MOAISim.stopTextInput()
	end
end

function Game:setTextInputRect( x, y, x1, y1 )
	return MOAISim.setTextInputRect( x, y, x1, y1 )
end

function Game:startBoostLoading()
	self.boostLoadLock = self.boostLoadLock + 1
	_log( 'boost loading',self.boostLoadLock )
	local boosting = self.boostLoadLock > 0
	if not self.boostLoading then
		self.boostLoading = true
		if MOAIAppNX then
			MOAIAppNX.setCpuBoostMode( assert( MOAIAppNX.CPU_BOOST_MODE_FASTLOAD ) )
		end
	end
end

function Game:stopBoostLoading()
	self.boostLoadLock = self.boostLoadLock - 1
	_log( 'boost loading',self.boostLoadLock )
	--will stop boosting in onRootUpdate
end

function Game:onEnvChange( key, value )
	return emitGlobalSignal( 'app.env_change', key, value )
end

function Game:_testEnvChange( id )
	if id == 'network_none' then
		MOAIEnvironment.setValue( 'connectionType', MOAIEnvironment.CONNECTION_TYPE_NONE )
	elseif id == 'network_wifi' then
		MOAIEnvironment.setValue( 'connectionType', MOAIEnvironment.CONNECTION_TYPE_WIFI )
	elseif id == 'network_wwan' then
		MOAIEnvironment.setValue( 'connectionType', MOAIEnvironment.CONNECTION_TYPE_WWAN )
	end
end

local _game = Game()
_M.game = _game


--------------------------------------------------------------------
--short cuts
function getGlobalObject( key )
	return _game:getGlobalObject( key )
end

function getGlobalManager( key )
	return _game:getGlobalManager( key )
end
