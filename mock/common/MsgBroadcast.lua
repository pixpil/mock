module 'mock'

CLASS: MsgBroadcast ( mock.Behaviour )
	:MODEL{
		Field 'targets' :array( mock.Entity );
		Field 'delay' :float();
		'----';
		Field 'overwriteMsgSource' :boolean();
	}

mock.registerComponent( 'MsgBroadcast', MsgBroadcast )

--------------------------------------------------------------------
function MsgBroadcast:__init()
	self.targets = {}
	self.delay = 0
	self.overwriteMsgSource = false
end

--------------------------------------------------------------------
function MsgBroadcast:onMsg( msg, data, source )
	self:addCoroutine( function ()
		self:wait( self.delay )
		if self.overwriteMsgSource then source = self:getEntity() end
		for i, target in ipairs( self.targets ) do
			if target then
				target:tell( msg, data, source )
			end
		end
	end)
	
end

--------------------------------------------------------------------
-- function MsgBroadcast:onBuildGizmo()
-- 	return mock_edit.IconGizmo( 'split.png' )
-- end

