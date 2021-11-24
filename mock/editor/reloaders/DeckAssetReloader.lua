module 'mock'

CLASS: DeckAssetReloader ( AssetReloader )
:register( 'deck_reloader' )

function DeckAssetReloader:onAssetModified( node )
	local assetType = node:getType()
	if assetType:startwith( 'deck' ) then
		return
	end

	local mainScene = game:getMainScene()
	local path = node:getPath()
	for deckCom in pairs( mainScene:collectComponents( DeckComponent, true ) ) do
		if deckCom:getDeck() == path then
			deckCom:setDeck( path )
		end
	end

end
