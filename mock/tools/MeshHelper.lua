module 'mock'

local BUFFER_USAGE_STATIC_DRAW = MOAIVertexBuffer.BUFFER_USAGE_STATIC_DRAW

local _icosphere = require 'icosphere'

--------------------------------------------------------------------
--by zipline
local vertexFormat = affirmVertexFormat[[
	position = coord( vec3 )
	uv       = uv()
	color    = color()
]]

local function makeSubdivPlane ( w, h, pw, ph )
	local cellCount = w * h
	pw = pw or 1
	ph = ph or 1
	local vbo = MOAIVertexBuffer.new ()
	vbo:setUsageHint( BUFFER_USAGE_STATIC_DRAW )
	vbo:setFormat( vertexFormat )
	vbo:reserve ( cellCount * 6 * vertexFormat:getVertexSize ())

	local dx, dy = 1/w, 1/h
	for iy = 0, h-1 do
		local y0 = dy * iy
		local y1 = y0 + dy
		local py0 = y0 * ph 
		local py1 = y1 * ph 
		for ix = 0, w-1 do
			local x0 = dx * ix
			local x1 = x0 + dx
			local px0 = x0 * pw
			local px1 = x1 * pw
			--p0
			vbo:writeFloat ( px0, py0, 0 )
			vbo:writeFloat ( x0, y0 )
			vbo:writeColor32 ( 0, 1, 1 )

			vbo:writeFloat ( px1, py0, 0 )
			vbo:writeFloat ( x1, y0 )
			vbo:writeColor32 ( 0, 1, 1 )

			vbo:writeFloat ( px0, py1, 0 )
			vbo:writeFloat ( x0, y1 )
			vbo:writeColor32 ( 0, 1, 1 )

			vbo:writeFloat ( px0, py1, 0 )
			vbo:writeFloat ( x0, y1 )
			vbo:writeColor32 ( 1, 1, 1 )

			vbo:writeFloat ( px1, py0, 0 )
			vbo:writeFloat ( x1, y0 )
			vbo:writeColor32 ( 1, 1, 1 )
			
			vbo:writeFloat ( px1, py1, 0 )
			vbo:writeFloat ( x1, y1 )
			vbo:writeColor32 ( 1, 1, 1 )
			
		end
	end

	local mesh = MOAIMesh.new ()

	mesh:setVertexBuffer( vbo )
	mesh:setTotalElements ( vbo:countElements())
	mesh:setBounds ( vbo:computeBounds())
	
	mesh:setPrimType ( MOAIMesh.GL_TRIANGLES )
	mesh:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.MESH_SHADER ))
	
	return mesh
end

local function makeSubdivPlaneVar ( w, h, pw, ph, vertfunc, uvfunc )
	vertfunc = vertfunc or function( x,y,z ) return x,y,z end
	uvfunc = uvfunc or function( x,y ) return x,y end
	local cellCount = w * h
	pw = pw or 1
	ph = ph or 1
	local vbo = MOAIVertexBuffer.new ()
	vbo:setUsageHint( BUFFER_USAGE_STATIC_DRAW )
	vbo:setFormat( vertexFormat )
	vbo:reserve ( cellCount * 6 * vertexFormat:getVertexSize ())

	local dx, dy = 1/w, 1/h
	for iy = 0, h-1 do
		local y0 = dy * iy
		local y1 = y0 + dy
		local py0 = y0 * ph 
		local py1 = y1 * ph 
		for ix = 0, w-1 do
			local x0 = dx * ix
			local x1 = x0 + dx
			local px0 = x0 * pw
			local px1 = x1 * pw
			--p0
			vbo:writeFloat ( vertfunc( px0, py0, 0 ) )
			vbo:writeFloat ( uvfunc( x0, y0 ) )
			vbo:writeColor32 ( 0, 1, 1 )

			vbo:writeFloat ( vertfunc( px1, py0, 0 ) )
			vbo:writeFloat ( uvfunc( x1, y0 ) )
			vbo:writeColor32 ( 0, 1, 1 )

			vbo:writeFloat ( vertfunc( px0, py1, 0 ) )
			vbo:writeFloat ( uvfunc( x0, y1 ) )
			vbo:writeColor32 ( 0, 1, 1 )

			vbo:writeFloat ( vertfunc( px0, py1, 0 ) )
			vbo:writeFloat ( uvfunc( x0, y1 ) )
			vbo:writeColor32 ( 1, 1, 1 )

			vbo:writeFloat ( vertfunc( px1, py0, 0 ) )
			vbo:writeFloat ( uvfunc( x1, y0 ) )
			vbo:writeColor32 ( 1, 1, 1 )
			
			vbo:writeFloat ( vertfunc( px1, py1, 0 ) )
			vbo:writeFloat ( uvfunc( x1, y1 ) )
			vbo:writeColor32 ( 1, 1, 1 )
			
		end
	end

	local mesh = MOAIMesh.new ()

	mesh:setVertexBuffer( vbo )
	mesh:setTotalElements ( vbo:countElements())
	mesh:setBounds ( vbo:computeBounds())
	
	mesh:setPrimType ( MOAIMesh.GL_TRIANGLES )
	mesh:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.MESH_SHADER ))
	
	return mesh
