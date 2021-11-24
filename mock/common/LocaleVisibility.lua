module 'mock'

CLASS: LocaleVisibility ( mock.Component )
	:MODEL{
		Field 'accept' :collection( 'string') :selection( EnumLocalesWithAll );
		Field 'excluede' :collection( 'string') :selection( EnumLocales );
	}

mock.registerComponent( 'LocaleVisibility', LocaleVisibility )
--mock.registerEntityWithComponent( 'LocaleVisibility', LocaleVisibility )

function LocaleVisibility:__init()
	self.accept = { 'all' }
	self.excluede = {}
end

function LocaleVisibility:onAttach( ent )
	if game:isEditorMode() then return end
	return self:update()
end

function LocaleVisibility:update()
	local activeLocale = getActiveLocale()
	local accepted = false
	if table.index( self.accept, 'all' ) then accepted = true end
	if table.index( self.accept, activeLocale ) then accepted = true end
	if not accepted and next( self.excluede ) then
		if not table.index( self.excluede, activeLocale ) then accepted = true end
	end
	print( 'checking', self, activeLocale, accepted )
	return self:getEntity():setVisible( accepted )
end

--TODO: online refresh on locale changed
