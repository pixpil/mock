module 'mock'
--------------------------------------------------------------------
CLASS: MovieClipPlane ( GraphicsPropComponent )
	:MODEL{
		Field 'texture' :no_edit();
		Field 'movie' :asset( 'movie' ) :getset( 'Movie' );
		Field 'autoplay' :boolean();
		Field 'preload' :boolean();
		Field 'autoRestart' :boolean();
		'----';
		Field 'size'    :type('vec2') :getset('Size');
}

registerComponent( 'MovieClipPlane', MovieClipPlane )

function MovieClipPlane:__init( )
	self.moviePath = false
	self.clip = false
	self.autoplay = false
	self.preload = false
	self.autoRestart = false
	self.quad = MOAISpriteDeck2D.new()
	self.quad:setUVRect( 0,0,1,1 )
	self.quad:setRect( 0,0,0,0 )
	self.prop:setDeck( self.quad )
	self.w = 100
	self.h = 100
end

function MovieClipPlane:onStart( )
	if not self.moviePath then return end
	if self.autoplay then
		self:playClip( self.moviePath )
	elseif self.preload then
		self:loadClip( self.moviePath )
	end
end

function MovieClipPlane:loadClip( clipPath, fitSize )
	local movieSrc = loadAsset( clipPath )
	if not movieSrc then return false end
	self:stop()
	local clip = movieSrc:buildClipInstance( self )
	if not clip then return false end
	local tex = clip:getTexture()
	self.clip = clip
	self.quad:setTexture( tex )
	self.duration = clip:getDuration()
	clip:setAutoRestart( self.autoRestart )
	local w, h = clip:getSize()
	local tw, th = tex:getSize()
	local u = w/tw
	local v = h/th
	self.quad:setUVRect( 0,v,u,0 )
	if fitSize then
		self:fitSize()
	end
	return true
end

function MovieClipPlane:resume()
	if self.clip then
		self.clip:start()
	end
end

function MovieClipPlane:playClip( clipPath, fitSize )
	if not self:loadClip( clipPath, fitSize ) then return false end
	self:resume()
	return true
end

function MovieClipPlane:setMovie( moviePath )
	self.moviePath = moviePath
end

function MovieClipPlane:getMovie()
	return self.moviePath
end

function MovieClipPlane:fitSize()
	if not self.clip then return end
	local w, h = self.clip:getSize()
	self:setSize( w, h )
end

function MovieClipPlane:stop()
	-- body
	if self.clip then
		self.clip:stop()
	end
end

function MovieClipPlane:seek( t )
	if self.clip then
		return self.clip:seek( t )
	end
end

function MovieClipPlane:seekToFrame( f )
	if self.clip then
		return self.clip:seekToFrame( f )
	end
end

function MovieClipPlane:getSize()
	return self.w, self.h
end

function MovieClipPlane:setSize( w, h )
	self.w = w
	self.h = h
	self.quad:setRect( -w/2,-h/2,w/2,h/2 )
	self.prop:forceUpdate()
end

function MovieClipPlane:isPlaying()
	return self.clip:isBusy()
end

function MovieClipPlane:getTimePosition()
	return self.clip and self.clip:getTimePosition() or 0
end
