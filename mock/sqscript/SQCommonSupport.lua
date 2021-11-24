module 'mock'

local globalEnv = getGlobalSQEvalEnv()

globalEnv.isDeveloperMode = function()
	return game:isDeveloperMode()
end

globalEnv.getActiveLocale = function()
	return getActiveLocale()
end

globalEnv.getUserObject = function( key )
	return game:getUserObject( key )
end

globalEnv.getCurrentLoadingScene = function()
	return getCurrentLoadingScene()
end

globalEnv.getCurrentLoadingSceneSession = function()
	return getCurrentLoadingSceneSession()
end

globalEnv.getCurrentLoadingSceneSessionName = function()
	return getCurrentLoadingSceneSessionName()
end

