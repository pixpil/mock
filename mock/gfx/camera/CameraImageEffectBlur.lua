module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectBlur ( CameraImageEffect )
	:MODEL{
		Field 'intensity' :float() :step( 0.1 ) :getset( 'Intensity' );
	}

function CameraImageEffectBlur:__init()
	self.intensity = 1
end

function CameraImageEffectBlur:onBuild( prop, layer )
	local shaderScriptBlur = loadMockAsset( 'shader/image_effect/Blur.shader_script' )
	self.shader = assert( shaderScriptBlur:affirmDefaultShader() )
	prop:setShader( self.shader:getMoaiShader() )
	self:updateParam()
end

function CameraImageEffectBlur:setIntensity( i )
	self.intensity = i
	self:updateParam()
end

function CameraImageEffectBlur:getIntensity()
	return self.intensity
end

function CameraImageEffectBlur:updateParam()
	if not self.shader then return end
	self.shader:setAttr( 'intensity', self.intensity )
end


mock.registerComponent( 'CameraImageEffectBlur', CameraImageEffectBlur )