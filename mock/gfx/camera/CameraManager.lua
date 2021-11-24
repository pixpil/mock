module 'mock'


--------------------------------------------------------------------
local function prioritySortFunc( a, b )	
	local pa = a.priority or 0
	local pb = b.priority or 0
	return pa < pb
end

--------------------------------------------------------------------
CLASS: CameraManager ()
	:MODEL{}

function CameraManager:__init()
	self.cameras    = {}
	self.cameraGroups = {}
end

function CameraManager:register( cam )
	local context = cam:getRenderContext()
	local group = self.cameraGroups[ context ]
	if not group then
		group = {}
		self.cameraGroups[ context ] = group
	end
	assert( not table.index( group, cam ), 'camera already registered')
	table.insert( group, cam )
	self:updateCameraGroup( context )
end

function CameraManager:unregister( cam )
	local context = cam:getRenderContext()
	local group = self.cameraGroups[ context ]
	if not group then
		_error( 'no context found in camera manager' )
		return
	end
	local idx = table.index( group, cam )
	if idx then
		table.remove( group, idx )
	end
	self:updateCameraGroup( context )
	if not next( group ) then
		self.cameraGroups[ context ] = nil --remove
	end
end

--------------------------------------------------------------------
function CameraManager:updateCameraGroup( context )
	local group = self.cameraGroups[ context ]
	table.sort( group, prioritySortFunc )
	local renderTable = {}
	for i, cam in ipairs( group ) do
		assert( cam._renderContext == context )
		renderTable[ i ] = cam:getRenderPass()
		table.insert( renderTable, cam:buildRenderPass() )
	end

	game:callOnSyncingRenderState( function()
		return context:setRenderTable( renderTable )
	end )
	
end

function CameraManager:updateAllCameraGroups()
	for context, _ in pairs( self.cameraGroups ) do
		self:updateCameraGroup( context )
	end
end

function CameraManager:updateLayerVisible()
	for _, group in pairs( self.cameraGroups ) do
		for _, cam in ipairs( group ) do
			cam:updateLayerVisible()
		end
	end
end

function CameraManager:onLayerUpdate( layer, var )
	if var == 'priority' then
		for _, group in pairs( self.cameraGroups ) do
			for _, cam in ipairs( group ) do
				cam:reorderRenderLayers()
			end
		end
		self:updateAllCameraGroups() --need to rebuild rendertable

	elseif var == 'editor_visible' or var == 'visible' then
		self:updateLayerVisible()

	end
end

---------------------------------------------------------------------


---------------------------------------------------------------------
--Singleton
local cameraManager = CameraManager()
connectSignalFunc( 'layer.update',  function(...) cameraManager:onLayerUpdate  ( ... ) end )

function getCameraManager()
	return cameraManager
end

