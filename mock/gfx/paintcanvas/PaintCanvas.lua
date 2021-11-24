module 'mock'
local insert = table.insert

--[[
TODO
	- automatic empty tile removing
]]

--------------------------------------------------------------------
CLASS: PaintCanvasTile ()
	:MODEL{}

function PaintCanvasTile:__init( canvas, x, y )
	self.parentCanvas = canvas
	local w, h = canvas.tileWidth, canvas.tileHeight

	self.x = x
	self.y = y
	self.locX = x * w
	self.locY = y * h
	self.w = w
	self.h = h
	self.image = false

	self.imageSeq   = 0
	self.textureSeq = 0
	self.valid = true

	self.name = string.format( '%d:%d', x, y )

	self.targetTexture = RenderTargetTexture()
	self.targetTexture:init( 
		w, h,
		'linear', MOAITexture.GL_RGBA8, false, false
	)
	self.renderTarget = self.targetTexture:getRenderTarget()
	self.frameBuffer = self.renderTarget:getFrameBuffer()

	local renderLayer = createPartitionRenderLayer()
	renderLayer:setLayerPartition( canvas.propPartition )
	local viewport = MOAIViewport.new()
	viewport:setSize( w, h )
	viewport:setScale( w, h )
	renderLayer:setViewport( viewport )

	local cam = MOAICamera.new()
	cam:setOrtho( true )
	cam:setScl( 1, -1, 1 )
	cam:setLoc( self.locX + w/2, self.locY + h/2 )
	cam:setNearPlane( -100000 )
	cam:setFarPlane( 100000 )
	-- cam:forceUpdate()

	renderLayer:setCamera( cam )

	self.renderLayer = renderLayer
	local fb = self.targetTexture:getMoaiFrameBuffer()
	renderLayer:setFrameBuffer( fb )
	renderLayer:setClearMode( MOAILayer.CLEAR_NEVER )

	self:clear( unpack( canvas.clearColor ) )

end

function PaintCanvasTile:__tostring()
	return string.format( '%s:%s', self:__repr(), self.name )
end

function PaintCanvasTile:getLoc()
	return self.locX, self.locY
end

function PaintCanvasTile:getRect()
	local x, y = self.locX, self.locY
	local w, h = self.w, self.h
	return x, y, x+w, y+h
end

function PaintCanvasTile:getMoaiTexture()
	return self.targetTexture:getMoaiFrameBuffer()
end

function PaintCanvasTile:getTexture()
	return self.targetTexture
end

function PaintCanvasTile:buildClearCommand( r,g,b,a )
	local renderLayer = MOAILayer.new()
	local fb = self.targetTexture:getMoaiFrameBuffer()
	renderLayer:setFrameBuffer( fb )
	renderLayer:setClearColor( r,g,b,a )
	renderLayer:setClearMode( MOAILayer.CLEAR_ALWAYS )
	return renderLayer
end

function PaintCanvasTile:getImage()
	local img = self.image
	if not img then
		img = MOAIImage.new()
		self.image = img
	end
	if self.imageSeq < self.textureSeq then
		self.imageSeq = self.textureSeq
		self.frameBuffer:grabCurrentFrame( img, false )
	end
	return img
end

function PaintCanvasTile:clear( r,g,b,a )
	mock.getRenderManager():addRenderTask( self:buildClearCommand( r,g,b,a ) )
end

----------------------------------------------------------------------
CLASS: PaintCanvasParam ()
:MODEL {
	Field 'tileWidth'      :int() :range(8);
	Field 'tileHeight'     :int() :range(8);
	Field 'scaleX'         :float() :range(0);
	Field 'scaleY'         :float() :range(0);
	Field 'growing'        :boolean();
}

--------------------------------------------------------------------
CLASS: PaintCanvas ( Component )
	:MODEL{
		Field 'data' :no_edit() :getset( 'SerializedData' );
		Field 'tileWidth' :int() :readonly();
		Field 'tileHeight' :int() :readonly();
		Field 'scaleX' :float() :readonly();
		Field 'scaleY' :float() :readonly();

		Field 'growing' :boolean() :readonly();
		'----';
		Field 'init'     :action( 'toolActionInit' );
	}
	:SIGNAL{
		changed = ''; 
	}

