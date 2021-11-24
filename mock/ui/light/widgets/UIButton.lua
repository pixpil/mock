module 'mock'

CLASS: UIButton ( UIButtonBase )
	:MODEL{
		Field 'text' :string() :getset( 'Text' );
	}

function UIButton:__init()
	self.text = 'Button'
end

function UIButton:getDefaultRendererClass()
	return UIButtonRenderer
end

function UIButton:setText( t )
	self.text = t
	self:invalidateContent()
end

function UIButton:getText()
	return self.text
end

function UIButton:setI18NText( t )
	return self:setText( self:translate( t ) )
end

function UIButton:getContentData( key, role )
	if key == 'text' then
		return self:getText()
	end
end

function UIButton:getLabelRect()
	return self:getContentRect()
end
