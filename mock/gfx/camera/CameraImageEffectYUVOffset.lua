module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectYUVOffset ( CameraImageEffect )
	:MODEL{
		Field 'intensity' :getset( 'Intensity' );
}

function CameraImageEffectYUVOffset:__init()
	self.intensity = 1
end

function CameraImageEffectYUVOffset:onBuild( prop, texture, layer )
	local shaderScriptYUVOffset = loadMockAsset( 'shader/image_effect/ColorDispering.shader_script' )
	self.shader = assert( shaderScriptYUVOffset:affirmDefaultShader() )
	prop:setShader( self.shader:getMoaiShader() )
	self.shader:setAttr( 'intensity', self.intensity or 1 )
end

function CameraImageEffectYUVOffset:getIntensity()
	return self.intensity
end

function CameraImageEffectYUVOffset:setIntensity( intensity )
	self.intensity = intensity
	if self.shader then
		self.shader:setAttr( 'intensity', self.intensity or 1 )
	end
end

mock.registerComponent( 'CameraImageEffectYUVOffset', CameraImageEffectYUVOffset )