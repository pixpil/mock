module 'mock'

--------------------------------------------------------------------
CLASS: SQNodeSignal ( SQNode )
	:MODEL{
		Field 'signalId' :string()
	}

function SQNodeSignal:__init()
	self.signalId = ''
end

function SQNodeSignal:isReplayable()
	return 'noplay'
end

function SQNodeSignal:load( data )
	local args = data.args
	self.signalId = args[1] or false
	if not self.signalId then
		self:_warn( 'no signal id' )
	end
end

function SQNodeSignal:enter( state, env )
	if not self.signalId then return end
	state:incSignalCounter( self.signalId )
end

function SQNodeSignal:getRichText()
	return string.format( '<cmd>SIG</cmd> <signal>%s</signal>', self.signalId )
end

function SQNodeSignal:getDebugRepr()
	return 'sig', self.signalId
end

--------------------------------------------------------------------
CLASS: SQNodeWaitNextSignal ( SQNode )
	:MODEL{
		Field 'signalId' :string()
	}

function SQNodeWaitNextSignal:__init()
	self.signalId = ''
end

function SQNodeWaitNextSignal:isReplayable()
	return 'noplay'
end

function SQNodeWaitNextSignal:load( data )
	local args = data.args
	self.signalId = args[1] or false
	if not self.signalId then
		self:_warn( 'no signal id' )
	end
end

function SQNodeWaitNextSignal:enter( state, env )
	if not self.signalId then return end
	local counter = state:getSignalCounter( self.signalId )
	env.counter0 = counter
end

function SQNodeWaitNextSignal:step( state, env )
	local counter = state:getSignalCounter( self.signalId )
	if counter ~= env.counter0 then return true end
end

function SQNodeWaitNextSignal:getRichText()
	return string.format( '<cmd>WAIT_SIG</cmd> <signal>%s</signal>', self.signalId )
end

function SQNodeWaitNextSignal:getDebugRepr()
	return 'wait_next_signal', self.signalId
end

--------------------------------------------------------------------
CLASS: SQNodeWaitFirstSignal ( SQNode )
	:MODEL{}

function SQNodeWaitFirstSignal:__init()
	self.signalId = ''
end

function SQNodeWaitFirstSignal:isReplayable()
	return 'noplay'
end

function SQNodeWaitFirstSignal:load( data )
	local args = data.args
	self.signalId = args[1] or false
	if not self.signalId then
		self:_warn( 'no signal id' )
	end
end

function SQNodeWaitFirstSignal:enter( state, env )
	if not self.signalId then return end
end

function SQNodeWaitFirstSignal:step( state, env )
	local counter = state:getSignalCounter( self.signalId )
	return counter > 0
end

function SQNodeWaitFirstSignal:getRichText()
	return string.format( '<cmd>WAIT_SIG</cmd> <signal>%s</signal>', self.signalId )
end

function SQNodeWaitFirstSignal:getDebugRepr()
	return 'wait_signal', self.signalId
end

--------------------------------------------------------------------
registerSQNode( 'signal', SQNodeSignal   )
registerSQNode( 'wait_signal', SQNodeWaitNextSignal )
registerSQNode( 'wait_first_signal', SQNodeWaitFirstSignal )