end

local function makeBoxMesh ( xMin, yMin, zMin, xMax, yMax, zMax, texture )
	
	local function pushPoint ( points, x, y, z )
	
		local point = {}
		point.x = x
		point.y = y
		point.z = z
		
		table.insert ( points, point )
	end

	local function writeTri ( vbo, p1, p2, p3, uv1, uv2, uv3 )
		
		vbo:writeFloat ( p1.x, p1.y, p1.z )
		vbo:writeFloat ( uv1.x, uv1.y )
		vbo:writeColor32 ( 1, 1, 1 )
		
		vbo:writeFloat ( p2.x, p2.y, p2.z )
		vbo:writeFloat ( uv2.x, uv2.y )
		vbo:writeColor32 ( 1, 1, 1 )

		vbo:writeFloat ( p3.x, p3.y, p3.z )
		vbo:writeFloat ( uv3.x, uv3.y  )
		vbo:writeColor32 ( 1, 1, 1 )
	end
	
	local function writeFace ( vbo, p1, p2, p3, p4, uv1, uv2, uv3, uv4 )

		writeTri ( vbo, p1, p2, p4, uv1, uv2, uv4 )
		writeTri ( vbo, p2, p3, p4, uv2, uv3, uv4 )
	end
	
	local p = {}
	
	pushPoint ( p, xMin, yMax, zMax ) -- p1
	pushPoint ( p, xMin, yMin, zMax ) -- p2
	pushPoint ( p, xMax, yMin, zMax ) -- p3
	pushPoint ( p, xMax, yMax, zMax ) -- p4
	
	pushPoint ( p, xMin, yMax, zMin ) -- p5
	pushPoint ( p, xMin, yMin, zMin  ) -- p6
	pushPoint ( p, xMax, yMin, zMin  ) -- p7
	pushPoint ( p, xMax, yMax, zMin  ) -- p8

	local uv = {}
	
	pushPoint ( uv, 0, 0, 0 )
	pushPoint ( uv, 0, 1, 0 )
	pushPoint ( uv, 1, 1, 0 )
	pushPoint ( uv, 1, 0, 0 )
	
	local vbo = MOAIVertexBuffer.new ()
	vbo:setUsageHint( BUFFER_USAGE_STATIC_DRAW )
	vbo:setFormat( vertexFormat )
	
	vbo:reserve ( 36 * vertexFormat:getVertexSize ())
	
	writeFace ( vbo, p [ 1 ], p [ 2 ], p [ 3 ], p [ 4 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 4 ], p [ 3 ], p [ 7 ], p [ 8 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 8 ], p [ 7 ], p [ 6 ], p [ 5 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 5 ], p [ 6 ], p [ 2 ], p [ 1 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 5 ], p [ 1 ], p [ 4 ], p [ 8 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 2 ], p [ 6 ], p [ 7 ], p [ 3 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])

	local mesh = MOAIMesh.new ()
	mesh:setTexture ( texture )


	mesh:setVertexBuffer( vbo )
	mesh:setTotalElements ( vbo:countElements())
	mesh:setBounds ( vbo:computeBounds())
	
	mesh:setPrimType ( MOAIMesh.GL_TRIANGLES )
	mesh:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.MESH_SHADER ))
	
	return mesh
end

