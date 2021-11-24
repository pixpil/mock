module 'mock'

registerGlobalSignals{
	'locale.change',
	'locale.update',
}

local _LocaleManager

function getLocaleManager()
	return _LocaleManager
end

function getDefaultSourceLocale()
	return _LocaleManager:getSourceLocale()
end

function translate( categoryId, stringId, ... )
	return _LocaleManager:translate( categoryId, stringId, ... )
end

function getActiveLocale()
	return _LocaleManager:getActiveLocale()
end

function getAssetTranslation( path, targetLocale )
	return _LocaleManager:getAssetTranslation( path, targetLocale )
end

function translateForAsset( assetPath, source, ... )
	return translateForAssetAs( nil, assetPath, source, ... )
end

function translateForAssetAs( targetLocale, assetPath, source, ... )
	local translation = getAssetTranslation( assetPath, targetLocale )
	if translation then
		local res, output, valid = pcall( translation.translate, source, ... )
		if res then
			if output then
				valid = true
			else
				valid = false
			end
			return output, valid
		else
			_warn( 'error in translation', assetPath, targetLocale, source, res, output )
			return nil
		end
	else
		-- _warn( 'no translation', assetPath, targetLocale )
		return nil
	end
end



local locales = {
	'en',
	'zh-CN',
	'zh-CN2',
	'ja',
	'fr',
	'it'
}

local function matchLocaleName( s )
	for i, k in ipairs( locales ) do
		if k == s then
			return k
		end
	end
	return nil
end


---------------------------------------------------------------------
CLASS: LocalePackEntry ()
	:MODEL{}

function LocalePackEntry:__init()
	self.path = ''
	self.active = false
	self.locales = {}
	self.pack = false
end

function LocalePackEntry:getPath()
	return self.path
end

function LocalePackEntry:isActive()
	return self.active
end

function LocalePackEntry:update()
end

function LocalePackEntry:toData()
	return {
		name    = self.name,
		path    = self.path,
		locales = self.locales,
		active  = self.active
	}
end

function LocalePackEntry:fromData( data )
	self.name    = data[ 'name' ]
	self.path    = data[ 'path' ]
	self.locales = data[ 'locales' ]
	self.active  = data[ 'active' ]
end

function LocalePackEntry:getPack()
	local pack = mock.loadAsset( self.path )
	return pack
end


local LOCALE_CONFIG_NAME  = 'locale_config.json'
--------------------------------------------------------------------
CLASS: LocaleManager ( GlobalManager )
	:MODEL{}

function LocaleManager:__init()
	_LocaleManager = self
	
	self.active = false

	self.locales = {}
	self.localeConfigMap = {}
	self.localePackEntries = {}
	self.sourceLocale = 'zh-CN'
	self.ignoreSourceLocale = true
	self.defaultLocaleId = 'en'
	self.activeLocaleId = 'en'
	self.activeLocaleConfig = false

	self.assetTranslationIndex = {}
end

function LocaleManager:onInit()
	if MOCK_FORCE_SOURCE_LOCALE then
		self.ignoreSourceLocale = false
	end
	self:loadConfig()
end

function LocaleManager:invalidateAssetLocaleIndex()
	self.assetTranslationIndex = false
end

function LocaleManager:affirmAssetLocaleIndex()
	if self.assetTranslationIndex then return self.assetTranslationIndex end
	local index = {}
	for i, entry in ipairs( self.localePackEntries ) do
		local pack, packNode = loadAsset( entry.path ) --config only
		if pack and packNode:getType() == 'locale_pack' then
			for _, item in ipairs( pack.items ) do
				index[ item.path ] = pack
			end
		else
			_warn( 'locale pack not load (missing)', entry.path )
		end
	end
	self.assetTranslationIndex = index
	return index
end

function LocaleManager:loadConfig()
	local data = mock.loadGameConfig( LOCALE_CONFIG_NAME )
	if not data then return false end
	
	local localePackEntries = {}
	for i, packData in ipairs( data[ 'packs' ] or {} ) do
		local entry = LocalePackEntry()
		entry:fromData( packData )
		table.insert( localePackEntries, entry )
	end
	
	self.localePackEntries = localePackEntries
	self.locales = data[ 'locales' ] or {}
	self.sourceLocale = data[ 'source_locale' ] or 'en'
	self.assetTranslationIndex = false
	
end


function LocaleManager:saveConfig()
	local data = {}
	local packDatas = {}
	for i, entry in ipairs( self.localePackEntries ) do
		table.insert( packDatas, entry:toData() )
	end
	data[ 'packs' ] = packDatas
	data[ 'locales' ] = self.locales
	data[ 'source_locale' ] = self.sourceLocale
	mock.saveGameConfig( data, LOCALE_CONFIG_NAME )
	--
	return nil
end

function LocaleManager:translate( categoryId, stringId, ... )
	if not self.active then return nil end
	local localeConfig = self.activeLocaleConfig
	if not localeConfig then
		_warn( 'no active localeConfig' )
		return stringId
	end
	return localeConfig:translate( categoryId, stringId, ... )
end

function LocaleManager:getSourceLocale()
	return self.sourceLocale or false
end

function LocaleManager:getActiveLocale()
	return self.activeLocaleId
end

function LocaleManager:getLocaleConfig( id, fallback )
	local localeConfig = self.localeConfigMap[ id ]
	if not localeConfig and fallback then
		localeConfig = self.localeConfigMap[ fallback ]
	end
	return localeConfig
end

