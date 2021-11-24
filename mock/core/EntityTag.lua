module 'mock'

CLASS: EntityTag ()
	:MODEL{}

function EntityTag:__init( owner )
	self.owner = owner
	self.tags = false
end

function EntityTag:get()
	return self.tags
end

function EntityTag:set( t )
	self.tags = table.simplecopy( t )
end

function EntityTag:getString()
	if not self.tags then 
		return false
	else
		return string.join( ',', table.keys( self.tags ) )
	end
end

function EntityTag:setString( s )
	local tags = false
	if s and s ~= '' then
		for part in string.gsplit( s, ',' ) do
			local tag = part:trim()
			if tag ~= '' then
				if not tags then tags = {} end
				tags[ tag ] = true
			end
		end
	end
	self.tags = tags
end

function EntityTag:__tostring()
	return self:getString()
end

function EntityTag:hasLocal( tag )
	return self.tags and ( self.tags[ t ] and true ) or false
end

function EntityTag:has( tag, searchParent )
	if self.tags and self.tags[ tag ] then return true end
	if searchParent then
		local parent = self:getParent()
		if parent then 
			return parent:has( tag, true )
		else
			return false
		end
	else
		return false
	end
end

function EntityTag:find( pattern )
	for tag in pairs( self.tags ) do
		if tag:find( pattern ) then return tag end
	end
	return false
end

function EntityTag:getAll()
	local result = false
	local p = self
	while p do
		local tags = p.tags
		if tags then
			if not result then result = {} end
			table.extend( result, tags )
		end
		p = p:getParent()
	end
	return result
end

function EntityTag:getStringAll()
	local fullTags = self:getAll()
	if not fullTags then
		return false
	else
		return string.join( ',', table.keys( fullTags ) )
	end
end

function EntityTag:getParent()
	local ent = self.owner
	while ent do
		ent = ent:getParentOrGroup()
		if ent then
			local tags = ent:getTagObject()
			if tags then return tags end
		else
			return false
		end
	end
	return false
end

function EntityTag:clear()
	self.tags = false
end