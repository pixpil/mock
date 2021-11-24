module 'mock'

CLASS: MSpriteCopy ( mock.GraphicsPropComponent )
	:MODEL{
		Field 'sourceSprite' :type( MSprite ) :set( 'setSourceSprite');
		Field 'overrideFeatures' :boolean():set( 'setOverrideFeatures' );
		Field 'hiddenFeatures' :collection( 'string' ) :selection( 'getAvailFeatures' ) :getset( 'HiddenFeatures' );
		'----';
		Field 'linkLoc' :boolean();
		Field 'linkScl' :boolean();
		Field 'linkRot' :boolean();
		-- Field 'copyScl'      :boolean();
		-- Field 'copyRot'      :boolean();
		-- Field 'copyLoc'      :boolean();
		-- Field 'flipX' :boolean() :onset( 'updateFlip' );
		-- Field 'flipY' :boolean() :onset( 'updateFlip' );
	}

registerComponent( 'MSpriteCopy', MSpriteCopy )

function MSpriteCopy:__init()
	self.hiddenFeatures = {}

	self.sourceSprite = false
	self.linked = false
	self.linkLoc = true
	self.linkScl = true
	self.linkRot = true
	self.flipX = false
	self.flipY = false
	self.overrideFeatures = false
	self.deckInstance = MOAIMaskedSpriteDeck2DInstance.reuse()
	self.prop:setDeck( self.deckInstance )
end

function MSpriteCopy:onAttach( ent )
	MSpriteCopy.__super.onAttach( self, ent )
	self:setSourceSprite( self.sourceSprite )
end

function MSpriteCopy:onDetach( ent )
	MSpriteCopy.__super.onDetach( self, ent )
	MOAIMaskedSpriteDeck2DInstance.recycle( self.deckInstance )
end

function MSpriteCopy:setSourceSprite( sprite )
	self.sourceSprite = sprite
	if not sprite then return end
	local spriteData = sprite.spriteData
	if not spriteData then return end
	-- if self.sourceSprite == sprite and self.linked then return end
	self.deckInstance:setDeck( spriteData.frameDeck )
	self.deckInstance:setSourceInstance( sprite.deckInstance )
	self.prop:setAttrLink( MOAIProp.ATTR_INDEX, sprite.prop, MOAIProp.ATTR_INDEX )

	local prop = self.prop
	local prop1 = sprite.prop
	if self.linkLoc then linkLoc( prop, prop1 ) end
	if self.linkScl then linkScl( prop, prop1 ) end
	if self.linkRot then linkRot( prop, prop1 ) end

	self:updateFeatures()
	-- self.linked = true
end

function MSpriteCopy:getTargetData()
	local source = self.sourceSprite
	return source and source.spriteData
end

function MSpriteCopy:setOverrideFeatures( state )
	self.overrideFeatures = state
	self:updateFeatures()
end


local tremove = table.remove
local tinsert = table.insert
local tindex  = table.index
function MSpriteCopy:addHiddenFeatures( hiddenFeatures )
	local features = self.hiddenFeatures
	local tindex = table.index
	for i, n in ipairs( hiddenFeatures ) do
		if not tindex( features, n ) then
			tinsert( features, n )
		end
	end
end

function MSpriteCopy:removeHiddenFeatures( hiddenFeatures )
	local features = self.hiddenFeatures
	for i, n in ipairs( hiddenFeatures ) do
		local idx = tindex( features, n )
		if idx then
			tremove( features, idx )
		end
	end
end

function MSpriteCopy:setHiddenFeatures( hiddenFeatures )
	self.hiddenFeatures = hiddenFeatures or {}
	--update hiddenFeatures
	if self.sourceSprite then return self:updateFeatures() end
end

function MSpriteCopy:getHiddenFeatures()
	return self.hiddenFeatures
end

function MSpriteCopy:updateFeatures()
	local sprite = self.sourceSprite
	if not sprite then return end
	local data   = sprite.spriteData 
	if not data then return end
	local features = sprite.hiddenFeatures
	if self.overrideFeatures then
		features = self.hiddenFeatures
	end

	if not self.deckInstance then return end
	self.deckInstance:setCopyMask( not self.overrideFeatures )

	local featureTable = data.features
	if not featureTable then return end
	local instance = self.deckInstance
	for i = 0, 64 do --hide all
		instance:setMask( i, false )
	end
	for i, featureName in ipairs( features ) do
		local bit
		if featureName == '__base__' then
			bit = 0
		else
			bit = featureTable[ featureName ]
		end
		if bit then
			instance:setMask( bit, true ) --show target feature
		end
	end
end

function MSpriteCopy:getAvailFeatures()
	local result = {
		{ '__base__', '__base__' }
	}
	local data = self:getTargetData()
	if data then
		for i, n in ipairs( data.featureNames ) do
			result[ i+1 ] = { n, n }
		end
	end
	return result
end
