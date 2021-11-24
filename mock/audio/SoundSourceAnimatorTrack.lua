module 'mock'
local min = math.min

--------------------------------------------------------------------
CLASS: SoundSourceAnimatorKey ( AnimatorEventKey )
	:MODEL{
		Field 'clip' :asset( getSupportedSoundAssetTypes() ) :set( 'setClip' );
		'----';
		Field 'fadeIn' :meta{ decimals = 2, step = 0.01 };
		Field 'fadeOut' :meta{ decimals = 2, step = 0.01 };
		'----';
		Field 'useRange'  :boolean();
		Field 'offset' :float() :meta{ decimals = 2, step = 0.01 };
		'----';
		Field 'resetLength' :action( 'resetLength' );
	}

function SoundSourceAnimatorKey:__init()
	self.clip   = ''
	self.offset = 0
	self.fadeIn = 0
	self.fadeOut = 0
end

function SoundSourceAnimatorKey:setClip( clip )
	self.clip = clip
end

function SoundSourceAnimatorKey:toString()
	local clip = self.clip
	if not clip then return '<nil>' end
	local evname =  stripdir( clip )
	if self.offset > 0 then
		return string.format( '%s > %s', evname, formatSecs( self.offset, false, true ) )
	else
		return evname
	end
end


function SoundSourceAnimatorKey:getRange()
	return unpack( self.range )
end

function SoundSourceAnimatorKey:setRange( mi, ma )
	self.range = { mi, ma }
end

function SoundSourceAnimatorKey:resetLength()
	if self.clip then
		local length = getAudioManager():getEventSetting( self.clip, 'length' )
		if length then
			self:setLength( length )
		end
	end
end

function SoundSourceAnimatorKey:convertPos( t )
	t = t - self.pos
	if self.offset > 0 then
		return t + self.offset
	else
		return t
	end
end

--------------------------------------------------------------------
CLASS: SoundSourceAnimatorTrack ( AnimatorEventTrack )
	:MODEL{
	}

function SoundSourceAnimatorTrack:getIcon()
	return 'track_audio'
end

function SoundSourceAnimatorTrack:toString()
	local pathText = self.targetPath:toString()
	return pathText..'<clips>'
end

function SoundSourceAnimatorTrack:isPreviewable()
	return true
end

function SoundSourceAnimatorTrack:createKey( pos, context )
	local key = SoundSourceAnimatorKey()
	key:setPos( pos )
	self:addKey( key )
	local target = context.target --SoundSource
	key.clip     = target:getDefaultEvent()
	return key
end

function SoundSourceAnimatorTrack:build( context )
	self.idCurve = self:buildIdCurve()
	context:updateLength( self:calcLength() )
end

function SoundSourceAnimatorTrack:onStateLoad( state )
	local rootEntity, scene = state:getTargetRoot()
	local soundSource = self.targetPath:get( rootEntity, scene )
	local currentInstance = false
	local endTime = 0
	local playContext = { soundSource, 0, currentInstance, endTime }
	state:addUpdateListenerTrack( self, playContext )
end

function SoundSourceAnimatorTrack:apply( state, playContext, t )
	if not state:isPlaying() then return end
	local soundSource, currentKeyId, currentInstance, endTime = unpack( playContext )
	local nextKeyId = self.idCurve:getValueAtTime( t )

	if currentKeyId == nextKeyId then
		if currentInstance then
			if t >= endTime then
				currentInstance:stop()
				playContext[ 3 ] = false
			else
				local key = self.keys[ currentKeyId ]
				local mgr = getAudioManager()
				local length = key.length
				local localT = t - key.pos
				local fin, fout = key.fadeIn, key.fadeOut
				if fin > 0 or fout > 0 then
					local v = 1
					if fin > 0 then
						v = min( 1, localT/fin )
					end
					if fout > 0 then
						v = v * min( 1, ( length - localT )/fout )
					end
					mgr:setEventInstanceVolume( currentInstance, v )
				end
			end
		end

	else
		if currentInstance then
			currentInstance:stop()
			currentInstance = false
		end

		if nextKeyId > 0 then
			local key = self.keys[ nextKeyId ]
			local event = key.clip
			local length = key.length
			if event then
				local mgr = getAudioManager()
				local endPos = key:getEnd()
				if t < endPos then
					if soundSource.is3D then
						currentInstance = soundSource:playEvent3D( event, soundSource.follow )
					else
						currentInstance = soundSource:playEvent2D( event )
					end
					if currentInstance then
						local pos = key:convertPos( t )
						if pos > 0 then
							mgr:setEventInstanceTime( currentInstance, pos )
						end
					end
					playContext[ 4 ] = endPos
				end
			end
		end
		playContext[ 2 ] = nextKeyId
		playContext[ 3 ] = currentInstance
	end

end

function SoundSourceAnimatorTrack:reset( state, playContext )
	-- playContext[2] = 0
	local currentInstance = playContext[ 3 ]
	if currentInstance then
		currentInstance:stop()
		playContext[ 3 ] = false
	end
	playContext[ 2 ] = -1
end

function SoundSourceAnimatorTrack:onPreviewStart( state, playContext )
	return self:onPreviewStop( state, playContext )
end

function SoundSourceAnimatorTrack:onPreviewStop( state, playContext )
	local soundSource, currentKeyId, currentInstance, endTime = unpack( playContext )
	if currentInstance then
		currentInstance:stop()
	end
	playContext[ 3 ] = false
	playContext[ 2 ] = 0
end


--------------------------------------------------------------------
registerCustomAnimatorTrackType( SoundSource, 'clips', SoundSourceAnimatorTrack )
