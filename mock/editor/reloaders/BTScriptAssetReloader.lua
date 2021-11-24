module 'mock'

CLASS: BTScriptAssetReloader ( AssetReloader )
:register( 'bt_script_reloader' )

function BTScriptAssetReloader:onAssetModified( node )
	local assetType = node:getType()
	if assetType ~= 'bt_script' then return end
	local path = node:getPath()
	local mainScene = game:getMainScene()
	local btControllers = mainScene:collectComponents( BTController, true )
	for btController in pairs( btControllers ) do
		if btController:getScheme() == path then
			btController:setScheme( path )
		end
	end
end
