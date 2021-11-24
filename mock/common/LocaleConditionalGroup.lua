module 'mock'

EnumConditionalGroupMode = _ENUM_V {
	'load_and_show',
	'load',
	'show',
}

---------------------------------------------------------------------
CLASS: LocaleConditionalGroup ( Entity )
	:MODEL{
		Field 'accept' :collection( 'string') :selection( EnumLocalesWithAll );
		Field 'excluede' :collection( 'string') :selection( EnumLocales );
		Field 'mode' :enum( EnumConditionalGroupMode );
	}

registerEntity( 'LocaleConditionalGroup', LocaleConditionalGroup )

local function _checkAccept( data )
	local activeLocale = getActiveLocale()
	local accepted = false
	if table.index( data.accept, 'all' ) then accepted = true end
	if table.index( data.accept, activeLocale ) then accepted = true end

	if not accepted and next( data.excluede ) then
		if not table.index( data.excluede, activeLocale ) then accepted = true end
	end
	return accepted
end

--static
function LocaleConditionalGroup.__accept( data )
	local accepted = _checkAccept( data )
	local mode = data.mode
	if mode == 'show' then
		return true
	else
		return accepted
	end		
end

function LocaleConditionalGroup:__init()
	self.accept = { 'all' }
	self.excluede = {}
	self.mode = 'show'
end

function LocaleConditionalGroup:onStart()
	self:updateVisible()
	self:connect( 'locale.change', 'updateVisible' )
end

function LocaleConditionalGroup:updateVisible()
	local accepted = _checkAccept( self )
	self:setVisible( accepted )
end
