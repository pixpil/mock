module 'mock'

local sort = table.sort

local ATTR_LOCAL_VISIBLE= MOAIProp. ATTR_LOCAL_VISIBLE
local ATTR_VISIBLE      = MOAIProp. ATTR_VISIBLE
local INHERIT_VISIBLE   = MOAIProp. INHERIT_VISIBLE
local INHERIT_COLOR     = MOAIProp. INHERIT_COLOR
local COLOR_TRAIT       = MOAIProp. COLOR_TRAIT 

CLASS: EntityGroup ()
	:MODEL{
		-- Field '__guid': string() :no_edit();
		-- Field '_editLocked' :boolean() :no_edit();
		Field 'name': string() :getset( 'Name' ) ;
		Field 'visible' :boolean() :get( 'isLocalVisible' ) :set( 'setVisible' );
		Field 'tags'    :string()  :getset('TagString');
		'----';
		Field 'ignoredInGame' :boolean();
		Field 'debugOnly'     :boolean();

	}

function EntityGroup.__accept( data )
	if data.ignoredInGame then
		return false
	else
		if data.debugOnly then
			if not game:isDeveloperMode() then return false end
		end
		return true
	end
end


function EntityGroup:__init()
	-- self.__guid = false
	self._prop       = MOAIGraphicsProp.new() --only control visiblity
	self._priority   = 0
	self._editLocked = false
	self.scene  = false
	self.parent = false
	self.childGroups = {}
	self.entities    = {}
	self.name = 'EntityGroup'
	self.icon = false
	
	self._isRoot    = false
	self._isDefault = false
	self._tag = EntityTag( self )

	self.ignoredInGame    = false
	self.debugOnly = false

end

function EntityGroup:__tostring()
	return string.format( '%s%s', self:__repr(), self:getFullName() or '???')
end


function EntityGroup:isRootGroup()
	return self._isRoot
end

function EntityGroup:getExtraFilePath( subName )
	if not subName then return false end
	if not self._isRoot then return false end
	local scene = self:getScene()
	if not scene then return false end
	local fileName = string.format( '%s.extra.%s', self.name, subName )
	return scene:getFilePath( fileName )
end

function EntityGroup:findGroupByGUID( guid )
	if self.__guid == guid then return self end
	for g in pairs( self.childGroups ) do
		local result = g:findGroupByGUID( guid )
		if result then
			return result
		end
	end
	return nil
end

function EntityGroup:getTagObject()
	return self._tag
end

function EntityGroup:hasTag( t, searchParent )
	if not self._tag then return false end
	return self._tag:has( t, searchParent )
end

function EntityGroup:setTagString( t )
	self._tag:setString( t )
end

function EntityGroup:getTagString()
	return self._tag:getString()
end

function EntityGroup:forceUpdate()
end

function EntityGroup:getName()
	return self.name
end

function EntityGroup:setName( name )
	self.name = name
end

function EntityGroup:isVisible()
	return self._prop:getAttr( MOAIProp.ATTR_VISIBLE ) == 1
end

function EntityGroup:isLocalVisible()
	local vis = self._prop:getAttr( MOAIProp.ATTR_LOCAL_VISIBLE )
	return vis == 1
end

function EntityGroup:isLocalEditLocked()
	return self._editLocked
end

function EntityGroup:setEditLocked( locked )
	self._editLocked = locked
end

function EntityGroup:isEditLocked()
	if self._editLocked then return true end
	if self.parent then return self.parent:isEditLocked() end
	return false
end

function EntityGroup:setVisible( visible )
	self._prop:setVisible( visible )
end

function EntityGroup:setEditOpacity( opa )
	if opa then
		self._prop:setColor( 1,1,1,1 )
	else
		self._prop:setColor( .3,.3,.3, 1 )
	end
end

function EntityGroup:getName()
	return self.name
end

function EntityGroup:getFullName()
	if not self.name then return false end
	local output = self.name
	local n = self.parent
	while n and not n:isRootGroup() do
		output = (n.name or '<noname>')..'/'..output
		n = n.parent
	end
	return output
end

function EntityGroup:getIcon()
	return self.icon
end

function EntityGroup:addEntity( e )
	if not e.FLAG_EDITOR_OBJECT then
		e:getProp( 'physics' ):setAttrLink( INHERIT_COLOR, self._prop, COLOR_TRAIT )
		e:getProp( 'physics' ):setAttrLink( INHERIT_VISIBLE, self._prop, ATTR_VISIBLE )
	end
	e._entityGroup = self
	self.entities[ e ] = true
	assert( not e.parent )
	return e
end

