module 'mock'

--------------------------------------------------------------------
CLASS: UICheckBoxRenderer ( UIWidgetRenderer )

function UICheckBoxRenderer:onInit()
	self.slotElement = self:addElement( UIWidgetElementImage(), 'slot' )
	self.markElement = self:addElement( UIWidgetElementImage(), 'mark' )
end

function UICheckBoxRenderer:onUpdateContent( widget, style )
	local checked = widget:getContentData( 'value', 'render' )
	self.markElement:setVisible( checked )
end

--------------------------------------------------------------------
CLASS: UICheckBox ( UIButtonBase )
	:MODEL{
		Field 'checked' :boolean() :isset( 'Checked' );
	}
	:SIGNAL{
		valueChanged = '';
	}

function UICheckBox:__init()
	self.checked = false
	self.markSprite = self:attachInternal( DeckComponent() )
	self.markSprite:hide()
	self:connect( self.clicked, 'toggleChecked' )
end

function UICheckBox:getDefaultRendererClass()
	return UICheckBoxRenderer
end

function UICheckBox:toggleChecked()
	return self:setChecked( not self.checked )
end

function UICheckBox:setChecked( checked )
	checked = checked and true or false
	if self.checked == checked then return end
	self.checked = checked
	self.valueChanged( self.checked )
	self:invalidateContent()
	self:setFeature( 'checked', checked )
end

function UICheckBox:isChecked()
	return self.checked
end

function UICheckBox:getLabelRect()
end

function UICheckBox:getContentData( key, role )
	if key == 'value' then
		return self.checked
	end
end

registerEntity( 'UICheckBox', UICheckBox )
