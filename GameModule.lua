
module( 'GameModule', package.seeall )

local checkFileExists
local readFile
if MOAIFileSystem then
	checkFileExists = MOAIFileSystem.checkFileExists
	
	local stream = MOAIFileStream.new()
	function readFile( path )
		stream:open( path, MOAIFileStream.READ )
		local data,size = stream:read()
		stream:close()
		return data
	end

else
	function checkFileExists( path )
		local fp = io.open( path, 'r' )
		if fp then
			fp:close()
			return true
		else
			return false
		end
	end

	function readFile( path )
		local fp = io.open( path )
		local data = fp:read( '*a' )
		fp:close()
		return data
	end

end

local GameModules = setmetatable( {}, { __no_traverse = true } )

local callbackModuleRelease = {}
local callbackModuleLoad    = {}

function addGameModuleReleaseListener( func )
	table.insert( callbackModuleRelease, func )
end

function addGameModuleLoadListener( func )
	table.insert( callbackModuleLoad, func )
end

function registerGameModule( name, m )
	GameModules[ name ] = m
end

function getGameModule( name )
	return GameModules[ name ]
end

function hasGameModule( name )
	return GameModules[ name ] ~= nil
end

function findGameModule( name )
	for k, m in pairs( GameModules ) do
		if k == name or k:endwith( name ) then
			return m
		end
	end
	return nil
end

--[[
	create a envrionment
]]

local gameModulePaths = {}
function addGameModulePath( pattern )
	table.insert( gameModulePaths, pattern )
end

function getGameModulePath()
	return gameModulePaths
end

function clearGameModulePath()
	gameModulePaths = {}
end

local checkFileExists = MOAIFileSystem.checkFileExists
local gameModuleMap   = {} --for runtime cache
local gameModuleOriginMap = {}
function addGameModuleMapping( srcPath, dstPath, originSrcPath )
	gameModuleMap[ srcPath ] = dstPath
	gameModuleOriginMap[ srcPath ] = originSrcPath
end

local function searchFile( path )
	local mapped = gameModuleMap[ path ]
	if mapped then
		if checkFileExists( mapped ) then
			local origin = gameModuleOriginMap[ path ]
			return mapped, origin
		else
			_warn( 'mapped script not found:', path, mapped )
		end
	end
	path = path:gsub( '%.','/' )
	for i = 1, #gameModulePaths do
		local pattern = gameModulePaths[ i ]
		local f = pattern:gsub( '?', path )
		if checkFileExists( f ) then
			return f, f
		end
	end
	return nil
end

--------------------------------------------------------------------
local GameModuleMT = { __index = _G }
local _createEmptyModule, _loadGameModule, _requireGameModule

local _errorInfos = {}
local function flushErrorInfo()
	local infos = _errorInfos
	_errorInfos = {}
	return infos
end

local function pushErrorInfo( data )
	table.insert( _errorInfos, data )
end

local _require = require
function _createEmptyModule( path, fullpath )
	local m = {
		_NAME   = path,
		_PATH   = path,
		_SOURCE = fullpath,
		__REQUIRES    = {},
		__REQUIREDBY  = {}
	}
	m._M = m
	local requireInModule = function( path, ... )
		local loaded, errType, errMsg, tracebackMsg = _requireGameModule( path )
		if loaded then 
			m.__REQUIRES[ path ] = true
			loaded.__REQUIREDBY[ m._PATH ] = true
			return loaded
		end
		if errType ~= 'notfound' then
			-- print( errMsg )
			-- if tracebackMsg then print( tracebackMsg ) end
			error( 'error loading game module', 2 )
		end
		return _require( path, ... )
	end

	local importInModule = function( path, ... )
		local result = requireInModule( path, ... )
		if result then
			for k, v in pairs( result ) do
				if type(k) == 'string' and not rawget( m, k ) and not k:startwith('_') then
					m[ k ] = v
				end
			end
		end
		return result
	end

	m.require = requireInModule
	m.import  = importInModule
	return setmetatable( m, GameModuleMT )
