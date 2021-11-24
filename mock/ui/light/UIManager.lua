module 'mock'



--------------------------------------------------------------------
CLASS: UIManager ( mock.GlobalManager )
	:MODEL{}


function UIManager:__init()
	self.resManager = UIResourceManager()
	self.resManager._global = true
end

function UIManager:registerResourceProvider( resType, provider, priority )
	return self.resManager:registerProvider( resType, provider, priority )
end

function UIManager:requestResource( resType, id )
	return self.resManager:request( resType, id )
end


--------------------------------------------------------------------
local _UIManager = UIManager()
function getUIManager()
	return _UIManager
end