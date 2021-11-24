module 'mock'

--------------------------------------------------------------------
CLASS: CloudSaveModule ()

function CloudSaveModule:__init()
	self.name = false
end

--------------------------------------------------------------------
CLASS: CloudSaveManager ( GlobalManager )

function CloudSaveManager:__init()
	self.modules = {}
end

function CloudSaveManager:registerModule( name, m )
	self.modules[ name ] = m
end

function CloudSaveManager:push()
end

function CloudSaveManager:pull()
end

CloudSaveManager()