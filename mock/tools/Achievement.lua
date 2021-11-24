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

module 'mock'

registerGlobalSignals{
	'achievement.unlock',	
	'achievement.progress',	
	'achievement.report',
}


local _AchievementClassRegistry = {}

local _achievementManager
--------------------------------------------------------------------
CLASS: Achievement ()
	:MODEL{}

function Achievement.register( clas, name )
	if _AchievementClassRegistry[ name ] then
		_error( 'duplicatd achievemnt clas', name )
		return
	end
	_AchievementClassRegistry[ name ] = clas
end

function Achievement:__init()
	self.progress = 0
	self.progressMax = 1
	self.progressNotify = false
	self.progressedGUIDs = {}
	self.unlocked = false
	self.hidden = false
	self.id = false
	self.name = ''
	self.desc = ''
	self.checking = false
	self.timestamp = 0
	self.order = 0
	self.icon = false
end

function Achievement:init( id, option )
	self.id = id
	option = option or {}
	self.name = option.name
	self.desc = option.description
	self.hidden = option.hidden
	self.order = option.order
	self.icon = option.icon or false
	self:onInit( option )
end

function Achievement:getId()
	return self.id
end

function Achievement:getName()
	return self.name
end

function Achievement:getIcon()
	return self.icon
end

function Achievement:getDescription()
	return self.desc
end

function Achievement:isHidden()
	return self.hidden
end

function Achievement:isUnlocked()
	return self.unlocked
end

function Achievement:getProgressMode()
	return false
end

function Achievement:getProgress()
	return self.progress, self.progressMax
end

function Achievement:getProgressRate()
	if self.progressMax > 0 then
		return self.progress / self.progressMax
	end
	return 0
end

function Achievement:startChecking()
	_log( 'start checking achievemennt:', self )
	self.checking = true
	self:onStartChecking()
end

function Achievement:stopChecking()
	_log( 'stop checking achievemennt:', self )
	self.checking = false
	self:onStopChecking()
end

function Achievement:onInit( option )
end

function Achievement:onStartChecking()
end

function Achievement:onStopChecking()
end

function Achievement:unlock( forced )
	if self.unlocked and (not forced) then return end
	self.unlocked = true
	_achievementManager:notifyAchievemntUnlock( self )
	_achievementManager:saveState()
	_achievementManager:onSavedataCommit()
end

function Achievement:setProgress( current )
	if self.unlocked then return end
	self.progress = current
	if self:checkProgressNotify() then
		_achievementManager:notifyAchievemntProgress( self )
	end
	if self.progress >= self.progressMax then
		self.progressedGUIDs = {}
		self:unlock()
	else
		_achievementManager:saveState()
	end
end

function Achievement:checkProgressNotify()
	return true
end

function Achievement:hasGUID( guid )
	return table.hasvalue( self.progressedGUIDs, guid )
end

function Achievement:addProgressWithId( guid )
	if not table.hasvalue( self.progressedGUIDs, guid ) then
		table.insert( self.progressedGUIDs, guid )
		self:setProgress( self.progress + 1 )
	end
end

function Achievement:addProgress()
	self:setProgress( self.progress + 1 )
end

function Achievement:__tostring()
	local name = string.format( '%s( %s %s )', self:__repr(), self.id, self.unlocked and '*unlocked' or '' )
	if self:isHidden() then
		name = '(H)'..name
	end
	return name
end

function Achievement:saveState()
	return {
		id = self.id,
		unlocked = self.unlocked,
		progress = self.progress,
		progressMax = self.progressMax,
		progressNotify = self.progressNotify,
		progressedGUIDs = self.progressedGUIDs,
		timestamp = self.timestamp
	}
end

function Achievement:loadState( data )
	assert( self.id == data.id )
	self.unlocked = data.unlocked
	self.progress = data.progress
	self.progressMax = data.progressMax
	self.progressNotify = data.progressNotify
	self.progressedGUIDs = data.progressedGUIDs
	self.timestamp = data.timestamp
end

--------------------------------------------------------------------
CLASS: AchievementService ()

function AchievementService:__init()
	self.stateSyncReady = false
end

-- function AchievementService:requestStateSync()
-- 	self.stateSyncReady = false

-- 	self.threadRequestState = MOAICoroutine.new()
-- 	self.threadRequestState:run( function()
-- 		if self:onRequestStateSync() then
-- 			self.stateSyncReady = true
-- 			_achievementManager:notifyStateSync( true )
-- 		else
-- 			_warn( 'failed to sync achievement state' )
-- 			_achievementManager:notifyStateSync( false )
-- 		end
-- 	end )

-- end
function AchievementService:isStateReady()
	return true
end

function AchievementService:onStart()
end

function AchievementService:onRequestAcheviementState( ach )
end

function AchievementService:onAchievementProgress( ach )
end

function AchievementService:onAchievementUnlock( ach )
end

function AchievementService:onReset()
end

-- function AchievementService:onRequestStateSync()
-- end


--------------------------------------------------------------------
CLASS: AchievementManager ( GlobalManager )
	:MODEL{}


