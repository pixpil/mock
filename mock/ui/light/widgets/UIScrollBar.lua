module 'mock'

--------------------------------------------------------------------
CLASS: UIScrollBar ( UISlider )
	:MODEL{
		Field 'pageStep';
}

function UIScrollBar:onUpdateVisual( style )
	UIScrollBar.__super.onUpdateVisual( self, style )
	local w, h = self:getSize()

	local handleSize = style:getNumber( 'handle_size', 30 )
	
	local orientation = self.orientation
	if orientation == 'h' then
		local handlePageSize = math.abs( self:getPageStep()/self:getRangeDiff() ) * w
		self.handle:setSize( handlePageSize, handleSize )
		self.handle:setPiv( 0, -handleSize/2 )

	else
		local handlePageSize = math.abs( self:getPageStep()/self:getRangeDiff() ) * h
		self.handle:setSize( handleSize, handlePageSize )
		self.handle:setPiv( handleSize/2, 0 )
		
	end
	self:_syncPos()
end


--------------------------------------------------------------------
CLASS: UIHScrollBar ( UIScrollBar )
	:MODEL{}

function UIHScrollBar:__init()
	self.orientation = 'h'
end
--------------------------------------------------------------------
CLASS: UIVScrollBar ( UIScrollBar )
	:MODEL{}

function UIVScrollBar:__init()
	self.orientation = 'v'
end

registerEntity( 'UIHScrollBar', UIHScrollBar )
registerEntity( 'UIVScrollBar', UIVScrollBar )

