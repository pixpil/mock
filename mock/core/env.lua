module 'mock'

MOCK_DEVELOPER_MODE = false

---env
local ProjectBasePath    = false
local GameConfigBasePath = false


function getProjectPath( path )
	if not path then
		return ProjectBasePath or ''
	end

	if ProjectBasePath then
		return ProjectBasePath .. '/' .. ( path or '' )
	else
		return path
	end
end

function getGameConfigPath( path )
	if not path then
		return GameConfigBasePath or ''
	end
	
	if GameConfigBasePath then
		return GameConfigBasePath .. '/' .. ( path or '' )
	else
		return path
	end
end

function setupEnvironment( prjBase, configBase )
	ProjectBasePath = prjBase
	GameConfigBasePath  = configBase
end

function setDeveloperMode()
	local userDataPath = 'env/workspace/_userdata'
	MOAIEnvironment.documentDirectory = userDataPath
	MOAIFileSystem.affirmPath( userDataPath )
	MOCK_DEVELOPER_MODE = true
end


--------------------------------------------------------------------
--config
function loadGameConfig( filename )
	local path = getGameConfigPath( filename )
	local data = tryLoadJSONFile( path )
	_stat( 'loading game config', path )
	return data
end

function saveGameConfig( data, filename )
	if not data then return false end
	local path = getGameConfigPath( filename )
	local dir = dirname( path )
	_info( 'saving game config', path )
	MOAIFileSystem.affirmPath( dir )
	saveJSONFile( data, path )
end

