module 'mock'

CLASS: DrawScript ( GraphicsPropComponent )
	-- :MODEL{
	-- 	Field 'blend'  :enum( EnumBlendMode ) :getset('Blend');		
	-- }

function DrawScript:__init()
	local prop = self.prop
	local deck = MOAIDrawDeck.new()
	prop:setDeck( deck )	
	self.deck = deck
end

function DrawScript:onAttach( entity )	
	local drawOwner, onDraw
	if self.onDraw then 
		onDraw = self.onDraw
		drawOwner = self
	elseif entity.onDraw then
		onDraw = entity.onDraw
		drawOwner = entity
	end
	if onDraw then
		self.deck:setDrawCallback( 
			function(...) return onDraw( drawOwner, ... ) end
		)
	end

	local rectOwner, onGetRect
	if self.onGetRect then 
		onGetRect = self.onGetRect
		rectOwner = self

	elseif entity.onGetRect then
		onGetRect = entity.onGetRect
		rectOwner = entity

	end

	if onGetRect then
		self.deck:setBoundsCallback( 
			function(...) return onGetRect( rectOwner, ... ) end
		)
	end
		
	return entity:_attachProp( self.prop )
end

function DrawScript:setRect( x0, y0, x1, y1 )
	if not x0 then
		self.deck:setBounds( 10000, 10000, -10000, -10000 ) 
	else
		self.deck:setBounds(  x0, y0, x1, y1 )
	end
end

function DrawScript:onDetach( entity )
	entity:_detachProp( self.prop )
end
