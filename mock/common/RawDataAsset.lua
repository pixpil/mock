module 'mock'

--------------------------------------------------------------------
local function RawDataLoader( node )
	local path = node:getObjectFile( 'data' )
	return path
end

registerAssetLoader( 'raw',   RawDataLoader )
