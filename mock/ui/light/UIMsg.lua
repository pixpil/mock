module 'mock'


---------------------------------------------------------------------
CLASS: UIMsgSourceBase ( Component )
	:MODEL{
}

function UIMsgSourceBase:__init()
end

function UIMsgSourceBase:findTarget( name )
	if name == '__root' then
		local ent = self:getEntity()
		if ent:isInstance( UIWidget ) then
			return ent:getParentView(), 'entity'
		else
			return false
		end
	elseif name == '.' then
		return self:getEntity(), 'entity'
	elseif name == '..' then
		return self:getEntity():getParent(), 'entity'
	end

	local ent = self:getEntity()
	while ent do
		local target = ent:com( UIMsgTarget )
		if target and target.name == name then return target, 'target' end
		ent = ent:getParent()
	end
	return false
end

function UIMsgSourceBase:emitMsgTo( name, msg, data )
	local target, targetType = self:findTarget( name )
	if targetType == 'target' then
		return target:receiveMsg( msg, data, self:getEntity() )
	elseif targetType == 'entity' then
		return target:tell( msg, data, self:getEntity() )
	end
end

--------------------------------------------------------------------
CLASS: UIMsgTarget ( UIMsgSourceBase )
	:MODEL{
	Field 'name' :string();
}

registerComponent( 'UIMsgTarget', UIMsgTarget )

function UIMsgTarget:__init()
	self.name = 'target'
end

function UIMsgTarget:getName()
	return self.name
end

function UIMsgTarget:receiveMsg( msg, data, src )
	return self:getEntity():tell( msg, data, src )
end


--------------------------------------------------------------------
CLASS: UIMsgSource ( UIMsgSourceBase )
	:MODEL{
		Field 'target' :string();
		Field 'data' :string();
}

function UIMsgSource:__init()
	self.target = 'target'
	self.data = 'data'
end

function UIMsgSource:emitMsg( msg )
	return self:emitMsgTo( self.target, msg, self.data )
end

