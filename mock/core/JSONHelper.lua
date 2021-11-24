module 'mock'


local function clearNullUserdata( t )
	for k,v in pairs( t ) do
		local tt = type( v )
		if tt == 'table' then
			clearNullUserdata( v )
		elseif tt == 'userdata' then
			t[ k ] = nil
		end
	end	
end

function loadJSONText( text, clearNulls )
	local data
	if clearNulls then
		data = MOAIJsonParser.decodeIgnoreNulls( text )
	else
		data =  MOAIJsonParser.decode(text)
	end
	if data then
		return data
	else
		_error( 'json file not parsed: '..path )
		return nil
	end

end

function loadJSONFile( path, clearNulls )
	if not MOAIFileSystem.checkFileExists( path ) then
		_error( 'data file not found:' .. tostring( path ),2  )
		return nil
	end
	if MOAIJsonParser.load then
		return MOAIJsonParser.load( path )
	else
		local stream = MOAIFileStream.new()
		stream:open( path, MOAIFileStream.READ )
		local data, size = stream:read()
		stream:close()
		return loadJSONText( data, clearNulls )
	end
end


function tryLoadJSONFile( path, clearNulls )
	if not MOAIFileSystem.checkFileExists( path ) then return nil end
	local succ, data = pcall( loadJSONFile, path, clearNulls )
	if succ then return data end
	return nil
end

function saveJSONFile( data, path, dataInfo )
	local output = encodeJSON( data )
	if not output then
		_error( 'cannot serialize into json' )
		return false
	end
	local file = io.open( path, 'w' )
	if file then
		file:write(output)
		file:close()
		_stat( dataInfo, 'saved to', path )
	else
		_error( 'can not save ', dataInfo , 'to' , path )
	end
end