end

--------------------------------------------------------------------
function _requireGameModule( path )
	local m = GameModules[ path ]
	if m then return m end
	return _loadGameModule( path )	
end

--------------------------------------------------------------------

function _loadGameModule( path )
	local fullpath, originPath = searchFile( path )
	if not fullpath then
		return nil, 'notfound'
	end
	_stat( 'loading module', path, fullpath )
	
	local source = readFile( fullpath )
	local chunk, compileErr = loadstring( source, '@'..originPath )
	if not chunk then
		pushErrorInfo{
			path = path,
			fullpath = fullpath,
			errtype =	'compile',
			msg     = compileErr
		}
		print( '[ERROR]fail to compile', compileErr ) 
		return nil, 'failtocompile', compileErr
	end
	local m = _createEmptyModule( path, fullpath )
	setfenv( chunk, m )

	local errMsg, tracebackMsg
	local function _onError( msg )
		errMsg = msg
		tracebackMsg = debug.traceback(2)
	end

	local ok = xpcall( chunk, _onError )
	if ok then
		registerGameModule( path, m )
		for i, func in ipairs( callbackModuleLoad ) do
			func( path, m )
		end
		return m
	else
		pushErrorInfo{
			path      = path,
			fullpath  = fullpath,
			errtype   =	'load',
			msg       = errMsg,
			traceback = tracebackMsg
		}
		print( 'failtoload ', path )
		print( errMsg ) 
		
		return nil, 'failtoload', errMsg, tracebackMsg
	end
end

--------------------------------------------------------------------
function loadGameModule( path, flushError )
	local loaded, errType, errMsg, tracebackMsg = _requireGameModule( path )
	
	if loaded then return loaded, {} end

	if flushError then
		return false, flushErrorInfo()
	else
		return false, _errorInfos
	end

end

--------------------------------------------------------------------
function releaseGameModule( path, releasedModules )
	releasedModules = releasedModules or {}
	_stat( 'release game module', path )
	local oldModule = GameModules[ path ]
	if not oldModule then
		_warn( 'can not release module', path )
		return nil
	end
	releasedModules[ path ] = true
	for i, func in ipairs( callbackModuleRelease ) do
		func( path, oldModule )
	end
	GameModules[ path ] = nil
	for requiredBy in pairs( oldModule.__REQUIREDBY ) do
		releaseGameModule( requiredBy, releasedModules )
	end
	return oldModule
end

--------------------------------------------------------------------
function getGameModule( path )
	return GameModules[ path ]
end

---------------------------------------------------------------------
function updateGameModule( path )
	if hasGameModule( path ) then
		return reloadGameModule( path )
	else
		return loadGameModule( path )
	end
end

--------------------------------------------------------------------
function reloadGameModule( path )
	flushErrorInfo()
	--release
	local releasedModules = {}
	releaseGameModule( path, releasedModules )
	--reload
	for path1 in pairs( releasedModules ) do
		loadGameModule( path1 )
	end
	local m = findGameModule( path )
	return m, flushErrorInfo()
end

---------------------------------------------------------------------
function unloadGameModule( path )
	flushErrorInfo()
	local released = {}
	releaseGameModule( path, released )
	for path1 in pairs( released ) do
		if path1 ~= path then
			loadGameModule( path1 )
		end
	end
	return flushErrorInfo()
end

--------------------------------------------------------------------
function compilePlainLua( inputFile, outputFile )
	local f = loadfile( inputFile )
	if f then
		local str = string.dump( f )
		local fp = io.open( outputFile, 'w' )
		if fp then
			fp:write( str )
			fp:close()
			return true
		end
	end
	return false
end

--------------------------------------------------------------------
function getErrorInfo()
	if #_errorInfos > 0 then
		return _errorInfos
	else
		return nil
	end
end
