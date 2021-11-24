module 'mock'

CLASS: ColorPreset ()
	:MODEL{
		Field 'name' :string() :getset( 'ColorName' )
	}

registerComponent( 'ColorPreset', ColorPreset )

function ColorPreset:onAttach()
	
end

function ColorPreset:setColorName( name )
	self.colorName = name
end

function ColorPreset:getColorName()
	return self.colorName
end

