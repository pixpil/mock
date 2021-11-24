--[[
* MOCK framework for Moai

* Copyright (C) 2012 Tommo Zhou(tommo.zhou@gmail.com).  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
local pairs,ipairs = pairs,ipairs
local tinsert      = table.insert
local tremove      = table.remove
local random       = math.random
local floor        = math.floor
local select       = select
local tonumber     = tonumber
local tostring     = tostring
local next         = next
local _print       = print

local gsub   = string.gsub
local match  = string.match
local byte   = string.byte
local format = string.format

local mp_pack = cmsgpack.pack
local mp_unpack = cmsgpack.unpack

--------------------------------------------------------------------
--type checking
--------------------------------------------------------------------
function istype( n, typename )
	return type( n ) == typename
end

function isnumber( n )
	return type( n ) == 'number'
end

function isstring( n )
	return type( n ) == 'string'
end

function istable( n )
	return type( n ) == 'table'
end

function isboolean( n )
	return type( n ) == 'boolean'
end

function isfunction( n )
	return type( n ) == 'function'
end

--------------------------------------------------------------------
function printf(patt,...)
	return print(string.format(patt,...))
end

function getG( key, default )
	local v = rawget( _G, key )
	if v == nil then return default end
	return v
end

--------------------------------------------------------------------
-----!!!!! ENABLE this to find forgotten log location !!!!
--------------------------------------------------------------------
-- function print(...)
-- 	_print(debug.traceback())
-- 	return _print(...)
-- end
if getG( 'MOCK_DISABLE_LOG' ) then
	print = function()
	end
	printf = function()
	end
end

function nilFunc() end

--------------------------------------------------------------------
----------Table Helpers
--------------------------------------------------------------------

function vextend(t,data)
	return setmetatable(data or {},{__index=t})
end

table.vextend=vextend

function table.extract( t, ... )
	local res = {}
	local keys = {}
	for i, key in ipairs( keys ) do
		res[ i ] = t[ key ]
	end
	return unpack( res )
end

function table.extend(t,t1)
	for k,v in pairs(t1) do
		t[k]=v
	end
	return t
end

function table.extend2(t,t1)
	for k,v in pairs(t1) do
		local v0 = t[ k ]
		if v0 == nil then
			t[k]=v
		end
	end
	return t
end

function table.filter( t, f )
	local output = {}
	for k, v in pairs( t ) do
		if f( v ) then output[ k ] = v end
	end
	return output
end

function table.map( t, f )
	local output = {}
	for k, v in pairs( t ) do
		local v11 = f( v )
		output[ k ] = v1
	end
	return output
end

function table.filterkey( t, f )
	local output = {}
	for k, v in pairs( t ) do
		if f( k ) then output[ k ] = v end
	end
	return output
end


function table.filteritem( t, f )
	local output = {}
	for k, v in pairs( t ) do
		if f( k, v ) then output[ k ] = v end
	end
	return output
end

local next=next
function table.len(t)
	local v=0
	for k in pairs(t) do
		v=v+1
	end
	return v
end

function table.sub(t,s,e)
	local t1={}
	local l=#t
	for i=s, e do
		if i>l then break end
		t1[i-s+1]= t[i]
	end

	return t1
end

local _cmpInner
local function _cmpReversed( a, b )
	return not _cmpInner( a, b )
end
local function _cmpGT( a,b )
	return a > b
end
local tsort = table.sort
---------------------------------------------------------------------
function table.sortdesc( t, comp )
	local _cmp
	if comp then
		_cmpInner = comp
		tsort( t, _cmpReversed )
		_cmpInner = nil
	else
		tsort( t, _cmpGT )
	end
end

function table.sum(t)
	local s=0
	for k,v in ipairs(t) do
		s=s+v
	end
	return s
end

function table.swap( t, k1, k2 )
	t[ k2 ], t[ k1 ] = t[ k1 ], t[ k2 ]
end

function table.shuffle( t )
	local l = #t
	local output = {}
	for i = 1, l do
		output[ i ] = randextract( t )
	end
	for i = 1, l do
		t[ i ] = output[ i ]
	end
end

function table.swapkv( t )
	local t1 = {}
	for k, v in pairs( t ) do
		t1[ v ] = k
	end
	return t1
end

function table.deepget( t, key1, key2, ... )
	local v = t[ key1 ]
	if not v then return nil end
	if key2 then
		return table.deepget( v, key2, ... )
	else
		return v
	end
end

local weakMT={ __mode = 'kv' }
function table.weak( n )
	return setmetatable( n or {}, weakMT)
end

local weakKMT={ __mode = 'k' }
function table.weak_k( n )
	return setmetatable( n or {}, weakKMT)
end

local weakVMT={ __mode = 'v' }
function table.weak_v( n )
	return setmetatable( n or {}, weakVMT)
end

function table.index( t, v )
	for k, v1 in pairs( t ) do
		if v1==v then return k end
	end
	return nil
end

function table.removevalue( t, v )
	local idx = table.index( t, v )
	if idx then
		return table.remove( t, idx )
	end
end

function table.match( t, func )	
	for k, v in pairs( t ) do
		if func( k,v ) then return k, v end
	end
	return nil
end

function table.get( t, k, default )
	local v = t[ k ]
	if v == nil then return default end
	return v
end

function table.haskey( t, k )
	return t[ k ] ~= nil
end

function table.hasvalue( t, v )
	local idx = table.index( t, v )
	return idx ~= nil
end

function table.randremove(t)
	local n=#t
	if n>0 then
		return table.remove(t,randi(1,n))
	else
		return nil
	end
end

function table.replace( t, t1 )
	while true do
		local k = next( t )
		if k == nil then return end
		t[ k ] = nil
	end
	for k, v in pairs( t1 ) do
		t[ k ] = v
	end
end


function table.extractvalues( t )
	local r = {}
	local i = 1
	for k, v in pairs( t ) do
		r[i] = v
		i = i + 1
	end
	return r
end

function table.simpleprint(t) 
	for k,v in pairs( t ) do
		print( k, v )
	end
end

function table.print(t) 
	return print( table.show( t ) )
end

function table.simplecopy(t)
	local nt={}
	for k,v in pairs(t) do
		nt[k]=v
	end
	return nt
end

function table.datacopy( t )
	local packed = assert( mp_pack( t ) )
	return mp_unpack( packed )
end

function table.listcopy(src,dst,keylist)
	for i, k in ipairs(keylist) do
		dst[k]=src[k]
	end
end

function table.sub(t,f,s)
	local l=#t
	local nt={}
	local e=f+s
	for i=f, e>l and l or e do
		nt[i-f+1]=t[i]
	end
	return nt
end

function table.split(t,s)
	local l=#t
	local t1,t2={},{}
	for i=1, s>l and l or s do
		t1[i]=t[i]
	end
	for i=s+1,l do
		t2[i-s+1]=t[i]
	end
	return t1,t2
end

function table.merge( a, b )
	local result = table.simplecopy( a )
	table.extend( result, b )
	return result
end

local function _table_clone( a )
	local result = {}
	for k, v in pairs( a ) do
		if type( v ) == 'table' then
			result[ k ] = _table_clone( v )
		else
			result[ k ] = v
		end
	end
	return result
end

function table.clone( a )
	return _table_clone( a )
end

-- function table.mergearray( a1, a2 )
-- 	local result = {}
-- 	for i, v in ipairs( a1 ) do
-- 		result[ i ] = v
-- 	end
-- 	local off = #a1
-- 	for i, v in ipairs( a2 ) do
-- 		result[ i + off ] = v
-- 	end
-- 	return result
-- end

function table.keys( t )
	local keys = {}
	local i = 1
	for k in pairs( t ) do
		keys[ i ] = k
		i = i + 1
	end
	return keys
end

function table.sortedkeys( t )
	local keys = table.keys( t )
	table.sort( keys )
	return keys
end

function table.values( t )
	local values = {}
	local i = 1
	for _, v in pairs( t ) do
		values[ i ] = v
		i = i + 1
	end
	return values
end

function table.reversed( t )
	local t1 = {}
	local count = #t
	for i = 1, count do
		t1[ i ] = t[ count - i + 1 ]
	end
	return t1
end

function table.reversed2( t )
	local t1 = {}
	local count = #t/2
	for i = 0, count - 1 do
		local j = count - i - 1
		t1[ i * 2 + 1 ] = t[ j * 2 + 1 ]
		t1[ i * 2 + 2 ] = t[ j * 2 + 2 ]
	end
	return t1
end

function table.reversed3( t )
	local t1 = {}
	local count = #t/3
	for i = 0, count - 1 do
		local j = count - i - 1
		t1[ i * 3 + 1 ] = t[ j * 3 + 1 ]
		t1[ i * 3 + 2 ] = t[ j * 3 + 2 ]
		t1[ i * 3 + 3 ] = t[ j * 3 + 3 ]
	end
	return t1
end

function table.affirm( t, k, default )
	local v = t[ k ]
	if v then return v end
	t[ k ] = default
	return default
end

function table.sub( t, a, b )
	b = b or -1
	local l = #t
	a = a > 0 and a or ( l + a + 1 )
	b = b > 0 and b or ( l + b + 1 )
	local t1 = {}
	for i = a, b do
		t1[ i - a + 1 ] = t[ i ]
	end
	return t1
end

function table.process( t, func, ... )
	local output = {}
	for k, v in pairs( t ) do
		output[ k ] = func( v, ... )
	end
	return output
end

function table.join( t1, t2 )
	local result = {}
	local n1 = #t1
	local n2 = #t2
	for i = 1, n1 do
		result[ i ] = t1[i]
	end
	for i = 1, n2 do
		result[ i + n1 ] = t2[i]
	end
	return result
end

local function _tableQuery( t, k, ... )
	if k == nil then return t end
	local v = t[ k ]
	if v then return _tableQuery( v, ... ) end
	return nil
end

function table.query( t, k, ... )
	assert( t and k )
	return _tableQuery( t, k, ... )
end

local _tableHashWriter = MOAIHashWriter.new()
function calcTableHash( t )
	local json = encodeJSON( t, true )
	_tableHashWriter:openCRC32()
	_tableHashWriter:write( json )
	_tableHashWriter:close()
	return _tableHashWriter:getHashHex()
end


function table.jointo( t1, t2 )
	local n1 = #t1
	for i = 1, #t2 do
		t1[ n1 +i ] = t2[ i ]
	end
end

local function _table_append( t, a, b, ... )
	tinsert( t, a )
	if b == nil then return end
	return _table_append( t, b, ... )
end
table.append = _table_append


--------------------------------------------------------------------
----MATH & Geometry
--------------------------------------------------------------------
local sqrt,atan2=math.sqrt,math.atan2
local min,max=math.min,math.max
local sin   = math.sin
local cos   = math.cos
local tan   = math.tan
local atan2 = math.atan2
local pi    = math.pi
local D2R   = pi/180
local R2D   = 180/pi

function math.mod1( a, b ) return ( ( a-1 ) % b ) + 1 end

if MOCKHelper.sind then
	math.sind = MOCKHelper.sind
	math.cosd = MOCKHelper.cosd
else
	function math.cosd(d) return cos(D2R*d) end
	function math.sind(d) return sin(D2R*d) end
end

function math.tand(d) return tan(D2R*d) end

function math.atan2d(dy,dx) return atan2(dy,dx)/pi*180 end

function arc2d(a) return a/pi*180 end

function d2arc(d) return d*D2R end

function circle(x,y,r,a)
	return x+cos(a)*r,y+sin(a)*r
end

local floor=math.floor
function floors(...)
	local t={...}
	for i,v in ipairs(t) do
		t[i]=floor(v)
	end
	return unpack(t)
end

function stepped( v, step, center )
	step = step or 1
	local k = v/step
	if center then
		return floor( k + 0.5 ) * step
	else
		return floor( k ) * step
	end
end

function math.magnitude( dx, dy )
	return sqrt( dx*dx + dy*dy )
end

function math.sign( v )
	return v>0 and 1 or v<0 and -1 or 0
end

function math.modsplit( v, m )
	local i = math.floor( v/m )
	local f = math.fmod( v,m )
	return i, f
end

function math.average( ... )
	local count = select( '#', ... )
	local sum = 0
	for i = 1, count do
		sum = sum + select( i, ... )
	end
	return sum/count
end

if MOCKHelper.lerp then
	lerp = MOCKHelper.lerp
else
	function lerp( v1, v2, k )
		return v1 + k * ( v2 - v1 )
	end
end

math.lerp = lerp

function lerpAngle( v1, v2, k )
	local diff = wrapDir( v2 - v1 )
	return v1 + diff * k
end

function moveTowards(f, t, max)
	local delta = t - f
	local d = math.abs(delta)
	d = d < max and d or max

	delta = delta > 0 and d or -d
	return f + delta
end

local lerp=lerp
function rangeMap( v, s0,e0, s1,e1 )
	local r1 = e0 - s0
	local k  = ( v - s0 ) / r1
	return lerp( s1, e1, k )
end

function smoothstep( e1, e2, v )
	if v <= e1 then return 0 end
	if v >= e2 then return 1 end
	return ( v-e1 )/( e2-e1 )
end

function between(a,min,max)
	return a>=min and a<=max
end

if MOCKHelper.clamp then
	clamp = MOCKHelper.clamp
else
	function clamp( v, minv, maxv)
		return v>maxv and maxv or v<minv and minv or v
	end
end

function wrap( v, minv, maxv)
	local r = maxv - minv
	local d0 = v - minv
	local diff = d0 % r
	return minv + diff
end

function wrapAngle( angle )
	angle = angle % 360
	if angle > 180 then angle = angle - 360 end
	return angle
end

function approxEqual(a, b, epislon)
	epislon = epislon or 0.01
	
	if math.abs(a-b) < epislon then
		return true
	end
	return false
end

math.clamp = clamp
math.wrap  = wrap
math.wrapangle = wrapAngle

--Vector helpers
function distance3( x1, y1, z1, x2, y2, z2 )
	local dx=x1-x2
	local dy=y1-y2
	local dz=z1-z2
	return sqrt(dx*dx+dy*dy+dz*dz)
end

function distance( x1, y1, x2, y2 )
	local dx=x1-x2
	local dy=y1-y2
	return sqrt(dx*dx+dy*dy)
end

function distance3Sqrd(x1,y1,z1, x2,y2,z2 )
	local dx=x1-x2
	local dy=y1-y2
	local dz=z1-z2
	return dx*dx+dy*dy+dz*dz
end

function distanceSqrd(x1,y1,x2,y2)
	local dx=x1-x2
	local dy=y1-y2
	return dx*dx+dy*dy
end

if MOCKHelper.normalize then
	normalize = MOCKHelper.normalize
else
	function normalize(x,y)
		local l = sqrt(x*x+y*y)
		if l == 0 then return 0, 0 end
		return x/l, y/l
	end
end

if MOCKHelper.length then
	_G.length = MOCKHelper.length
else
	function length(x,y,z)
		y = y or 0
		z = z or 0
		return sqrt(x*x+y*y+z*z)
	end
end

function lengthSqrd(x,y)
	return x*x+y*y
end

-- Direction from 1 to 2
function direction(x1,y1,x2,y2)
	return atan2(y2-y1,x2-x1)
end

function vecDiff(x1,y1,x2,y2)
	local dx=x1-x2
	local dy=y1-y2
	return atan2(dy,dx),sqrt(dx*dx+dy*dy)
end

function inRect(x,y,x0,y0,x1,y1)
	return x>=x0 and x<=x1 and y>=y0 and y<=y1
end

function rect(x,y,w,h)
	local x1,y1=x+w,y+h
	return min(x,x1),min(y,y1),max(x,x1),max(y,y1)	
end

function splitOriginName( origin )
	if origin == 'top_left' then
		return 'top', 'left'
	elseif origin == 'teop_center' then
		return 'top', 'center'
	elseif origin == 'top_right' then
		return 'top', 'right'
	elseif origin == 'middle_left' then
		return 'middle', 'left'
	elseif origin == 'middle_center' then
		return 'middle', 'center'
	elseif origin == 'center' then
		return 'middle', 'center'
	elseif origin == 'middle_right' then
		return 'middle', 'right'
	elseif origin == 'bottom_left' then
		return 'bottom', 'left'
	elseif origin == 'bottom_center' then
		return 'bottom', 'center'
	elseif origin == 'bottom_right' then
		return 'bottom', 'right'
	end
end

function rectOrigin( origin, x0,y0,w,h )
	local x1, y1 = x0 + w, y0 + h
	-- if y0>y1 then y0,y1 = y1,y0 end
	-- if x0>x1 then x0,x1 = x1,x0 end
	local xc = (x0+x1)/2
	local yc = (y0+y1)/2
	if origin=='center' then 
		return xc, yc
	elseif origin=='middle_center' then 
		return xc, yc
	elseif origin=='top_left' then
		return x0, y1
	elseif origin=='top_right' then
		return x1, y1
	elseif origin=='top_center' then
		return xc, y1
	elseif origin=='bottom_left' then
		return x0, y0	
	elseif origin=='bottom_right' then
		return x1, y0
	elseif origin=='bottom_center' then
		return xc, y0
	elseif origin=='middle_left' then
		return x0, yc
	elseif origin=='middle_right' then
		return x1, yc
	end
	return xc,0
end

function rectCenter(x,y,w,h)
	x,y,x1,y1=x-w/2,y-h/2,x+w/2,y+h/2
	return min(x,x1),min(y,y1),max(x,x1),max(y,y1)	
end

function rectCenterTop(x,y,w,h)
	x,y,x1,y1=x-w/2,y,x+w/2,y+h
	return min(x,x1),min(y,y1),max(x,x1),max(y,y1)	
end

function vecAngle( angle, length )
	local d = angle * D2R
	if length then
		return length * cos( d ), length * sin( d )
	else
		return cos( d ), sin( d )
	end
end

function dotProduct(x1, y1, x2, y2)
	return x1*x2 + y1*y2
end

function dirToBitmask(nx, ny)

	local mask = 0
	if nx == 1 then
		mask = mask + 0x001
	elseif nx == -1 then
		mask = mask + 0x002
	end

	if ny == 1 then
		mask = mask + 0x004
	elseif ny == -1 then
		mask = mask + 0x008
	end

	return mask
end

function major4Direction2(nx, ny)
	local x, y = nx, ny
	local four_dir = {
		{0, 1}, {0, -1}, {1, 0}, {-1, 0}
	}

	local biggest = -1
	local biggestIndex = -1

	for i=1,4 do
		local dp = dotProduct(four_dir[i][1], four_dir[i][2], x, y)
		if dp >= biggest then
			biggestIndex = i
			biggest = dp
		end
	end

	return unpack(four_dir[biggestIndex])
end

function major4Direction(rotDir)
	local x, y = math.cosd( rotDir ), math.sind( rotDir )
	return major4Direction2(x, y)
end

function reflection(ix, iy, nx, ny)
	local dp = dotProduct(ix, iy, nx, ny)
	local rx = ix - 2 * nx * dp
	local ry = iy - 2 * ny * dp
	return rx, ry
end

local huge = math.huge
function calcBoundRect( verts )
	local bx0 = huge
	local by0 = huge
	local bx1 = -huge
	local by1 = -huge

	local count = #verts
	for id = 1, count, 2 do
		local x, y = verts[ id ], verts[ id + 1 ]
		bx0 = min( x, bx0 )
		bx1 = max( x, bx1 )
		by0 = min( y, by0 )
		by1 = max( y, by1 )
	end
	return bx0, by0, bx1, by1
end

function calcBoundBox( verts )
	local bx0 = huge
	local by0 = huge
	local bz0 = huge
	local bx1 = -huge
	local by1 = -huge
	local bz1 = -huge

	local count = #verts
	for id = 1, count, 2 do
		local x, y = verts[ id ], verts[ id + 1 ]
		bx0 = min( x, bx0 )
		bx1 = max( x, bx1 )
		by0 = min( y, by0 )
		by1 = max( y, by1 )
		bz0 = min( z, bz0 )
		bz1 = max( z, bz1 )
	end
	return bx0, by0, bz0, bx1, by1, bz1
end

--------------------------------------------------------------------
function calcAABB( verts )
	local x0,y0,x1,y1
	for i = 1, #verts, 2 do
		local x, y = verts[ i ], verts[ i + 1 ]
		x0 = x0 and ( x < x0 and x or x0 ) or x
		y0 = y0 and ( y < y0 and y or y0 ) or y
		x1 = x1 and ( x > x1 and x or x1 ) or x
		y1 = y1 and ( y > y1 and y or y1 ) or y
	end
	return x0 or 0, y0 or 0, x1 or 0, y1 or 0 
end


--gemometry related

-- Returns the distance from p to the closest point on line segment a-b.
function distanceToLine( ax, ay, bx, by, px, py )
	local dx, dy = projectionPointToLine(ax, ay, bx, by, px, py )
	dx = dx - px
	dy = dx - py
	return math.sqrt( dx * dx + dy * dy )
end

function projectPointToLine( ax, ay, bx, by, px, py )
	local dx = bx - ax
	local dy = by - ay
	if dx == 0 and dy == 0 then return dx, dy  end
	local t = ( (py-ay)*dy + (px-ax)*dx ) / (dy*dy + dx*dx)
	
	if t < 0 then
		dx = ax
		dy = ay
	elseif t > 1 then
		dx = bx
		dy = by
	else
		dx = ax+t*dx
		dy = ay+t*dy
	end

	return dx, dy 
end


function intersectLines( ax0, ay0, ax1, ay1, bx0, by0, bx1, by1 )
	-- Denominator for ua and ub are the same, so store this calculation
	local d = (by1 - by0) * (ax1 - ax0) - (bx1 - bx0) * (ay1 - ax0)

	-- Make sure there is not a division by zero - this also indicates that the lines are parallel.
	-- If n_a and n_b were both equal to zero the lines would be on top of each
	-- other (coincidental).  This check is not done because it is not
	-- necessary for this implementation (the parallel check accounts for this).
	if (d == 0) then
		return false
	end

	-- n_a and n_b are calculated as seperate values for readability
	local n_a = (bx1 - bx0) * (ax0 - by0) - (by1 - by0) * (ax0 - bx0)
	local n_b = (ax1 - ax0) * (ax0 - by0) - (ay1 - ax0) * (ax0 - bx0)

	-- Calculate the intermediate fractional point that the lines potentially intersect.
	local ua = n_a / d
	local ub = n_b / d

	-- The fractional point will be between 0 and 1 inclusive if the lines
	-- intersect.  If the fractional calculation is larger than 1 or smaller
	-- than 0 the lines would need to be longer to intersect.
	if (ua >= 0 and ua <= 1 and ub >= 0 and ub <= 1) then
		local x = ax0 + (ua * (ax1 - ax0))
		local y = ax0 + (ua * (ay1 - ax0))
		return true, x, y
	end

	return false
end


local sin = math.sin
local clock = os.clock
function wave( freq, min,max, phaseOff, timeoff, time )	
	phaseOff     = phaseOff or 0
	timeoff = timeoff or 0
	local t = ( time or clock() ) + timeoff
	return (sin( t *freq* (2*3.141592653) + phaseOff - 3.141592653/4 )*(max-min)+(min+max))/2
end

-- function wavefunc( freq, min, max, off )
-- 	off = off or 0
-- 	local t0 = os.clock()
-- 	local f = function()
-- 		local t = os.clock() + timeoff
-- 		return ( sin( t * freq* ( 2 * 3.141592653 ) ) * (max-min)+(min+max))/2
-- 	end
-- 	return f
-- end

function inRange(x,y,diff)
	local d=math.abs(x-y)
	return d<=diff
end

function centerRange(center,range)
	return center-range/2,center+range/2
end

function checkDimension(x,y,w,h)
	return (x==w and y==h) or (x==h and y==w)
end

function pow2(x)
	local i=2
	while x>i do
		i=i*2
	end
	return i
end

local abs = math.abs
function powsign( x, y )
	local v = abs( x )
	return x > 0 and x ^ y or  - ( x^y )
end


function isInteger(v)
	return math.floor(v) == v
end

function isFractal(v)
	return math.floor(v) ~= v
end

function isNonEmptyString( s )
	local tt = type( s )
	if tt == 'string' then return #s > 0 end
	return false
end

function nonEmptyString( s )
	if type( s ) == 'string' and s ~= '' then return s end
	return nil
end

function nonWhiteSpaceString( s )
	if type( s ) == 'string' then
		s = s:trim()
		if s ~= '' then return s end
	end
	return nil
end



--------------------------------------------------------------------
--String Helpers
--------------------------------------------------------------------

function stringSet(t, v)
	local res={}
	v=v==nil and true or v
	for i, s in ipairs(t) do
		res[s]=v
	end
	return res
end

function string.trim(s)
  return match(s,'^()%s*$') and '' or match(s,'^%s*(.*%S)')
end

function string.gsplit(s, sep, plain )
	sep = sep or '\n'
	plain = plain ~= false
	local start = 1
	local done = false
	local function pass(i, j, ...)
		if i then
			local seg = s:sub(start, i - 1)
			start = j + 1
			return seg, ...
		else
			done = true
			return s:sub(start)
		end
	end
	return function()
		if done then return end
		if sep == '' then done = true return s end
		return pass( s:find(sep, start, plain) )
	end
end

function string.split( s, sep, plain )
	local result = {}
	local i = 0
	for p in string.gsplit( s, sep, plain ) do
		i = i + 1
		result[ i ] = p
	end
	return result, i
end

function string.startwith(s,s1)
	local ss = string.sub(s,1,#s1)
	return ss==s1
end

function string.endwith(s,s1)
	local l  = #s1
	local ss = string.sub(s,-l,-1)
	return ss==s1
end

function string.findlast( s, pattern )
	local fp0, fp1
	while true do
		local p0, p1 = string.find( s, pattern, fp1 and ( fp1 + 1 ) or nil )
		if not p0 then break end
		fp0 = p0
		fp1 = p1
	end
	return fp0, fp1
end

function string.count( s, pattern )
	local fp0, fp1
	local count = 0
	while true do
		local p0, p1 = string.find( s, pattern, fp1 and ( fp1 + 1 ) or nil )
		if not p0 then break end
		fp0 = p0
		fp1 = p1
		count = count + 1
	end
	return count
end

local quotepattern = '(['..("%^$().[]*+-?"):gsub("(.)", "%%%1")..'])'
function string.escapepattern( str )
	return gsub( str, quotepattern, "%%%1" )
end

local _vectorTemplateCache = {}
local function _makeVectorTemplate( element, count )
	local t = _vectorTemplateCache[ element ]
	local template = t and t[ count ]
	if template then return template end
	local inner = ''
	for i = 1, count do
		inner = inner .. element
		if i < count then
			inner = inner .. ', '
		end
	end
	local template = string.format( '( %s )', inner )
	if not t then
		t = {}
		_vectorTemplateCache[ element ] = t
	end
	t[ count ] = template
	return template
end

function string.formatvector( element, ... )
	-- body
	local count = select( '#', ... )
	local template = _makeVectorTemplate( element, count )
	return string.format( template, ... )
end

function string.join( sep, t )
	local result = nil
	for i, s in ipairs( t ) do
		s = tostring( s )
		if result then
			result = result .. sep .. s
		else
			result = s
		end
	end
	return result
end

function string.fromlines( ... )
	return string.join( '\n', {...} )
end


local function _urlencode( str )
	str = gsub (str, "\r?\n", "\r\n")
	--Percent-encode all non-unreserved characters
	--as per RFC 3986, Section 2.3
	--(except for space, which gets plus-encoded)
	str = gsub (str, "([^%w%-%.%_%~ ])",
	  function (c) return format ("%%%02X", byte(c)) end)
	--Convert spaces to plus signs
	str = gsub (str, " ", "+")
end

string.urlencode = _urlencode

function table.urlencode( t )
	local argts = {}
	local i = 1
	for k, v in pairs(t) do
		argts[i]=_urlencode(k).."=".._urlencode(v)
		i=i+1
	end
	return table.concat(argts,'&')
end


local function processCodeLine( condIdx, line )
	local ifBody = line:match( 'if%s*(.*)%s*then%s*$' )
	if ifBody then
		local ctype = 'if'
		local procesed = string.format( 'if _cond_[%d] or ( %s ) then', condIdx + 1, ifBody )
		return ctype, procesed
	end
	return false, line
end
--------------------------------------------------------------------
function loadpreprocess2( src, chunkname )
	local line = 0
	local chunkSrc = 'local _LINE_ = ...'
	local condIdx = 0
	for l in src:gsplit( '\n' ) do
		local code = l:match( '^%s*$(.*)')
		line = line + 1
		if code then
			local ctype, processedCode = processCodeLine( condIdx, code )
			if ctype == 'if' then
				code = processedCode
				condIdx = condIdx + 1
			end
			chunkSrc = chunkSrc .. code .. '\n'
		else
			chunkSrc = chunkSrc .. string.format( '_LINE_( %d, %q )\n', line, l )
		end
	end
	print( chunkSrc )
	local chunk, loadErr = loadstring( chunkSrc, chunkname or '<preprocess>' )
	
	if not chunk then
		return false, 'parsing error:' .. loadErr
	end
	
	local templateFunc = function( env )
		local currentLine = 1
		local result = ''
		local function _addLine( lineId, text )
			result = result .. string.rep( '\n', lineId - currentLine )
			result = result .. text
			currentLine = lineId
		end
		setfenv( chunk, env or {} )
		local ok, evalErr = pcall( chunk, _addLine )
		if not ok then
			return false, 'preprocessing error:' .. evalErr
		end
		return result
	end

	return templateFunc
end


--------------------------------------------------------------------
function loadpreprocess( src, chunkname )
	local line = 0
	local chunkSrc = 'local _LINE_ = ...\nlocal _O=""'
	for l in src:gsplit( '\n' ) do
		local code = l:match( '^%s*$(.*)')
		line = line + 1
		if code then
			chunkSrc = chunkSrc .. code .. '\n'
		else
			if l ~= "" then
				chunkSrc = chunkSrc .. string.format( '_O = _O .. _LINE_( %d, %q )\n', line, l )
			end
		end
	end
	chunkSrc = chunkSrc .. '\nreturn _O'
	local chunk, loadErr = loadstring( chunkSrc, chunkname or '<preprocess>' )
	if not chunk then
		return false, 'parsing error:' .. loadErr
	end
	
	local templateFunc = function( env, lineFunc )
		local currentLine = 1

		local function _addLine( lineId, text )
			local line = ''
			line = line .. string.rep( '\n', lineId - currentLine )
			line = line .. text
			currentLine = lineId
			return line
		end

		setfenv( chunk, env or {} )
		local ok, output = pcall( chunk, lineFunc or _addLine )
		if not ok then
			return false, 'preprocessing error:' .. output
		end
		return output
	end

	return templateFunc
end

function preprocess( src, env, chunkname )
	local templateFunc, err = loadpreprocess( src, chunkname )
	if not templateFunc then return false, err end
	return templateFunc( env )
end

--------------------------------------------------------------------
local autotableMT={
	__index=function(t,k)
		local r={}
		t[k]=r
		return r
	end
}

function newAutoTable(t1)
	return setmetatable(t1 or {},autotableMT)
end

-------------Strange Helpers
function numWithCommas(n)
  return tostring(math.floor(n)):reverse():gsub("(%d%d%d)","%1,")
                                :gsub(",(%-?)$","%1"):reverse()
end


local eachMT={
	__index=function(t,k)
		t.__methodToCall__=k
		return t
	end,
	__newindex = function( t,k,v )
		for i, o in ipairs(t.__objects__) do
			o[k] = v			
		end
	end,
	__call=function(t,t1,...)
		local m={}
		local methodname=t.__methodToCall__
		if t==t1 then
			for i, o in ipairs(t.__objects__) do
				m[i]=o[methodname](o,...)
			end
		else
			for i, o in ipairs(t.__objects__) do
				m[i]=o[methodname](...)
			end
		end
		return unpack(m)
	end
}


function eachT(t)
	return setmetatable( { 
		__objects__      = t or {},
		__methodToCall__ = false
		},eachMT)
end

function each(...)
	return eachT({...})
end


local function _oneOf(v,a,b,...)
	if v==a then return true end
	if b~=nil then
		return _oneOf(v,b,...)
	end
	return false
end

oneOf = _oneOf

------------------------------------------------------------------------
function isIn( value, ... )
	for i, v in ipairs{ ... } do
		if value == v then return true end
	end
	return false
end

--------------TIME & DATE
function formatSecs( s, hour, millisecs ) --return 'mm:ss'
	local m = math.floor(s/60)
	local ss=s-m*60
	local fac = s - math.floor( s )
	local result
	if hour then
		local hh=math.floor(s/60/60)
		m=m-hh*60
		result = string.format('%02d:%02d:%02d',hh,m,ss)
	else
		result = string.format('%02d:%02d',m,ss)
	end
	if millisecs then
		result = result .. string.format( '.%02d', fac*100 )
	end
	return result
end


function fakeSecs(s) --return '00:ss(99)'
	-- local m=math.floor(s/60)
	-- local ss=s-m*60
	if s>99 then s=99 end
	return string.format('%02d:%02d',0,s)
end


local function timeDiffName(t2,t1)
	local diff=os.difftime(t2,t1)
	if diff<60 then
		return diff..'secs'
	elseif diff<60*60 then
		return math.floor(diff/60)..' mins'
	elseif diff<60*60*24 then
		return math.floor(diff/60/60)..' hours'
	elseif diff<60*60*24*7 then
		return math.floor(diff/60/60/24)..' days'
	elseif diff<60*60*60*24*30 then
		return math.floor(diff/60/60/24/7)..' weeks'
	else
		return math.floor(diff/60/60/24/30)..' months'
	end
end

----------Color helpers
if MOCKHelper.hexColor then
	hexcolor = MOCKHelper.hexColor
	
else
	local ssub=string.sub
	local format = string.format

	function hexcolor( s, alpha ) --convert #ffffff to (1,1,1)
		local l = #s
		if l >= 7 then
			if l == 9 then
				alpha = alpha or tonumber('0x'..ssub(s,8,9))/255
			end
			local r,g,b
			r = tonumber('0x'..ssub(s,2,3))/255
			g = tonumber('0x'..ssub(s,4,5))/255
			b = tonumber('0x'..ssub(s,6,7))/255
			return r,g,b,alpha or 1
		elseif l >= 4 then
			if l == 5 then
				alpha = alpha or tonumber('0x'..ssub(s,5,5))/15
			end
			local r,g,b
			r = tonumber('0x'..ssub(s,2,2))/15
			g = tonumber('0x'..ssub(s,3,3))/15
			b = tonumber('0x'..ssub(s,4,4))/15
			return r,g,b,alpha or 1
		else
			return nil
		end
	end
end

function colorhex( r,g,b, a )
	local R = clamp( r, 0, 1) * 255
	local G = clamp( g, 0, 1) * 255
	local B = clamp( b, 0, 1) * 255
	if a then
		local A = clamp( a, 0, 1) * 255
		return format( '#%02x%02x%02x%02x', R,G,B,A )
	else
		return format( '#%02x%02x%02x', R,G,B )
	end
end

function HSL(h, s, l, a)
   if s == 0 then return l,l,l,a or 1 end
   -- h, s, l = h/60, s, l
   h=h/60
   local c = (1-math.abs(2*l-1))*s
   local x = (1-math.abs(h%2-1))*c
   local m,r,g,b = (l-.5*c), 0,0,0
   if h < 1     then r,g,b = c,x,0
   elseif h < 2 then r,g,b = x,c,0
   elseif h < 3 then r,g,b = 0,c,x
   elseif h < 4 then r,g,b = 0,x,c
   elseif h < 5 then r,g,b = x,0,c
   else              r,g,b = c,0,x
   end
   return 
   	math.ceil((r+m)*256)/256,
   	math.ceil((g+m)*256)/256,
   	math.ceil((b+m)*256)/256,
   	a or 1
end


function gradColor(colors,k)
	local count=#colors
	
	assert(count>1)

	local spans=count-1
	local pitch=1/spans
	local start=math.floor(k/pitch)
	
	local frac=(k-start*pitch)/pitch
	
	local r1,g1,b1,a1 = unpack(colors[start+1])
	local r2,g2,b2,a2 = unpack(colors[math.min(start+2,count)])
	
	-- print(r1,g1,b1,r2,g2,b2,frac)

	return lerp(r1,r2,frac),
		   lerp(g1,g2,frac),
		   lerp(b1,b2,frac),
		   lerp(a1 or 1,a2 or 1,frac)
end



------------extend clock closure
function newClock(srcTimer)
	srcTimer = srcTimer or os.clock
	-- local base=srcTimer()
	local paused=true
	local lasttime=0
	local elapsed=0

	return function(op,arg)
		op = op or 'get'

		if op=='reset' then
			lasttime=srcTimer()
			elapsed=0
			paused=true
			return 0
		elseif op=='set' then
			lasttime=srcTimer()
			elapsed=arg	or 0		
			return elapsed
		end

		if paused then
			if op=='get' then
				return elapsed
			elseif op=='resume' then
				paused=false
				lasttime=srcTimer()
				return elapsed
			end
		else
			local newtime=srcTimer()
			elapsed=elapsed+(newtime-lasttime)
			lasttime=newtime
			if op=='get' then
				return elapsed
			elseif op=='pause' then
				paused=true
				return elapsed
			end
		end
	end
end


function tickTimer(defaultInterval,srcTimer)
	srcTimer=srcTimer or os.clock
	local baseTime=srcTimer()
	defaultInterval=defaultInterval or 1
	return function(interval)
		interval=interval or defaultInterval
		local ntime=srcTimer()
		if ntime>= baseTime+interval then
			baseTime=baseTime+interval
			return true
		end
		return false
	end
end


function ticker(m,i)
	i=i or 0
	local t=coroutine.wrap(function()
		while true do
			i=i+1
			if i>=m then
				i=coroutine.yield(true) or 0
			else
				coroutine.yield(false) 
			end
		end
	end)
	return t
end

function tickerd(m,i)
	i=i or 0
	local t=coroutine.wrap(function()
		local mm=m
		while true do
			i=i+1
			if i>=mm then
				mm=coroutine.yield(true) or m
				i=0
			else
				mm=coroutine.yield(false) or m
			end
		end
	end)
	return t
end




--------------------------------------------------------------------
-------Debug Helper?
--------------------------------------------------------------------
local nameCounters={} --setmetatable({},{__mode='k'})
function nameCount(name,c)
	local v=nameCounters[name] or 0
	v=v+c
	print(name, c>0 and "+"..c or "-"..math.abs(c),'-> ',v)
	nameCounters[name]=v
	return v
end

function dostring(s,...)
	local f=loadstring(s)
	return f(...)
end

local counts={}
function callLimiter(name,count,onExceed)
	if not count then counts[name]=0 return end
	local c=counts[name] or 0
	c=c+1
	if c>=count then 
		if onExceed then onExceed() end
		return error('call limited exceed:'..name)
	end
	counts[name]=c
end

function loadSheetData(t,container) --load data converted from spreadsheet
	--read column title
	container=container or {}
	for tname,sheet in pairs(t) do
		
		local mode
		if tname:match('@kv') then 
			mode='kv'
		elseif tname:match('@list') then
			mode='list'
		elseif tname:match('@raw') then
			mode='raw'
		else
			mode='normal'
		end

		tname = tname:match('([^@]*)[%.@]*')
		local r1 = sheet[1]
		local colCount = #r1
		local result = {}

		if mode~='raw' then
			for i=2,#sheet do
				local row=sheet[i]
				if next(row) then --skip empty row
				
					if mode=='list' then
						local data={}
						for j=1,colCount do
							local col=r1[j]
							data[col]=row[j]
						end
						result[i-1]=data
					else
						local key=row[1]
						if key then
							assert(not result[key], "duplicated key:"..key)
							if mode=='kv' then
								data=row[2]
							else
								data={}
								for j=2,colCount do
									local col=r1[j]
									data[col]=row[j]
								end
							end
							result[key]=data
						end
					end

				end --end if empty 
			end --endfor
		else--raw mode
			result=sheet
		end
		-- print(">>>>table:",tname,result)
		-- for k,v in pairs(result) do
		-- 	print(k,v)
 	-- 	end
 	-- 	print("------")
		container[tname]=result
	end

	return container
end


function makeStrictTable(t)
	return setmetatable(t or {}, {
			__index=function(t,k) error("item not found:"..k, 2) end
		}
	)
end


--------STACK & QUEUE
function newStack()
	local s={}
	local t=0
	local function pop(self) --fake parameter
		if t==0 then return nil end
		local v=s[t]
		s[t]=nil
		t=t-1
		return v
	end

	local function peek(self)
		return t>0 and s[t] or nil
	end

	local function push(self,v)
		t=t+1
		s[t]=v
		return v
	end

	return {_stack=s, pop=pop,peek=peek,push=push}
end

function newQueue()
	local s={}
	local t=0
	local h=0
	local function pop(self) --fake parameter
		if h>=t then return nil end
		h=h+1
		local v=s[h]
		s[h]=nil
		return v
	end

	local function peek(self)
		return h>=t and s[h] or nil
	end

	local function push(self,v)
		t=t+1
		s[t]=v
		return v
	end

	return {_queue=s, pop=pop,peek=peek,push=push}
end


--------------------------------------------------------------------
--OS Related
--------------------------------------------------------------------
function ___sleep(n)
  os.execute("sleep " .. tonumber(n))
end

--------------------------------------------------------------------
--MISC
--------------------------------------------------------------------
--[[
   Author: Julio Manuel Fernandez-Diaz
   Date:   January 12, 2007
   (For Lua 5.1)
   
   Modified slightly by RiciLake to avoid the unnecessary table traversal in tablecount()

   Formats tables with cycles recursively to any depth.
   The output is returned as a string.
   References to other tables are shown as values.
   Self references are indicated.

   The string returned is "Lua code", which can be procesed
   (in the case in which indent is composed by spaces or "--").
   Userdata and function keys and values are shown as strings,
   which logically are exactly not equivalent to the original code.

   This routine can serve for pretty formating tables with
   proper indentations, apart from printing them:

      print(table.show(t, "t"))   -- a typical use
   
   Heavily based on "Saving tables with cycles", PIL2, p. 113.

   Arguments:
      t is the table.
      name is the name of the table (optional)
      indent is a first indentation (optional).
--]]
function table.show(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   --[[ counts the number of elements in a table
   local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
   end
   ]]
   -- (RiciLake) returns true if the table is empty
   local function isemptytable(t) return next(t) == nil end

   local function basicSerialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return string.format("%q", so .. ", C function")
         else 
            -- the information is defined through lines
            return string.format("%q", so .. ", defined in (" ..
                info.linedefined .. "-" .. info.lastlinedefined ..
                ")" .. info.source)
         end
      elseif type(o) == "number" or type(o) == "boolean" then
         return so
      else
         return string.format("%q", so)
      end
   end

   local function addtocart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if type(value) ~= "table" then
         cart = cart .. " = " .. basicSerialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value] 
                        .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = string.format("%s[%s]", name, k)
                  field = string.format("[%s]", k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end


-- --------------------------------------------------------------------
-- local weakVMT = { 
-- 	__call = function( t, v )
-- 		t[1] = v
-- 	end,
-- 	__mode = 'v' }
-- function newweakref( value )
-- 	local t = setmetatable( {}, weakVMT )
-- 	t[1] = value
-- 	return t
-- end


--tool functions
function fixpath(p)
	p=gsub(p,'\\','/')
	return p
end

local function splitpath( path )
	path = fixpath( path )
	local dir, file = match( path, '(.*)/(.*)' )
	if not dir then
		dir = ''
		file = path
	end
	local name, ext = match( file, '(.*)%.(.*)' )
	if not name then
		name = file
		ext = ''
	end
	return dir, name, ext
end

function stripext(p)
	return gsub( p, '%.[^.]*$', '' )
end

function stripdir(p)
	p = fixpath(p)
	return match(p, "[^\\/]+$")
end

function basename(p)
	return stripdir( p )
end

function basename_noext(p)
	return stripext( stripdir(p) )
end

function dirname(p)
	local dname, bname = splitpath( p )
	return dname
end

_G.splitpath = splitpath

-------others------
if MOCKHelper.wrapDir then
	wrapDir = MOCKHelper.wrapDir
else
	function wrapDir( angle )
		angle = angle % 360
		if angle > 180 then angle = angle - 360 end
		return angle
	end
end


local function strToValue( v )
	if v == 'true' then return true end
	if v == 'false' then return false end
	local n = tonumber( v )
	if n then return n end
	return v
end

function parseSimpleStringList( data )
	local output = {}
	for s in data:gsplit( ',' ) do
		s = s:trim()
		table.insert( output, s )
	end
	return output
end

function parseSimpleValueList( data )
	local output = {}
	for s in data:gsplit( ',' ) do
		s = s:trim()
		table.insert( output, strToValue( s ) )
	end
	return output
end

function parseSimpleNamedValueList( data )
	local output = {}
	for s in data:gsplit( ',' ) do
		s = s:trim()
		local key, value = s:match( '^([%w_]+)%s*=(.*)')
		if key then
			value = strToValue( value )
		else
			key = s
			value = true
		end
		output[ key ] = value
	end
	return output
end

function parseNamedParenValueList( data )
	local output = {}
	for s in data:gsplit( ',' ) do
		s = s:trim()
		local key, value = s:match( '^([%w_]+)%s*%((.*)%)')
		if key then
			value = strToValue( value )
		else
			key = s
			value = true
		end
		output[ key ] = value
	end
	return output
end

function parseNamedArgumentsList( data )
	local output = {}
	for s in data:gsplit( ',' ) do
		s = s:trim()
		local key, value = s:match( '^([%w_]+)%s*%((.*)%)')
		if key then
			value = parseSimpleValueList( value )
		else
			key = s
			value = {}
		end
		output[ key ] = value
	end
	return output
end

function levenshtein(a, b)
	if #a == 0 then return #b end
	if #b == 0 then return #a end

	local matrix = {}
	local a_len = #a+1
	local b_len = #b+1

	-- increment along the first column of each row
	for i = 1, b_len do 
		matrix[i] = {i-1}
	end
	
	-- increment each column in the first row
	for j = 1, a_len do
		matrix[1][j] = j-1
	end

	-- Fill in the rest of the matrix
	for i = 2, b_len do
		for j = 2, a_len do
			if b:byte(i-1) == a:byte(j-1) then
				matrix[i][j] = matrix[i-1][j-1]
			else
				matrix[i][j] = math.min(
					matrix[i-1][j-1] + 1,	-- substitution
					matrix[i  ][j-1] + 1,	-- insertion
					matrix[i-1][j  ] + 1) 	-- deletion
			end
		end
	end

	return matrix[b_len][a_len]
end

function attenuation( distance, minDistance, maxDistance, power, minValue, maxValue )
	minValue = minValue or 0
	maxValue = maxValue or 1
	power = power or 2
	if distance <= minDistance then return maxValue end
	if distance >= maxDistance then return minValue end
	local d = maxDistance - minDistance
	local k = ( distance - minDistance ) / d
	return lerp( minValue, maxValue, ( 1 - k ^ power ) )
end

--------------------------------------------------------------------

--------------------------------------------------------------------
--------Random number & Probablity helpers
--------------------------------------------------------------------

function randi(mi,ma,rng)
	rng = rng or random
	mi,ma = floor(mi), floor(ma)
	return floor( mi + rng() * ( ma-mi+1) )
end

function rand(mi,ma, rng)
	rng = rng or random
	mi = mi or 1
	ma = ma or mi
	return mi + rng() * ( ma - mi )
end

-- function randParameters( ... )
-- 	print( 'randParameters' )
-- 	local ptable = { ... }
-- 	local l = #ptable
-- 	if l <= 0 then return end
-- 	return ptable[ randi( 1, l ) ]
-- end

function randboolean( rng )
	rng = rng or random
	return rng() >= 0.5
end

function randsign( rng )
	rng = rng or random
	if rng() >= 0.5 then
		return 1
	else
		return -1
	end
end

function noise( n0, n1, rng )
	n0 = n0 or 1
	if not n1 then
		n1 = n0
		n0 = 0
	end
	return randsign( rng ) * rand( n0, n1, rng )
end

function noisei( n0, n1, rng )
	return math.floor( noise( n0, n1, rng ) )
end

function prob( n, rng )
	rng = rng or random
	if n <= 0   then return false end
	if n >= 100 then return true  end
	local r = n
	
	return rng()*100<=n 
end

function probselect( t, rng )
	rng = rng or random
	local total=0
	for i, s in ipairs(t) do
		local w = s[1]
		if w > 0 then
			total=total+w
		end
	end
	
	local k = rng()*total
	local kk = 0

	for i, s in ipairs(t) do
		local w=s[1]
		if w > 0 then
			if k>kk and k<=kk+w then return s[2] end
			kk=kk+w
		end
	end
	return t.default
end

function randselect( t, rng )
	rng = rng or random
	local i = #t
	local k = ( math.floor( rng() * 100 * i ) % i )+1
	return t[ k ]
end

function randselectexcept( t, x, rng )
	rng = rng or random
	local v
	local t0 = { unpack( t ) }
	local l=#t0
	for i = 1, l do
		v = t0[ i ]
		if v == x then 
			table.remove( t0, i )
			break
		end
	end

	l = #t0
	v = t0[ randi( 1, l ) ]

	return v
end

function randextract( t, rng )
	rng = rng or random
	local i=#t
	if i<=0 then return nil end
	local k=(math.floor(rng()*100*i) % i)+1
	return table.remove(t,k)
end

local math_log = math.log
function gaussian ( mean, variance, rng )
	rng = rng or random
	return sqrt( -2 * ( variance or 1 ) * math_log( rng() ) ) *	cos( 2 * math.pi * rng() ) + ( mean or 0 )
end

function gaussianRange ( v0, v1, rng )
	if v1 < v0 then
		v0, v1 = v1, v0
	end
	local diff   = v1 - v0
	local center = ( v1 + v0 ) / 2
	return gaussian(  center, diff/2, rng )
end

function randNormal( mu, sigma )
	local NV_MAGICCONST = 1.71552776992

	local z
  while true do
      local u1 = math.random()
      local u2 = 1.0 - math.random()
      z = NV_MAGICCONST*(u1-0.5)/u2
      local zz = z*z/4.0
      if zz <= -math.log(u2) then
          break
      end
  end
      
  return mu + z*sigma
end

--------------------------------------------------------------------
local weakrefMT = { 
	__mode     = 'v', 
	__call     = function( t ) 
		return t[1]
	end,
}

function weakref( v )
	return setmetatable( {v}, weakrefMT )
end

function indexToGrid( i, col, gridWidth, gridHeight )
	local i0 = i - 1
	local row = math.floor( i0 / col )
	local col = i0 % col
	if gridWidth and gridHeight then --return loc
		return col*gridWidth, row*gridHeight
	else --return index
		return col + 1, row + 1
	end
end

--------------------------------------------------------------------
--table.cleared
if table.clear then
	local tclear = table.clear
	table.cleared = function( t ) tclear( t ) return t end
	
else
	function table.clear( t )
		while true do
			local k = next( t )
			if k == nil then return end
			t[ k ] = nil
		end
	end

	table.cleared = function( t )
		return {}
	end
end

--------------------------------------------------------------------
if not table.new then
	table.new = MOCKHelper.tablenew
end

assert( table.new )


--------------------------------------------------------------------
local strbufferProto = {}
local __strbufmeta

local function newstrbuffer()
	return setmetatable({}, __strbufmeta)
end

function strbufferProto:append(...)
	local c = #self
	for i = 1, select('#', ...) do
		self[ c + i ] = select( i, ... )
	end
	return self
end

function strbufferProto:concat( sep )
	return table.concat(self, sep)
end

function strbufferProto:copy()
	local buf = newstrbuffer()
	for i = 1, #self do
		buf[ i ] = self[ i ]
	end
	return buf
end

function strbufferProto:combine(b)
	local buf = self:copy()
	local tt = type( b )
	if tt == 'table' then
		local c = #self
		for i = 1, #b do
			self[ c+i ] = b[ i ]
		end
		return buf
	else
		return buf:append( b )
	end
end

function ip2dec(ip)
	local i, dec = 3, 0
	for d in string.gmatch(ip, "%d+") do
		dec = dec + 2 ^ (8 * i) * d
		i = i - 1
	end
	return dec
end

function dec2ip(decip) 
	local divisor, quotient, ip
	for i = 3, 0, -1 do
		divisor = 2 ^ (i * 8)
		quotient, decip = math.floor(decip / divisor), math.fmod(decip, divisor)
		ip = ip and quotient .. "." .. ip or quotient
	end
	return ip
end


__strbufmeta = {
	__index=strbufferProto;
	__tostring=strbufferProto.concat;
	__concat=strbufferProto.combine;
	__call=strbufferProto.append;
}

newStringBuffer = newstrbuffer
