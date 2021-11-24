module 'mock'

--[[
	key format:
		{ pos,  value, mode,  { preBPX, preBPY, postBPX, postBPY } }
	data format:
	{ 
		keys = { keyEntry, ... },
	}
]]

CLASS: CurveConfig ()

function CurveConfig:__init()
	self.data = false
	self.animCurve = false
end

function CurveConfig:getAnimCurve()
	if self.animCurve then
		return self.animCurve
	end
	return self:buildAnimCurve()
end

function CurveConfig:load( data )
	self.keys = data.keys or {}
	self.animCurve = false
end

function CurveConfig:buildAnimCurve()
	self:sortKeys()
	local keys = self.keys
	local curve = MOAIAnimCurveEX.new()
	local keyCount = #keys
	curve:reserveKeys( keyCount )
	if keyCount > 0 then
		for i, key in ipairs( keys ) do
			local pos, value, mode, extra, preBPX, preBPY, postBPX, postBPY = unpack( key )
			curve:setKey( i, pos, value )
			curve:setKeyMode( i, mode )
			curve:setKeyParam( i, preBPX, preBPY, postBPX, postBPY )
		end
	end
	return curve
end

function CurveConfig:toDataString()
	return MOAIMsgPackParser.encode( self.data )
end

---------------------------------------------------------------------
function parseCurveData( dataString )
	assert( type( dataString )  == 'string' )
	local refPath = string.match( dataString, 'ref:(%.*)' )
	if refPath then
		local c = loadAsset( refPath )
		return assertInstanceOf( c, curveConfig )
	else
		return CurveConfig.fromDataString( dataString )
	end
end

--------------------------------------------------------------------
local function CurveConfigLoader( node, option )
	local curveConfig = CurveConfig()
	local path = node:getObjectFile( 'data' )
	local data = loadJSONFile( path )
	curveConfig:load( data )
	return curveConfig
end

registerAssetLoader( 'curve', CurveConfigLoader )
