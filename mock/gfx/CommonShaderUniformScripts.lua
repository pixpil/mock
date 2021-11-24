module 'mock'

--------------------------------------------------------------------
CLASS: GameTimeUniformScriptSource ( UniformScriptSource )
:register( 'game_time', 'float' )

function GameTimeUniformScriptSource:onInit()
	self.uniform = GameTimeUniformScript()
end

function GameTimeUniformScriptSource:createUniform( shader )
	return self.uniform
end

--------------------------------------------------------------------
CLASS: GameTimeUniformScript ( UniformScript )
function GameTimeUniformScript:onBind( shader, blockId, uid, attrId )
	shader:setAttrLink( attrId, game:getTimer(), MOAITimer.ATTR_TIME )
end

-- --------------------------------------------------------------------
-- CLASS: TimerUniformScriptSource ( UniformScriptSource )
-- :register( 'timer' )

-- function TimerUniformScriptSource:createUniform( shader )
-- 	return TimerUniformScript()
-- end

-- --------------------------------------------------------------------
-- CLASS: TimerUniformScript ( UniformScript )

-- function TimerUniformScript:onInit( source )
-- 	self.timer = MOAITimer.new()
-- 	self.timer:setMode( MOAITimer.CONTINUE )
-- end

-- function TimerUniformScript:onBind( shader, idx )
-- 	self.timer:start()
-- 	shader:setAttrLink( idx, self.timer, MOAITimer.ATTR_TIME )
-- end


