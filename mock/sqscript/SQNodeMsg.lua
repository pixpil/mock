module 'mock'

--------------------------------------------------------------------
CLASS: SQNodeMsg ( SQNode )
	:MODEL{
		Field 'msg'  :string();
		Field 'data' :string();
	}

function SQNodeMsg:__init()
	self.msg  = ''
	self.data = nil
end

function SQNodeMsg:isReplayable()
	return true
end

function SQNodeMsg:load( data )
	local args = data.args
	self.msg = args[1] or false
	self.data = args[2] or nil
end

function SQNodeMsg:enter( state, env )
	if not self.msg or self.msg == '' then return false end
	local targets = self:getContextEntities( state )
	local msg, data = self.msg, self.data and self.data:trim() or nil
	for i, target in ipairs( targets ) do
		target:tell( msg, data, state )
	end
end

function SQNodeMsg:getRichText()
	return string.format( '<cmd>MSG</cmd> <data>%s ( <string>%s</string> )</data>', self.msg, self.data )
end

--------------------------------------------------------------------
CLASS: SQNodeMsgSelfAndChildren ( SQNodeMsg )

function SQNodeMsgSelfAndChildren:enter( state, env )
	if not self.msg or self.msg == '' then return false end
	local targets = self:getContextEntities( state )
	local msg, data = self.msg, self.data and self.data:trim() or nil
	for i, target in ipairs( targets ) do
		target:tellSelfAndChildren( msg, data )
	end
end

--------------------------------------------------------------------
CLASS: SQNodeMsgChildrenOnly ( SQNodeMsg )

function SQNodeMsgChildrenOnly:enter( state, env )
	if not self.msg or self.msg == '' then return false end
	local targets = self:getContextEntities( state )
	local msg, data = self.msg, self.data and self.data:trim() or nil
	for i, target in ipairs( targets ) do
		target:tellChildren( msg, data )
	end
end

--------------------------------------------------------------------
CLASS: SQNodeChildMsg ( SQNode )
	:MODEL{
		Field 'target'  :string();
		Field 'msg'  :string();
		Field 'data' :string();
	}

function SQNodeChildMsg:__init()
	self.target  = ''
	self.msg  = ''
	self.data = nil
end

function SQNodeChildMsg:load( data )
	local args = data.args
	self.target = args[1]
	self.msg    = args[2] or false
	self.data   = args[3] or nil
end

function SQNodeChildMsg:enter( state, env )
	if not self.msg or self.msg == '' then return false end
	local target = self:getContextEntity( state ):findChildCom( self.target )
	target:tell( self.msg, self.data )
end

function SQNodeChildMsg:getRichText()
	return string.format( '<cmd>MSG</cmd> <data>%s ( <string>%s</string> )</data>', self.msg, self.data )
end

--------------------------------------------------------------------
CLASS: SQNodeComponentMsg ( SQNode )
	:MODEL{
		Field 'target'  :string();
		Field 'msg'  :string();
		Field 'data' :string();
	}

function SQNodeComponentMsg:__init()
	self.targetcom  = ''
	self.msg  = ''
	self.data = nil
end

function SQNodeComponentMsg:load( data )
	local args = data.args
	self.targetcom = args[1]
	self.msg = args[2] or false
	self.data   = args[3] or nil
end

function SQNodeComponentMsg:enter( state, env )
	-- print( 'enter_targetcom' )
	if not self.msg or self.msg == '' then return false end
	-- print( self.targetcom )
	self:getContextEntity( state ):com( self.targetcom ):tell( self.msg )
end

function SQNodeComponentMsg:getRichText()
	return string.format( '<cmd>MSG</cmd> <data>%s ( <string>%s</string> )</data>', self.msg, self.data )
end

--------------------------------------------------------------------
CLASS: SQNodeWaitMsg ( SQNode )
	:MODEL{
		Field 'msg' :string()
	}

function SQNodeWaitMsg:__init()
	self.msg = ''
end

function SQNodeWaitMsg:isExecutable()
	return true
end

function SQNodeWaitMsg:load( data )
	local args = data.args
	self.msg = args[1] or false
end

function SQNodeWaitMsg:enter( state, env )
	local entity = state:getActorEntity()
	if not entity then return false end
	if not self.msg then return false end
	local msgListener = function( msg, data )
		return self:onMsg( state, env, msg, data )
	end
	env.msgListener = msgListener
	entity:addMsgListener( msgListener )
end

function SQNodeWaitMsg:step( state, env )
	if env.received then
		local entity = state:getActorEntity()
		entity:removeMsgListener( env.msgListener )
		return true
	end
end

function SQNodeWaitMsg:onMsg( state, env, msg, data )
	if msg == self.msg then
		env.received = true
	end
end

function SQNodeWaitMsg:getRichText()
	return string.format( '<cmd>WAIT_MSG</cmd> <data>%s</data>', self.msg )
end

--------------------------------------------------------------------
registerSQNode( 'tell', SQNodeMsg   )
registerSQNode( 'tell_self_children', SQNodeMsgSelfAndChildren   )
registerSQNode( 'tell_children', SQNodeMsgChildrenOnly   )
registerSQNode( 'tellto', SQNodeChildMsg   )
registerSQNode( 'wait_msg', SQNodeWaitMsg )
registerSQNode( 'tellcom', SQNodeComponentMsg   )