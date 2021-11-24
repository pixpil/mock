module 'mock'

local min = math.min
local interpolate = MOCKHelper.interpolate
function actionTween( duration, easeType, func )
	assert( type( func ) == 'function' )
	local e = 0
	while e < duration do
		e = e + coroutine.yield()
		local k = min( e/duration, 1 )
		local v = interpolate( 0, 1, k, easeType )
		func( v )
	end
end

function actionTweenValue( from, to, duration, easeType, func )
	assert( type( func ) == 'function' )
	local e = 0
	local diff = to - from
	while e < duration do
		e = e + coroutine.yield()
		local k = min( e/duration, 1 )
		local v = interpolate( from, to, k, easeType )
		func( v )
	end
end
