module 'mock'

--------------------------------------------------------------------
CLASS: SQNodeLog ( SQNode )
	:MODEL{
		Field 'text' :string();
	}

function SQNodeLog:__init()
	self.text = 'message'
end

function SQNodeLog:enter( context, env )
	print( self.text )
end

function SQNodeLog:getRichText()
	return string.format( '<cmd>LOG</cmd> <comment>%s</comment>', self.text )
end

--------------------------------------------------------------------
registerSQNode( 'log', SQNodeLog )
