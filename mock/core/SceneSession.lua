module 'mock'

local _currentLoadingSceneSession = false
local _currentLoadingScene = false

function getCurrentLoadingScene()
	return _currentLoadingScene
end

function getCurrentLoadingSceneSession()
	return _currentLoadingSceneSession
end

function getCurrentLoadingSceneSessionName()
	local session = _currentLoadingSceneSession
	if session then return session:getName() end
	return false
end
--------------------------------------------------------------------
CLASS: SceneSession ()
	:MODEL{}

function SceneSession:__init()
	self.scene = Scene()
	self.scene.session = self
	self.initialized = false
	self.initialScene = false
	self.name = false
	self.main = false
	self.skippingFrames = false
	self.pendingLoading = false
	self.currentSceneResourceHolder = false
end

function SceneSession:__tostring()
	return string.format( '%s@%s', self:__repr(), tostring( self.name ) )
end


function SceneSession:getName()
	return self.name
end

function SceneSession:init()
	if self.initialized then return end
	self.initialized = true
	self.scene:init()
end

function SceneSession:getPath()
	return self.scene and self.scene:getPath()
end

function SceneSession:_openSceneByPath( scnPath, additive, arguments, autostart )
	_stat( 'openning scene:', scnPath )
	game:startBoostLoading()
	
	if not self.initialScene then
		self.initialScene = scnPath
	end
	local scene = self.scene
	if not additive then
		scene.assetPath = scnPath
	end
	autostart = autostart ~= false
	
	_currentLoadingScene = scene
	_currentLoadingSceneSession = self

	local fromEditor = arguments and arguments[ 'fromEditor' ] or false
	-- game:addGCExtraStep( 10000 )
	getGlobalResourceHolder():weakReleaseAllAssets()
	if not additive then
		scene:stop()
		scene:clear( true )
		-- if self.main then
		-- 	collectAssetGarbage()
		-- end
		-- flushAssetClear()
		scene:reset()
		-- reportAssetLoadTimers()
	end

	if self.main then
		local _renderGroup = MOAINodeMgr.getRenderGroup()
		_renderGroup:update()
	end

	-- if self.main and ( not game:isEditorMode() ) then
	-- 	MOAISim.forceGC(1)
	-- end

	--load arguments first
	local args = scene.arguments or {}
	if not additive then args = {} end
	if arguments then
		for k,v in pairs( arguments ) do
			args[ k ] = v
		end
	end

	--todo: previous scene
	scene.arguments = args and table.simplecopy( args ) or {}

	--load entities
	local runningState = scene.running
	scene.running = false --start entity in batch
	
	scene:setPreloadResourceHolder( false )

	scene.path = scnPath
	scene:notifyPreload()
	
	local preloadResourceHolder = scene:getPreloadResourceHolder()
	if self.currentSceneResourceHolder ~= preloadResourceHolder then
		local prevHolder = self.currentSceneResourceHolder
		self.currentSceneResourceHolder = preloadResourceHolder
		if prevHolder then
			_stat( 'release preload holder', prevHolder, preloadResourceHolder, scene )
			prevHolder:releaseAllAssets()
		end
	end

	setDefaultResourceHolder( scene )
	local scn, node = loadAsset(
		scnPath, 
		{ 
			scene = scene,
			allowConditional = not fromEditor,
			preloadResourceHolder = preloadResourceHolder
		}
	)

	--failed to load?
	if not node then 
		game:stopBoostLoading()
		return _error('scene not found', scnPath )

	elseif node.type ~= 'scene' then
		game:stopBoostLoading()
		return _error('invalid type of entry scene:', tostring( node.type ), scnPath )

	end

	--post open
	scene.running = runningState

	emitGlobalSignal( 'scene.open', scn, arguments )
	if self.main then
		emitGlobalSignal( 'mainscene.open', scn, arguments )
	end

	scene:notifyLoad( scnPath )

	if autostart then
		scn:start()
	end

	emitGlobalSignal( 'scene.start', scn, arguments )
	if self.main then
		emitGlobalSignal( 'mainscene.start', scn, arguments )
	end

	_currentLoadingScene = false
	_currentLoadingSceneSession = false
	
	getGlobalResourceHolder():flushWeakRelease()
	flushAssetClear()
	
	getTaskManager():update()	
	
	if self.main and ( not game:isEditorMode() ) then
		if scn.comment ~= 'no_force_gc' then			
			MOAISim.forceGC(1)
		end
		local _renderGroup = MOAINodeMgr.getRenderGroup()
		_renderGroup:update()
		-- local _updateGroup = MOAINodeMgr.getUpdateGroup()
		-- _updateGroup:update()
	end

	game:stopBoostLoading()

	return scn
