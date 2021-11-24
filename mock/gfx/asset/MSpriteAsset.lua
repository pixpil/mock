module ('mock')

--------------------------------------------------------------------
CLASS: _DeckContainer ()
	:MODEL{}

function _DeckContainer:__init( deck )
	self.deck = deck or false
end

function _DeckContainer:getMoaiDeck()
	return self.deck
end


local setDeckRect = MOAIMaskedSpriteDeck2D.getInterfaceTable().setRect
local setDeckUVRect = MOAIMaskedSpriteDeck2D.getInterfaceTable().setUVRect
local setCurveKey = MOAIAnimCurve.getInterfaceTable().setKey

--------------------------------------------------------------------
local function MSpriteLoader( node )
	--[[
		sprite <package>
			.moduletexture <texture>
			.modules <uvquad[...]>
			.frames  <deck_quadlist>
	]]	
	_Stopwatch.start( 'msprite_load_source' )
	local data

	local packedDefFile = node:getObjectFile('packed_def')
	if packedDefFile then
		data = loadMsgPackFile( packedDefFile )
	else
		local defFile = node:getObjectFile('def')
		data = loadAssetDataTable( defFile )
	end

	if not data then
		_error( 'invalid msprite:', node )
		return false
	end

	local textures = {}
	local texRects = {}
	local uvRects  = {}
	local features = {}
	local featureNames = {}
	-- _Stopwatch.stop( 'msprite_load_source' )

	-- _Stopwatch.start( 'msprite_load_prepare' )
	if data.features then
		for i, entry in pairs( data.features ) do
			features[ entry.name ] = entry.id
			featureNames[ i ] = entry.name
		end
	end

	local moduleDatas = data.modules
	local frameDatas = data.frames
	

	--load images
	local count = 0
	for id, name in pairs( data.atlases ) do
		count = count+1
		if count>1 then error("multiple image not supported") end

		local texNodePath = node:getChildPath( node:getBaseName() .. '_texture' )
		local tex, texNode = loadAsset( texNodePath )
		if not tex then 
			_error( 'cannot load sprite texture', texNodePath )
			return nil
		end
		local mtex, uvRect = tex:getMoaiTextureUV()
		textures[ count ] = mtex
		local tw, th = tex:getOriginalSize()
		local ox, oy = 0, 0 --todo
		texRects[ id ] = { tw, th, ox, oy } 
		uvRects[ id ] = uvRect
	end


	local deck = MOAIMaskedSpriteDeck2D.new()
	--count parts
	local partCount = 0
	for frameId, frame in pairs( frameDatas ) do
		partCount = partCount + #frame.parts
	end

	local moduleCount = table.len( moduleDatas )
	local frameCount = table.len( frameDatas )
	--
	deck:reserveSprites( partCount ) --one pair per frame component
	deck:reserveQuads( partCount ) --one quad per frame component
	deck:reserveUVQuads( moduleCount ) --one uv per module
	deck:reserveSpriteLists( frameCount ) --one list per frame

	deck:setTexture( textures[1] )
	-- _Stopwatch.stop( 'msprite_load_prepare' )

	
	-- _Stopwatch.start( 'msprite_load_build_frames' )
	local moduleIdToIndex = {}
	local frameIdToIndex  = {}
	local i = 0
	for id, m in pairs( moduleDatas ) do
		i = i + 1
		moduleIdToIndex[ id ] = i
		local rect = m.rect
		local x, y, w, h = rect[1],rect[2],rect[3],rect[4]

		local texRect = texRects[ m.atlas ]
		local uvRect = uvRects[ m.atlas ]
		local tw, th, ox, oy = texRect[1],texRect[2],texRect[3],texRect[4]
		local u0, v0, u1, v1 = (x+ox+0.1)/tw, (y+oy+0.1)/th, (x+ox+w)/tw, (y+oy+h)/th
		local tu0, tv1, tu1,tv0 = uvRect[1],uvRect[2],uvRect[3],uvRect[4]
		local us, vs = tu1-tu0, tv1-tv0
		u0 = u0 * us +tu0
		v0 = v0 * vs +tv0
		u1 = u1 * us +tu0
		v1 = v1 * vs +tv0
		m.uv = {u0, v0, u1, v1}
		m.index = i
		setDeckUVRect( deck, i, u0, v0, u1, v1 )
	end

	local partIdx = 1
	local i = 0
	for id, frame in pairs( frameDatas ) do
		i = i + 1
		frameIdToIndex[ id ] = i
		local basePartId = partIdx
		frame.index = i
		local parts = frame.parts
		for j = 1, #parts do
			local part = parts[j]
			local m = moduleDatas[ part[1] ]
			local rect = m.rect
			local ox, oy = part[2], part[3]
			local w, h = rect[3], rect[4]
			local x0, y0 = ox, oy
			local x1, y1 = x0 + w, y0 + h
			-- deck:setRect( partIdx, x0 + ox, y0 + oy, x1 + ox, y1 + oy )
			setDeckRect( deck, partIdx, x0, -y0, x1, -y1 )
			local featureBit = m.feature or 0
			deck:setSprite( partIdx, m.index, partIdx, nil, featureBit )
			partIdx = partIdx + 1
		end
		deck:setSpriteList( i, basePartId, partIdx - basePartId )
	end
	preloadIntoAssetNode( node:getChildPath('frames'), deck )
	-- _Stopwatch.stop( 'msprite_load_build_frames' )

	-- _Stopwatch.start( 'msprite_load_build_curve' )

	--animations
	local EaseFlat   = MOAIEaseType.FLAT
	local EaseLinear = MOAIEaseType.LINEAR
	local animations = {}
	local indexToMetaData = {}

	for id, animation in pairs( data.anims ) do
		local name = animation.name
		local sequence = animation.seq
		local srcType  = animation.src_type or 'ase'
		local deprecated = animation.deprecated or false
		--create anim curve
		local indexCurve   = MOAIAnimCurve.new()
		-- local offsetXCurve = MOAIAnimCurve.new()
		-- local offsetYCurve = MOAIAnimCurve.new()
		local count = #sequence

		indexCurve   : reserveKeys( count + 1 )
		-- offsetXCurve : reserveKeys( count + 1 )
		-- offsetYCurve : reserveKeys( count + 1 )
		

		--TODO: support flags? or just forbid it!!!!
		local offsetEaseType = EaseLinear
		local ftime = 0
		-- local timePoints = {}
		local metaDatas  = {}
		local subDecIndex  = rawarray.new( count )
		for fid = 1, count do
			local f = sequence[ fid ]
			local frameId, delay, ox, oy = f[1], f[2], f[3], f[4]
			local frame = frameDatas[ frameId ]
			local index = frame.index

			indexToMetaData [ index ]  = frame[ 'meta' ] or false
			subDecIndex[ fid ] = index
			-- timePoints[ fid ] = ftime
			-- setCurveKey( offsetXCurve, fid, ftime, ox, offsetEaseType )
			-- setCurveKey( offsetYCurve, fid, ftime, -oy, offsetEaseType )
			setCurveKey( indexCurve  , fid, ftime, index, EaseFlat )

			ftime = ftime + delay  --will use anim:setSpeed to fit real playback FPS

			if fid == count then --copy last frame to make loop smooth
				-- setCurveKey( offsetXCurve, fid + 1, ftime, ox, offsetEaseType )
				-- setCurveKey( offsetYCurve, fid + 1, ftime, -oy, offsetEaseType )
				setCurveKey( indexCurve  , fid + 1, ftime, frame.index, EaseFlat )
			end

		end

		-- remapper:setWrapping( true )
		local clipData = {
			-- offsetXCurve    = offsetXCurve,
			-- offsetYCurve    = offsetYCurve,
			subDecIndex     = subDecIndex,
			indexCurve      = indexCurve,
			length          = ftime,
			frameCount      = count,
			name            = name,
			deprecated      = deprecated,
		} 

		animations[ name ] = clipData
	end


	local sprite = {
		frameDeck       = deck,
		animations      = animations,
		features        = features,
		featureNames    = featureNames,
		indexToMetaData = indexToMetaData
	}

	node:bindMoaiFinalizer( deck )
	-- _Stopwatch.stop( 'msprite_load_build_curve' )
	-- _Stopwatch.log( 'msprite_load_source', 'msprite_load_prepare', 'msprite_load_build_frames', 'msprite_load_build_curve' )
	return sprite
end


local function MSpriteSeqLoader( node )
	local mspriteData = loadAsset( node.parent )	
	local name = node:getName()

	local animData = mspriteData.animations[ name ]
	if animData then
		local deck = animData.subDeck
		if not deck then
			--affirm subdeck
			local remapper = MOAIDeckRemapper.new()
			local subDecIndex = animData.subDecIndex
			remapper:reserve( animData.frameCount )
			remapper:setDeck( mspriteData.frameDeck )

			for i = 1, animData.frameCount do
				remapper:setRemap( i, subDecIndex[ i ] )
			end
			
			deck = _DeckContainer( remapper )
			animData.subDeck = deck
		end
		return deck
	end

	return item
end

registerAssetLoader( 'msprite', MSpriteLoader )
registerAssetLoader( 'deck2d.msprite_seq', MSpriteSeqLoader )
