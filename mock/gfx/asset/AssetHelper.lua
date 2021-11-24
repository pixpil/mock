module 'mock'

function affirmMoaiTexture( t )
	local tt = type( t )
	if tt == 'userdata' then
		return t --assume it's MOAITextureBase
	elseif tt == 'string' then
		local atype = getAssetType( t )
		if isSupportedTextureAssetType( atype ) then
			local asset = loadAsset( t )
			return asset and asset:getMoaiTexture()
		end
	elseif isInstance( t, TextureInstance ) then
		return t:getMoaiTexture()
	else
		return nil
	end
end
