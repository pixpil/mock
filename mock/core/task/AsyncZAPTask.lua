module 'mock'

--------------------------------------------------------------------
CLASS:  AsyncZAPPackTask ( Task )
	:MODEL{}

function AsyncZAPPackTask:__init( sourcePath, outputPath, compression )
	self.sourcePath = sourcePath
	self.outputPath = outputPath
	self.compression = compression
end

function AsyncZAPPackTask:onExec( queue )
	-- _log( 'ZAPPack', 	self.sourcePath,	self.outputPath,	self.compression	)

	MOCKZAPHelper.packAsync(
		self.sourcePath,
		self.outputPath,
		self.compression,
		self:requestThreadTaskQueue(),
		function( result )
			-- _log( 'task done', self, result )
			if result then
				return self:complete()
			else
				return self:fail()
			end
		end
	)
	return 'running'
end

