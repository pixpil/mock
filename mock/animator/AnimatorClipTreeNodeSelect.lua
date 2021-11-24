module 'mock'

-------------------------------------------------------------------
CLASS: AnimatorClipTreeNodeSelect ( AnimatorClipTreeNode )
	:MODEL{
		Field 'var' :string() :label('var');
}

function AnimatorClipTreeNodeSelect:__init()
	self.var = 'state'
	self.cases = {}
	self.caseCount = 0
	self.default = false
end

function AnimatorClipTreeNodeSelect:toString()
	return string.format( 'select %q', self.var )
end

function AnimatorClipTreeNodeSelect:getTypeName()
	return 'select'
end

function AnimatorClipTreeNodeSelect:acceptChildType( typeName )
	return 'case'
end

function AnimatorClipTreeNodeSelect:getIcon()
	return 'animator_clip_tree_node_group'
end

function AnimatorClipTreeNodeSelect:evaluate( treeState )
	local cases = self.cases
	for i = 1, self.caseCount do
		local child = cases[ i ]
		if child:checkCondition( treeState ) then
			return child:evaluateChildren( treeState )
		end
	end
	local default = self.default
	if default then
		return default:evaluateChildren( treeState )
	end
end

function AnimatorClipTreeNodeSelect:onBuild( context )
	for i, child in ipairs( self.children ) do
		if child:isDefault() then
			if not self.default then
				self.default = child
			end
		else
			table.insert( self.cases, child )
		end
	end
	self.caseCount = #self.cases
end

-------------------------------------------------------------------
CLASS: AnimatorClipTreeNodeSelectCase ( AnimatorClipTreeNode )
	:MODEL{
		Field 'value' :string();
}

function AnimatorClipTreeNodeSelectCase:__init()
	self.value = '1'
	self.checkFunc = false
end

function AnimatorClipTreeNodeSelectCase:toString()
	return string.format( 'case: %s', self.value )
end

function AnimatorClipTreeNodeSelectCase:getTypeName()
	return 'case'
end

function AnimatorClipTreeNodeSelectCase:isDefault()
	return false
end

function AnimatorClipTreeNodeSelectCase:acceptChildType( typeName )
	return true
end

function AnimatorClipTreeNodeSelectCase:checkCondition( treeState )
	local func = self.checkFunc
	if func then
		return func( treeState )
	else
		return false
	end
end

local type = type
local function isNumber( v )
	return type( v ) == 'number'
end

local function getStateVar( state, id )
	return state.animator.vars[ id ]
end

local function parseConditionPart( part )
	local part = part:trim()
	if tonumber( part ) then
		return string.format( '( v==%s or v==%q )', part, part )
	elseif part == 'true' then
		return string.format( 'v==true' )
	elseif part == 'false' then
		return string.format( 'v==false' )
	elseif part == 'nil' then
		return string.format( 'v==nil' )
	end
	--try range
	local r0, r1 = part:match( '^([%d%-%.]+)%s*:%s*([%d%-%.]+)$')
	if tonumber(r0) and tonumber(r1) then
		return string.format( '(isn(v) and (v>=%s and v<=%s))', r0, r1 )
	end
	--try gt
	local op,r = part:match( '^([<>]=?)%s([%d%-%.]+)$')
	if tonumber( r ) then
		return string.format( '(isn(v) and (v%s%s)', 90, r )
	end
	return string.format( 'v==%q', part )
end

local function makeConditionChecker( var, cond )
	local head = string.format(
		'local isn, getvar=...; return function(state) local v=getvar(state,%q);', var
		)
	local body
	for part in cond:gsplit( ',' ) do
		local code = parseConditionPart( part )
		if code then
			if body then
				body = body .. ' or ' .. code
			else
				body = 'return ' .. code
			end
		end
	end
	if not body then
		body = 'return false'
	end
	local tail = ';end'
	local src = head .. body .. tail
	local funcFunc, err  = loadstring( src )
	if funcFunc then
		local func = funcFunc( isNumber, getStateVar )
		return func
	else
		_warn( 'error loading condition', cond )
		return false
	end
end

function AnimatorClipTreeNodeSelectCase:onBuild( context )
	local parent = self.parent
	if not parent:isInstance( AnimatorClipTreeNodeSelect ) then return end
	local var = parent.var
	local value = self.value
	if var:trim() == ''   then self.checkFunc = false end
	if value:trim() == '' then self.checkFunc = false end
	self.checkFunc = makeConditionChecker( var, value ) or false
end

--------------------------------------------------------------------
CLASS: AnimatorClipTreeNodeSelectCaseDefault ( AnimatorClipTreeNodeSelectCase )
	:MODEL{
		Field 'value' :string() :no_edit();
	}

function AnimatorClipTreeNodeSelectCaseDefault:onBuild( context )
	--do nothing
end

function AnimatorClipTreeNodeSelectCaseDefault:isDefault()
	return true
end



registerAnimatorClipTreeNodeType( 'select',   AnimatorClipTreeNodeSelect )
registerAnimatorClipTreeNodeType( 'case',     AnimatorClipTreeNodeSelectCase )
registerAnimatorClipTreeNodeType( 'default',     AnimatorClipTreeNodeSelectCaseDefault )