mock.registerComponent( 'PaintCanvas', PaintCanvas )

function PaintCanvas:__init()
	self.updatePending = false
	self.growing = true
	self.rows = {}
	self.tileWidth  = 128
	self.tileHeight = 128
	self.scaleX = 1
	self.scaleY = 1
	self.propPartition = MOAIPartition.new()
	self.clearColor = { 1,1,1,0 }
	self.dirtyTiles = {}
	self.currentStrokes = {}
	self.visualizer = false
	self._seq = 0
	self.transform = MOAITransform.new()
end

function PaintCanvas:onAttach( ent )
	self.transform:setScl( self:getScale() )
end

function PaintCanvas:onDetach( ent )
	if self.visualizer then
		self.visualizer:onCanvasDetach()
	end
end

function PaintCanvas:markDataModified()
	markProtoInstanceFieldsOverrided(
		self, 'data'
	)
end

function PaintCanvas:setClearColor( r,g,b,a )
	self.clearColor = { r,g,b,a }
end

local floor = math.floor
function PaintCanvas:locToCoord( x, y )
	local gw, gh = self.tileWidth, self.tileHeight
	local ix = 	floor( x / gw )
	local iy = 	floor( y / gw )
	return ix, iy
end

function PaintCanvas:getTileSize()
	return self.tileWidth, self.tileHeight
end

function PaintCanvas:setTileSize( w, h )
	self.tileWidth = w
	self.tileHeight = h
end

function PaintCanvas:setScale( sx, sy )
	self.scaleX = sx or 1
	self.scaleY = sy or sx or 1
end

function PaintCanvas:getScale()
	return self.scaleX, self.scaleY
end

function PaintCanvas:getTile( x, y )
	local rows = self.rows
	local row = rows[ y ]
	if not row then return nil end
end

function PaintCanvas:affirmTile( x, y )
	local gw, gh = self.tileWidth, self.tileHeight
	local rows = self.rows
	local row = rows[ y ]
	if not row then
		row = {}
		rows[ y ] = row
		local tile = PaintCanvasTile( self, x, y )
		row[ x ] = tile
		return tile
	end

	local tile = row[ x ]
	if not tile then
		tile = PaintCanvasTile( self, x, y )
		row[ x ] = tile
	end
	return tile
end

function PaintCanvas:affirmTileAABB( x0, y0, x1, y1, updateOnly )
	if x0 > x1 then x0, x1 = x1, x0 end
	if y0 > y1 then y0, y1 = y1, y0 end
	local output = {}
	local rows = self.rows
	for iy = y0, y1 do
		local row = rows[ iy ]
		if not row then
			if ( not updateOnly ) then
				row = {}
				rows[ iy ] = row
				for ix = x0, x1 do
					local tile = PaintCanvasTile( self, ix, iy )
					row[ ix ] = tile
					insert( output, tile )
				end
			end
		else
			for ix = x0, x1 do
				local tile = row[ ix ]
				if not tile then 
					if not updateOnly then
						tile = PaintCanvasTile( self, ix, iy )
						row[ ix ] = tile
						insert( output, tile )
					end
				else
					insert( output, tile )
				end
			end
		end
	end
	return output
end

function PaintCanvas:collectTiles()
	local result = {}
	for _, row in pairs( self.rows ) do
		for _, tile in pairs( row ) do
			insert( result, tile )
		end
	end
	return result
end

function PaintCanvas:markDirtyAABB( x0,y0,x1,y1, updateOnly )
	local tiles = self:affirmTileAABB( x0,y0,x1,y1, updateOnly )
	local dirtyTiles = self.dirtyTiles
	for _, t in pairs( tiles ) do
		dirtyTiles[ t ] = true
	end
end

function PaintCanvas:addStroke( stroke )
	insert( self.currentStrokes, stroke )
end

