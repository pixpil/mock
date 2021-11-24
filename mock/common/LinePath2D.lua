module 'mock'

--------------------------------------------------------------------
CLASS: LinePath2D ( Component )
	:MODEL{
		Field 'verts' :array( 'number' ) :getset( 'Verts' ) :no_edit();
		Field 'looped' :boolean() :isset( 'Looped' );
		Field 'reverse' :action();
		Field 'reset' :action();
	}
registerComponent( 'LinePath2D', LinePath2D )

function LinePath2D:__init()
	self.animCurve = false
	self.looped = false
	self.boundRect = {0,0,0,0}
	self.outputVerts = {}
	self:setVerts{
		0,0,
		0,100,
		100,100,
		100, 0
	}
end

function LinePath2D:setLooped( looped )
	self.looped = looped
	self:updateVerts()
end

function LinePath2D:isLooped()
	return self.looped
end

function LinePath2D:onAttach( ent )
	-- LinePath2D.__super.onAttach( self, ent )
	self:updateVerts()
end

function LinePath2D:getWorldVerts( role )
	local worldVerts = {}
	local verts = self.verts
	local count = #verts
	local ent = self:getEntity()
	local vcount = math.floor( count/2 )
	local prop = ent:getProp( role or 'render' )
	for i = 0, vcount - 1 do
		local k = i * 2
		local x, y = verts[ k + 1 ], verts[ k + 2 ]
		local x1,y1,z1 = prop:modelToWorld( x, y, 0 )
		local k2 = i * 3
		worldVerts[ k2 + 1 ] = x1
		worldVerts[ k2 + 2 ] = y1
		worldVerts[ k2 + 3 ] = z1
	end
	return worldVerts
end

function LinePath2D:getVerts( world )
	return self.verts
end

function LinePath2D:setVerts( verts )
	self.verts = verts 
	self:updateVerts()	
end

function LinePath2D:getStartPoint( world )
	local verts = self.verts
	local x, y = verts[ 1 ], verts[ 2 ]
	if world then
		local ent = self:getEntity()
		ent:forceUpdate()
		x, y, z = ent:modelToWorld( x, y, 0 )
	end
	return x, y, 0
end

function LinePath2D:getEndPoint( world )
	local verts = self.verts
	local count = #verts
	local x, y = verts[ count-1 ], verts[ count ]
	if world then
		local ent = self:getEntity()
		ent:forceUpdate()
		x, y, z = ent:modelToWorld( x, y, 0 )
	end
	return x, y, 0
end

function LinePath2D:updateVerts()
	self.animCurve = false
	if not self._entity then return end
	local verts = self.verts
	local x0,y0,x1,y1
	for i = 1, #verts, 2 do
		local x, y = verts[ i ], verts[ i + 1 ]
		x0 = x0 and ( x < x0 and x or x0 ) or x
		y0 = y0 and ( y < y0 and y or y0 ) or y
		x1 = x1 and ( x > x1 and x or x1 ) or x
		y1 = y1 and ( y > y1 and y or y1 ) or y
	end
	self.boundRect = { x0 or 0, y0 or 0, x1 or 0, y1 or 0 }
	local outputVerts = { unpack(verts) }
	if self:isLooped() then
		table.insert( outputVerts, outputVerts[ 1 ] )
		table.insert( outputVerts, outputVerts[ 2 ] )
	end
	local length = 0
	local length2 = 0
	local x0,y0 
	for i = 1, #outputVerts, 2 do
		local x, y = outputVerts[ i ], outputVerts[ i+1 ]
		if i > 1 then
			local l2 = distanceSqrd( x0,y0, x,y )
			local l = math.sqrt( l2 )
			length = length + l
			length2 = length2 + l2
		end
		x0,y0 = x, y
	end
	self.totalLength = length
	self.totalLength2 = length2
	self.outputVerts = outputVerts
end


function LinePath2D:onDraw()
	gfx.setPenWidth( self.penWidth )
	draw.drawLine( unpack( self.outputVerts ) )
end

function LinePath2D:onGetRect()
	return unpack( self.boundRect )
end

function LinePath2D:reverse()
	self.verts = table.reversed2( self.verts )
	self:updateVerts()
end

function LinePath2D:reset()
	self.outputVerts = {}
	self:setVerts{
		0,0,
		0,100,
		100,100,
		100, 0
	}
end

