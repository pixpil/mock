--------------------------------------------------------------------
--@classmod Geometry
module 'mock'

local draw = MOAIDraw


CLASS: GeometryComponent( GraphicsPropComponent )
	:MODEL{
		Field 'index' :no_edit();
		-- Field 'blend'  :enum( EnumBlendMode ) :getset('Blend');		
		Field 'penWidth' :getset( 'PenWidth' );
	}

function GeometryComponent:__init()
	self.penWidth = 1
end

function GeometryComponent:getPenWidth()
	return self.penWidth
end

function GeometryComponent:setPenWidth( w )
	self.penWidth = w
end

--------------------------------------------------------------------
CLASS: GeometryDrawScriptComponent ( GeometryComponent )
	:MODEL{}

function GeometryDrawScriptComponent:__init()
	local prop = self.prop
	
	local deck = MOAIDrawDeck.new()
	prop:setDeck( deck )	
	self.deck = deck

end

function GeometryDrawScriptComponent:onDraw()
end

function GeometryDrawScriptComponent:onGetRect()
	return 0,0,0,0
end

function GeometryDrawScriptComponent:onAttach( entity )	
	GeometryDrawScriptComponent.__super.onAttach( self, entity )

	self.deck:setDrawCallback( 
		function(...) return self:onDraw( ... ) end
	)
	self.deck:setBoundsCallback( 
		function(...) return self:onGetRect( ... ) end
	)
		
end


--------------------------------------------------------------------
CLASS: GeometryRect ( GeometryComponent )
	:MODEL{
		Field 'w' :on_set( 'updateDeck' );
		Field 'h' :on_set( 'updateDeck' );
		Field 'fill'  :boolean() :on_set( 'updateDeck' );
	}
registerComponent( 'GeometryRect', GeometryRect )

function GeometryRect:__init()
	self.w = 100
	self.h = 100
	self.fill = false
	self.deck = MOAIGeometry2DDeck.new()
	self.deck:reserve( 1 )
	self.prop:setDeck( self.deck )
	self:updateDeck()
end

function GeometryRect:updateDeck()
	local w,h = self.w, self.h
	local deck = self.deck
	if self.fill then
		deck:setFilledRectItem( 1, -w/2, -h/2, w/2, h/2 )
	else
		deck:setRectItem( 1, -w/2,-h/2, w/2, h/2 )
	end
	deck:setItemPenWidth( 1, self.penWidth )
end

function GeometryRect:getSize()
	return self.w, self.h
end

function GeometryRect:setSize( w, h )
	self.w = w
	self.h = h
	self:updateDeck()
end

function GeometryRect:setFilled( fill )
	self.fill = fill
	self:updateDeck()
end

function GeometryRect:isFilled()
	return self.fill
end


--------------------------------------------------------------------
CLASS: GeometryCircle ( GeometryComponent )
	:MODEL{
		Field 'radius' :on_set( 'updateDeck' );
		Field 'fill' :boolean() :on_set( 'updateDeck' );
	}
registerComponent( 'GeometryCircle', GeometryCircle )

function GeometryCircle:__init()
	self.radius = 100
	self.fill = false
	self.deck = MOAIGeometry2DDeck.new()
	self.deck:reserve( 1 )
	self.prop:setDeck( self.deck )
	self:updateDeck()
end

function GeometryCircle:updateDeck()
	local w,h = self.w, self.h
	local deck = self.deck
	if self.fill then
		deck:setFilledCircleItem( 1, 0, 0, self.radius )
	else
		deck:setCircleItem( 1, 0, 0, self.radius )
	end
	deck:setItemPenWidth( 1, self.penWidth )
end

function GeometryCircle:getRadius()
	return self.radius
end

function GeometryCircle:setRadius( r )
	self.radius = r
	self:updateDeck()
end

function GeometryCircle:onGetRect()
	local r = self.radius
	return -r,-r, r,r
end

