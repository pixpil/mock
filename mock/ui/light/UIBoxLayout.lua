module 'mock'

local insert = table.insert
local max = math.max

EnumBoxLayoutDirection = _ENUM_V{
	'vertical',
	'horizontal',
}

--------------------------------------------------------------------
CLASS: UIBoxLayout ( UILayout )
	:MODEL{
		Field 'direction' :enum( EnumBoxLayoutDirection ) :getset( 'Direction' );
		Field 'spacing' :getset( 'Spacing' );
	}

function UIBoxLayout:__init()
	self.direction = 'vertical'
	self.spacing = 5
end

function UIBoxLayout:setDirection( dir )
	self.direction = dir
end

function UIBoxLayout:getDirection()
	return self.direction
end

function UIBoxLayout:setSpacing( s )
	self.spacing = s
	self:invalidate()
end

function UIBoxLayout:getSpacing()
	return self.spacing
end

function UIBoxLayout:onUpdate( entries )
	local dir = self.direction
	if dir == 'vertical' then
		self:calcLayoutVertical( entries )
	elseif dir == 'horizontal' then
		self:calcLayoutHorizontal( entries )
	else
		error( 'unknown layout direction: ' .. tostring( dir ) )
	end
end

function UIBoxLayout:calcLayoutVertical( entries )
	local count = #entries
	if count == 0 then return end

	local spacing = self.spacing
	local marginL, marginT, marginR, marginB = self:calcMargin()

	local owner = self:getOwner()
	local innerWidth, innerHeight = self:getInnerSize()

	innerHeight = innerHeight - spacing * ( count - 1 )
	local minHeightTotal = 0
	local minWidthTotal = 0

	--update minSize
	for i, entry in ipairs( entries ) do
		entry:setFrameSize( innerWidth, false )
	end

	--width pass
	for i, entry in ipairs( entries ) do
		minWidthTotal = max( minWidthTotal, entry.minWidth )
		local policy = entry.policyH
		if policy == 'expand' then
			entry.targetWidth = max( innerWidth, entry.minWidth )
			entry.offsetX = 0
		else
			local targetWidth = entry.minWidth
			entry.targetWidth = targetWidth
		end
	end

	--height pass
	for i, entry in ipairs( entries ) do
		minHeightTotal = minHeightTotal + entry.minHeight
	end

	--use min height?
	if innerHeight <= minHeightTotal then 
		for i, entry in ipairs( entries ) do
			entry.targetHeight = entry.minHeight
		end
	else
		--grow?
		local propAvailHeight = innerHeight --height available for proportional widgets
		local proportional = {}
		local nonproportional = {}
		local fixed = {}
		local totalProportion = 0
		for i, entry in ipairs( entries ) do
			local policy = entry.policyV
			if policy == 'expand' then
				if entry.proportionV > 0 then
					insert( proportional, entry )
					totalProportion = totalProportion + entry.proportionV
				else
					entry.targetHeight = entry.minHeight
					propAvailHeight = propAvailHeight - entry.minHeight
					insert( nonproportional, entry )
				end
			elseif policy == 'minimum' then
				entry.targetHeight = entry.minHeight
				propAvailHeight = propAvailHeight - entry.minHeight
				insert( fixed, entry )

			elseif policy == 'fixed' then
				entry.targetHeight = entry.fixedHeight
				propAvailHeight = propAvailHeight - entry.fixedHeight
				insert( fixed, entry )

			else
				error( 'unknown policy', policy )
				
			end
		end

		--no proportional?
		if totalProportion == 0 then
			if next( nonproportional ) then
				local remain = innerHeight - minHeightTotal
				local expand = remain/( #nonproportional )
				for _, entry in ipairs( nonproportional ) do
					entry.targetHeight = entry.minHeight + expand
				end
			end
		else
			--proportional	
			--find non-fits
			while true do
				local proportional2 = {}
				local heightUnit = propAvailHeight / totalProportion
				totalProportion = 0
				for _, entry in ipairs( proportional ) do
					local targetHeight = entry.proportionV * heightUnit
					if targetHeight < entry.minHeight then
						entry.targetHeight = entry.minHeight
						propAvailHeight = propAvailHeight - entry.minHeight
					else
						entry.targetHeight = targetHeight
						totalProportion = totalProportion + entry.proportionV
						insert( proportional2, entry )
					end
				end
				if #proportional == #proportional2 then break end --no nonfits anymore
				proportional = proportional2
			end
		end

	end

	--location phase
	local x = marginL
	local y = - marginT
	for i, entry in ipairs( entries ) do
		entry:setLoc( x, y )
		y = y - entry.targetHeight - spacing
	end

end

function UIBoxLayout:calcLayoutHorizontal( entries )
	local count = #entries
	if count == 0 then return end

	local spacing = self.spacing
	local marginL, marginT, marginR, marginB = self:calcMargin()

	local owner = self:getOwner()
	local innerWidth, innerHeight = self:getInnerSize()

	innerWidth  = innerWidth - spacing * ( count - 1 )

	local minWidthTotal = 0
	local minHeightTotal = 0

	--update minSize
	for i, entry in ipairs( entries ) do
		entry:setFrameSize( false, innerHeight )
	end

	--height pass
	for i, entry in ipairs( entries ) do
		minHeightTotal = max( minHeightTotal, entry.minHeight )
		local policy = entry.policyV
		if policy == 'expand' then
			entry.targetHeight = max( innerHeight, entry.minHeight )
			entry.offsetY = 0
		else
			local targetHeight = entry.minHeight
			entry.targetHeight = targetHeight
		end
	end

	--width pass
	for i, entry in ipairs( entries ) do
		minWidthTotal = minWidthTotal + entry.minWidth
	end

	--use min iwdth?
	if innerWidth <= minWidthTotal then 
		for i, entry in ipairs( entries ) do
			entry.targetWidth = entry.minWidth
		end

	else
		--grow?
		local propAvailWidth = innerWidth --Width available for proportional widgets
		local proportional = {}
		local nonproportional = {}
		local fixed = {}
		local totalProportion = 0
		for i, entry in ipairs( entries ) do
			if entry.policyH == 'expand' then
				if entry.proportionH > 0 then
					insert( proportional, entry )
					totalProportion = totalProportion + entry.proportionH
				else
					entry.targetWidth = entry.minWidth
					propAvailWidth = propAvailWidth - entry.minWidth
					insert( nonproportional, entry )
				end
			else
				entry.targetWidth = entry.minWidth
				propAvailWidth = propAvailWidth - entry.minWidth
				insert( fixed, entry )
			end
		end

		--no proportional?
		if totalProportion == 0 then
			if next( nonproportional ) then
				local remain = innerWidth - minWidthTotal
				local expand = remain/( #nonproportional )
				for _, entry in ipairs( nonproportional ) do
					entry.targetWidth = entry.minWidth + expand
				end
			end
		else
			--proportional	
			--find non-fits
			while true do
				local proportional2 = {}
				local widthUnit = propAvailWidth / totalProportion
				totalProportion = 0
				for _, entry in ipairs( proportional ) do
					local targetWidth = entry.proportionH * widthUnit
					if targetWidth < entry.minWidth then
						entry.targetWidth = entry.minWidth
						propAvailWidth = propAvailWidth - entry.minWidth
					else
						entry.targetWidth = targetWidth
						totalProportion = totalProportion + entry.proportionH
						insert( proportional2, entry )
					end
				end
				if #proportional == #proportional2 then break end --no nonfits anymore
				proportional = proportional2
			end
		end
	end

	--location phase
	local y = -marginT
	local x = marginL
	for i, entry in ipairs( entries ) do
		entry:setLoc( x, y )
		x = x + entry.targetWidth + spacing
	end

end

--------------------------------------------------------------------

CLASS: UIHBoxLayout ( UIBoxLayout )
	:MODEL{
		Field 'direction' :no_edit();
	}

function UIHBoxLayout:__init()
	self:setDirection( 'horizontal' )
end

function UIHBoxLayout:setDirection( dir )
	return UIHBoxLayout.__super.setDirection( self, 'horizontal' )
end

registerComponent( 'UIHBoxLayout', UIHBoxLayout )

--------------------------------------------------------------------

CLASS: UIVBoxLayout ( UIBoxLayout )
	:MODEL{
		Field 'direction' :no_edit();
	}

function UIVBoxLayout:__init()
	self:setDirection( 'vertical' )
end

function UIVBoxLayout:setDirection( dir )
	return UIVBoxLayout.__super.setDirection( self, 'vertical' )
end

registerComponent( 'UIVBoxLayout', UIVBoxLayout )
