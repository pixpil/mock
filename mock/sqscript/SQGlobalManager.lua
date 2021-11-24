module 'mock'

local _SQGlobalManger

function getSQGlobalManager()
	return _SQGlobalManger
end

function getSQDebugHelper()
	return _SQGlobalManger:getDebugHelper()
end

--------------------------------------------------------------------
CLASS: SQGlobalManager ( GlobalManager )
 	:MODEL{} 

function SQGlobalManager:__init()
	_SQGlobalManger = self
	self.debugHelper = SQDebugHelper()
end

function SQGlobalManager:postInit( game )
	self.debugHelper:init()
	self:startRecording()
	for _, provider in pairs( getSQContextProviders() ) do
		provider:init()
	end
end

function SQGlobalManager:startRecording()
	self.debugHelper:startRecording()
end

function SQGlobalManager:getDebugHelper()
	return self.debugHelper
end

function SQGlobalManager:onUpdate( game, dt )
	self.debugHelper:onUpdate( dt )
end


--------------------------------------------------------------------
SQGlobalManager()