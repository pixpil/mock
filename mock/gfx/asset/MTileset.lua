module 'mock'

--------------------------------------------------------------------
--Quad with Normalmap
--------------------------------------------------------------------

local mtilesetVertexFormat = mock.affirmVertexFormat[[
	position = coord( vec3 )
	uv       = uv()
	color    = color()
]]

function getMTilesetVertexFormat()
	return mtilesetVertexFormat
end

CLASS: MTileset ( NamedTileset )
	:MODEL{
	}

function MTileset:__init()
	self.verts = {}
	self.meshSpans = {}
	self.pack = false
	self.rawMesh = MOAIMesh.new()
	self.rawMesh:setPrimType ( MOAIMesh.GL_TRIANGLES )
end

function MTileset:createMoaiDeck()
	-- local mesh = MOAITileMesh.new ()	
	local mesh = MOAISelectionMesh.new()
	mesh:setMesh( self.rawMesh )
	return mesh
end

local writeFloat = MOAIVertexBuffer.getInterfaceTable().writeFloat
local writeColor32 = MOAIVertexBuffer.getInterfaceTable().writeColor32
function MTileset:update()
	local selectionMesh = self:getMoaiDeck()
	selectionMesh:setMesh( self.rawMesh)
	
	local rawMesh = self.rawMesh
	local texColor = self.pack.texColor
	local texNormal = self.pack.texNormal
	rawMesh:setTexture( 1, texColor )
	rawMesh:setTexture( 1, 1, texColor )
	rawMesh:setTexture( 1, 2, texNormal )

	local u0,v0,u1,v1 = 0,0,1,1
	
	local us = u1-u0
	local vs = v1-v0

	local verts  = self.verts	
	local vertCount = #verts

	local vbo = MOAIVertexBuffer.new ()
	vbo:setUsageHint( MOAIVertexBuffer.BUFFER_USAGE_STATIC_DRAW )
	vbo:setFormat( mtilesetVertexFormat )
	local memSize = vertCount * mtilesetVertexFormat:getVertexSize()
	vbo:reserve ( memSize )
	for i = 1, vertCount do
		local vert = verts[ i ]
		writeFloat ( vbo, vert[1], vert[2], vert[3] )
		writeFloat ( vbo, vert[4]*us + u0,  vert[5]*vs + v0 )
		writeColor32 ( vbo, 1, 1, 1 )
	end

	rawMesh:setVertexBuffer( vbo )
	rawMesh:setTotalElements ( vertCount )
	
	--tile spans
	selectionMesh:reserveSelections( self.tileCount )
	for i, span in ipairs( self.meshSpans ) do
		local offset, spanSize = span[1], span[2]
		-- print( i, offset, spanSize )
		selectionMesh:addSelection( i, offset + 1 , offset + spanSize + 1 )
	end
	
	-- local u = {vbo:computeBounds() }
	-- if u[1] then
		-- rawMesh:setBounds ( unpack(u) )
		-- local tw, th = self.tileWidth, self.tileHeight
		rawMesh:setBounds( -0.5,-3,0, 0.5,3,1 )
	-- end
end

local insert = table.insert
local function insertVert( output, verts, uvs, i )
	local vert = verts[i]
	local uv = uvs[i]
	local v = { vert[1], vert[2], vert[3], uv[1], uv[2] }
	return insert( output, v )
end

function MTileset:load( deckData )
	self:loadData( deckData )	
	--load rawMesh verts
	local vbos = {}
	local u0,v0,u1,v1 = 0,0,1,1
	local us = u1-u0
	local vs = v1-v0
	local vertSize = mtilesetVertexFormat:getVertexSize()
	
	local currentVertexOffset = 0

	local verts = {}
	local meshSpans = {}
	for idx, tileData in ipairs( self.idToTile ) do
		local spanSize = 0
		for i, meshData in ipairs( tileData.meshes ) do
			local uvs = meshData.uv
			local vts = meshData.verts
			insertVert( verts, vts, uvs, 4 )
			insertVert( verts, vts, uvs, 2 )
			insertVert( verts, vts, uvs, 1 )
			insertVert( verts, vts, uvs, 4 )
			insertVert( verts, vts, uvs, 3 )
			insertVert( verts, vts, uvs, 2 )
			spanSize = spanSize + 6
		end
		meshSpans[ idx ] = { currentVertexOffset, spanSize }
		currentVertexOffset = currentVertexOffset + spanSize	
	end

	self.verts = verts
	self.meshSpans = meshSpans
	
end

--------------------------------------------------------------------
registerAssetLoader ( 'deck2d.mtileset',  DeckPackItemLoader )
registerBundleItemAssetType ( 'deck2d.mtileset' )
