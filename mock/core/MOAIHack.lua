
--------------------------------------------------------------------
--workaround for listing mounted archive file
--------------------------------------------------------------------
local _listFiles = MOAIFileSystem.listFiles
local insert = table.insert
MOAIFileSystem.listFiles = function( path )
	local result = _listFiles( path ) 
	if result then
		local output = {}
		for i, file in ipairs( result ) do
			if not file:match( '^%._' ) then
				insert( output, file )
			end
		end
		return output
	else
		return result
	end
end

