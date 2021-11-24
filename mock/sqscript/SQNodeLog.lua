module 'mock'

--------------------------------------------------------------------
CLASS: SQNodeLog ( SQNode )
	:MODEL{
		Field 'text' :string();
	}

function SQNodeLog:__init()
	self.text = 'message'
end

function SQNodeLog:isReplayable()
	return true
end

function SQNodeLog:load( data )
	local args = data.args
	local text = false
	for i, arg in ipairs( data.args ) do
		if not text then
			text = arg
		else
			text = text .. '\n' .. arg
		end
	end
	self.text = text or ''
end

function SQNodeLog:enter( state, env )
	self:_log( self.text )
end

function SQNodeLog:getRichText()
	return string.format( '<cmd>LOG</cmd> <comment>%s</comment>', self.text )
end

function SQNodeLog:getDebugRepr()
	return 'log', self.text
end
--------------------------------------------------------------------
registerSQNode( 'log', SQNodeLog )