function EntityGroup:removeEntity( e )
	e:getProp( 'physics' ):clearAttrLink( INHERIT_COLOR )
	e:getProp( 'physics' ):clearAttrLink( INHERIT_VISIBLE )
	e._entityGroup = false
	self.entities[ e ] = nil
end

function EntityGroup:addChildGroup( g )
	g.parent = self
	g.scene  = self.scene
	g._prop:setAttrLink( INHERIT_COLOR, self._prop, COLOR_TRAIT )
	g._prop:setAttrLink( INHERIT_VISIBLE, self._prop, ATTR_VISIBLE )
	self.childGroups[ g ] = true
	local entityListener = self.scene.entityListener
	if entityListener then entityListener( 'add_group', g, self.scene ) end
	return g
end

function EntityGroup:removeChildGroup( g )
	if g.parent == self then
		g._prop:clearAttrLink( INHERIT_COLOR )
		g._prop:clearAttrLink( INHERIT_VISIBLE )
		self.childGroups[ g ] = nil
		local entityListener = self.scene.entityListener
		if entityListener then entityListener( 'remove_group', g, self.scene ) end
	end
end

function EntityGroup:getChildGroups()
	return self.childGroups
end

function EntityGroup:isEmpty()
	if next( self.childGroups ) then return false end
	if next( self.entities ) then return false end
	return true
end

function EntityGroup:getEntities()
	return self.entities
end


local function entitySortFunc( a, b )
	return ( a._priority or 0 ) < ( b._priority or 0 )
end

local function entitySortFuncReversed( b, a )
	return ( a._priority or 0 ) > ( b._priority or 0 )
end

function EntityGroup:getSortedEntityList( reversed )
	local l = table.keys( self.entities )
	if reversed then
		sort( l, entitySortFuncReversed )
	else
		sort( l, entitySortFunc )
	end
	return l
end


function EntityGroup:getParentOrGroup( reversed )
	return self.parent
end

function EntityGroup:addChild( entity )
	if isInstance( entity, Entity ) then
		self.scene:addEntity( entity, nil, self )
	elseif isInstance( entity, EntityGroup ) then
		self:addChildGroup( entity )
	end
end

function EntityGroup:clear()
	--TODO
end


function EntityGroup:_ungroupEntities( targetGroup )
	for childGroup in pairs( self.childGroups ) do
		childGroup:_ungroupEntities( targetGroup )
	end
	for ent in pairs( self.entities ) do
		targetGroup:addEntity( ent )
	end
end

function EntityGroup:reparent( targetGroup )
	if targetGroup == self.parent then return end
	self.parent:removeChildGroup( self )
	targetGroup:addChildGroup( self )
end

function EntityGroup:ungroup()
	assert( self.parent )
	self:_ungroupEntities( self.parent )
	self.parent:removeChildGroup( self )
end


function EntityGroup:destroyWithChildrenNow()
	for childGroup in pairs( self.childGroups ) do
		childGroup:destroyWithChildrenNow()
	end
	if self.parent then
		self.parent:removeChildGroup( self )
	end
	for e in pairs( self.entities ) do
		e:destroyWithChildrenNow()
	end
	self.entities = {}
end

function EntityGroup:getScene()
	return self.scene
end

function EntityGroup:foreachChildGroup( func, deep )
	for childGroup in pairs( self.childGroups ) do
		if not ( childGroup.FLAG_INTERNAL or childGroup.FLAG_EDITOR_OBJECT ) then
			func( childGroup )
			if deep then
				childGroup:foreachChildGroup( func, true )
			end
		end
	end
end

function EntityGroup:foreachEntity( func, deep )
	for childGroup in pairs( self.childGroups ) do
		if not ( childGroup.FLAG_INTERNAL or childGroup.FLAG_EDITOR_OBJECT ) then
			local res = childGroup:foreachEntity( func, deep )
			if res == 'stop' then
				return 'stop'
			end
		end
	end

	for e in pairs( self.entities ) do
		if not ( e.FLAG_INTERNAL or e.FLAG_EDITOR_OBJECT ) then
			local res = func( e )
			if res == 'stop' then return 'stop' end
			if res == 'out' then return end
			if res ~= 'skip' and deep then
				local res = e:foreachChild( func, true )
				if res == 'stop' then
					return 'stop'
				end
			end
		end
	end

end

function EntityGroup:getRootGroup()
	local g = self
	while g do
		if g:isRootGroup() then return g end
		g = g.parent
	end
	return nil
end

---------------------------------------------------------------------
-- ...
--@todo
--------------------------------------------------------------------
function EntityGroup:getRootGroupName()
	local r = self:getRootGroup()
	if r then
		return r:getName()
	else
		return nil
	end
end
