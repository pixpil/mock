module 'mock'

--------------------------------------------------------------------
CLASS: UIResourceProvider ()
	:MODEL{}

local providerSeq = 0
function UIResourceProvider:__init()
	self.priority = 0
	self.__seq = providerSeq
	providerSeq = providerSeq+1
end

function UIResourceProvider:request( id )
end

--------------------------------------------------------------------
CLASS: UIResourceManager ()

function UIResourceManager:__init()
	self.resourceProviders = {}
	self._global = false
end

function UIResourceManager:registerProvider( resType, provider, priority )
	local list = self.resourceProviders[ resType ]
	if not list then
		list = {}
		self.resourceProviders[ resType ] = list
	end
	provider.priority = priority or 0
	table.insert( list, provider )
	table.sort( list, function( a, b )
		local pa, pb = a.priority, b.priority
		if pa == pb then
			return a.__seq > b.__seq
		end
		return pa > pb
	end )
end

function UIResourceManager:request( resType, id )
	local list = self.resourceProviders[ resType ]
	if list then
		for i, provider in ipairs( list ) do
			local res = provider:request( id )
			if res then return res end
		end
	end
	--try global manager
	if not self._global	then
		return getUIManager():requestResource( resType, id )
	end
end

