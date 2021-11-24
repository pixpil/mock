require 'mock.input.KeyMaps'
require 'mock.input.FFBController'
require 'mock.input.FFBSource'
require 'mock.input.FFBPlayer'

require 'mock.input.JoystickManager'
require 'mock.input.InputCommandMapping'

require 'mock.input.InputDevice'
require 'mock.input.InputSignal'

--------------------------------------------------------------------
--------------------------------------------------------------------

--------------------------------------------------------------------
--preset
--------------------------------------------------------------------
require 'mock.input.AnimCurveFFBEventType'


--------------------------------------------------------------------
local InputConfiguration = MOAIInputMgr.configuration

if InputConfiguration == 'SDL' then
	require 'mock.input.JoystickManagerSDL'
elseif InputConfiguration == 'NX' then
	require 'mock.input.JoystickManagerNX'
end

require 'mock.input.VirtualJoystickManager'
