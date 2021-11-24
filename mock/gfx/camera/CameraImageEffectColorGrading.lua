module 'mock'

--------------------------------------------------------------------
CLASS: CameraImageEffectColorGrading ( CameraImageEffect )
	:MODEL{
		Field 'LUT'  :asset( 'texture;color_grading;lut_texture' ) :getset( 'LUT' );
		Field 'LUT2' :asset( 'texture;color_grading;lut_texture' ) :getset( 'LUT2' );
		Field 'mix'  :onset( 'updateMix' ) :range(0,1) :meta{ step = 0.1 } :widget('slider');
		Field 'intensity' :onset( 'updateIntensity' ) :meta{ step = 0.1 };
		Field 'gamma' :onset( 'updateGamma' ) :meta{ step = 0.1 };
}

local _ColorGradings = {}
function refreshColorGradingTextures()
	for g in pairs( _ColorGradings ) do
		g:updateTex()
	end
end

function CameraImageEffectColorGrading:__init()
	self.intensity = 1
	self.lutPath = false
	self.lutPath2 = false
	self.lutTex1  = false
	self.lutTex2  = false
	self.size1 = 32
	self.size2 = 32
	self.mix   = 0
	self.gamma = 0
	self.material = MOAIMaterialBatch.new()
end

function CameraImageEffectColorGrading:onAttach( ent )
	CameraImageEffectColorGrading.__super.onAttach( self, ent )
	_ColorGradings[ self ] = true
end

function CameraImageEffectColorGrading:onDetach( ent )
	CameraImageEffectColorGrading.__super.onDetach( self, ent )
	_ColorGradings[ self ] = nil
end

function CameraImageEffectColorGrading:onBuild( prop, texture, layer, passId )
	local shaderScriptLUT = loadMockAsset( 'shader/image_effect/ColorGradingGamma.shader_script' )
	self.shader = assert( shaderScriptLUT:affirmDefaultShader() )
	self.material:setTexture( texture )
	self.material:setShader( self.shader:getMoaiShader() )
	
	prop:setMaterialBatch( self.material )

	self:updateIntensity()
	self:updateMix()
	self:updateGamma()
end

function CameraImageEffectColorGrading:setLUT( path )
	self.lutPath = path
	local atype = getAssetType( path )
	if atype == 'color_grading' then
		self.lutTex1 = mock.loadAsset( path ):getTexture()
	elseif atype == 'lut_texture' then
		self.lutTex1 = mock.loadAsset( path )
	elseif atype == 'texture' then
		local t = mock.loadAsset( path )
		self.lutTex1 = t and t:getMoaiTexture()
	end
	return self:updateTex()
end

function CameraImageEffectColorGrading:getLUT()
	return self.lutPath
end

function CameraImageEffectColorGrading:setLUT2( path )
	self.lutPath2 = path
	local atype = getAssetType( path )
	if atype == 'color_grading' then
		self.lutTex2 = mock.loadAsset( path ):getTexture()
	elseif atype == 'lut_texture' then
		self.lutTex2 = mock.loadAsset( path )
	elseif atype == 'texture' then
		local t = mock.loadAsset( path )
		self.lutTex2 = t and t:getMoaiTexture()
	end
	return self:updateTex()
end

function CameraImageEffectColorGrading:getLUT2()
	return self.lutPath2
end

local function getTextureSize( tex )
	local w, h = tex:getSize()
	if w == 0 and tex._ownerObject then
		return tex._ownerObject:getSize()
	end
	return w, h 
end

function CameraImageEffectColorGrading:updateTex()
	local t1 ,t2 = self.lutTex1, self.lutTex2
	self.material:setTexture( 1, 2, t1 )
	self.material:setTexture( 1, 3, t2 )
	local h1 = 32
	local h2 = 32
	if t1 then
		local w, h = getTextureSize( t1 )
		h1 = h
	end
	if t2 then
		local w, h = getTextureSize( t2 )
		h2 = h
	end
	self.size1 = h1
	self.size2 = h2
	self:updateMix()
	self:updateIntensity()
end

function CameraImageEffectColorGrading:setIntensity( intensity )
	self.intensity = intensity
	self:updateIntensity()
end

function CameraImageEffectColorGrading:setGamma( gamma )
	self.gamma = gamma
	self:updateGamma()
end

function CameraImageEffectColorGrading:setMix( mix )
	self.mix = mix
	return self:updateMix()
end

function CameraImageEffectColorGrading:updateMix()
	if not self.shader then return end
	local a, b = self.lutTex1, self.lutTex2
	self.shader:setAttr( 'size1', self.size1 )
	self.shader:setAttr( 'size2', self.size2 )
	if a and b then
		return self.shader:setAttr( 'LUTMix', self.mix )
	else
		if b then
			return self.shader:setAttr( 'LUTMix', 1 )
		else
			return self.shader:setAttr( 'LUTMix', 0 )
		end
	end
end

function CameraImageEffectColorGrading:updateIntensity()
	if not self.shader then return end
	if not self.lutPath then
		return self.shader:setAttr( 'intensity', 0 )
	else
		return self.shader:setAttr( 'intensity', self.intensity )
	end
end

function CameraImageEffectColorGrading:updateGamma()
	if not self.shader then return end
	return self.shader:setAttr( 'gamma', self.gamma )
end

mock.registerComponent( 'CameraImageEffectColorGrading', CameraImageEffectColorGrading )

