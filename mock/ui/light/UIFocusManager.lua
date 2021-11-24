module 'mock'

local _activeFocusManager = false

function getFocusedUIView()
	return _activeFocusManager and _activeFocusManager.view or false
end

--------------------------------------------------------------------
CLASS: UIFocusManager ()
	:MODEL{}

function UIFocusManager:__init( view )
	self.view = view
	self.focusedWidget = false
	self.focusMap = false
	self.active = false
	self.focusGroups = {}
end

function UIFocusManager:activate()
	if _activeFocusManager == self then return end
	if _activeFocusManager then
		_activeFocusManager:deactivate( false )
	end
	--TODO: set focus to 'default focusable widget?'
	_activeFocusManager = self
	if self.prevFocusedWidget then
		if self.prevFocusedWidget._parentView == self.view then
			self:setFocusedWidget( self.prevFocusedWidget )
		end
		self.prevFocusedWidget = false
	end
	self.active = true
	self.view.focus_in:emit()
end

function UIFocusManager:deactivate()
	if _activeFocusManager ~= self then return end
	_activeFocusManager = false
	self.prevFocusedWidget = self.focusedWidget
	self:setFocusedWidget( false )
	self.active = false
	self.view.focus_out:emit()
end

function UIFocusManager:isActive()
	return _activeFocusManager == self
end

local function canFocus( widget )
	local view = widget:getParentView()
	if not view then return false end

	if not widget:isFocusable() then return false end
	if not widget:isInteractive() then return false end

	local modal = view.modalWidget
	if modal then
		return modal:hasChild( widget )
	else
		return true
	end
end

local function findFocusable( widget )
	local focusable = widget:getFocusProxy()
	if focusable then	return findFocusable( focusable ) end
	widget:forceUpdate()
	if canFocus( widget ) then
		return widget
	end
	local focusable = widget:getDefaultFocusableChild()
	if focusable then
		return findFocusable( focusable )
	else
		return false
	end

end

function UIFocusManager:setFocusedWidget( widget, reason )
	local view = self.view

	if widget then
		widget = findFocusable( widget )
		if not widget then return end --no valid focusable
	end
	
	if widget then
		self:activate()
	end

	local previous = self.focusedWidget
	if previous == widget then return true end

	if previous then
		previous:setFeature( '_focused', false )
		view:postEvent( previous, UIEvent( UIEvent.FOCUS_OUT, 
			{ reason = reason, current = widget }
		) )
	end

	if widget then
		widget:setFeature( '_focused', true )
		view:postEvent( widget, UIEvent( UIEvent.FOCUS_IN, 
			{ reason = reason, previous = previous } 
		) )
	end

	self.focusedWidget = widget or false
	self.view.focus_widget_changed:emit( widget, previous )
	return true
end

function UIFocusManager:getFocusedWidget()
	return self.focusedWidget
end

function UIFocusManager:getNextFocus( widget, dir, wrap ) -- N/S/E/W
	--TODO
end

function UIFocusManager:getFocusGroup( name )
	return self.focusGroups[ name ]
end

function UIFocusManager:affirmFocusGroup( name )
	local g = self.focusGroups[ name ]
	if not g then
		g = {}
		self.focusGroups[ name ] = g
	end
	return g
end

function UIFocusManager:onWidgetDestroyed( widget )
	if self.focusedWidget == widget then
		self:setFocusedWidget( false, 'destroy' )
	end
	local groupName = widget.activeFocusGroup
	if groupName then
		local group = self:getFocusGroup( groupName )
		if group then
			group[ widget ] = nil
		end
	end
end

function UIFocusManager:registerFocusableWidget( widget, groupName )
	groupName = groupName or 'default'
	local groupName0 = widget.activeFocusGroup
	if groupName0 == groupName then
		return
	end
	local group0 = self:getFocusGroup( groupName0 )
	local group = self:affirmFocusGroup( groupName )
	if group0 then
		group0[ widget ] = nil
	end
	widget.activeFocusGroup = groupName
	group[ widget ] = true
end

function UIFocusManager:findFocusConnection( widget, dir )
	local groupName = widget.activeFocusGroup
	local group = groupName and self:getFocusGroup( groupName )
	if not group then return false end

	if dir == 'next' then
		return self:findNextFocusConnection( group, widget )

	elseif dir == 'prev' then
		return self:findPrevFocusConnection( group, widget )

	else
		return self:findDirectionalFocusConnection( group, widget, dir )

	end

end

function UIFocusManager:findNextFocusConnection( group, widget )
	local idx0 = widget.focusIndex
	if not idx0 then return false end --TODO: just use min index?
	local result, nearest
	for w in pairs( group ) do
		if w ~= widget and canFocus( w ) then
			local idx = w.focusIndex
			local diff = idx - idx0
			if diff < 0 then diff = 100000 + idx end --for wrapping
			if idx and ( ( not nearest ) or diff < nearest ) then
				result = w
				nearest = diff
			end
		end
	end
	return result