function PaintCanvas:clear( r,g,b,a )
	local renderMgr = mock.getRenderManager()
	for _, tile in ipairs( self.canvas:collectTiles() ) do
		renderMgr:addRenderTask( tile:buildClearCommand( r,g,b,a ) )
	end
	self._seq = self._seq + 1
	self.changed:emit( 'update' )
end

function PaintCanvas:scheduleUpdate()
	if self.updatePending then return end
	self.updatePending = true
	-- game:callOnSyncingRenderState( function()
		if self._entity then
			return self:update()
		end
	-- end )
end

function PaintCanvas:update()
	self.updatePending = false
	local renderMgr = mock.getRenderManager()
	local updated = false
	local dirtyTileList = nil
	if self:uploadTextures() then
		updated = true
	end
	
	--build strokes
	local strokes = self.currentStrokes
	if next( strokes ) then
		for  _, stroke in ipairs( strokes ) do 
			stroke:applyToCanvas( self )
		end

		--flush
		local renderTable = {}
		local dirtyTiles = self.dirtyTiles
		self.dirtyTiles = {}
		local count = 0
		dirtyTileList = {}
		for tile in pairs( dirtyTiles ) do
			count = count + 1
			dirtyTileList[ count ] = tile
			tile.textureSeq = tile.textureSeq + 1
			insert( renderTable, tile.renderLayer )
		end

		if count > 0 then
			MOAINodeMgr.update()
			renderMgr:addRenderTask( renderTable, function() self.propPartition:clear() end )
		end
		
		--reset
		self.currentStrokes = {}
		updated = true
	end

	if updated then
		self._seq = self._seq + 1
		self.changed:emit( 'update', dirtyTileList )

		if self.visualizer then
			self.visualizer:onCanvasUpdate()
		end
	end

end

function PaintCanvas:setVisualizer( visualizer )
	self.visualizer = visualizer
	visualizer.canvas = self
	visualizer:onInit( self )
end

function PaintCanvas:testdraw()
	local testStroke = mock.TestBrushStroke2( 50, 50 )
	self:addStroke( testStroke )
	self:update()
end

function PaintCanvas:clearAll()
	self.propPartition:clear()
	self.dirtyTiles = {}
	for i, tile in ipairs( self:collectTiles() ) do
		tile.valid = false
	end
	self.rows = {}
	self.currentStrokes = {}
	self.transform:setScl( self:getScale() )
	self._seq = self._seq + 1
	self.changed:emit( 'clear' )
end

function PaintCanvas:initWithParam( param )
	self.tileWidth  = param.tileWidth
	self.tileHeight = param.tileHeight
	self.scaleX = param.scaleX
	self.scaleY = param.scaleY
	self:clearAll()
end

function PaintCanvas:getDefaultParam()
	local param = PaintCanvasParam()
	param.tileWidth  = self.tileWidth
	param.tileHeight = self.tileHeight
	param.scaleX = self.scaleX
	param.scaleY = self.scaleY
	param.growing = self.growing
	return param
end

function PaintCanvas:toolActionInit()
	local param = self:getDefaultParam()
	if mock_edit.requestProperty( '(re)Initialize Paint Canvas', param ) then
		self:initWithParam( param )
		mock_edit.alertMessage( 'message', 'initialized', 'info' )
	end
end

function PaintCanvas:_saveImages()
	for _, tile in ipairs( self:collectTiles() ) do
		tile:getImage():write( tile.name..'.png' )
	end
end

function PaintCanvas:getSerializedData()
	local tiles = {}
	local data = {
		size  = { self:getTileSize() };
		scale = { self:getScale() };
		tiles = tiles;
	}
	for _, tile in ipairs( self:collectTiles() ) do
		local tileEntry = {
			x = tile.x;
			y = tile.y;
			img = saveImageBase64( tile:getImage() );
		}
		table.insert( tiles, tileEntry )
	end
	return MOAIDataBuffer.base64Encode(
		encodeJSON( data )
	)
end

local GL_FUNC_ADD               = MOAIProp. GL_FUNC_ADD
local GL_ZERO                   = MOAIProp. GL_ZERO
local GL_ONE                    = MOAIProp. GL_ONE
local TRUECOLOR                 = MOAIImage.TRUECOLOR

