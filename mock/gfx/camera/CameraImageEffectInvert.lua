module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectInvert ( CameraImageEffect )
	:MODEL{}

function CameraImageEffectInvert:onBuild( prop, frameBuffer, layer, passId )
  local shaderScriptInvert = loadMockAsset( 'shader/image_effect/Invert.shader_script' )
  local shader = assert( shaderScriptInvert:affirmDefaultShader() )
	prop:setShader( shader:getMoaiShader() )
end


mock.registerComponent( 'CameraImageEffectInvert', CameraImageEffectInvert )