module 'mock'

--------------------------------------------------------------------
local clearMOAIObject = clearMOAIObject
local function injectUpdateNodeCtor( clas )
	local _new = clas.new
	clas.new = function()
		return markUpdateNode( _new() )
	end
end

injectUpdateNodeCtor( MOAIAnim )
injectUpdateNodeCtor( MOAITimer )
injectUpdateNodeCtor( MOAIAnimCurve )
injectUpdateNodeCtor( MOAIAnimCurveEX )


function createMOAIObjectPool( clas, t )
	local pool = {}
	local count = 0
	local total = 0
	local new = clas.new
	local init   = t and t.init
	local revive = t and t.revive
	local clear  = t and t.clear
	local logging = t and t.logging or false
	local disabled = t and t.disabled or false
	local total = 0

	local reuse = function()
		if count == 0 then
			total = total + 1
			local o = new()
			if init then
				init( o )
			end
			return o
		end
		local o = pool[ count ]
		pool[ count ] = false
		count = count - 1
		if logging then printf( '>> reusing: %s %d/%d', tostring(o), count, total  ) end
		if revive then
			revive( o )
		end
		return o
	end

	local recycle = function( o )
		if disabled then return end
		if not o then return end
		count = count + 1
		pool[ count ] = o
		if clear then
			clear( o )
		end
		clearMOAIObject( o )
		if logging then printf( '<< recycle: %s %d/%d', tostring(o), count, total  ) end
	end

	local fillpool = function( n )
		for i = 1, n do
			local o = new()
			if init then
				init( o )
			end
			count = count + 1
			total = total + 1
			pool[ count ] = o
		end
	end

	pool.reuse = reuse
	pool.recycle = recycle
	pool.fillpool = fillpool

	if t and t.fill then
		fillpool( t.fill )
	end

	return pool
end


--------------------------------------------------------------------
local EVENT_POST_STOP = MOAIAction.EVENT_POST_STOP
function createMOAIActionPool( clas, t )
	local pool
	local recycle
	local function _actionPostStopRecycleFunc( action )
		action:throttle( 1 )
		action:setAutoStop( true )
		return recycle( action )
	end

	local init0 = t and t.init
	local function init( action )
		action:setListener( EVENT_POST_STOP, _actionPostStopRecycleFunc )
		if init0 then
			return init0( action )
		end
	end
	local t1 = {
		init = init,
		clear = t and t.clear,
		revive = t and t.revive
	}

	pool = createMOAIObjectPool( clas, t1 )
	recycle = pool.recycle
	return pool
end
--------------------------------------------------------------------
function injectMOAIObjectPool( clas, t )
	local pool = createMOAIObjectPool( clas, t )
	clas.reuse   = pool.reuse
	clas.recycle = pool.recycle
	return pool
end

function injectMOAIActionPool( clas, t )
	local pool = createMOAIActionPool( clas, t )
	clas.reuse   = pool.reuse
	clas.recycle = pool.recycle
	return pool
end

--------------------------------------------------------------------
injectMOAIObjectPool( MOAIAnim, {
	fill = 100,
	-- logging = true,
	clear = function( anim )
		anim:setListener( MOAIAnim.EVENT_TIMER_KEYFRAME, nil )
		anim:setListener( MOAIAnim.EVENT_ACTION_POST_UPDATE, nil )
		anim:setListener( MOAIAnim.EVENT_NODE_POST_UPDATE, nil )
		anim:setListener( MOAIAnim.EVENT_TIMER_END_SPAN, nil )
		anim:clearAllLinks()
		anim:reserveLinks( 0 )
	end
})

injectMOAIObjectPool( MOAIGraphicsProp, {
	fill = 500,
	clear = function( prop )
		prop:setVisible( true )
		prop:setColor( 1,1,1,1)
		prop:reset()
	end
} )

injectMOAIObjectPool( MOAIGraphicsGridProp, {
	clear = function( prop )
		prop:setVisible( true )
		prop:setColor( 1,1,1,1)
		prop:setGrid( nil )
		prop:reset()
	end
} )

injectMOAIActionPool( MOAICoroutine, {
	clear = function( coro )
		coro:setDefaultParent( false )
	end
} )

injectMOAIActionPool( MOAITimer )