end

function SceneSession:openSceneByPathNow( scnPath, additive, arguments, autostart )
	return self:_openSceneByPath( scnPath, additive, arguments, autostart )
end

function SceneSession:openSceneByPath( scnPath, additive, arguments, autostart )
	return self:scheduleOpenSceneByPath( scnPath, additive, arguments, autostart )
end

function SceneSession:scheduleOpenSceneByPath( scnPath, additive, arguments, autostart )
	_stat( 'schedule openning scene:', scnPath )
	autostart = true
	
	if self.pendingLoading then
		_warn( 'multiple scene-open at same time requested.', self )
	end

	self.pendingLoading = { 
		['path']      = scnPath,
		['additive']  = additive,
		['arguments'] = arguments,
		['autostart'] = autostart
	}
	
	emitGlobalSignal( 'scene.schedule_open', self.pendingLoading )
	if self.main then
		emitGlobalSignal( 'mainscene.schedule_open', self.pendingLoading )
	end

end

function SceneSession:reopenScene( arguments )
	_stat( 're-openning scene' )
	if not self.scene then return false end
	local assetPath = self.scene.assetPath
	if assetPath then
		return self:openSceneByPath( assetPath, false,arguments )
	else
		return false
	end
end

function SceneSession:scheduleReopenScene( arguments )
	_stat( 'schedule re-openning scene' )
	if not self.scene then return false end
	local assetPath = self.scene.assetPath
	if assetPath then
		return self:scheduleOpenSceneByPath( assetPath, false, arguments )
	else
		return false
	end
end

function SceneSession:clearPendingScene()
	self.pendingLoading = false
end

function SceneSession:getPendingSceneData()
	return self.pendingLoading
end

function SceneSession:getScene()
	return self.scene
end

function SceneSession:skipFrames( f )
	f = f or 1
	if self.skippingFrames and self.skippingFrames >= f then return end
	if self.skippingFrames and self.skippingFrames > self.lastSkippingFrames/2 then return end
	
	self.lastSkippingFrames = f
	self.skippingFrames = f
	if f > 0 then
		self.scene:pause( true, 'skip_frame' )
	end
	
end

function SceneSession:update()
	if self.pendingLoading then
		local loadingParams = self.pendingLoading
		self.pendingLoading = false
		self:_openSceneByPath( 
			loadingParams['path'],
			loadingParams['additive'],
			loadingParams['arguments'],
			loadingParams['autostart']
		)
	end

	local f = self.skippingFrames
	if f then
		f = f - 1
		if f > 0 then
			self.scene:pause( true, 'skip_frame' )
			self.skippingFrames = f
		else
			self.scene:pause( false, 'skip_frame' )
			self.skippingFrames = false
		end
	end
end

function SceneSession:start()
	return self.scene:start()
end

function SceneSession:stop()
	return self.scene:stop()
end

function SceneSession:stopAndClear( keepEditorObjects )
	self.scene:stop()
	self.scene:clear( keepEditorObjects )
end

function SceneSession:clear( keepEditorObjects )
	return self.scene:clear( keepEditorObjects )
end

function SceneSession:isSceneReady()
	return self.scene and self.scene.ready
end

function SceneSession:isRunning()
	return self.scene and self.scene:isRunning()
end

function SceneSession:pause( paused )
	return self.scene:pause( paused )
end

function SceneSession:isPaused()
	return self.scene:isPaused()
end
