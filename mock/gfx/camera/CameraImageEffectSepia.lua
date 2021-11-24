module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectSepia ( CameraImageEffect )
	:MODEL{
		Field 'intensity' :onset( 'updateIntensity' ) :meta{ step = 0.1 };
}

function CameraImageEffectSepia:__init()
	self.intensity = 1
	self.shader = false
end

function CameraImageEffectSepia:onBuild( prop, layer )
	local shaderScriptSepia = loadMockAsset( 'shader/image_effect/Sepia.shader_script' )
	self.shader = assert( shaderScriptSepia:affirmDefaultShader() )
	prop:setShader( self.shader:getMoaiShader() )
	self:updateIntensity()
end

function CameraImageEffectSepia:setIntensity( i )
	self.intensity = i or 1
	return self:updateIntensity()
end

function CameraImageEffectSepia:updateIntensity()
	if not self.shader then return end
	self.shader:setAttr( 'intensity', self.intensity )
end

mock.registerComponent( 'CameraImageEffectSepia', CameraImageEffectSepia )
