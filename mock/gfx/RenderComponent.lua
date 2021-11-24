module 'mock'

CLASS: RenderComponent( Component )
	:MODEL{
		Field 'material' :asset_pre( 'material' ) :getset( 'Material' );
	}
	:META{
		category = 'graphics'
	}

--------------------------------------------------------------------
local DEPTH_TEST_DISABLE = MOAIProp.DEPTH_TEST_DISABLE
function RenderComponent:__init()
	self.materialPath     = false
	self.material         = false

	self.blend            = 'normal'
	self.shader           = false
	self.billboard        = false
	self.depthMask        = false
	self.depthTest        = DEPTH_TEST_DISABLE

end

function RenderComponent:getMaterial()
	return self.materialPath
end

function RenderComponent:getDefaultRenderMaterial()
	return getDefaultRenderMaterial()
end

function RenderComponent:setMaterial( path )
	if isAdHocAsset( path ) then
		self.materialPath = false
	else
		self.materialPath = path
	end
	local material = self:loadAsset( path, nil, true, self )
	material = material or self:getDefaultRenderMaterial()
	local materialInstance = material and material:affirmInstance( self ) 
	self.materialInstance = materialInstance
	return self:applyMaterial( materialInstance )
end

function RenderComponent:getMaterialInstance()
	if not self.materialInstance then
		self.materialInstance = self:getDefaultRenderMaterial():affirmInstance( self )
	end
	return self.materialInstance
end

function RenderComponent:getMaterialObject()
	return self.material or self:getDefaultRenderMaterial()
end

function RenderComponent:getEntity()
	return self._entity
end

function RenderComponent:getBlend()
	return self.blend
end

function RenderComponent:setBlend( b )
	self.blend = b	
end

function RenderComponent:setShader( s )
	self.shader = s
end

function RenderComponent:getShader( s )
	return self.shader
end

function RenderComponent:resetMaterial()
	if self.material then
		self:applyMaterial( self.material or self:getDefaultRenderMaterial() )
	end
end

function RenderComponent:setVisible( f )
end

function RenderComponent:isVisible()
	return true
end

function RenderComponent:setDepthMask( enabled )
	self.depthMask = enabled
end

function RenderComponent:setDepthTest( mode )
	self.depthTest = mode
end

function RenderComponent:setBillboard( billboard )
	self.billboard = billboard
end

function RenderComponent:applyMaterial( material )
end

function RenderComponent:onSuspend( suspendState )
	suspendState.visible = self:isVisible()
	self:setVisible( false )
end

function RenderComponent:onResurrect( suspendState )
	self:setVisible( suspendState.visible )
end

