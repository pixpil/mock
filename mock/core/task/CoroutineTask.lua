module 'mock'

local yield = coroutine.yield

--------------------------------------------------------------------
CLASS: CoroutineTask ( Task )
	:MODEL{}

function CoroutineTask:yield()
end

function CoroutineTask:onStart()
end

function CoroutineTask:onFail()
end

function CoroutineTask:onComplete()
end


--------------------------------------------------------------------
CoroutineTaskManager()
