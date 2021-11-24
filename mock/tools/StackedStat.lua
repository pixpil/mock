module 'mock'

local __NIL = {}

--------------------------------------------------------------------
CLASS: StatModifier ()
	:MODEL{}

function StatModifier:proc( key, v0 )
	return v0
end

--------------------------------------------------------------------
CLASS: StackedStat ()
	:MODEL{}

function StackedStat:__init()
	self.entryQueue = {}
	self.entryMap = {}
	self.cache = {}
end

local __index = 0
function StackedStat:addItem( item, priority, op )
	if self.entryMap[ item ] then
		_error( 'duplicated stat item', item )
		return
	end
	if isInstance( item, Stat ) or isInstance( item, StatModifier ) or isInstance( item, StackedStat ) or type( item ) == 'table' then
		local entry = {
			item = item,
			index = __index,
			priority = priority,
			op = op or 'add'
		}
		__index = __index + 1
		self.entryMap[ item ] = entry
		table.insert( self.entryQueue, entry )
		table.sort( self.entryQueue, function( a, b )
			local pa, pb = a.priority, b.priority
			if pa == pb then
				return a.index < b.index
			else
				return pa < pb
			end
		end)
	else
		_error( 'invalid stacked stat item', item )
	end
end

function StackedStat:removeItem( item )
	local entry = self.entryMap[ item ]
	if entry then
		self.entryMap[ item ] = nil
		local idx = table.index( self.entryQueue, entry )
		if idx then
			table.remove( self.entryQueue, idx )
		end
	end
end

function StackedStat:get( key, default )
	local v
	local entryMap = self.entryMap
	for i, entry in ipairs( self.entryQueue ) do
		local item = entry.item 
		local op = entry.op
		local v1
		if isInstance( item, Stat ) then
			v1 = item:get( key )		
		elseif isInstance( item, StackedStat ) then
			v1 = item:get( key )
		elseif isInstance( item, StatModifier ) then
			v1 = item:proc( key, v )
		else --table
			v1 = item[ key ]
		end

		if v1 ~= nil then
			if op == 'add' then
				v = ( v or 0 ) + tonumber( v1 ) or 0
			elseif op == 'sub' then
				v = ( v or 0 ) - tonumber( v1 ) or 0
			elseif op == 'mul' then
				v = ( v or 1 ) * tonumber( v1 ) or 0
			elseif op == 'override' then
				v = v1
			elseif op == 'default' then
				if v == nil then v = v1 end
			end
		end

	end
	if v == nil then return default end
	return v
end
