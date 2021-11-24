module 'mock'

--------------------------------------------------------------------
CLASS: EffectResourceProvider ()
	:MODEL{}

function EffectResourceProvider:createParticleSystem( node )
	return markRenderNode( MOAIParticleSystem.new() )
	-- return MOAIParticleSystem.new()
end

--------------------------------------------------------------------
CLASS: EffectManager ( GlobalManager )
	:MODEL{}

function EffectManager:__init()
	self.defaultProvider = EffectResourceProvider()
	self.provider = false
end

function EffectManager:setResourceProvider( provider )
	self.provider = provider
end

function EffectManager:createParticleSystem( effectNode )
	local provider = self.provider	
	local res
	res = provider and provider:createParticleSystem( effectNode )
	if res then
		return res
	else
		return self.defaultProvider:createParticleSystem( effectNode )
	end
end

--------------------------------------------------------------------
local _EffectManager = EffectManager()
function getEffectManager()
	return _EffectManager
end
