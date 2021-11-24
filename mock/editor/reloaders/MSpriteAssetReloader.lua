module 'mock'

--------------------------------------------------------------------
CLASS: MSpriteAssetReloader ( AssetReloader )
:register( 'msprite_reloader' )

function MSpriteAssetReloader:onTextureRebuild( node )
	local pnode = node:getParentNode()
	if not ( pnode and pnode:getType() == 'msprite' ) then return end
	_log( 'msprite reimporting', pnode )
	
	local assetPath = pnode:getPath()
	local mainScene = game:getMainScene()
	local msprites = mainScene:collectComponents( MSprite, true )

	for sprite in pairs( msprites ) do
		if sprite:getSprite() == assetPath then
			local state = sprite.animState
			local clip  = state and state.clip or false
			local time  = state and state:getTime() or 0
			local mode  = state and state.mode 
			local restoreState = state and state:isBusy()
			sprite:setSprite( assetPath )
			if restoreState then
				if clip then
					sprite:setClip( clip.name, mode )
					local newState = sprite.animState
					if newState then
						_warn( 'sprite ready', sprite, clip.name, mode )
						newState:setTime( time )
						newState:apply( time )
						newState:start()
					else
						_warn( 'state not started', sprite )
					end
				end
			end
		end
	end

end
