module 'mock'


--------------------------------------------------------------------
CLASS: MSpriteAnimatorKey ( AnimatorEventKey )
	:MODEL{
		Field 'clip'  :string() :selection( 'getClipNames' ) :set( 'setClip' );
		Field 'playMode' :enum( EnumTimerMode );
		Field 'throttle'   :number();
		'----';
		Field 'useRange'  :boolean();
		Field 'range'     :type( 'vec2' ) :getset( 'Range' ) :meta{ decimals = 3, step = 0.01 };
		'----';
		Field 'resetLength' :action( 'resetLength' );
		Field 'makeRange'   :action( 'makeRange' );
	}

function MSpriteAnimatorKey:__init()
	self.throttle = 1
	self.clip = 'default'
	self.playMode = MOAITimer.NORMAL
	self.useRange = false
	self.range = { 0, 0 }
end

function MSpriteAnimatorKey:getRange()
	return unpack( self.range )
end

function MSpriteAnimatorKey:setRange( mi, ma )
	self.range = { mi, ma }
end

function MSpriteAnimatorKey:getClipNames()
	local msprite = self:getTrack():getEditorTargetObject()
	return msprite:getClipNames()
end

function MSpriteAnimatorKey:setClip( clip )
	self.clip = clip
end

function MSpriteAnimatorKey:toString()
	return self.clip or '<nil>'
end

function MSpriteAnimatorKey:resetLength()
	local msprite = self:getTrack():getEditorTargetObject()
	local clipData = msprite:getClip( self.clip )
	if clipData then
		self:setLength( clipData.length / self.throttle )
	end
end

function MSpriteAnimatorKey:makeRange()
	--TODO
end

--------------------------------------------------------------------
CLASS: MSpriteAnimatorTrack ( AnimatorEventTrack )
	:MODEL{
	}

function MSpriteAnimatorTrack:getIcon()
	return 'track_anim'
end

function MSpriteAnimatorTrack:toString()
	local pathText = self.targetPath:toString()
	return pathText..'<clips>'
end


function MSpriteAnimatorTrack:createKey( pos, context )
	local key = MSpriteAnimatorKey()
	key:setPos( pos )
	self:addKey( key )
	local target = context.target --MSprite
	key.clip     = target.default
	return key
end

function MSpriteAnimatorTrack:build( context )
	self:sortKeys()
	local count = #self.keys
	local spanCurve    = MOAIAnimCurve.new()
	spanCurve:reserveKeys( count + 2 )
	spanCurve:setKey( 1, 0, -1, MOAIEaseType.FLAT )
	local pos = 0
	for i = 1, count do
		local key = self.keys[ i ]
		spanCurve:setKey( i + 1, key.pos, i,  MOAIEaseType.FLAT )
	end
	local l = self:calcLength()
	-- spanCurve:setKey( count + 2, l+0.0001, -1, MOAIEaseType.FLAT )
	spanCurve:setKey( count + 2, l, count, MOAIEaseType.FLAT )
	self.spanCurve    = spanCurve
	context:updateLength( l )
end

local min = math.min
function MSpriteAnimatorTrack:apply( state, playContext, t, t0 )
	local spanId  = self.spanCurve:getValueAtTime( t )
	if spanId < 0 then return end
	local key     = self.keys[ spanId ]
	local sprite  = playContext.sprite
	local animState = playContext[ spanId ]
	if not animState then return end
	local subTime = min( key.length, ( t - key.pos ) ) * key.throttle
	if key.useRange then
		local range = key.range
		local conv = animState.timeConverter
		local t0, t1 = range[1], range[2]
		if conv then
			subTime = conv( subTime, t1 - t0 ) + t0
		else
			subTime = min( subTime + t0, t1 )
		end
	else
		local conv = animState.timeConverter
		if conv then
			subTime = conv( subTime, animState.length )
		end
	end
	animState:apply( subTime )
end

local max = math.max
local floor = math.floor

--TODO: optimization using C++
local function mapTimeReverse( t, length )
	return max( length - t, 0 )
end

local function mapTimeReverseContinue( t, length )
	return length - t
end

local function mapTimeReverseLoop( t, length )
	t = t % length
	return length - t
end

local function mapTimePingPong( t, length )
	local span = floor( t / length )
	t = t % length
	if span % 2 == 0 then --ping
		return t
	else
		return length - t
	end
end

local function mapTimeLoop( t, length )
	return t % length
end

local timeMapFuncs = {
	[MOAITimer.NORMAL]           = false;
  [MOAITimer.REVERSE]          = mapTimeReverse;
  [MOAITimer.CONTINUE]         = false;
  [MOAITimer.CONTINUE_REVERSE] = mapTimeReverseContinue;
  [MOAITimer.LOOP]             = mapTimeLoop;
  [MOAITimer.LOOP_REVERSE]     = mapTimeReverseLoop;
  [MOAITimer.PING_PONG]        = mapTimePingPong;
}

