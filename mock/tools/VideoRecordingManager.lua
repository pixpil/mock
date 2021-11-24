module 'mock'

local EnumRecordingFormat = _ENUM_V{
	'h264',
	'webm',
	'jpg',
}

--------------------------------------------------------------------
local defaultVideoRecordingOption = {
		record_fps = 8,
		record_jpg_quality = 100,
		downsample = 8,
		video_bitrate = 20000,
		video_format = 'h264',
}

--------------------------------------------------------------------
local VideoRecordingOptions ={
	['VeryLow'] = {
		record_fps = 10,
		record_jpg_quality = 80,
		downsample = 4,
		video_bitrate = 20000,
		video_format = 'h264',
	},

	['Normal'] = {
		record_fps = 30,
		record_jpg_quality = 80,
		downsample = 1,
		video_format = 'h264',
	},

	['High'] = {
		record_fps = 60,
		record_jpg_quality = 95,
		downsample = 1,
		video_format = 'jpg',
	},

}


--------------------------------------------------------------------
CLASS: VideoRecordingManager ( GlobalManager )
	:MODEL{}

function VideoRecordingManager:onInit( game )
	if not game.graphicsInitialized then return false end
	if not getG( 'MOAIOpenGLRecorder' ) then return false end
	self.recording = false
	self.currentOutputFile = false
	self.startRecordingTime = 0
	--TODO: read option from config file
	local option = table.simplecopy( VideoRecordingOptions[ 'High' ] )
	self:initRecorder( option )

end

local function _videoFormatFromName( name )
	if     name == 'h264' then return MOAIOpenGLRecorder.VF_H264
	elseif name == 'webm' then return MOAIOpenGLRecorder.VF_WEBM
	elseif name == 'jpg'  then return MOAIOpenGLRecorder.VF_MJPEG
	else return error( 'unkown format' )
	end
end

function VideoRecordingManager:initRecorder( option )
	local recorderOption = {}
	recorderOption.record_fps         = option.record_fps
	recorderOption.record_jpg_quality = option.record_jpg_quality
	recorderOption.downsample         = option.downsample
	recorderOption.video_bitrate      = option.video_bitrate
	recorderOption.video_format       = _videoFormatFromName( option.video_format )
	local w, h = game:getDeviceResolution()
	recorderOption.width = w
	recorderOption.height = h
	MOAIOpenGLRecorder.init( recorderOption )
end

function VideoRecordingManager:isRecording()
	return self.recording
end

function VideoRecordingManager:getElapsedTime()
	if not self:isRecording() then return 0 end 
	return os.clock() - self.startRecordingTime
end

function VideoRecordingManager:startRecording( outputFile )
	if self.recording then return end
	if type( outputFile ) ~= 'string' then
		return _error( 'output file name expected' )
	end
	self.currentOutputFile = outputFile
	self.startRecordingTime = os.clock()
	self.recording = true
	if MOAIOpenGLRecorder.startRecording( outputFile ) then
		_log( 'video recording started:', outputFile )
	end
end

function VideoRecordingManager:stopRecording( delay )
	if not self.recording then
		return _warn( 'not recording video...' )
	end
	if delay then
		local coro = MOAICoroutine.new()
		coro:run( function()
			local e = 0
			while e < delay do
				e = coroutine.yield()
			end
			self:_stopNow()
		end)
	else
		self:_stopNow()
	end
end

function VideoRecordingManager:_stopNow()
	if not self.recording then return end
	self.stopRecordingTime = os.clock()
	MOAIOpenGLRecorder.stopRecording()
	_log( 'video recording stopped', self.currentOutputFile )
	self.recording = false
end


local _videoRecordingManager = VideoRecordingManager()
function getVideoRecordingManager()
	return _videoRecordingManager
end

function startRecordingVideo( output )
	return _videoRecordingManager:startRecording( output )
end

function stopRecordingVideo()
	return _videoRecordingManager:stopRecording()
end

function isRecordingVideo()
	return _videoRecordingManager:isRecording()
end