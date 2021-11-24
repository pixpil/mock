module 'mock'

CLASS: LayeredSwitch ()
	:MODEL{}

function LayeredSwitch:__init()
	self.levels = {}
	self.state = false
end

function LayeredSwitch:setOn( level )
end

function LayeredSwitch:updateState()
end