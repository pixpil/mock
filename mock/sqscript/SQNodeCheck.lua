module 'mock'
--------------------------------------------------------------------
CLASS: SQNodeCheck ( SQNode )
	:MODEL{}

function SQNodeCheck:__init()
	self.expr = false
end

function SQNodeCheck:load( data )
	self.expr = data.args[ 1 ]
	local valueFunc, err   = loadEvalScriptWithEnv( self.expr )
	if not valueFunc then
		self:_warn( 'failed compiling condition expr:', err )
		self.valueFunc = false
	else
		self.valueFunc = valueFunc
	end
end

local setfenv = setfenv
function SQNodeCheck:checkCondition( state, env )
	local func = self.valueFunc
	if not func then return false end

	local ok, result = func( state:getEvalEnv() )
	if ok then return result end
	
	return false
end

function SQNodeCheck:enter( state, env )
	local result = self:checkCondition( state, env )
	if not result then
		state._jumpTargetNode = false --jump to end
		return 'jump'
	else
		return true
	end
end

registerSQNode( 'check', SQNodeCheck )