function LocaleManager:affirmLocale( id )
	local localeConfig = self.localeConfigMap[ id ]
	if not localeConfig then
		localeConfig = LocaleConfig()
		localeConfig.id = id
		localeConfig._isSource = id == self.sourceLocale
		if self.ignoreSourceLocale and localeConfig._isSource then
			-- print( 'disable source locale', localeConfig )
			localeConfig.active = false
		end
		self.localeConfigMap[ id ] = localeConfig
	end
	return localeConfig
end

function LocaleManager:loadStringMap( categoryId, path )
	local assetType = getAssetType( path )
	if not assetType then
		_warn( 'failed loading string map', path )
		return false
	end
	if assetType == 'data_sheet' then
		local sheet = loadAsset( path )
		for i, row in pairs( sheet ) do
			local id = row[ 'id' ]
			if id then
				for k, v in pairs( row ) do
					if v:trim() == '' then v = nil end
					local localeName = v and matchLocaleName( k )
					if localeName then
						local localeConfig = self:affirmLocale( localeName )
						localeConfig:addString( categoryId, id, v )
					end
				end
			end
		end
	else
		_warn( 'unknown string map asset type', path, assetType )
		return false
	end

	return true
end

function LocaleManager:setSourceLocale( id )
	self.sourceLocale = id
end

function LocaleManager:setActiveLocale( id, force )
	if ( not force ) and self.activeLocaleId == id then return end
	self.activeLocaleId = id
	if self.ignoreSourceLocale and self.sourceLocale == self.activeLocaleId then
		self.active = false
	else
		self.active = true
	end
	
	local localeConfig = self:getLocaleConfig( id )
	if not localeConfig then
		_error( 'no localeConfig found', id )
		return false
	end
	self.activeLocaleConfig = localeConfig
	emitGlobalSignal( 'locale.change', id )
	_log( 'active locale ->', id )
	return true
end

function LocaleManager:scanPacks()
	local touched = {}
	for i, entry in ipairs( self.localePackEntries ) do
		touched[ entry.path ] = false
	end
	for path, assetNode in pairs( getAssetLibrary() ) do
		if assetNode:getType() == 'locale_pack' then
			if touched[ path ] == nil then
				touched[ path ] = 'new'
			else
				touched[ path ] = 'ok'
			end
		end
	end
	for path, state in pairs( touched ) do
		if state == 'new' then
			self:registerLocalePack( path )
		elseif state == 'ok' then
			--do nothing
		else
			--remove
			self:unregisterLocalePack( path )
		end
	end	
end

function LocaleManager:hasLocalePack( packPath )
	for i, entry in ipairs( self.localePackEntries ) do
		if entry.path == packPath then return true end
	end
	return false
end

function LocaleManager:findLocalePackEntry( packPath )
	for i, entry in ipairs( self.localePackEntries ) do
		if entry.path == packPath then return entry end
	end
	return nil
end

function LocaleManager:registerLocalePack( packPath )
	local entry = self:findLocalePackEntry( packPath )
	if entry then
		_error( 'duplicated locale pack', packPath )
		return nil
	else
		local entry = LocalePackEntry()
		entry.path = packPath
		table.insert( self.localePackEntries, entry )
		self.assetTranslationIndex = false
		return entry
	end
end

function LocaleManager:unregisterLocalePack( packPath )
	local entry = self:findLocalePackEntry( packPath )
	if not entry then return false end
	local idx = table.index( self.localePackEntries, entry )
	if idx then 
		table.remove( self.localePackEntries, idx )
		self.assetTranslationIndex = false
		return true
	end
	return false
end


function LocaleManager:getAssetTranslation( assetPath, locale )
	-- print( 'getting translation', assetPath, locale, self.activeLocaleId )
	if not self.active then
		if not locale then return false end
		if locale == self.activeLocaleId then return false end
	end

	local index = self:affirmAssetLocaleIndex()
	if not index then return false end
	local pack = index[ assetPath ]
	if not pack then return nil end
	local locale = locale or self:getActiveLocale()
	local translation = pack:getAssetTranslation( locale, assetPath )
	return translation
end

--------------------------------------------------------------------
CLASS: LocaleConfig ()
	:MODEL{}

function LocaleConfig:__init()
	self.id = 'en'
	self.stringCategories = {}
	self._isSource = false
	self.active = true
end

function LocaleConfig:__tostring()
	return string.format( '%s:%s', self:__repr(), self.id )
end


function LocaleConfig:isSourceLocale()
	return self._isSource
end

function locale_config( ... )
	-- body
end

function LocaleConfig:affirmCategory( id )
	local cat = self.stringCategories[ id ]
	if not cat then
		cat = {}
		self.stringCategories[ id ] = cat
	end
	return cat
end

function LocaleConfig:translate( categoryId, stringId, ... )
	if not self.active then return false end
	local category = self.stringCategories[ categoryId or 'main' ]
	local s = category and category[ stringId ]
	if not s then
		_warn( 'no string found in locale', stringId, self.id )
		return stringId, false
	end
	return s, true
end

function LocaleConfig:addString( categoryId, id, value )
	local category = self:affirmCategory( categoryId or 'main' )
	-- print( 'adding string', self.id, categoryId, id, value )
	category[ id ] = value
end


--------------------------------------------------------------------
LocaleManager()

-------------------------------------------------------------------
--source code i18n helper
function __( source, ... )
	assert( type( source ) == 'string' )

	local categoryId, stringId 
	local p0, p1 = source:find( '::', 1, true )
	if p0 then
		categoryId = source:sub( 1, p0 - 1 )
		stringId   = source:sub( p1+1, -1 )
	else
		categoryId = false
		stringId = source
	end
	return _LocaleManager:translate( categoryId, stringId, ... )
end

