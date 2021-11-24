module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectBrightness ( CameraImageEffect )
	:MODEL{
		Field 'strength' :getset( 'Strength' ) :meta{ step = 0.1 };
}

function CameraImageEffectBrightness:__init()
	self.strength = 0.1
	self.shader = false
end

function CameraImageEffectBrightness:getStrength()
	return self.strength
end

function CameraImageEffectBrightness:setStrength( strength )
	self.strength = strength
	self:updateParam()
end

function CameraImageEffectBrightness:onBuild( prop, layer )
	local shaderScriptBrightness = loadMockAsset( 'shader/image_effect/Brightness.shader_script' )
	self.shader = assert( shaderScriptBrightness:affirmDefaultShader() )
	prop:setShader( self.shader:getMoaiShader() )
	self:updateParam()
end

function CameraImageEffectBrightness:updateParam()
	if not self.shader then return end
	self.shader:setAttr( 'strength', self.strength )
end

mock.registerComponent( 'CameraImageEffectBrightness', CameraImageEffectBrightness )
