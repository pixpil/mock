module 'mock'
--------------------------------------------------------------------
CLASS: TopOverlayManager ( GlobalManager )
	:MODEL{}

function TopOverlayManager:onInit()
	connectGlobalSignalMethod( 'device.resize', self, 'onDeviceResize' )
	local layer = createPartitionRenderLayer()
	local viewport = MOAIViewport.new ()
	layer:setViewport( viewport )
	layer:setFrameBuffer( MOAIGfxMgr.getFrameBuffer() )

	self.viewport = viewport
	self.renderLayer = layer

	local quadCamera = MOAICamera.new()
	quadCamera:setOrtho( true )
	quadCamera:setNearPlane( -100000 )
	quadCamera:setFarPlane( 100000 )

	layer:setCamera( quadCamera )
end

function TopOverlayManager:onStart( game )
	self:updateViewport()
end

function TopOverlayManager:getRenderLayer()
	return assert( self.renderLayer )
end

function TopOverlayManager:insertProp( prop )
	prop:setPartition( self.renderLayer )
	return prop
end

function TopOverlayManager:removeProp( prop )
	prop:setPartition()
end

function TopOverlayManager:updateViewport()
	local w, h = game:getDeviceResolution()
	self.viewport:setSize ( w,h )
	self.viewport:setScale ( w,h )
	self.viewport:setOffset ( -1,1 )
end

function TopOverlayManager:onDeviceResize( w, h )
	self:updateViewport()
end

---------------------------------------------------------------------
local _TopOverlayManager = TopOverlayManager()
function getTopOverlayManager()
	return _TopOverlayManager
end
