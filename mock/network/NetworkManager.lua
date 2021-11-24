module 'mock'

--------------------------------------------------------------------
CLASS: NetworkManager ( GlobalManager )
	:MODEL{}

function NetworkManager:__init()
	self.RPCRegistry = {}
end

-- local function collectRPCEntry( clas, collected )
-- 	if clas.__rpcs then
-- 		for id, args in pairs( clas.__rpcs ) do
-- 			local id = clas
-- 			table.insert()
-- 		end
-- 	end
-- end

function NetworkManager:initRPC()
	local RPCEntries = {}
	collectRPCEntry( NetworkRPC, RPCEntries )

end

--------------------------------------------------------------------
NetworkManager()
