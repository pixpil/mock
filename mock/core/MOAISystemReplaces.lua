if MOAISim then
	require 'mock.core.MOAIInterfaces'

	-------replace system os.clock
	os._clock = os.clock
	os.clock  = MOAISim.getDeviceTime


	-------replace system random
	math.random     = MOAIMath.randSFMT
	math.seedrandom = MOAIMath.seedSFMT

	MOAIMath.seedSFMT( 1 )
	local _globalSFMTSeed = 1
	math.randomseed = function( seed )
		seed = seed or 0
		local seed0 = _globalSFMTSeed
		_globalSFMTSeed = seed
		MOAIMath.seedSFMT( seed )
		return seed0
	end



	----CJSON
	if cjson then
		MOAIJsonParser.decode = cjson.decode
		local cjsonIgnoreNulls = cjson.new()
		cjsonIgnoreNulls.decode_ignore_null( true )
		MOAIJsonParser.decodeIgnoreNulls = assert( cjsonIgnoreNulls.decode )
	end

	----msgpack
	if cmsgpack then
		MOAIMsgPackParser = {
			encode = cmsgpack.pack,
			decode = cmsgpack.unpack,
		}
	end

end