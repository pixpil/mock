module 'mock'


local function getSQScriptFilePath( script )
	local path = script:getSourcePath()
	local node = path and getAssetNode( path )
	if not node then return false end
	return node:getAbsFilePath()
end

function getSQScriptSourceString( script )
	local path = script:getSourcePath()
	local node = path and getAssetNode( path )
	if not node then return false end
	local sqFile = io.open( node:getAbsFilePath(), 'r' )
	if not sqFile then return false end
	local src = sqFile:read( '*a' )
	sqFile:close()
	return src
end

function getSQScriptSourceStringLines( script )
	local path = script:getSourcePath()
	local node = path and getAssetNode( path )
	if not node then return false end
	local sqFile = io.open( node:getAbsFilePath(), 'r' )
	if not sqFile then return false end
	
	local srcLines = {}
	local insert = table.insert
	for lineText in sqFile:lines() do
		insert( srcLines, lineText )
	end
	sqFile:close()
	return srcLines

end

-- function updateSQScriptString( script )
-- 	local sourcePath = script:getSourcePath()
-- end

local function traverseSQNode( n, func )
	func( n )
	for i, child in ipairs( n.children ) do
		traverseSQNode( child, func )
	end
end

local function getInlineDirectiveString( inlineDirectives )
	local output = false
	for i, d in ipairs( inlineDirectives ) do
		local line = string.format( '$%s(%s)', d.name, d.value )
		if output then
			output = output .. ' ' .. line
		else
			output = line
		end
	end
	return output
end

function replaceInlineDirective( line, newDirectiveString )
	local commentPos = line:find( '//' )
	local body, comment
	if commentPos then
		body = line:sub( 1, commentPos - 1 )
		comment = line:sub( commentPos, -1 )
	else
		body = line
		comment = newDirectiveString and '//' or ''
	end
	local stripped = comment:gsub( '$%w+%([^()]*%)', '' )
	local stripped = stripped:gsub( '$%w+', '' )
	local newComment
	if newDirectiveString then
		newComment = stripped:trim() .. '\t\t'..newDirectiveString
		newComment = newComment:gsub( '//%s+(%$%w)', '//%1' )
		newComment = newComment:gsub( '//%s*$', '' )
		newComment = newComment:gsub( '^(//%$%w)', '\t\t%1' )
		return body .. newComment
	else
		return body .. comment
	end
end

function _updateSQScriptInlineDirective( script )
	local routine = script.routines and script.routines[1]
	if not routine then return false end
	local srcLines = getSQScriptSourceStringLines( script )
	if not srcLines then return end
	local toChange = {}
	traverseSQNode( routine.rootNode, function( node )
		if not node then return end
		local inlineDirectives = node.inlineDirectives
		local outputInlineDirectiveString = inlineDirectives and getInlineDirectiveString( inlineDirectives )
		local lineNumber = node.lineNumber
		local line = srcLines[ lineNumber ]
		if line then
			local newLine = replaceInlineDirective( line, outputInlineDirectiveString )
			srcLines[ lineNumber ] = newLine
		end
	end)
	return srcLines
end

function rewriteSQScriptInlineDirective( script, outputFile )

	local updatedLines = _updateSQScriptInlineDirective( script )
	if not updatedLines then return false end
	if not outputFile then
		outputFile = getSQScriptFilePath( script )
	end
	local f = io.open( outputFile, 'w' )
	if not f then return false end
	for i, line in ipairs( updatedLines ) do
		f:write( line )
		f:write( '\n' )
	end
	f:close()
	return true
end