function AchievementManager:__init()
	self.service = false
	self.keepLocalState = true
	self.achievements = {}
	self.nextOrder = 0
end

function AchievementManager:setService( service )
	self.service = service
	if service then
		service:onStart()
	end
end

function AchievementManager:postStart()
	local coro = MOAICoroutine.new()
	coro:run( function() return self:actionSyncAndStartChecking() end )
	self.threadSync = coro
	connectGlobalSignalMethod( 'game.commit_savedata', self, 'onSavedataCommit' )
end

function AchievementManager:actionSyncAndStartChecking()
	--sync from service
	local service = self.service
	if service then
		while not service:isStateReady() do
			coroutine.yield()
			coroutine.yield()
		end
		_log( 'sync achievemennt state from service' )
		for id, ach in pairs( self.achievements ) do
			local remoteUnlocked, percent, unlockTime = service:onRequestAcheviementState( ach )
			local localUnlocked = ach:isUnlocked()
			if remoteUnlocked == nil then --invalid achievement?
				--nothing
			elseif remoteUnlocked ~= localUnlocked then --need sync
				local canSyncPush = true
				local canSyncPull = true
				
				if localUnlocked and canSyncPush then
					service:onAchievementUnlock( ach )
					_log( 'achievement unlocked local', ach )

				elseif remoteUnlocked and canSyncPull then
					ach.unlocked = true
					_log( 'achievement unlocked remote', ach )
				end

			end
		end
	end

	--start checking
	for id, ach in pairs( self.achievements ) do
		if not ach:isUnlocked() then
			ach:startChecking()
		end
	end

end

function AchievementManager:saveStateToData()
	local output = {}
	local achDatas = {}
	for id, ach in pairs( self.achievements ) do
		achDatas[ id ] = ach:saveState()
	end
	output[ 'timestamp' ] = os.time()
	output[ 'states' ] = achDatas
	return output
end

function AchievementManager:loadStateFromData( data )
	if not data then return end
	local timestamp = data[ 'timestamp' ]
	local achDatas = data[ 'states' ]
	if not achDatas then return end
	for id, achData in pairs( achDatas ) do
		local ach = self:getAchievement( id )
		if ach then
			ach:loadState( achData )
		end
	end
end

function AchievementManager:getAchievement( id )
	return self.achievements[ id ]
end

function AchievementManager:getAchievementList()
	local list = table.values( self.achievements )
	table.sort( list, function( a, b ) return a.order < b.order end )
	return list
end

function AchievementManager:addAchievement( id, options )
	if self.achievements[ id ] then
		_error( 'duplicated achievement', id )
		return
	end
	options = options or {}
	local clas = options[ 'class' ]	
	local achievement
	if clas then		
		local achClass = _AchievementClassRegistry[ clas ]
		assert( achClass, 'no achievement class found:' .. tostring( clas ) )
		achievement = achClass()
	else
		achievement = Achievement()
	end
	
	local order = options.order or self.nextOrder
	self.nextOrder = order + 1
	options.order = order
	achievement:init( id, options )
	self.achievements[ id ] = achievement
	_log( 'register achievement:', achievement )
	return achievement
end

function AchievementManager:notifyAchievemntProgress( ach )
	_log( 'achievement progress', ach )
	ach.timestamp = os.time()
	emitGlobalSignal( 'achievement.progress', ach, ach:getProgress() )
	if self.service then
		self.service:onAchievementProgress( ach )
	end
end

function AchievementManager:notifyAchievemntUnlock( ach )
	_log( 'achievement unlocked', ach )
	ach.timestamp = os.time()
	emitGlobalSignal( 'achievement.unlock', ach )
	if self.service then
		self.service:onAchievementUnlock( ach )
	end
	ach:stopChecking()
end

function AchievementManager:notifyStateSync( succ  )
	if succ then
		self:startCheckingAchievements()
	else
		if self.keepLocalState then
			self:startCheckingAchievements()
		end
	end
end

function AchievementManager:saveStateToFile( path )
	-- local path = self.localStateFile
	local data = self:saveStateToData()
	game:saveSafeSettingData( data, path, 'Achievement' )
end

function AchievementManager:loadStateFromFile( path )
	local data = game:tryLoadSafeSettingData( path, 'Achievement' )
	if data then
		self:loadStateFromData( data )
	end
end

function AchievementManager:saveState()
	self.cachedData = self:saveStateToData()
	self.isDirty = true
	-- local dataPath = 'SaveData/ach.save'
	-- self:saveStateToFile( dataPath )
end

function AchievementManager:loadState()
	-- local dataPath = 'SaveData/ach.save'
	-- self:loadStateFromFile( dataPath )
	if self.cachedData then
		self:loadStateFromData( self.cachedData )
	else
		local dataPath = 'SaveData/ach.save'
		self:loadStateFromFile( dataPath )
	end
	self.isDirty = false
end

function AchievementManager:onSavedataCommit()
	if not self.isDirty then return end

	local dataPath = 'SaveData/ach.save'
	self:saveStateToFile( dataPath )
	self.isDirty = false
end

--------------------------------------------------------------------
_achievementManager = AchievementManager()

function getAchievementManager()
	return _achievementManager
end