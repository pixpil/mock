module 'mock'

--------------------------------------------------------------------
CLASS: MsgParentRedirector ( Component )
	:MODEL{		
	}

mock.registerComponent( 'MsgParentRedirector', MsgParentRedirector )

function MsgParentRedirector:__init()
end

function MsgParentRedirector:onAttach( ent )	
	self.msgListener = ent:addMsgListener( 
		function( msg, data, source )
			local p = ent.parent
			if p then
				return p:tell( msg, data, source )
			end			
		end
	)
end

function MsgParentRedirector:onDetach( ent )
	ent:removeMsgListener( self.msgListener )
end

--------------------------------------------------------------------
local EnumSearchEntityIn = _ENUM_V {
	'scene',
	'parent'
}

CLASS: MsgNamedRedirector ( Component )
	:MODEL{		
		Field 'searchIn'   :enum( EnumSearchEntityIn );
		Field 'targetName' :string();
	}

mock.registerComponent( 'MsgNamedRedirector', MsgNamedRedirector )


function MsgNamedRedirector:__init()
	self.targetName = ''
	self.searchIn = 'scene'
end

function MsgNamedRedirector:setTarget( name )
	self.targetName = name
end

function MsgNamedRedirector:findTarget()
	local name = self.targetName
	local mode = self.searchIn
	local ent = self._entity
	if mode == 'scene' then
		return ent:findEntity( name )
	elseif mode == 'parent' then
		local p = ent.parent
		while p do
			if p:getName() == name then
				return p
			end
			p = p.parent
		end
	elseif mode == 'sibling' then
		--TODO:
		error( 'not implemented yet' )
	end
end

function MsgNamedRedirector:onAttach( ent )	
	self.msgListener = ent:addMsgListener( 
		function( msg, data, source )
			local target = self:findTarget()
			if target then
				return target:tell( msg, data, source )
			end
		end
	)
end

function MsgNamedRedirector:onDetach( ent )
	ent:removeMsgListener( self.msgListener )
end

--------------------------------------------------------------------
CLASS: MsgChildrenRedirector ( Component )
	:MODEL{		
	}

mock.registerComponent( 'MsgChildrenRedirector', MsgChildrenRedirector )

function MsgChildrenRedirector:__init()
end

function MsgChildrenRedirector:onAttach( ent )	
	self.msgListener = ent:addMsgListener( 
		function( msg, data, source )
			return self:tellChildren( msg, data, source )	
		end
	)
end

function MsgChildrenRedirector:onDetach( ent )
	ent:removeMsgListener( self.msgListener )
end