end


function UIFocusManager:findPrevFocusConnection( group, widget )
	local idx0 = widget.focusIndex
	if not idx0 then return false end --TODO: just use min index?
	local result, nearest
	for w in pairs( group ) do
		if w ~= widget and canFocus( w ) then
			local idx = w.focusIndex
			local diff = idx0 - idx
			if diff < 0 then diff = 100000 + idx end --for wrapping
			if idx and ( ( not nearest ) or diff < nearest ) then
				result = w
				nearest = diff
			end
		end
	end
	return result
end

local function distanceX( x0, y0, x1, y1, r )
	local dx, dy = x1 - x0, y1 - y0
	-- return dx*dx
	return dx*dx + dy*dy * ( r or 2 )
end

local function distanceY( x0, y0, x1, y1, r )
	local dx, dy = x1 - x0, y1 - y0
	-- return dy*dy
	return dx*dx * ( r or 2 ) + dy*dy
end

function UIFocusManager:findDirectionalFocusConnection( group, widget, dir )
	local minDistSameLine, resultSameLine
	local minDistOtherLine, resultOtherLine
	local l0, b0, r0, t0 = widget:getFocusRect()
	local x0, y0 = ( l0 + r0 ) /2, ( b0 + t0 ) /2
	if dir == 'n' then
		for w in pairs( group ) do
			if w ~= widget and canFocus( w ) then
				local l, b, r, t = w:getFocusRect()
				local x, y = ( l + r )/2, ( b + t )/2
				local pass = ( t > b0 and b > t0  )
				if pass then
					local sameLine = ( not ( r < l0 or l > r0 ) )
					if sameLine then
						local dist = distanceY( x0,y0, x,y )
						if ( ( not minDistSameLine ) or dist < minDistSameLine ) then
							resultSameLine = w
							minDistSameLine = dist
						end
					else
						local dist = distanceY( x0,y0, x,y, 10 )
						if ( ( not minDistOtherLine ) or dist < minDistOtherLine ) then
							resultOtherLine = w
							minDistOtherLine = dist
						end
					end
				end
			end
		end
	elseif dir == 's' then
		for w in pairs( group ) do
			if w ~= widget and w:isVisible() and w:isActive() then
				local l, b, r, t = w:getFocusRect()
				local x, y = ( l + r )/2, ( b + t )/2
				local pass = ( t < b0 and b < t0 )
				if pass then
					local sameLine = ( not ( r < l0 or l > r0 ) )
					if sameLine then
						local dist = distanceY( x0,y0, x,y )
						if ( ( not minDistSameLine ) or dist < minDistSameLine ) then
							resultSameLine = w
							minDistSameLine = dist
						end
					else
						local dist = distanceY( x0,y0, x,y, 10 )
						if ( ( not minDistOtherLine ) or dist < minDistOtherLine ) then
							resultOtherLine = w
							minDistOtherLine = dist
						end
					end
				end
			end
		end
	elseif dir == 'w' then
		for w in pairs( group ) do
			if w ~= widget and w:isVisible() and w:isActive() then
				local l, b, r, t = w:getFocusRect()
				local x, y = ( l + r )/2, ( b + t )/2
				local pass = ( l < r0 and r < l0 )
				if pass then
					local sameLine = ( not ( b > t0 or t < b0 ) )
					if sameLine then
						local dist = distanceX( x0,y0, x,y )
						if ( ( not minDistSameLine ) or dist < minDistSameLine ) then
							resultSameLine = w
							minDistSameLine = dist
						end
					else
						local dist = distanceX( x0,y0, x,y, 10 )
						if ( ( not minDistOtherLine ) or dist < minDistOtherLine ) then
							resultOtherLine = w
							minDistOtherLine = dist
						end
					end
				end
			end
		end
	elseif dir == 'e' then
		for w in pairs( group ) do
			if w ~= widget and w:isVisible() and w:isActive() then
				local l, b, r, t = w:getFocusRect()
				local x, y = ( l + r )/2, ( b + t )/2
				local pass = ( r > l0 and l > r0 )
				if pass then
					local sameLine = ( not ( b > t0 or t < b0 ) )
					if sameLine then
						local dist = distanceX( x0,y0, x,y )
						if ( ( not minDistSameLine ) or dist < minDistSameLine ) then
							resultSameLine = w
							minDistSameLine = dist
						end
					else
						local dist = distanceX( x0,y0, x,y, 10 )
						if ( ( not minDistOtherLine ) or dist < minDistOtherLine ) then
							resultOtherLine = w
							minDistOtherLine = dist
						end
					end
				end
			end
		end
	end

	return resultSameLine or resultOtherLine
	
end