function PaintCanvas:setSerializedData( dataString )
	local dataString = MOAIDataBuffer.base64Decode( dataString )
	local data = decodeJSON( dataString )
	local tw, th = unpack( data.size )
	local sx, sy = unpack( data.scale )
	self:setTileSize( tw, th )
	self:setScale( sx, sy )
	self:clearAll()
	
	for _, tileEntry in pairs( data.tiles ) do
		local x = tileEntry.x
		local y = tileEntry.y
		local buffer = MOAIDataBuffer.new()
		local img = loadImageBase64( nil, tileEntry.img, TRUECOLOR )
		local tile = self:affirmTile( x, y )
		tile.image = assert( img )
		tile.textureSeq = 0
		tile.imageSeq = 1
	end

end

function PaintCanvas:uploadTextures()
	local renderTable = {}
	local tmpTex = {}
	local partition = self.propPartition
	local count = 0
	--upload image
	for _, tile in pairs( self:collectTiles() ) do
		if tile.textureSeq < tile.imageSeq then
			count = count + 1
			local tex = MOAITexture.new()
			tex:load( tile.image )
			tex:affirm()
			tmpTex[ tex ] = true
			local prop = createRenderProp()
			local deck = MOAISpriteDeck2D.new()
			deck:setTexture( tex )
			deck:setRect( tile:getRect() )
			prop:setDeck( deck )
			prop:setBlendMode( GL_FUNC_ADD, GL_ONE, GL_ZERO )
			prop:setPartition( partition )
			insert( renderTable, tile.renderLayer )
			tile.textureSeq = tile.imageSeq
			-- prop:forceUpdate()
		end
	end

	if count > 0 then
		MOAINodeMgr.update()
		local renderMgr = mock.getRenderManager()
		renderMgr:addRenderTask( renderTable, 
			function()
				partition:clear()
				for tex in pairs( tmpTex ) do
					tex:purge()
				end
			end
		)
	end
	return count > 0
end

function PaintCanvas:worldToCanvas( x, y, z )
	if self.visualizer then
		return self.visualizer:worldToCanvas( x, y, z )
	end
	local ent = self:getEntity()
	local px, py, pz = ent:getProp( 'physics' ):worldToModel( x, y, z )
	return ent:physicsToRender( px, py, pz )
end

function PaintCanvas:wndToCanvas( x, y, camera )
	if self.visualizer then
		return self.visualizer:wndToCanvas( x, y, camera )
	end
	if not camera then
		local ent = self:getEntity()
		local wx, wy, wz  =  ent:wndToWorld( x, y )
		return self:worldToCanvas( wx, wy, wz )
	else
		local ent = self:getEntity()
		local wx, wy, wz  =  camera:wndToWorld( x, y )
		return self:worldToCanvas( wx, wy, wz )
	end
end

--------------------------------------------------------------------
--for editor [ visualizer/ paint brush transform ]
---------------------------------------------------------------------
CLASS: PaintCanvasVisualizer ( Component )
	:MODEL{}

function PaintCanvasVisualizer:__init()
	self.canvas = false
	self.canvasSeq = false
end

function PaintCanvasVisualizer:getCanvas()
	return self.canvas
end

function PaintCanvasVisualizer:onInit( canvas )
end

function PaintCanvasVisualizer:onCanvasDetach( canvas )
end

function PaintCanvasVisualizer:onCanvasUpdate()
end

function PaintCanvasVisualizer:updateVisual()
	local canvas = self.canvas
	if not canvas then return end
	if self.canvasSeq == canvas._seq then return end
	self.canvasSeq = canvas._seq
	return self:onUpdateVisual()
end

function PaintCanvasVisualizer:wndToCanvas( x, y )
	--TODO
	return self:getEntity():wndToModel( x, y )
end

function PaintCanvasVisualizer:worldToCanvas( x, y, z )
	return self:getEntity():wndToWorld( x, y, z )
end

function PaintCanvasVisualizer:onUpdateVisual()
end

