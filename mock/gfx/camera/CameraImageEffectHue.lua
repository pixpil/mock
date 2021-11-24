module 'mock'


--------------------------------------------------------------------
CLASS: CameraImageEffectHue ( CameraImageEffect )
    :MODEL{
        Field 'hueOffset' :float() :onset( 'updateHueOffset' ) :meta{ step = 0.1 };
    }

function CameraImageEffectHue:__init()
    self.hueOffset = 0
end

function CameraImageEffectHue:onBuild( prop, layer )
    local shaderScriptHue = loadMockAsset( 'shader/image_effect/Hue.shader_script' )
    self.shader = assert( shaderScriptHue:affirmDefaultShader() )
    prop:setShader( self.shader:getMoaiShader() )
    self:updateHueOffset()
end

function CameraImageEffectHue:updateHueOffset()
    if not self.shader then return end
    self.shader:setAttr( 'hueOffset', self.hueOffset )
end

function CameraImageEffectHue:setHueOffset( h )
    self.hueOffset = h
    self:updateHueOffset()
end

mock.registerComponent( 'CameraImageEffectHue', CameraImageEffectHue )