local insert = table.insert
function LinePath2D:makeSubPath( x0, y0, x1, y1, includeEndPoint )
	local px0, py0, va0, vb0 = self:projectPoint( x0, y0 )
	local px1, py1, va1, vb1 = self:projectPoint( x1, y1 )
	local looped = self.looped
	local output = {}
	insert( output, px0 )
	insert( output, py0 )
	local verts = self.verts
	local vcount = #verts/2
	local ent = self:getEntity()
	ent:forceUpdate()

	local l = 0
	local _x, _y = px0, py0
	if va0 > va1 then
		for i = va0, vb1, -1 do
			local k = ( i - 1 ) * 2
			local x, y = verts[ k + 1 ], verts[ k + 2 ]
			x, y = ent:modelToWorld( x, y )
			insert( output, x )
			insert( output, y )
			l = l + distance( x, y, _x, _y)
			_x, _y = x, y
		end
	elseif va0 < va1 then
		for i = vb0, va1, 1 do
			local k = ( i - 1 ) * 2
			local x, y = verts[ k + 1 ], verts[ k + 2 ]
			x, y = ent:modelToWorld( x, y )
			insert( output, x )
			insert( output, y )
			l = l + distance( x, y, _x, _y)
			_x, _y = x, y
		end
	end
	insert( output, px1 )
	insert( output, py1 )
	l = l + distance( px1, py1, _x, _y)
	if looped and l > self.totalLength/2 then --make reversed path
		output = {}
		insert( output, px0 )
		insert( output, py0 )		
		if va0 > va1 then -- dir+
			if vb0 == 1 then vb0 = vcount + 1 end
			local va1 = va1 + vcount
			local vb1 = vb1 + vcount
			for i = vb0, va1, 1 do
				i = ( ( i - 1 ) % vcount ) + 1
				local k = ( i - 1 ) * 2
				local x, y = verts[ k + 1 ], verts[ k + 2 ]
				x, y = ent:modelToWorld( x, y )
				insert( output, x )
				insert( output, y )
			end
		elseif va0 < va1 then
			local va0 = va0 + vcount
			local vb0 = vb0 + vcount
			if vb1 == 1 then vb1 = vcount + 1 end
			for i = va0, vb1, -1 do
				i = ( ( i - 1 ) % vcount ) + 1
				local k = ( i - 1 ) * 2
				local x, y = verts[ k + 1 ], verts[ k + 2 ]
				x, y = ent:modelToWorld( x, y )
				insert( output, x )
				insert( output, y )
			end
		end
		insert( output, px1 )
		insert( output, py1 )
	end
	if includeEndPoint then
		insert( output, x1 )
		insert( output, y1 )
	end
	return output
end

function LinePath2D:projectPoint( x, y )
	local ent = self:getEntity()
	ent:forceUpdate()
	x, y = ent:worldToModel( x, y )
	local verts = self.verts
	local vcount = #verts / 2
	local dstMin = math.huge
	local mx, my
	local va, vb
	local tail = self.looped and vcount or vcount - 1
	for v0 = 1, tail do
		local i = ( v0 - 1 ) * 2
		local v1 = ( v0 == vcount ) and 1 or ( v0 + 1 )
		local j = ( v1 - 1 ) * 2
		local x1,y1 = verts[ i + 1 ], verts[ i + 2 ]
		local x2,y2 = verts[ j + 1 ], verts[ j + 2 ]
		local px,py = projectPointToLine( x1,y1, x2,y2, x,y )
		local dst = distanceSqrd( px,py, x,y )
		if dst < dstMin then
			dstMin = dst
			mx = px
			my = py
			va = v0
			vb = v1
		end
	end
	mx, my = ent:modelToWorld( mx, my )
	return mx, my, va, vb
end

function LinePath2D:getAnimCurve()
	if not self.animCurve then
		self.animCurve = self:buildAnimCurve()
	end
	return self.animCurve
end

function LinePath2D:buildAnimCurve()
	local curve = MOAIAnimCurveVec.new()
	local mode = MOAIEaseType.LINEAR
	local verts = self.verts
	local count = #verts
	local vcount = math.floor( count/2 )
	if vcount < 2 then return curve end

	local totalLength = 0
	local x0, y0 = verts[ 1 ], verts[ 2 ]
	local spanLengths = {}
	for i = 1, vcount - 1 do
		local k = i * 2
		local x, y = verts[ k + 1 ], verts[ k + 2 ]
		local l = distance( x0, y0, x, y )
		x0 = x
		y0 = y
		totalLength = totalLength + l		
		spanLengths[ i ] = l
	end

	if totalLength == 0 then return curve end
	
	curve:reserveKeys( vcount )
	local t = 0
	for i = 0, vcount - 1 do
		local k = i * 2
		local x, y = verts[ k + 1 ], verts[ k + 2 ]
		local l = spanLengths[ i ] or 0
		t = t + l/totalLength
		curve:setKey( i + 1, t, x, y, 0, mode )
	end
	return curve

end

--------------------------------------------------------------------
--EDITOR
--------------------------------------------------------------------
function LinePath2D:onBuildGizmo()
	return mock_edit.DrawScriptGizmo()
end

function LinePath2D:onDrawGizmo( selected )
	GIIHelper.setVertexTransform( self:getEntity():getProp( 'render' ) )
	if selected then
		MOAIDraw.setPenColor( hexcolor'#f67bff' )
	else
		MOAIDraw.setPenColor( hexcolor'#b96b99' )
	end
	local verts = self.outputVerts
	local count = #verts
	local x1, y1 = verts[ count - 1 ], verts[ count ]
	MOAIDraw.drawCircle( x1, y1, 10 )
	MOAIDraw.drawLine( unpack( self.outputVerts ) )
end

