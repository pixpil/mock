module 'mock'
--------------------------------------------------------------------
CLASS: CameraPass ()
	:MODEL{}

function CameraPass:__init()
	self.camera = false
	self.renderLayers = {}
	self.renderTarget  = false
	self.renderTargets = {}
	self.passes = {}
	self.currentRenderTarget = false
	self.defaultRenderTarget = false
	self.outputRenderTarget  = false
end

function CameraPass:init( camera )
	self.camera = camera
	self.outputRenderTarget = camera:getRenderTarget()

	if camera.hasImageEffect then
		self.defaultRenderTarget = self:buildRenderTarget( nil, self.outputRenderTarget )
	else
		self.defaultRenderTarget = self.outputRenderTarget
	end

	self:onInit()
end

function CameraPass:release()
	self:onRelease()
end

function CameraPass:onRelease()
	for key, renderTarget in pairs( self.renderTargets ) do
		renderTarget:clear()
	end
end

function CameraPass:build()
	self.passes = {}
	self:onBuild()
	self:buildImageEffects()
	return self.passes
end

function CameraPass:onInit()
end

function CameraPass:onBuild()
end

function CameraPass:getCamera()
	return self.camera
end

function CameraPass:getDefaultRenderTarget()
	return self.defaultRenderTarget
end

function CameraPass:getCurrentRenderTarget()
	return self.currentRenderTarget
end

function CameraPass:getOutputRenderTarget()
	return self.outputRenderTarget
end

function CameraPass:pushPassData( data )
	data[ 'camera' ] = self:getCamera()
	table.insert( self.passes, data )
end

function CameraPass:pushRenderLayer( layer, renderTarget, option )
	if not layer then 
		_error( 'no render layer given!' )
		return
	end
	if renderTarget or option then
		self:pushRenderTarget( renderTarget, option )
	end
	self:pushPassData {
		tag   = 'layer',
		layer = layer
	}
	return layer
end

function CameraPass:pushRenderTarget( renderTarget, option )
	if type( renderTarget ) == 'string' then
		local renderTargetName = renderTarget
		renderTarget = self:getRenderTarget( renderTargetName )
		if not renderTarget then
			_error( 'render target not found:', renderTargetName )
		end
	end

	local renderTarget = renderTarget or self:getDefaultRenderTarget()
	self.currentRenderTarget = renderTarget
	assert( isInstance( renderTarget, RenderTarget ) )
	--
	self:pushPassData { 
		tag          = 'render-target',
		renderTarget = renderTarget,
		option       = option 
		}
end

function CameraPass:findPreviousRenderTarget()
	for i = #self.passes, 1, -1 do
		local pass = self.passes[ i ]
		if pass.tag == 'render-target' then
			return pass.renderTarget
		end
	end
	return nil
end

function CameraPass:pushOverridedShader( shader )
	local moaiShader = nil
	if type( shader ) == 'string' then --path
		shader = mock.loadAsset( shader )
	end
	if shader then
		if shader:getClassName() == 'MOAIShader' then
			moaiShader = shader
		else
			moaiShader = shader:getMoaiShader()
		end
	end
	self:pushCallback( function()
		MOAIGfxDevice.setOverridedShader( moaiShader )
	end)
end


----
--Render Targets
function CameraPass:requestRenderTarget( name, option )
	name = name or 'default'
	local renderTarget = self.renderTargets[ name ]
	if renderTarget then return renderTarget end
	renderTarget = self:buildRenderTarget( option )
	renderTarget.__name = name
	self.renderTargets[ name ] = renderTarget
	return renderTarget
end

function CameraPass:getRenderTarget( name )
	return self.renderTargets[ name ]
end

function CameraPass:getRenderTargetTexture( name )
	local target = self.renderTargets[ name ]
	return target and target:getFrameBuffer()
end

function CameraPass:clearRenderTargets()
	for name, renderTarget in pairs( self.renderTargets ) do
		renderTarget:release()
	end
	self.renderTargets = {}
end

function CameraPass:buildRenderTarget( option, srcRenderTarget )
	local renderTarget = TextureRenderTarget()
	renderTarget:initFrameBuffer( option )
	srcRenderTarget = srcRenderTarget or self:getDefaultRenderTarget()
	srcRenderTarget:addSubViewport( renderTarget )
	return renderTarget
