module('mock')

CLASS: MeshDeck ()
	:MODEL{

}

function MeshDeck:__init()
	self.deck = false
end

function MeshDeck:getMoaiDeck()
	return self.deck;
end
-- /Users/yibojiang/Documents/GameDevelop/EastwardProject/giitest/game/lib/mock/tools/TMXTool.lua

local vertexFormat = mock.affirmVertexFormat[[
	position = coord( vec3 )
	uv       = uv()
	color    = color()
]]
-- vertexFormat:declareNormal ( 4, MOAIVertexFormat.GL_FLOAT )

local function MeshLoader( node )
	-- print("mesh loading")

	local function pushPoint ( points, x, y, z )
		
		local point = {}
		point.x = x
		point.y = y
		point.z = z
		
		table.insert ( points, point )
	end

	local function writeTri ( vbo, p1, p2, p3, uv1, uv2, uv3, nor1, nor2, nor3 )
		
		vbo:writeFloat ( p1.x, p1.y, p1.z )
		vbo:writeFloat ( uv1.x, uv1.y )
		vbo:writeColor32 ( 1, 1, 1 )
		-- vbo:writeFloat ( nor1.x, nor1.y, nor1.z )
		
		vbo:writeFloat ( p2.x, p2.y, p2.z )
		vbo:writeFloat ( uv2.x, uv2.y )
		vbo:writeColor32 ( 1, 1, 1 )
		-- vbo:writeFloat ( nor2.x, nor2.y, nor2.z )

		vbo:writeFloat ( p3.x, p3.y, p3.z )
		vbo:writeFloat ( uv3.x, uv3.y  )
		vbo:writeColor32 ( 1, 1, 1 )
		-- vbo:writeFloat ( nor3.x, nor3.y, nor3.z )
	end

	-- return false
	local meshdata = false
	local rootPath = node:getObjectFile( 'mesh' )
	local meshFile = rootPath .. '/mesh'
	local dataString = loadTextData( meshFile )
	meshdata = MOAIXmlParser.parseString( dataString )
	print( meshFile, type( meshdata ) )
	assert( type(meshdata) == 'table')

	local sceneNode = meshdata['children']['Scene'][1]
	

	local meshListNode = sceneNode['children']['MeshList'][1]
	local materialListNode = sceneNode['children']['MaterialList'][1]
	
	local meshCount = meshListNode['attributes']['num']
	local materialCount = materialListNode['attributes']['num']

	local texPaths = {}
	

	-- Parse Material
	for i = 1, materialCount do
		local materialNode = materialListNode['children']['Material'][i]
		local matPropertyListNode = materialNode['children']['MatPropertyList'][1]

		-- table.print( matPropertyListNode )

		local matPropertyCount = matPropertyListNode['attributes']['num']
		for j = 1, matPropertyCount do
			local matPropertyNode = matPropertyListNode['children']['MatProperty'][j]
			local usage = matPropertyNode['attributes']['tex_usage']
			local key = matPropertyNode['attributes']['key']
			if key == '$tex.file' then
				local texPath = matPropertyNode['value']
				-- print( "orignal texture path", texPath )
				texPath = string.gsub( texPath, "\"", "" )
				-- print( "texture path", texPath )
				if texPath~="" then
					local texFileName = basename_noext( texPath ) .. '.png'
					table.insert( texPaths, rootPath .. '\\' .. texFileName )
				end
			
			end
			-- table.print( matPropertyNode )
		end
	end

	-- local texMulti = MOAIMultiTexture.new()
	-- texMulti:reserve( #texPaths + 1 )
	local materialBatch = MOAIMaterialBatch.new()

	local lasttex, lastTexID
	for k, v in pairs(texPaths) do 
		local texture = MOAITexture.new()
		texture:load( v )
		print( "texture name", k, v, texture:getSize() )
		if texture then
			texture:setFilter( MOAITexture.GL_NEAREST )
			-- texture:setFilter( MOAITexture.GL_LINEAR )
		end
		lastTexID = k 
		lastTex = texture
		if k == 1 then
			materialBatch:setTexture( 1, texture )
		else
			materialBatch:setTexture( 1, k, texture )
		end
	end

	if lastTexID and lastTexID < 2 then
		materialBatch:setTexture( 1, 2, lastTex )
	end

	for i = 1, meshCount do
		
		-- MeshList
		local meshNode = meshListNode['children']["Mesh"][i]["children"]

		-- Parse Position Data.
		local positionWord = {}
		local positionValues = meshNode["Positions"][1]["value"]
		
		for word in positionValues:gmatch("%S+") do
			table.insert( positionWord, tonumber( word ) )
		end

		-- Parse UV Data.
		local texCoordWord = {}
		if meshNode["TextureCoords"] then
			
			local texCoordValues = meshNode["TextureCoords"][1]["value"]

			for word in texCoordValues:gmatch("%S+") do
				table.insert( texCoordWord, tonumber( word ) )
			end
		end

		-- Parse Vertex Normals Data.
		local normalWord = {}
		local normalValues = meshNode["Normals"][1]["value"]

		for word in normalValues:gmatch("%S+") do
			table.insert( normalWord, tonumber( word ) )
		end

		local positions = {}
		local uvs = {}
		local normals = {}
		local faces = {}
		
		local positionCount = math.floor( #positionWord/3 )
		for idx = 1, positionCount do
			local k = ( idx - 1 ) * 3
			local l = ( idx - 1 ) * 2
			
			positions[ idx ] = {
				x = positionWord[ k + 1 ],
				y = positionWord[ k + 2 ],
				z = positionWord[ k + 3 ],
			}

			if #texCoordWord > 0 then
				uvs[ idx ] = {
					x = texCoordWord[ l + 1 ],
					y = 1 - texCoordWord[ l + 2 ]
				}
			else
				uvs[ idx ] = {
					x = 0,
					y = 1
				}
			end

			normals[ idx ] = {
				x = normalWord[ k + 1 ],
				y = normalWord[ k + 2 ],
				z = normalWord[ k + 3 ]
			}

			-- printf( '%d \t %.1f, %.1f, %.1f', idx, positions[idx].x, positions[idx].y,positions[idx].z)
		end

		for i, faceNode in ipairs( meshNode["FaceList"][1]["children"]["Face"] ) do
			local v = faceNode[ 'value' ]
			local a,b,c = v:match( '%s*(%w+)%s*(%w+)%s*(%w+)' )
			local v1 = tonumber( a ) + 1
			local v2 = tonumber( b ) + 1
			local v3 = tonumber( c ) + 1
			faces[ i ] = { v1, v2, v3 }
		end
		
		-- Parse Triangle Data.
		local faceCount = #faces
		local vbo = MOAIVertexBuffer.new ()
		vbo:reserve ( faceCount * 3 * vertexFormat:getVertexSize() )
		vbo:setFormat( vertexFormat )

		for i, face in ipairs( faces ) do
			local v1, v2, v3 = unpack( face )
			writeTri(
				vbo, 
				positions[ v1 ], positions[ v2 ], positions[ v3 ],
				uvs[ v1 ], uvs[ v2 ], uvs[ v3 ],
				normals[ v1 ], normals[ v2 ], normals[ v3 ]
			)

		end

		
		local mesh = MeshDeck()
		local deck = MOAIMesh.new()
		mesh.deck = deck
		
		deck:setVertexBuffer( vbo )
		deck:setTotalElements ( vbo:countElements())
		deck:setBounds ( vbo:computeBounds())
		deck:setPrimType ( MOAIMesh.GL_TRIANGLES )
		deck:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.MESH_SHADER ))
		deck:setMaterialBatch( materialBatch )

		return mesh

	end
	
	
end


-- local function 


registerAssetLoader( 'mesh', MeshLoader )
