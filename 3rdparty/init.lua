-- pcall( function()
-- 	require 'socket'
-- end )
--------------------------------------------------------------------
local rootPath = _G[ 'MOCK_ROOT_PATH' ] or _G[ 'GII_PROJECT_SCRIPT_LIB_PATH' ] or '.'
local SCRIPT_EXT = rawget( _G, 'SCRIPT_EXT' ) or '.lua'
package.path = ''
	.. ( rootPath .. '/3rdparty/?' .. SCRIPT_EXT .. ';'  )
	.. ( rootPath .. '/3rdparty/?/init' .. SCRIPT_EXT .. ';'  )
	.. package.path

--------------------------------------------------------------------
require 'QuadTree'
require 'i18n'
require 'utf8'


chariot = require 'chariot'
-- htmllua = require 'htmllua'
url     = require 'url'
mri     = require 'MemoryReferenceInfo'
csv     = require 'csv'
memdump = require 'memdump'
serpent = require 'serpent'