end


function CameraPass:buildDebugDrawLayer()
	local camera   = self.camera
	if not camera.showDebugLines then return nil end
	local layer    = MOAILayer.new()
	layer.priority = 100000

	layer:setViewport  ( camera:getMoaiViewport() )
	layer:setCamera    ( camera._camera )

	layer._mock_camera = camera

	layer:showDebugLines( true )
	
	local renderTable = {}

	local world = self.camera.scene:getBox2DWorld()
	world:setDebugDrawEnabled( true )
	table.insert( renderTable, world )

	layer:setOverlayTable( renderTable )
	-- if world then layer:setBox2DWorld( world ) end

	return layer
end


function CameraPass:applyCameraToMoaiLayer( layer, option )	
	local camera   = self.camera
	layer:setViewport ( self.currentRenderTarget:getMoaiViewport() )
	layer:setCamera   ( camera._camera )
	return layer
end

function CameraPass:buildSceneLayerRenderLayer( sceneLayer, option )	
	local camera   = self.camera
	local allowEditorLayer = option and option.allowEditorLayer
	if not camera:isLayerIncluded( sceneLayer.name, allowEditorLayer ) then return false end
	local includeLayer = option and option.include
	local excludeLayer = option and option.exclude
	
	if includeLayer and not table.index( includeLayer, sceneLayer.name ) then return false end
	if excludeLayer and table.index( excludeLayer, sceneLayer.name ) then return false end
	local source   = sceneLayer.source
	local layer    = MOAILayer.new()
	
	layer.name     = sceneLayer.name
	layer.priority = -1
	layer.source   = source

	layer:showDebugLines( false )
	layer:setPartition ( sceneLayer:getPartition() )
	
	if option and option.viewport then
		layer:setViewport  ( option.viewport )
	else
		layer:setViewport  ( self:getCurrentRenderTarget():getMoaiViewport() )
	end

	if option and option.transform then
		layer:setCamera  ( option.transform )
	else
		layer:setCamera  ( camera._camera )
	end

	if camera.parallaxEnabled and source.parallax then
		layer:setParallax( unpack(source.parallax) )
	end
	
	if sceneLayer.sortMode then
		layer:setSortMode( sceneLayer.sortMode )
	end

	inheritVisible( layer, sceneLayer )
	layer._mock_camera = camera

	if camera.FLAG_EDITOR_OBJECT then		
		local src = sceneLayer.source
		local visible = src.editorVisible and src.editorSolo~='hidden'
		if not visible then layer:setVisible( false ) end
	end

	return layer
end

function CameraPass:buildSimpleOrthoRenderLayer()
	local camera   = self.camera
	local w, h = 1, 1
	
	local viewport = Viewport()
	viewport:setMode( 'relative' )
	viewport:setFixedScale( w, h )
	
	local renderTarget = self:getDefaultRenderTarget()
	viewport:setParent( self:getDefaultRenderTarget() )

	local layer = MOAILayer.new()
	layer:setViewport( viewport:getMoaiViewport() )

	local quadCamera = MOAICamera.new()
	quadCamera:setOrtho( true )
	quadCamera:setNearPlane( -100000 )
	quadCamera:setFarPlane( 100000 )

	layer:setCamera( quadCamera )
	layer.width  = w
	layer.height = h
	return layer, w, h 
end

function CameraPass:buildSimpleQuadProp( w, h, texture, shader )
	local quad = MOAIGfxQuad2D.new()
	quad:setRect( -w/2, -h/2, w/2, h/2 )
	quad:setUVRect( 0,0,1,1 )
	local quadProp = MOAIProp.new()
	quadProp:setDeck( quad )

	if texture then quad:setTexture( texture ) end
	if shader  then quad:setShader( shader )   end

	return quadProp, quad
end

function CameraPass:buildSingleQuadRenderLayer( texture, shader )
	local layer, w, h = self:buildSimpleOrthoRenderLayer()
	local prop, quad = self:buildSimpleQuadProp( w, h, texture, shader )
	layer:insertProp( prop )
	layer.prop = prop
	return layer, prop, quad
