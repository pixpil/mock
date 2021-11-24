module 'mock'

CLASS: AnimatorTrackColorComponent ( AnimatorValueTrack )
	:MODEL {
		Field 'comId' :int() :no_edit();
	}
--------------------------------------------------------------------
function AnimatorTrackColorComponent:__init( comId, name )
	self.comId = comId
	self.name = name
end

function AnimatorTrackColorComponent:createKey( pos )
	local key = AnimatorKeyNumber( pos )
	key:setPos( pos )
	return self:addKey( key )
end

function AnimatorTrackColorComponent:isPlayable()
	return false
end

function AnimatorTrackColorComponent:isCurveTrack()
	return true
end

function AnimatorTrackColorComponent:getIcon()
	return 'track_number'
end

function AnimatorTrackColorComponent:canReparent( target )
	return false
end

--------------------------------------------------------------------
CLASS: AnimatorTrackFieldColor ( AnimatorTrackField )
function AnimatorTrackFieldColor:init()
	--create sub component track
	self:createSubComponentTrack( 1, 'r' )
	self:createSubComponentTrack( 2, 'g' )
	self:createSubComponentTrack( 3, 'b' )
	self:createSubComponentTrack( 4, 'a' )
end

function AnimatorTrackFieldColor:getComponentTrack( id )
	for i, sub in ipairs( self.children ) do
		if sub.comId == id then return sub end
	end
	return nil
end

function AnimatorTrackFieldColor:createSubComponentTrack( id, name )
	local track = AnimatorTrackColorComponent( id, name )
	self:addChild( track )
end

function AnimatorTrackFieldColor:createSubComponentTrackKey( comId, pos, value )
	local track = self:getComponentTrack( comId )
	local key = track:createKey( pos )
	key:setValue( value )
	return key
end

function AnimatorTrackFieldColor:updateParentKey( parentKey )
	local childKeys = parentKey:getChildKeys()
	if not childKeys then return end
	local value = {}
	for i, k in ipairs( childKeys ) do
		local childTrack = k:getTrack()
		local comId = childTrack.comId
		value[ comId ] = k.value
		k.pos = parentKey.pos
	end
	parentKey:setValue( unpack( value ) )
end

function AnimatorTrackFieldColor:updateChildKeys( parentKey )
	local childKeys = parentKey:getChildKeys()
	if not childKeys then return end
	local value = { parentKey:getValue() }
	for i, k in ipairs( childKeys ) do
		local childTrack = k:getTrack()
		local comId = childTrack.comId
		k:setValue( value[ i ] )
		k.pos = parentKey.pos
	end
end

function AnimatorTrackFieldColor:createKey( pos, context )
	local target = context.target
	local r,g,b,a = self.targetField:getValue( target )
	local keyR = self:createSubComponentTrackKey( 1, pos, r )
	local keyG = self:createSubComponentTrackKey( 2, pos, g )
	local keyB = self:createSubComponentTrackKey( 3, pos, b )
	local keyA = self:createSubComponentTrackKey( 4, pos, a )
	local masterKey = AnimatorKeyColor()
	masterKey:setValue( r,g,b,a )
	masterKey:setPos( pos )
	masterKey:addChildKey( keyR )
	masterKey:addChildKey( keyG )
	masterKey:addChildKey( keyB )
	masterKey:addChildKey( keyA )
	self:addKey( masterKey )
	return keyR, keyG, keyB, keyA, masterKey
end

function AnimatorTrackFieldColor:apply( state, target, t )
	local r = self.curveR:getValueAtTime( t )
	local g = self.curveG:getValueAtTime( t )
	local b = self.curveB:getValueAtTime( t )
	local a = self.curveA:getValueAtTime( t )
	return self.targetField:setValue( target, r, g, b, a )
end

function AnimatorTrackFieldColor:build( context ) --building shared data
	self.curveR = self:getComponentTrack( 1 ):buildCurve()
	self.curveG = self:getComponentTrack( 2 ):buildCurve()
	self.curveB = self:getComponentTrack( 3 ):buildCurve()
	self.curveA = self:getComponentTrack( 4 ):buildCurve()
	context:updateLength( self:calcLength() )
end

function AnimatorTrackFieldColor:isEmpty()
	return
		self:getComponentTrack(1):isEmpty() and
		self:getComponentTrack(2):isEmpty() and
		self:getComponentTrack(3):isEmpty() and
		self:getComponentTrack(4):isEmpty()
end

function AnimatorTrackFieldColor:calcLength()
	local length = math.max( 
		self:getComponentTrack(1):calcLength(), 
		self:getComponentTrack(2):calcLength(), 
		self:getComponentTrack(3):calcLength(),
		self:getComponentTrack(4):calcLength()
	)
	return length
end

function AnimatorTrackFieldColor:getIcon()
	return 'track_color'
end
