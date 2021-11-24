module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectGrayScale ( CameraImageEffect )
	:MODEL{
		Field 'intensity' :onset( 'updateIntensity' ) :meta{ step = 0.1 };
}

function CameraImageEffectGrayScale:__init()
	self.intensity = 1
	self.shader = false
end

function CameraImageEffectGrayScale:onBuild( prop, texture, layer, passId )
	local shaderScriptGrayscale = loadMockAsset( 'shader/image_effect/Grayscale.shader_script' )
	self.shader = assert( shaderScriptGrayscale:affirmDefaultShader() )
	prop:setShader( self.shader:getMoaiShader() )
	self:updateIntensity()
end

function CameraImageEffectGrayScale:setIntensity( i )
	self.intensity = i or 1
	return self:updateIntensity()
end

function CameraImageEffectGrayScale:updateIntensity()
	if not self.shader then return end
	self.shader:setAttr( 'intensity', self.intensity )
end

mock.registerComponent( 'CameraImageEffectGrayScale', CameraImageEffectGrayScale )