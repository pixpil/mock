module 'mock'

CLASS: UIFocusConnection ( Component )
	:MODEL{
		Field 'connectionN' :type( UIWidget ) :label( 'N' );
		Field 'connectionS' :type( UIWidget ) :label( 'S' );
		Field 'connectionE' :type( UIWidget ) :label( 'E' );
		Field 'connectionW' :type( UIWidget ) :label( 'W' );
	}

registerComponent( 'UIFocusConnection', UIFocusConnection )

function UIFocusConnection:__init()
	-- body
	self.connectionN = false
	self.connectionS = false
	self.connectionE = false
	self.connectionW = false
end

function UIFocusConnection:onStart( ent )
	self:updateConnections()
end

function UIFocusConnection:updateConnections()
	local widget = self:getEntity()
	if not widget:isInstance( UIWidget ) then return end
	widget:setFocusConnection( 'n', self.connectionN )
	widget:setFocusConnection( 's', self.connectionS )
	widget:setFocusConnection( 'e', self.connectionE )
	widget:setFocusConnection( 'w', self.connectionW )
end
