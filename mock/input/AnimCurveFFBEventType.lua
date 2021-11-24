module 'mock'

--------------------------------------------------------------------
CLASS: AnimCurveFFBEventType ( mock.FFBEventType )
	:MODEL{}

function AnimCurveFFBEventType:__init( curveA, curveB )
	self.curveA = curveA
	self.curveB = curveB or curveA
	local l = 0
	if curveA then
		l = math.max( curveA:getLength() or 0, l )
	end
	if curveB then
		l = math.max( curveB:getLength() or 0, l )
	end
	self.length = assert( l )
end

function AnimCurveFFBEventType:getLength()
	return self.length
end

function AnimCurveFFBEventType:onUpdate( instance, elapsed )
	if elapsed > self.length then 
		return false
	end
	local a = self.curveA:getValueAtTime( elapsed ) or 0
	local b = self.curveB:getValueAtTime( elapsed ) or 0
	instance:sendData( a, b )

end


--------------------------------------------------------------------
function buildAnimCurveFFBEventType( data )
	local id = data.id
	local curveDataA, curveDataB         = data.curveA, data.curveB
	local attenuationMin, attenuationMax = unpack( data.attenuation or { false, false } )
	local strengthMin, strengthMax       = unpack( data.strength or { 0, 1 } )

	local ffbPlayer = mock.getFFBPlayer()
	local curveA =  curveDataA and mock.buildAnimCurve( curveDataA )
	local curveB =  curveDataB and mock.buildAnimCurve( curveDataB )
	local eventType = AnimCurveFFBEventType( curveA, curveB )
	eventType.attenuationMin = attenuationMin or -1
	eventType.attenuationMax = attenuationMax or attenuationMin
	eventType.strengthMin = strengthMin
	eventType.strengthMax = strengthMax
	return ffbPlayer:registerEventType( id, eventType )
end
