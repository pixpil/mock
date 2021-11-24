-- lovr-icosphere v0.0.1
-- https://github.com/bjornbytes/lovr-icosphere

--[[
	Copyright (c) 2017 Bjorn Swenson

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]


local insert = table.insert
local remove = table.remove
local sqrt = math.sqrt
local PI = math.pi
local sin = math.sin
local cos = math.cos
local asin = math.asin
local acos = math.acos
local atan = math.atan
local atan2 = math.atan2
local phi = (1 + math.sqrt(5)) / 2

return function(subdivisions, radius)
	radius = radius or 1
  local vertices = {
    { -1,  phi, 0 },
    {  1,  phi, 0 },
    { -1, -phi, 0 },
    {  1, -phi, 0 },

    { 0, -1,  phi },
    { 0,  1,  phi },
    { 0, -1, -phi },
    { 0,  1, -phi },

    {  phi, 0, -1 },
    {  phi, 0,  1 },
    { -phi, 0, -1 },
    { -phi, 0,  1 }
  }

  local indices = {
    1, 12, 6,
    1, 6, 2,
    1, 2, 8,
    1, 8, 11,
    1, 11, 12,

    2, 6, 10,
    6, 12, 5,
    12, 11, 3,
    11, 8, 7,
    8, 2, 9,

    4, 10, 5,
    4, 5, 3,
    4, 3, 7,
    4, 7, 9,
    4, 9, 10,

    5, 10, 6,
    3, 5, 12,
    7, 3, 11,
    9, 7, 8,
    10, 9, 2
  }

  -- Cache vertex splits to avoid duplicates
  local splits = {}

  -- Splits vertices i and j, creating a new vertex and returning the index
  local function split(i, j)
    local key = i < j and (i .. ',' .. j) or (j .. ',' .. i)

    if not splits[key] then
      local x = (vertices[i][1] + vertices[j][1]) / 2
      local y = (vertices[i][2] + vertices[j][2]) / 2
      local z = (vertices[i][3] + vertices[j][3]) / 2
      insert(vertices, { x, y, z })
      splits[key] = #vertices
    end

    return splits[key]
  end

  -- Subdivide
  for _ = 1, subdivisions or 0 do
    for i = #indices, 1, -3 do
      local v1, v2, v3 = indices[i - 2], indices[i - 1], indices[i - 0]
      local a = split(v1, v2)
      local b = split(v2, v3)
      local c = split(v3, v1)

      insert(indices, v1)
      insert(indices, a)
      insert(indices, c)

      insert(indices, v2)
      insert(indices, b)
      insert(indices, a)

      insert(indices, v3)
      insert(indices, c)
      insert(indices, b)

      insert(indices, a)
      insert(indices, b)
      insert(indices, c)

      remove(indices, i - 0)
      remove(indices, i - 1)
      remove(indices, i - 2)
    end
  end

  -- Normalize
  local uvs = {}

  for i = 1, #vertices do
    local vert = vertices[ i ]
    local x, y, z = vert[1], vert[2], vert[3]
    local length = sqrt(x * x + y * y + z * z)

    --find uv
    local u, v
    local normalizedX = 0;
    local normalizedZ = -1;
    
    if ((x * x) + (z * z)) > 0 then
      normalizedX = sqrt( (x * x) / ((x * x) + (z * z)) )
      normalizedZ = sqrt( (z * z) / ((x * x) + (z * z)) )
      if x < 0 then normalizedX = -normalizedX end
      if z < 0 then normalizedZ = -normalizedZ end
    end

    
    local u = atan2( normalizedZ, normalizedX )
    if u < 0 then
      u = u + 2 * PI
    end
    u = u / ( 2 * PI )
    -- v = ( 1 - y ) / 2
    -- v = ( cos( v * PI ) + 1 ) / 2
    -- u = atan2( z, x )/( 2 * PI )
    -- local u = atan2( normalizedZ, normalizedX )/( 2 * PI )
    -- v = asin( v )/PI - 0.5

    -- local u = 0.5 - 0.5 * atan2( normalizedX, -normalizedZ ) / PI
    local v = 1 - acos( y * 0.5 ) / PI
    uvs[ i ] = { u, v }

    --
    x, y, z = x / length, y / length, z / length
    vert[1], vert[2], vert[3] = x * radius, y * radius, z * radius
  end

  local added = {}
  local vertCount = #vertices
  local function addWrappedVert( v, umax )
    local v1 = added[ v ]
    if v1 then
      return v1
    end
    local uv0 = uvs[ v ]
    local v0 = vertices[ v ]
    
    local v1 = vertCount + 1
    vertices[ v1 ] = { v0[1], v0[2], v0[3] }
    local u0 = uv0[ 1 ]
    uvs[ v1 ] = { u0 + 1, uv0[2] }

    vertCount = v1
    added[v] = v1
    return v1
  end
  local max = math.max

  for i = 1, #indices, 3 do
    local v1 = indices[ i ]
    local v2 = indices[ i + 1 ]
    local v3 = indices[ i + 2 ]
    
    local u0 = uvs[v1][1]
    local u1 = uvs[v2][1]
    local u2 = uvs[v3][1]

    local umax = max( u0, u1, u2 )
    if umax - u0 > 0.5 then
      indices[i] = addWrappedVert( v1, umax )
    end
    if umax - u1 > 0.5 then
      indices[i+1] = addWrappedVert( v2, umax )
    end
    if umax - u2 > 0.5 then
      indices[i+2] = addWrappedVert( v3, umax )
    end
  end

  return vertices, indices, uvs
end