end

function CameraPass:buildCallbackRenderLayer( func )
	local camera   = self.camera
	local dummyProp = MOAIProp.new()
	local dummyDeck = MOAIScriptDeck.new()
	dummyProp:setDeck( dummyDeck )
	dummyDeck:setDrawCallback( func )
	return dummyProp
end

function CameraPass:pushGfxPass( passId )
	self:pushRenderLayer( self:buildCallbackRenderLayer( function()
		MOAIGfxDevice.setPass( passId )
	end) )
end

function CameraPass:pushCallback( func )
	self:pushRenderLayer( self:buildCallbackRenderLayer( func ) )
end


function CameraPass:pushSceneRenderPass( option )
	local camera = self.camera
	local scene  = camera.scene

	for id, sceneLayer in ipairs( scene.layers ) do
		local name  = sceneLayer.name
		local p = self:buildSceneLayerRenderLayer( sceneLayer, option )
		if p then
			self:pushRenderLayer( p )
		end
	end
end


function CameraPass:pushEditorLayerPass()
	local camera = self.camera
	local scene  = camera.scene

	for id, sceneLayer in ipairs( scene.layers ) do
		local name  = sceneLayer.name
		if name == '_GII_EDITOR_LAYER' then
			local p = self:buildSceneLayerRenderLayer( sceneLayer, { allowEditorLayer = true } )
			if p then
				self:pushRenderLayer( p )
			end
			break
		end
	end
end

function CameraPass:buildImageEffects()
	if not self.camera.hasImageEffect then return end
	
	local defaultRenderTarget = self:getDefaultRenderTarget()
	local outputRenderTarget = self.outputRenderTarget
	assert( defaultRenderTarget ~= outputRenderTarget )

	local imageEffects = self.camera.imageEffects
	local effectPassCount = 0
	for i, effect in ipairs( self.camera.imageEffects ) do
		effectPassCount = effectPassCount + effect:getPassCount()
	end

	local backbuffer  = defaultRenderTarget
	local frontbuffer = outputRenderTarget
	if effectPassCount > 1 then --need backbuffer
		frontbuffer = self:requestRenderTarget( 'image-effect-backbuffer', self.outputRenderTarget )
	end

	local totalEffectPassId = 0
	for i, imageEffect in ipairs( imageEffects ) do
		local passCount = imageEffect:getPassCount()
		
		for pass = 1, passCount do
			totalEffectPassId = totalEffectPassId + 1
			if totalEffectPassId == effectPassCount then
				--last one output to output buffer
				frontbuffer = outputRenderTarget
			end
			self.defaultRenderTarget = frontbuffer
			self:pushRenderTarget( frontbuffer )
			local result = imageEffect:buildCameraPass( self, backbuffer:getFrameBuffer(), pass )			
			--swap double buffer
			backbuffer, frontbuffer = frontbuffer, backbuffer
		end

	end

	self.defaultRenderTarget = defaultRenderTarget
end


--------------------------------------------------------------------
CLASS: SceneCameraPass ( CameraPass )
 	:MODEL{} 

function SceneCameraPass:__init( clear, clearColor )
	self.clearBuffer = clear ~= false
	self.clearColor  = clearColor or false
end

function SceneCameraPass:onBuild()
	local camera = self:getCamera()
	local fb0 = self:getDefaultRenderTarget()
	if not self.clearBuffer then
		self:pushRenderTarget( fb0, { clearColor = false } )
	else
		self:pushRenderTarget( fb0, { clearColor = self.clearColor } )
	end
	self:pushSceneRenderPass()

	local debugLayer = self:buildDebugDrawLayer()
	if debugLayer then
		self:pushRenderLayer( debugLayer )
	end

	if camera:isEditorCamera() then
		self:pushEditorLayerPass()
	end

end

--------------------------------------------------------------------
CLASS: CallbackCameraPass ( CameraPass )
	:MODEL{}

function CallbackCameraPass:onBuild()
	local function callback( ... )
		return self:onDraw( ... )
	end
	self:pushRenderLayer( self:buildCallbackRenderLayer( callback ) )
end

function CallbackCameraPass:onDraw( ... )
end
