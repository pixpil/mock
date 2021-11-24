module 'mock'

CLASS: TextureAssetReloader ( AssetReloader )
:register( 'texture_reloader' )

function TextureAssetReloader:onTextureRebuild( node )
	local assetType = node:getType()
	if assetType ~= 'texture' then
		return
	end

	local path = node:getNodePath()
	for _, item in pairs( getLoadedDecks() ) do
		if item:getTexture() == path then
			item:setTexture( path, false )
		end
	end

end
