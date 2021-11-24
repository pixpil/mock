--[[
* MOCK framework for Moai

* Copyright (C) 2012 Tommo Zhou(tommo.zhou@gmail.com).  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
--------------------------------------------------------------------
local DebugHelper = mock.DebugHelper
local _mockLog = MOCKHelper.log
_codemark = function(s,...) return DebugHelper:setCodeMark(s,...) end
--------------------------------------------------------------------

local startTimePoints={}
function _logtime(name)
	local t1=os._clock()
	startTimePoints[name]=t1
end

function _logtime_end(name)
	local t1=os._clock()
	local t=startTimePoints[name]
	if t then
		printf('time for "%s": %d',name, (t1-t)*1000)
		startTimePoints[name]=false
	end
end

--------------------------------------------------------------------
local nameToLogLevel = {
	['status']  =  MOAILogMgr.LOG_STATUS,
	['warning'] =  MOAILogMgr.LOG_WARNING,
	['error']   =  MOAILogMgr.LOG_ERROR,
	['fatal']   =  MOAILogMgr.LOG_ERROR,
	['none']    =  MOAILogMgr.LOG_NONE,
}

local error = error
local _logLevel = MOAILogMgr.LOG_WARNING
local _logFile  = false
local _logFileHandle = false

local _raiseOnError = false
local _raiseOnWarn = false

function setLogLevel( level, moaiLogLevel )
	if type(level) == 'string' then
		level = nameToLogLevel[level] or MOAILogMgr.LOG_STATUS
	end
	moaiLogLevel = moaiLogLevel or level
	if type(moaiLogLevel) == 'string' then
		moaiLogLevel = nameToLogLevel[moaiLogLevel] or MOAILogMgr.LOG_STATUS
	end
	MOAILogMgr.setLogLevel( moaiLogLevel )
	_logLevel = level
end

function getLogLevel()
	return table.index( nameToLogLevel, _logLevel ) or 'none'
end

function setRaiseLevel( levelName )
	if levelName == 'fatal' then
		_raiseOnError = false
		_raiseOnWarn = false
	elseif levelName == 'error' then
		_raiseOnError = true
		_raiseOnWarn = false
	elseif levelName == 'warning' then
		_raiseOnError = true
		_raiseOnWarn = true
	else
		--do nothing...
	end
end

function checkLogLevel( levelName )
	local level = nameToLogLevel[ levelName ] or MOAILogMgr.LOG_STATUS
	return _logLevel >= level
end

function openLogFile( path, clear )
	if _logFile then
		MOAILogMgr.closeFile()
		_logFile = false
	end
	
	print( 'open log file:', path )
	_logFile = path
	MOAILogMgr.openFile( path )
	_mockLog( 'MISC', '--------------------------------------------------------------------' )
	_mockLog( 'MISC', 'Logging started:\t' .. os.date( "%Y-%m-%d %H:%M:%S" ) )
	_mockLog( 'MISC', '--------------------------------------------------------------------' )
	-- _logFileHandle = io.open( path, clear and 'w' or 'a' )
	-- _logFileHandle:setvbuf( 'line' )
	-- _logFileHandle:write( '\n' )
	-- _logFileHandle:write( '--------------------------------------------------------------------\n' )
	-- _logFileHandle:write( 'Logging started:\t' .. os.date( "%Y-%m-%d %H:%M:%S" ) .. '\n' )
	-- _logFileHandle:write( '--------------------------------------------------------------------\n' )

end

function closeLogFile()
	if _logFile then
		print( 'close log file:', _logFile )
		MOAILogMgr.closeFile()
	end

	_logFile = false
	-- if _logFileHandle then
	-- 	_logFileHandle:close()
	-- 	_logFileHandle = false
	-- end

end

function getLogFile()
	return _logFile
end


--------------------------------------------------------------------
-- local _writeLog = io.write
-- local _writeLog = log.info

local open = io.open
local logFP = false
local logListeners = {}
local clock = os.clock
local format = string.format

local function _writeLog( token, msg )
	local prefix = format( '%s : %.3f', token, clock() )
	-- io.write( outputLine )
	-- io.write( '\n' )
	-- if _logFileHandle then
	-- 	_logFileHandle:write( outputLine )
	-- 	_logFileHandle:write( '\n' )
	-- 	_logFileHandle:flush()
	-- end
	_mockLog( prefix, msg )

	if next( logListeners ) then
		local outputLine = format( '[%s]\t%s', prefix, msg )
		for listener in pairs( logListeners ) do
			listener( token, msg, outputLine  )
		end
	end
end


function addLogListener( func )
	logListeners[ func ] = true
end

function removeLogListener( func )
	logListeners[ func ] = nil
end

function _logWithToken( token, ... ) 
	local output = string.join( '\t', {...} ) or ''
	_writeLog( token or '', output )
end

function _log(...) 
	return _logWithToken( 'LOG  :mock', ... )
end

local function _nilFunc() end

function _logf( patt, ... )
	return _log( string.format( patt, ... ) )
end

function _stat( ... )
	if _logLevel <= MOAILogMgr.LOG_STATUS then
		return _logWithToken( 'STAT :mock', ... )
	end
end

function _statf( patt, ... )
	if _logLevel <= MOAILogMgr.LOG_STATUS then
		return _stat( string.format( patt, ... ) )
	end
end

function _info( ... )
	return _stat( ... )
end

function _error( ... )
	if _logLevel <= MOAILogMgr.LOG_ERROR then
		--print( debug.traceback( 2 ) )
		_logWithToken( 'ERROR:mock', ... )
		_logWithToken( 'ERROR:mock', singletraceback( 2 ) )
		_logWithToken( 'ERROR:mock', singletraceback( 3 ) )
	end
	if _raiseOnError then return error( '!!! execution stopped on ERROR !!!' ) end
end

function _errorf( patt, ... )
	if _logLevel <= MOAILogMgr.LOG_ERROR then
		return _error( string.format( patt, ... ) )
	end
end

function _fatal( ... )
	_error( ... )
	return error( '!!! execution stopped on FATAL !!!' )
end

function _fatalf( ... )
	_errorf( ... )
	return error( '!!! execution stopped on FATAL !!!' )
end

function _assert( cond, ... )
	if not cond then return _error( ... ) end
end

function _warn( ... )
	if _logLevel <= MOAILogMgr.LOG_WARNING then
		_logWithToken( 'WARN :mock', singletraceback() )
		_logWithToken( 'WARN :mock', ... )
	end
	if _raiseOnWarn then return error( '!!! execution stopped on WARNING !!!' ) end
end

function _warnf( patt, ... )
	if _logLevel <= MOAILogMgr.LOG_WARNING then
		return _warn( string.format( patt, ... ) )
	end
end

function _traceback( msg, ... )
	print( msg )
	print( debug.traceback(2) )
end

if getG( 'MOCK_DISABLE_LOG' ) then
	_writeLog  = _nilFunc
	_logf      = _nilFunc
	_stat      = _nilFunc
	_statf     = _nilFunc
	_info      = _nilFunc
	_error     = _nilFunc
	_errorf    = _nilFunc
	_fatal     = _nilFunc
	_fatalf    = _nilFunc
	_assert    = _nilFunc
	_warn      = _nilFunc
	_warnf     = _nilFunc
	_traceback = _nilFunc
end

--------------------------------------------------------------------
function reportHistogram()
	MOAILuaRuntime.reportHistogram( 'histogram' )
	local f = io.open( 'histogram', 'r' )
	print( f:read( '*a' ) )
	f:close()
end

setLogLevel( getG( 'MOCK_LOG_LEVEL', 'warning' ), getG( 'MOAI_LOG_LEVEL', false ) )
