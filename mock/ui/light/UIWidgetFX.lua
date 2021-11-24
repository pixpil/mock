module 'mock'

local UIWidgetFXRegistry = {}

--------------------------------------------------------------------
CLASS: UIWidgetFX ( mock.Behaviour )
	:MODEL{}

function UIWidgetFX.register( clas, name )
	if UIWidgetFXRegistry[ name ] then
		_warn( 'duplicated uiwidget class', name )
	end
	UIWidgetFXRegistry[ name ] = clas
end

function UIWidgetFX:__init()
end

--------------------------------------------------------------------
CLASS: UIWidgetFXHolder ()

function UIWidgetFXHolder:__init()
end

function UIWidgetFXHolder:updateVisual( style )
	--TODO????
end

