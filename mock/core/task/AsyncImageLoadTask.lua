module 'mock'
CLASS: AsyncImageLoadTask ( Task )
	:MODEL{}

function AsyncImageLoadTask:__init( path, transform )
	self.imagePath = path
	self.imageTransform = transform
end

local n = 0
function AsyncImageLoadTask:onExec( queue )
	if not self.imagePath then
		return self:fail()
	end
	
	local img = MOAIImage.new()
	self.img = img
	self.callback = function()
		if img:getSize() <= 0 then
			return self:fail()				
		else
			return self:complete( img )
		end
 	end
	img:loadAsync( self.imagePath, self:requestThreadTaskQueue(), self.callback, self.imageTransform )

end

function AsyncImageLoadTask:toString()
	return '<imageLoadTask>' .. self.imagePath
end