--------------------------------------------------------------------
CLASS: GeometryRay ( GeometryDrawScriptComponent )
	:MODEL{
		'----';
		Field 'length' :set( 'setLength' );		
	}
registerComponent( 'GeometryRay', GeometryRay )

function GeometryRay:__init()
	self.length = 100
end

function GeometryRay:onDraw()
	draw.setPenWidth( self.penWidth )
	local l = self.length
	draw.fillRect( -1,-1, 1,1 )
	draw.drawLine( 0, 0, l, 0 )
	draw.fillRect( -1 + l, -1, 1 + l,1 )
end

function GeometryRay:onGetRect()
	local l = self.length
	return 0,0, l,1
end

function GeometryRay:setLength( l )
	self.length = l
end

--------------------------------------------------------------------
CLASS: GeometryBoxOutline ( GeometryDrawScriptComponent )
	:MODEL{
		Field 'size' :type( 'vec3' ) :getset( 'Size' );
	}
registerComponent( 'GeometryBoxOutline', GeometryBoxOutline )

function GeometryBoxOutline:__init()
	self.sizeX = 100
	self.sizeY = 100
	self.sizeZ = 100
end

function GeometryBoxOutline:getSize()
	return self.sizeX, self.sizeY, self.sizeZ
end

function GeometryBoxOutline:setSize( x,y,z )
	self.sizeX, self.sizeY, self.sizeZ = x,y,z
end

function GeometryBoxOutline:onDraw()
	local x,y,z = self.sizeX/2, self.sizeY/2, self.sizeZ/2
	draw.setPenWidth( self.penWidth )
	draw.drawBoxOutline( -x, -y, -z, x, y, z )
end

function GeometryBoxOutline:onGetRect()
	local x,y,z = self.sizeX/2, self.sizeY/2, self.sizeZ/2
	return -x, -y, x, y
end


--------------------------------------------------------------------
CLASS: GeometryLineStrip ( GeometryDrawScriptComponent )
	:MODEL{
		Field 'verts' :array( 'number' ) :getset( 'Verts' ) :no_edit();
		Field 'looped' :boolean() :isset( 'Looped' );
		Field 'reset' :action( 'reset' );
	}
registerComponent( 'GeometryLineStrip', GeometryLineStrip )

function GeometryLineStrip:__init()
	self.looped = false
	self.boundRect = {0,0,0,0}
	self.outputVerts = {}
	self.verts = {
		0,0,
		0,100,
		100,100,
		100, 0
	}
end

function GeometryLineStrip:setLooped( looped )
	self.looped = looped
	self:updateVerts()
end

function GeometryLineStrip:isLooped()
	return self.looped
end

function GeometryLineStrip:onAttach( ent )
	GeometryLineStrip.__super.onAttach( self, ent )
	self:updateVerts()
end

function GeometryLineStrip:getVerts()
	return self.verts
end

function GeometryLineStrip:setVerts( verts )
	self.verts = verts 
	self:updateVerts()	
end

function GeometryLineStrip:reset()
	self:setVerts{
		0,0,
		0,100,
		100,100,
		100, 0
	}
end

function GeometryLineStrip:updateVerts()
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
	self.outputVerts = outputVerts
end


function GeometryLineStrip:onDraw()
	draw.setPenWidth( self.penWidth )
	draw.drawLine( unpack( self.outputVerts ) )
end

function GeometryLineStrip:onGetRect()
	return unpack( self.boundRect )
end


--------------------------------------------------------------------
CLASS: GeometryPolygon ( GeometryLineStrip )
	:MODEL{
		Field 'looped' :boolean() :no_edit();
		Field 'fill' :boolean() :isset( 'Filled' );
	}
registerComponent( 'GeometryPolygon', GeometryPolygon )

