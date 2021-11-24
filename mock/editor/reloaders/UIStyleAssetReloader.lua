module 'mock'

--------------------------------------------------------------------
CLASS: UIStyleAssetReloader ( AssetReloader )
:register( 'ui_style_reloader' )

function UIStyleAssetReloader:onAssetModified( node )
	if node:getType() ~= 'ui_style' then return end

	local UIViews = {}
	for key, session in pairs( game.sceneSessionMap ) do
		local scene = session:getScene()
		for e in pairs( scene.entities ) do
			if not ( e.FLAG_INTERNAL or e.FLAG_EDITOR_OBJECT ) then
				if e:isInstance( 'UIView' ) then
					UIViews[ e ] = true
				end
			end
		end
	end
	
	for e in pairs( UIViews ) do
		e:refreshStyle()
		e:foreachChild( function( child )
			if child:isInstance( 'UIWidget' ) then
				if child.localStyleSheetPath then
					child:refreshStyle()
				end
			end
		end, true )
	end

end
