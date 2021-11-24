module 'mock'

local hashWriter = MOAIHashWriter.new()
local function _getHash( hashType, raw, key, output )
	if hashType == 'CRC32' then
		hashWriter:openCRC32()
	elseif hashType == 'MD5' then
		hashWriter:openMD5()
	elseif hashType == 'Whirlpool' then
		hashWriter:openWhirlpool()
	elseif hashType == 'SHA1' then
		hashWriter:openSHA1()
	end

	hashWriter:write( raw )
	if key then hashWriter:write( key ) end
	hashWriter:close()

	if output == 'base64' then
		return hashWriter:getHashBase64()
	elseif output == 'hex' then
		return hashWriter:getHashHex()
	else
		return hashWriter:getHash()
	end

end

_M.getHash = _getHash

function getHashCRC32( raw, key, output )
	return _getHash( 'CRC32',raw, key, output )
end

function getHashMD5( raw, key, output )
	return _getHash( 'MD5', raw, key, output )
end

function getHashWhirlpool( raw, key, output )
	return _getHash( 'Whirlpool', raw, key, output )
end

function getHashSHA1( raw, key, output )
	return _getHash( 'SHA1', raw, key, output )
end

function getMangledPath( path )
	local base = basename_noext( path )
	local hash = getHashMD5( path, nil, 'hex' )
	local output = hash..base
	return output
end