local vtxFormat = MOAIVertexFormatMgr.getFormat ( MOAIVertexFormatMgr.XYZWC )
function GeometryPolygon:__init()
	self.looped = true
	self.fill = true
	local mesh = MOAIMesh.new()
	mesh:setPrimType ( MOAIMesh.GL_TRIANGLES )
	mesh:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.LINE_SHADER_3D ))
	mesh:setTexture( getWhiteTexture() )
	self.meshDeck = mesh
end

function GeometryPolygon:isFilled()
	return self.fill
end

function GeometryPolygon:setFilled( fill )
	self.fill = fill and true or false
	self:updatePolygon()
end

function GeometryPolygon:isLooped()
	return true
end

function GeometryPolygon:updateVerts()
	GeometryPolygon.__super.updateVerts( self )
	return self:updatePolygon()
end

function GeometryPolygon:updatePolygon()
	if not self.fill then
		self.prop:setDeck( self.deck ) --use drawScriptDeck
		return
	else
		self.prop:setDeck( self.meshDeck )
	end

	local verts = self.verts
	local count = #verts	
	if count < 6 then return end
	
	local tess = MOAIVectorTesselator.new ()
	tess:setFillStyle ( MOAIVectorTesselator.FILL_SOLID )
	tess:setFillColor ( 1,1,1,1 )
	tess:setStrokeStyle ( MOAIVectorTesselator.STROKE_NONE )
		tess:pushPoly()
			for k = 1, count/2 do
				local idx = (k-1) * 2
				tess:pushVertex ( verts[idx+1], verts[idx+2] )
			end
		tess:finish()
	tess:finish()

	local vtxBuffer = MOAIVertexBuffer.new ()
	local idxBuffer = MOAIIndexBuffer.new ()
	local totalElements = tess:tesselate ( vtxBuffer, idxBuffer, 2, vtxFormat );
	vtxBuffer:setFormat( vtxFormat )

	local mesh = self.meshDeck

	mesh:setVertexBuffer( vtxBuffer )
	mesh:setIndexBuffer ( idxBuffer )
	mesh:setTotalElements ( totalElements )
	mesh:setBounds ( vtxBuffer:computeBounds())

	--triangulate
	local x0,y0,x1,y1 = calcAABB( self.verts )
	self.aabb  = { x0, y0, x1, y1 }

end

--------------------------------------------------------------------
CLASS: GeometryCatmullRomCurve ( GeometryLineStrip )
	:MODEL{
		Field 'subdivision' :int() :range( 1 )  :getset( 'Subdivision' );
		Field 'tension' :float() :range( 0, 1 ) :step( 0.1 ) :getset( 'Tension' );
	}
registerComponent( 'GeometryCatmullRomCurve', GeometryCatmullRomCurve )

function GeometryCatmullRomCurve:__init()
	self.curveDeck = MOCKCatmullRomPathDeck.new()
	self.prop:setDeck( self.curveDeck )
	self.subdivision = 4
	self.tension = 0.5
end

function GeometryCatmullRomCurve:setSubdivision( v )
	self.subdivision = v
	self.curveDeck:setSegment( v )
end

function GeometryCatmullRomCurve:setTension( v )
	self.tension = v
	self.curveDeck:setTension( v )
end

function GeometryCatmullRomCurve:getSubdivision()
	return self.subdivision
end

function GeometryCatmullRomCurve:getTension()
	return self.tension
end

function GeometryCatmullRomCurve:setPenWidth( w )
	self.penWidth = w
	self.curveDeck:setPenWidth( w )
end

function GeometryCatmullRomCurve:updateVerts()
	GeometryCatmullRomCurve.__super.updateVerts( self )
	self.curveDeck:setSegment( self.subdivision )
	self.curveDeck:setTension( self.tension )
	local verts = self.verts
	local count = #verts
	local vertCount = count / 2
	local deck = self.curveDeck
	deck:reserve( vertCount )
	for i = 1, vertCount do
		local k = (i-1) * 2
		deck:setVert( i , verts[ k + 1 ], verts[ k + 2 ] )
	end
end
