module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectSharpen ( CameraImageEffect )
	:MODEL{
		Field 'intensity' :float() :step( 0.1 ) :getset( 'Intensity' );
}

function CameraImageEffectSharpen:__init()
	self.intensity = 1
end

function CameraImageEffectSharpen:onBuild( prop, layer )
	local shaderScriptSharpen = loadMockAsset( 'shader/image_effect/Sharpen.shader_script' )
	self.shader = assert( shaderScriptSharpen:affirmDefaultShader() )
	prop:setShader( self.shader:getMoaiShader() )
	self:updateParam()
end

function CameraImageEffectSharpen:setIntensity( i )
	self.intensity = i
	self:updateParam()
end

function CameraImageEffectSharpen:getIntensity()
	return self.intensity
end

function CameraImageEffectSharpen:updateParam()
	if not self.shader then return end
	self.shader:setAttr( 'intensity', self.intensity )
end


mock.registerComponent( 'CameraImageEffectSharpen', CameraImageEffectSharpen )