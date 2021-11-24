module 'mock'

--------------------------------------------------------------------
--Common Routine
--------------------------------------------------------------------
-- CLASS: EffectPropNode ( EffectNode )
-- 	:MODEL{}

-- function EffectPropNode:createProp( fxState )

-- end

-- function EffectPropNode:onLoad( fxState )
-- 	local prop = self:createProp( fxState )

-- end

--------------------------------------------------------------------
--Static Sprite
--------------------------------------------------------------------
CLASS: EffectStaticSprite ( EffectTransformNode )
	:MODEL{
		Field 'deck'  :asset('deck2d\\..*');
		Field 'index' :int() :range(0);
		'----';
		Field 'color'    :type('color')  :getset('Color') ;
		Field 'blend' :enum( EnumBlendMode );
	}

function EffectStaticSprite:__init()
	self.color = { 1,1,1,1 }
end

function EffectStaticSprite:getDefaultName()
	return 'sprite'
end

function EffectStaticSprite:getTypeName()
	return 'sprite'
end

function EffectStaticSprite:onLoad( fxState )
	local sprite = markRenderNode( MOAIGraphicsProp.new() )
	local deck = loadAsset( self.deck )
	deck = deck and deck:getMoaiDeck()
	sprite:setDeck( deck )
	setPropBlend( sprite, self.blend )
	--todo: shader	
	self:applyTransformToProp( sprite )

	fxState:linkTransform( sprite )
	fxState:linkPartition( sprite )
	sprite:setColor( unpack( self.color ) )
	fxState[ self ] = sprite
end

function EffectStaticSprite:getColor()
	return unpack( self.color )
end

function EffectStaticSprite:setColor( r,g,b,a )
	self.color = { r,g,b,a }
end



--------------------------------------------------------------------
--Aurora Sprite
--------------------------------------------------------------------
CLASS: EffectAuroraSprite ( EffectTransformNode )
	:MODEL{
		Field 'spritePath' :asset( 'aurora_sprite' );
		Field 'clip'  :string() :selection( 'getClipNames' );
		Field 'mode'  :enum( EnumTimerMode );
		Field 'FPS'   :int() :range( 0,200 ) :widget( 'slider' );
		'----';
		Field 'blend' :enum( EnumBlendMode );
	}

function EffectAuroraSprite:__init()
	self.blend = 'alpha'
	self.mode  = MOAITimer.NORMAL
	self.FPS   = 10
end

function EffectAuroraSprite:getDefaultName()
	return 'aurora'
end

function EffectAuroraSprite:getTypeName()
	return 'aurora'
end

function EffectAuroraSprite:onLoad( fxState )
	local sprite = AuroraSprite()
	sprite:setSprite( self.spritePath )
	sprite:setFPS( self.FPS )
	sprite:play( self.clip, self.mode )
	sprite:setBlend( self.blend )
	self:applyTransformToProp( sprite )
	fxState:linkTransform( sprite.prop )
	fxState:linkPartition( sprite.prop )
	fxState[ self ] = sprite	
end

function EffectAuroraSprite:getClipNames()
	local data = mock.loadAsset( self.spritePath )
	if not data then return nil end
	local result = {}
	for k,i in pairs( data.animations ) do
		table.insert( result, { k, k } )
	end
	return result
end

function EffectAuroraSprite:onStop( fxState )
	local sprite = fxState[ self ]
	fxState:unlinkPartition( sprite.prop )
end


--------------------------------------------------------------------
--MSprite
--------------------------------------------------------------------
CLASS: EffectMSprite ( EffectTransformNode )
	:MODEL{
		Field 'material'   :asset( 'material' );
		Field 'color'      :type( 'color' ) :getset( 'Color');
		Field 'spritePath' :asset( 'msprite' );
		Field 'clip'  :string() :selection( 'getClipNames' );
		Field 'mode'  :enum( EnumTimerMode );
		Field 'throttle';
	}

function EffectMSprite:__init()
	self.material = false
	self.blend = 'alpha'
	self.mode  = MOAITimer.NORMAL
	self.throttle = 1
	self.color = {1,1,1,1}
end

function EffectMSprite:getColor()
	return unpack( self.color )
end

function EffectMSprite:setColor( r,g,b,a )
	self.color = {r,g,b,a}
end

function EffectMSprite:getDefaultName()
	return 'msprite'
end

function EffectMSprite:getTypeName()
	return 'msprite'