local function makeSkewBoxMesh ( xMin, yMin, zMin, xMax, yMax, zMax, texture )
	
	local function pushPoint ( points, x, y, z )
	
		local point = {}
		point.x = x
		point.y = y
		point.z = z
		
		table.insert ( points, point )
	end

	local function writeTri ( vbo, p1, p2, p3, uv1, uv2, uv3 )
		
		vbo:writeFloat ( p1.x, p1.y, p1.z )
		vbo:writeFloat ( uv1.x, uv1.y )
		vbo:writeColor32 ( 1, 1, 1 )
		
		vbo:writeFloat ( p2.x, p2.y, p2.z )
		vbo:writeFloat ( uv2.x, uv2.y )
		vbo:writeColor32 ( 1, 1, 1 )

		vbo:writeFloat ( p3.x, p3.y, p3.z )
		vbo:writeFloat ( uv3.x, uv3.y  )
		vbo:writeColor32 ( 1, 1, 1 )
	end
	
	local function writeFace ( vbo, p1, p2, p3, p4, uv1, uv2, uv3, uv4 )

		writeTri ( vbo, p1, p2, p4, uv1, uv2, uv4 )
		writeTri ( vbo, p2, p3, p4, uv2, uv3, uv4 )
	end
	
	local p = {}
	
	-- pushPoint ( p, xMin, yMax, zMax - yMax ) -- p1
	-- pushPoint ( p, xMin, yMin, zMax - yMin ) -- p2
	-- pushPoint ( p, xMax, yMin, zMax - yMin ) -- p3
	-- pushPoint ( p, xMax, yMax, zMax - yMax ) -- p4
	
	-- pushPoint ( p, xMin, yMax, zMin - yMax ) -- p5
	-- pushPoint ( p, xMin, yMin, zMin - yMin  ) -- p6
	-- pushPoint ( p, xMax, yMin, zMin - yMin  ) -- p7
	-- pushPoint ( p, xMax, yMax, zMin - yMax  ) -- p8
	
	pushPoint ( p, xMin, yMax - zMax, zMax ) -- p1
	pushPoint ( p, xMin, yMin - zMax, zMax ) -- p2
	pushPoint ( p, xMax, yMin - zMax, zMax ) -- p3
	pushPoint ( p, xMax, yMax - zMax, zMax ) -- p4
	
	pushPoint ( p, xMin, yMax - zMin, zMin ) -- p5
	pushPoint ( p, xMin, yMin - zMin, zMin ) -- p6
	pushPoint ( p, xMax, yMin - zMin, zMin ) -- p7
	pushPoint ( p, xMax, yMax - zMin, zMin ) -- p8

	local uv = {}
	
	pushPoint ( uv, 0, 0, 0 )
	pushPoint ( uv, 0, 1, 0 )
	pushPoint ( uv, 1, 1, 0 )
	pushPoint ( uv, 1, 0, 0 )
	
	local vbo = MOAIVertexBuffer.new ()
	vbo:setUsageHint( BUFFER_USAGE_STATIC_DRAW )
	vbo:setFormat( vertexFormat )
	
	vbo:reserve ( 36 * vertexFormat:getVertexSize ())
	
	writeFace ( vbo, p [ 1 ], p [ 2 ], p [ 3 ], p [ 4 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 4 ], p [ 3 ], p [ 7 ], p [ 8 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 8 ], p [ 7 ], p [ 6 ], p [ 5 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 5 ], p [ 6 ], p [ 2 ], p [ 1 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 5 ], p [ 1 ], p [ 4 ], p [ 8 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])
	writeFace ( vbo, p [ 2 ], p [ 6 ], p [ 7 ], p [ 3 ], uv [ 1 ], uv [ 2 ], uv [ 3 ], uv [ 4 ])

	local mesh = MOAIMesh.new ()
	mesh:setTexture ( texture )

	mesh:setVertexBuffer( vbo )
	mesh:setTotalElements ( vbo:countElements())
	mesh:setBounds ( vbo:computeBounds())
	
	mesh:setPrimType ( MOAIMesh.GL_TRIANGLES )
	mesh:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.MESH_SHADER ))
	
	return mesh
end

local function makeCubeMesh ( size, texture )
	size = size * 0.5
	return makeBoxMesh ( -size, -size, -size, size, size, size, texture )
end

local function makeICOSphereMesh( radius, subdivision, texture )
	subdivision = subdivision or 0
	local verts, indices, uvs = _icosphere( subdivision, radius )
	--no uv support yet
	local vbo = MOAIVertexBuffer.new ()
	vbo:setUsageHint( BUFFER_USAGE_STATIC_DRAW )
	
	local vertCount = #verts
	vbo:reserve( vertCount * vertexFormat:getVertexSize() )
	for i, v in ipairs( verts ) do
		local uv = uvs[ i ]
		vbo:writeFloat( v[1], v[2], v[3] ) --vertice
		vbo:writeFloat( uv[1], uv[2] ) --UV
		vbo:writeColor32( 1,1,1 )
	end
	local ibo = MOAIIndexBuffer.new()
	local indiceCount = #indices
	local SIZE_U16 = 2
	ibo:reserve( indiceCount * SIZE_U16 )
	for i, idx in ipairs( indices ) do
		ibo:writeU16( idx - 1 )
	end

	local mesh = MOAIMesh.new()
	vbo:setFormat( vertexFormat )

	mesh:setVertexBuffer( vbo )
	mesh:setIndexBuffer( ibo )
	mesh:setTotalElements( indiceCount )
	local bounds = { vbo:computeBounds() }
	mesh:setBounds (  unpack( bounds ) )
	mesh:setPrimType( MOAIMesh.GL_TRIANGLES )
	mesh:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.MESH_SHADER ))
	return mesh
end

MeshHelper = {
	makeSkewBox       = makeSkewBoxMesh;
	makeBox           = makeBoxMesh;
	makeCube          = makeCubeMesh;
	makeICOSphere     = makeICOSphereMesh;
	makeSubdivPlane   = makeSubdivPlane;
	makeSubdivPlaneVar   = makeSubdivPlaneVar;
}


