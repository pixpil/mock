module 'mock'

--------------------------------------------------------------------
--Quad with Normalmap
--------------------------------------------------------------------


local mquadVertexFormat = mock.affirmVertexFormat[[
	position = coord( vec3 )
	uv       = uv()
	color    = color()
]]

CLASS: MQuadDeck ( Deck2D )
	:MODEL{
	}

function MQuadDeck:__init()
	self.verts = {}
	self.bounds = { 0,0,0, 1,1,1 }
	self.pack = false
end

function MQuadDeck:createMoaiDeck()
	local mesh = MOAIMesh.new ()	
	mesh:setPrimType ( MOAIMesh.GL_TRIANGLES )
	return mesh
end

function MQuadDeck:getSize()
	return self.w, self.h, self.depth
end

local insert = table.insert
local function insertVert( output, verts, uvs, i )
	local vert = verts[i]
	local uv = uvs[i]
	return insert( output, { vert[1], vert[2], vert[3], uv[1], uv[2] } )
end

function MQuadDeck:affirmVertData()
	local deckData = self.deckData
	local verts = {}
	local meshes = deckData.meshes
	for i = 1, #meshes do
		local mesh = meshes[ i ]
		local uvs = mesh.uv
		local vts = mesh.verts
		insertVert( verts, vts, uvs, 4 )
		insertVert( verts, vts, uvs, 2 )
		insertVert( verts, vts, uvs, 1 )
		insertVert( verts, vts, uvs, 4 )
		insertVert( verts, vts, uvs, 3 )
		insertVert( verts, vts, uvs, 2 )
	end
	self.verts = verts
	self.vertCount = #verts
end

local writeFloat = MOAIVertexBuffer.getInterfaceTable().writeFloat
local writeColor32 = MOAIVertexBuffer.getInterfaceTable().writeColor32
local BUFFER_USAGE_STATIC_DRAW = MOAIVertexBuffer.BUFFER_USAGE_STATIC_DRAW
function MQuadDeck:update()
	self:affirmVertData()
	local mesh = self:getMoaiDeck()

	-- local tex = self.pack.texMulti
	local texColor = self.pack.texColor
	local texNormal = self.pack.texNormal
	mesh:setTexture( 1,texColor )
	mesh:setTexture( 1,1, texColor )
	mesh:setTexture( 1,2, texNormal )

	local u0,v0,u1,v1 = 0,0,1,1
	
	local us = u1-u0
	local vs = v1-v0

	local verts  = self.verts
	local vertCount = #verts

	local vbo = MOAIVertexBuffer.new ()
	local memSize = vertCount * mquadVertexFormat:getVertexSize()
	vbo:setUsageHint( BUFFER_USAGE_STATIC_DRAW )
	vbo:reserve ( memSize )
	vbo:setFormat( mquadVertexFormat )
	for i = 1, vertCount do
		local vert = verts[ i ]
		local x, y, z =  vert[1], vert[2], vert[3]
		local u, v = vert[4], vert[5]
		writeFloat ( vbo,  x,y,z, u*us + u0,  v*vs + v0 )
		writeColor32 ( vbo, 1, 1, 1 )
	end

	local bound = { vbo:computeBounds() }
	if bound[1] then
		local x0,y0,z0, x1,y1,z1 = unpack(bound)

		mesh:setBounds ( x0,y0,z0, x1,y1,z1 )
		self.w, self.h, self.depth = x1 - x0, y1 - y0 , z1 - z0
		self.bounds = { x0,y0,z0, x1,y1,z1 }
	end

	if vertCount > 0 then
		mesh:setVertexBuffer( vbo )
		mesh:setTotalElements ( vertCount )
		-- mesh:setTile( 1, 0, count )
	end
	
	self.rawMesh = mesh

end

function MQuadDeck:load( deckData )
	self.deckData = deckData	
end

function MQuadDeck:getBounds()
	return unpack( self.bounds )
end

--------------------------------------------------------------------
registerAssetLoader ( 'deck2d.mquad',     DeckPackItemLoader )