end

function EffectMSprite:onLoad( fxState )
	local sprite = MSprite()
	sprite:setSprite( self.spritePath )
	sprite:getMoaiProp():setColor( self:getColor() )
	sprite:getMoaiProp():setVisible( true )
	local state = sprite:play( self.clip, self.mode )
	if not state then
		return false
	end
	state:throttle( self.throttle )
	local mode = self.mode
	if mode == MOAITimer.LOOP or mode == MOAITimer.LOOP_REVERSE then
		--do nothing
	else
		state:setListener( MOAITimer.EVENT_TIMER_END_SPAN, function()
			sprite:getMoaiProp():setVisible( false )
		end )
	end
	sprite:setMaterial( self.material )
	-- sprite:setBlend( self.blend )
	self:applyTransformToProp( sprite )
	fxState:linkTransform( sprite.prop )
	fxState:linkPartition( sprite.prop )
	fxState:attachAction ( state, self:getDelay() )
	fxState[ self ] = sprite	
end

function EffectMSprite:getClipNames()
	local data = mock.loadAsset( self.spritePath )
	if not data then return nil end
	local result = {}
	for k,i in pairs( data.animations ) do
		table.insert( result, { k, k } )
	end
	return result
end

function EffectMSprite:onStop( fxState )
	local sprite = fxState[ self ]
	if sprite then
		sprite:stop()
		fxState:unlinkPartition( sprite.prop )
	end
end

--------------------------------------------------------------------
--Aurora Sprite
--------------------------------------------------------------------
CLASS: EffectSpineSprite ( EffectTransformNode )
	:MODEL{
		Field 'spritePath' :asset( 'spine' );
		Field 'clip'  :string() :selection( 'getClipNames' );
		Field 'mode'  :enum( EnumTimerMode );
		'----';
		Field 'throttle'  :range( 0 );
		Field 'offset'   ;
		'----';
		Field 'color'    :type('color')  :getset('Color') ;
		Field 'blend' :enum( EnumBlendMode );
	}

function EffectSpineSprite:__init()
	self.blend = 'alpha'
	self.mode  = MOAITimer.NORMAL
	self.clip  = false
	self.color = { 1,1,1,1 }
	self.throttle = 1
	self.offset = 0
end


function EffectSpineSprite:getDefaultName()
	return 'spine'
end

function EffectSpineSprite:getTypeName()
	return 'spine'
end


function EffectSpineSprite:getColor()
	return unpack( self.color )
end

function EffectSpineSprite:setColor( r,g,b,a )
	self.color = { r,g,b,a }
end

-- local function _onSpineAnimStop( anim )
-- 	return anim._effectNode:stop()
-- end

function EffectSpineSprite:onLoad( fxState )
	local sprite = SpineSpriteSimple()
	sprite:setSprite( self.spritePath )
	setPropBlend( sprite.skeleton, self.blend )
	self:applyTransformToProp( sprite )
	
	fxState:linkTransform( sprite.skeleton )
	fxState:linkPartition( sprite.skeleton )

	sprite.skeleton:setColor( unpack( self.color ) )
	sprite:setThrottle( self.throttle )
	local animState = sprite:play( self.clip, self.mode, nil, 'waitAttach', self.offset )
	fxState[ self ] = sprite
	if animState then
		fxState:attachAction( animState )
		animState._effectNode = self
		animState:setListener( MOAIAction.EVENT_STOP, 
			function()
				fxState:removeActiveNode( self )				
				sprite.skeleton:setPartition( nil )
			end
		)
	else
		fxState:removeActiveNode( self )
	end
end

function EffectSpineSprite:getClipNames()
	local data = mock.loadAsset( self.spritePath )
	if not data then return nil end
	local result = {}
	for k,i in pairs( data._animationTable ) do
		table.insert( result, { k, k } )
	end
	return result
end


function EffectSpineSprite:onStop( fxState )
	local sprite = fxState[ self ]
	fxState:unlinkPartition( sprite.skeleton )
end
--------------------------------------------------------------------
registerTopEffectNodeType(
	'sprite-static',
	EffectStaticSprite,
	EffectCategoryTransform	
)


registerTopEffectNodeType(
	'sprite-msprite',
	EffectMSprite,
	EffectCategoryTransform
)

registerTopEffectNodeType(
	'sprite-spine',
	EffectSpineSprite,
	EffectCategoryTransform
)

