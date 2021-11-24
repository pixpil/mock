module 'mock'

CLASS: TextureSphere ( GraphicsPropComponent )
	:MODEL{
		Field 'radius' :on_set( 'updatePolygon' );
		Field 'subdivision' :on_set( 'updatePolygon' );
		Field 'texture' :asset_pre('texture;render_target') :getset( 'Texture' );

}

registerComponent( 'TextureSphere', TextureSphere )
mock.registerEntityWithComponent( 'TextureSphere', TextureSphere )


function TextureSphere:__init()
	self.radius = 50
	self.subdivision = 1
	self.polygonReady = false
	self.mesh = false
end

function TextureSphere:onAttach( ent )
	TextureSphere.__super.onAttach( self, ent )
	self:updatePolygon()
end

function TextureSphere:getTexture()
	return self.texture
end

function TextureSphere:setTexture( t )
	self.texture = t
	local tex = loadAsset( self.texture )
	if tex then
		self.prop:setTexture( tex:getMoaiTexture() )
	end
end

local append = table.append
function TextureSphere:updatePolygon()
	if not self._entity then return end
	self.mesh = mock.MeshHelper.makeICOSphere( self.radius, self.subdivision )
	self.prop:setDeck( self.mesh )
end

--------------------------------------------------------------------
local defaultMeshShader = MOAIShaderMgr.getShader( MOAIShaderMgr.MESH_SHADER )

function TextureSphere:getDefaultShader()
	return defaultMeshShader
end
