module 'mock'


---------------------------------------------------------------------
local ProxyThreadConfig = effil.thread( function( id )
	MOCK_PROXY_MODE = true
	MOCK_PROXY_ID = id
	require 'mock.proxy'
	require 'mock.core.MsgPackHelper'

	print( 'hello from proxy!', MOCK_PROXY_ID  )
	local decoder = mock.MsgPackDecoder()
	decoder:open( 'game/test/mspritetest.lbin' )
	print( decoder:decode() )
	
end )


--------------------------------------------------------------------
local ProxyServiceRegistry = {}

--------------------------------------------------------------------
CLASS: ProxyService ()

local proxyId = 0
function ProxyService:__init()
	self._thread = false
	proxyId = proxyId + 1
	ProxyServiceRegistry[ proxyId ] = self
	self._id = proxyId
end

function ProxyService:start()
	self:_initEnv()
	self:onStart()
end

function ProxyService:_initEnv()
	assert( not self._proxy )
	local thr = ProxyThreadConfig( self._id )
	self:onStart()
end

function ProxyService:onStart()
end
