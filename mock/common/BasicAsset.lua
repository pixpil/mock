module 'mock'

function loadAssetDataTable( filename ) --lua or json?
	-- _stat( 'loading json data table', filename )
	if not filename then return nil end
	if not MOAIFileSystem.checkFileExists( filename ) then
		error( 'data file not found:' .. tostring( filename ),2  )
	end

	if MOAIJsonParser.load then
		return MOAIJsonParser.load( filename )
	end
	
	local stream = MOAIFileStream.new()
	stream:open( filename, MOAIFileStream.READ )
	local raw, size = stream:read()
	stream:close()

	local ok, data = pcall( function() return MOAIJsonParser.decode(raw) end )
	if not data then _error( 'json file not parsed: '..filename ) end
	return data
end

function loadTextData( filename )
	if not filename then return '' end
	if not MOAIFileSystem.checkFileExists( filename ) then
		_error( 'error opening file', filename )
		return ''
	end

	local stream = MOAIFileStream.new()
	stream:open( filename, MOAIFileStream.READ )
	local data, size = stream:read()
	stream:close()
	return data
end

function saveTextData( txt, filename )
	local fp = io.open( filename, 'w' )
	fp:write( txt )
	fp:close()
end
---------------------basic loaders
local basicLoaders = {}
function basicLoaders.text( node )
	return loadTextData( node.filePath )
end

----------REGISTER the loaders
for assetType, loader in pairs( basicLoaders ) do
	registerAssetLoader( assetType, loader )
end
