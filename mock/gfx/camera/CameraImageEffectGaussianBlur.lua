module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectGaussianBlur ( CameraImageEffect )
	:MODEL{}

function CameraImageEffectGaussianBlur:getPassCount()
	return 2
end

function CameraImageEffectGaussianBlur:onBuild( prop, frameBuffer, layer, passId )
	local shaderScriptBlur = loadMockAsset( 'shader/image_effect/GaussianBlur.shader_script' )
	if passId == 1 then
		local shader = shaderScriptBlur:getSubConfig( 'passH' ):affirmDefaultShader()
		prop:setShader( assert( shader:getMoaiShader()) )
	elseif passId == 2 then
		local shader = shaderScriptBlur:getSubConfig( 'passV' ):affirmDefaultShader()
		prop:setShader( assert( shader:getMoaiShader()) )
	end
end


mock.registerComponent( 'CameraImageEffectGaussianBlur', CameraImageEffectGaussianBlur )