function MSpriteAnimatorTrack:onStateLoad( state )
	local rootEntity, scene = state:getTargetRoot()
	local sprite = self.targetPath:get( rootEntity, scene )
	if not sprite then
		_warn( sprite, 'no sprite:' .. tostring( self.targetPath ) )
		return false
	end

	local playContext = { sprite = sprite, spriteAsset = sprite:getSprite() }
	self:updatePlayContext( state, playContext, true )
	state:addUpdateListenerTrack( self, playContext )
end

function MSpriteAnimatorTrack:updatePlayContext( state, playContext, init )
	local sprite = playContext.sprite
	local rebuild
	if init then
		rebuild = true
	else
		local asset = sprite:getSprite()
		if playContext.spriteAsset ~= asset then
			playContext.spriteAsset = asset
			rebuild = true
		end
	end

	if rebuild then
		for i, key in ipairs( self.keys ) do
			local animState, clip = sprite:createAnimState( key.clip, key.playMode )
			if animState then
				animState.timeConverter = timeMapFuncs[ key.playMode ]
				animState.length = clip.length
				animState.clip   = clip
				playContext[ i ] = animState
			else
				_warn( 'no msprite clip named', key.clip, 'in', sprite.spritePath )
				playContext[ i ] = false
			end
		end
	end
	
end

function MSpriteAnimatorTrack:reset( state, playContext )
	self:updatePlayContext( state, playContext )
end

function MSpriteAnimatorTrack:clear( state, playContext )
	-- for i, key in ipairs( self.keys ) do
	-- 	local s = playContext[ i ]
	-- 	if s then
	-- 		MOAIAnim.cycle( s )
	-- 	end
	-- end
end

--------------------------------------------------------------------
registerCustomAnimatorTrackType( MSprite, 'clips', MSpriteAnimatorTrack )




--------------------------------------------------------------------
CLASS: MSpriteHiddenFeaturesAnimatorKey ( AnimatorValueKey )
	:MODEL{
		Field 'hiddenFeatures' :collection( 'string' ) :selection( 'getAvailFeatures' ) :getset( 'HiddenFeatures' );
	}

function MSpriteHiddenFeaturesAnimatorKey:__init()
	self.hiddenFeatures = {}
end

function MSpriteHiddenFeaturesAnimatorKey:setHiddenFeatures( hiddenFeatures )
	self.hiddenFeatures = hiddenFeatures or {}
end

function MSpriteHiddenFeaturesAnimatorKey:getHiddenFeatures()
	return self.hiddenFeatures
end

function MSpriteHiddenFeaturesAnimatorKey:getAvailFeatures()
	local msprite = self:getTrack():getEditorTargetObject()
	return msprite:getAvailFeatures()
end

function MSpriteHiddenFeaturesAnimatorKey:isResizable()
	return false
end

--------------------------------------------------------------------
CLASS: MSpriteHiddenFeaturesAnimatorTrack ( AnimatorValueTrack )
	:MODEL{
	}

function MSpriteHiddenFeaturesAnimatorTrack:getIcon()
	return 'track_msg'
end

function MSpriteHiddenFeaturesAnimatorTrack:toString()
	local pathText = self.targetPath:toString()
	return pathText..':(HidFeat)'
end

function MSpriteHiddenFeaturesAnimatorTrack:createKey( pos, context )
	local target = context.target
	local key = MSpriteHiddenFeaturesAnimatorKey()
	key:setPos( pos )
	key.hiddenFeatures = table.simplecopy( target.hiddenFeatures )
	self:addKey( key )
	return key
end

function MSpriteHiddenFeaturesAnimatorTrack:build( context )
	self.idCurve = self:buildIdCurve()
	context:updateLength( self:calcLength() )
end

function MSpriteHiddenFeaturesAnimatorTrack:onStateLoad( state )
	local rootEntity, scene = state:getTargetRoot()
	local sprite = self.targetPath:get( rootEntity, scene )
	local playContext = { sprite, 0 }
	state:addUpdateListenerTrack( self, playContext )
end

function MSpriteHiddenFeaturesAnimatorTrack:apply( state, playContext, t )
	local sprite = playContext[1]
	local keyId = playContext[2]
	local newId = self.idCurve:getValueAtTime( t )
	if keyId ~= newId then
		playContext[2] = newId
		if newId > 0 then
			local key = self.keys[ newId ]
			return sprite:updateFeatures( key.hiddenFeatures )
		end
	end
end

function MSpriteHiddenFeaturesAnimatorTrack:reset( state, playContext )
	local sprite = playContext[1]
	if sprite then
		sprite:updateFeatures()
	end	
end

function MSpriteHiddenFeaturesAnimatorTrack:isPreviewable()
	return true
end


--------------------------------------------------------------------
registerCustomAnimatorTrackType( MSprite, 'HiddenFeatures', MSpriteHiddenFeaturesAnimatorTrack )
