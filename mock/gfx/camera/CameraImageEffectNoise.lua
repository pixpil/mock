module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectNoise ( mock.CameraImageEffect )
	:MODEL{
		Field 'intensity' :meta{ step = 0.1 };
}

function CameraImageEffectNoise:__init()
	self.intensity = 1
end

function CameraImageEffectNoise:onStart()
	self._entity.scene:addUpdateListener( self )
end

function CameraImageEffectNoise:onDetach( entity )
	entity.scene:removeUpdateListener( self )
end

function CameraImageEffectNoise:onBuild( prop, texture, layer, passId )
  local shaderScriptNoise = loadMockAsset( 'shader/image_effect/Noise.shader_script' )
	self.shader = assert( shaderScriptNoise:affirmDefaultShader() )
	prop:setShader( self.shader:getMoaiShader() )
end

function CameraImageEffectNoise:setIntensity( intensity )
	self.intensity = intensity
end

local t = 0
function CameraImageEffectNoise:onUpdate( dt )
	t = t + dt
	local fps = 10
	self.shader:setAttr( 'time',  math.floor( t*fps ) /fps )
	self.shader:setAttr( 'intensity', self.intensity )
end


registerComponent( 'CameraImageEffectNoise', CameraImageEffectNoise )
