--------------------------------------------------------------------
-- Lightweight UI Module for MOCK
--------------------------------------------------------------------

EnumUILayoutPolicy = _ENUM_V {
	'expand',
	'minimum',
	'fixed'
}

EnumUILayoutAlignmentH = _ENUM_V {
	'left',
	'center',
	'right'
}

EnumUILayoutAlignmentV = _ENUM_V {
	'top',
	'middle',
	'bottom'
}


--base
require 'mock.ui.light.UIGlobalSignals'
require 'mock.ui.light.UICommon'
require 'mock.ui.light.UICursor'
require 'mock.ui.light.UIPointer'

require 'mock.ui.light.UIStyle'
require 'mock.ui.light.UIStyleAccessor'
require 'mock.ui.light.UIStyleBase'

require 'mock.ui.light.UIEvent'
require 'mock.ui.light.UIMsg'
require 'mock.ui.light.UIWidgetFX'
require 'mock.ui.light.UIWidget'
require 'mock.ui.light.UIWidgetElement'
require 'mock.ui.light.UIWidgetRenderer'

require 'mock.ui.light.UILayout'
require 'mock.ui.light.UILayoutItem'
require 'mock.ui.light.UIFocusManager'

require 'mock.ui.light.UIResourceManager'
require 'mock.ui.light.UIView'
require 'mock.ui.light.UIViewMapping'
require 'mock.ui.light.UIFocusCursor'
require 'mock.ui.light.UIManager'


--------------------------------------------------------------------fo

require 'mock.ui.light.UIBoxLayout'
require 'mock.ui.light.UIGridLayout'

require 'mock.ui.light.UIFocusConnection'

--------------------------------------------------------------------
require 'mock.ui.light.UIWidgetGroup'
require 'mock.ui.light.UISpacer'

require 'mock.ui.light.renderers'
require 'mock.ui.light.widgets'

