module 'mock'

--------------------------------------------------------------------
CLASS: UILayoutItem ( Component )
	:MODEL{
		Field 'policyH' :enum( EnumUILayoutPolicy ) :getset( 'PolicyH' );
		Field 'policyV' :enum( EnumUILayoutPolicy ) :getset( 'PolicyV' );
		Field 'alignmentH' :enum( EnumUILayoutAlignmentH ) :getset( 'AlignmentH' );
		Field 'alignmentV' :enum( EnumUILayoutAlignmentV ) :getset( 'AlignmentV' );
		Field 'proportion' :type( 'vec2' ) :meta{ decimals = 0 } :getset( 'Proportion' );
		Field 'minSize' :type( 'vec2' ) :meta{ decimals = 0 } :getset( 'MinSize' );
		Field 'maxSize' :type( 'vec2' ) :meta{ decimals = 0 } :getset( 'MaxSize' );
	}


function UILayoutItem:__init()
	self.policy = { 'expand', 'expand' }
	self.alignment = { 'left', 'middle' }
	self.proportion = { 0, 0 }
	self.minSize = { 0,0 }
	self.maxSize = { 10000, 10000 }
end

function UILayoutItem:onAttach( ent )
	if not ent:isInstance( UIWidget ) then
		return _warn( 'UILayoutItem attached to non UIWidget' )
	end
	self:sync()
end

function UILayoutItem:onEditorInit()
	local ent = self:getEntity()
	if ent:isInstance( UIWidget ) then
		self.policy  = { ent:getLayoutPolicy() }
	end
end

function UILayoutItem:getParentLayout()
	local widget = self:getEntity()
	if not isInstance( widget, UIWidget ) then return false end
	return widget:getParentLayout()
end

function UILayoutItem:getAlignment()
	return unpack( self.alignment )
end

function UILayoutItem:setAlignment( h, v )
	self.alignment = { h, v }
	self:sync()
end

function UILayoutItem:getProportion()
	return unpack( self.proportion )
end

function UILayoutItem:setProportion( h, v )
	self.proportion = { h, v }
	self:sync()
end

function UILayoutItem:setPolicy( h, v )
	self.policy = { h, v }
	self:sync()
end

function UILayoutItem:getPolicy()
	return unpack( self.policy )
end

function UILayoutItem:getPolicyH()
	return self.policy[ 1 ]
end

function UILayoutItem:setPolicyH( policy )
	self:setPolicy( policy, self.policy[ 2 ] )
end

function UILayoutItem:getPolicyV()
	return self.policy[ 2 ]
end

function UILayoutItem:setPolicyV( policy )
	self:setPolicy( self.policy[ 1 ], policy )
end


function UILayoutItem:getAlignmentH()
	return self.alignment[ 1 ]
end

function UILayoutItem:setAlignmentH( alignment )
	self:setAlignment( alignment, self.alignment[ 2 ] )
end

function UILayoutItem:getAlignmentV()
	return self.alignment[ 2 ]
end

function UILayoutItem:setAlignmentV( alignment )
	self:setAlignment( self.alignment[ 1 ], alignment )
end

function UILayoutItem:sync()
	local ent = self._entity
	if not ( ent and ent:isInstance( UIWidget ) ) then return end
	ent:invalidateLayout()
end

function UILayoutItem:getMinSize()
	return unpack( self.minSize )
end

function UILayoutItem:setMinSize( w, h )
	self.minSize = { w, h }
	self:sync()
end

function UILayoutItem:getMaxSize()
	return unpack( self.maxSize )
end

function UILayoutItem:setMaxSize( w, h )
	self.maxSize = { w, h }
	self:sync()
end

function UILayoutItem:setGeometry( x, y, w, h )
	local widget = self:getEntity()
	if isInstance( widget, 'UIWidget' ) then
		return widget:setGeometry( x, y, w, h, false, true )
	end
end

function UILayoutItem:getMargin()
	local widget = self:getEntity()
	return widget:getMargin()
end

registerComponent( 'UILayoutItem', UILayoutItem )