module 'mock'

local vertexFormatMap = {}

local defaultTypes = {
		coord = 'vec3',
		uv    = 'vec2',
		color = 'rgba8'
}

local function _parseLine( line )
	local name, usage, atype = line:match( '(%w+)%s*=%s*(%w+)%s*%(%s*(%w*)%s*%)')
	if not name then return false end
	if atype =="" then
		atype = defaultTypes[ usage ]
	end
	return { name, usage, atype }
end

local function _delcareCoord( fmt, idx, atype )
	if atype == 'float' then
		fmt:declareCoord( idx, MOAIVertexFormat.GL_FLOAT, 1 )
	elseif atype == 'vec2' then
		fmt:declareCoord( idx, MOAIVertexFormat.GL_FLOAT, 2 )
	elseif atype == 'vec3' then
		fmt:declareCoord( idx, MOAIVertexFormat.GL_FLOAT, 3 )
	elseif atype == 'vec4' then
		fmt:declareCoord( idx, MOAIVertexFormat.GL_FLOAT, 4 )
	else
		error( 'wtf?' )
	end
end


local function _delcareNormal( fmt, idx, atype )
	if atype == 'float' then
		fmt:declareNormal( idx, MOAIVertexFormat.GL_FLOAT, 1 )
	elseif atype == 'vec2' then
		fmt:declareNormal( idx, MOAIVertexFormat.GL_FLOAT, 2 )
	elseif atype == 'vec3' then
		fmt:declareNormal( idx, MOAIVertexFormat.GL_FLOAT, 3 )
	elseif atype == 'vec4' then
		fmt:declareNormal( idx, MOAIVertexFormat.GL_FLOAT, 4 )
	else
		error( 'wtf?' )
	end
end

local function _delcareUV( fmt, idx, atype )
	if atype == 'float' then
		fmt:declareUV( idx, MOAIVertexFormat.GL_FLOAT, 1 )
	elseif atype == 'vec2' then
		fmt:declareUV( idx, MOAIVertexFormat.GL_FLOAT, 2 )
	elseif atype == 'vec3' then
		fmt:declareUV( idx, MOAIVertexFormat.GL_FLOAT, 3 )
	elseif atype == 'vec4' then
		fmt:declareUV( idx, MOAIVertexFormat.GL_FLOAT, 4 )
	else
		error( 'wtf?' )
	end
end

local function _delcareColor( fmt, idx, atype )
	if atype == 'rgba8' then
		fmt:declareColor( idx, MOAIVertexFormat.GL_UNSIGNED_BYTE )
	else
		error( 'wtf?' )
	end
end

--TODO: normal
--TODO: BoneWeights?
function affirmVertexFormat( str )
	local attrs = {}
	local sig = ""
	for i, line in ipairs( str:split( '\n' ) ) do
		local attr = _parseLine( line )
		if attr then
			table.insert( attrs, attr )
			sig = sig .. string.format( "%s:%s;", attr[2], attr[3] )
		end
	end

	local format = vertexFormatMap[ sig ]
	if not format then
		format = MOAIVertexFormat.new()
		for i, attr in ipairs( attrs ) do 
			local usage, atype = attr[2], attr[3]
			if usage == 'coord' then
				_delcareCoord( format, i, atype )
			elseif usage == 'uv' then
				_delcareUV( format, i, atype )
			elseif usage == 'color' then
				_delcareColor( format, i, atype )
			elseif usage == 'normal' then
				_delcareNormal( format, i, atype )
			else
				error( 'not supported' )
			end
		end
		vertexFormatMap[ sig ] = format
		format.signature = sig
	end

	return format
end


--add builtin formats
local builtinFormats = {
	[ 'coord:vec3;color:rgba8;' ]                     =  MOAIVertexFormatMgr.XYZC ;
	[ 'coord:vec4;color:rgba8;' ]                     =  MOAIVertexFormatMgr.XYZWC ;
	[ 'coord:vec4;uv:vec2;color:rgba8;' ]             =  MOAIVertexFormatMgr.XYZWUVC ;
	[ 'coord:vec4;normal:vec3;color:rgba8;' ]         =  MOAIVertexFormatMgr.XYZWNNNC ;
	[ 'coord:vec4;normal:vec3;uv:vec2;color:rgba8;' ] =  MOAIVertexFormatMgr.XYZWNNNUVC ;
}
for sig, id in pairs( builtinFormats ) do
	vertexFormatMap[ sig ] = MOAIVertexFormatMgr.getFormat( id )
end

