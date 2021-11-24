module 'mock'

CLASS: LinePath2DFollower ( mock.Component )
	:MODEL{
		Field 'targetPath' :type( LinePath2D ) :getset( 'TargetPath' );
		Field 'position' :number() :getset( 'Position' ) :step( 0.01 ) :range( 0, 1 );
		'----';
		Field 'evtMsg' 		:string();
		Field 'evtTime' 	:array( 'number' ):step( 0.01 ) :range( 0, 1 );
		Field 'evtTarget' :array( mock.Entity );
	}

mock.registerComponent( 'LinePath2DFollower', LinePath2DFollower )
--mock.registerEntityWithComponent( 'LinePath2DFollower', LinePath2DFollower )

local function _posControlNodeCallback( node )
	return node.owner:updatePosition()
end


function LinePath2DFollower:__init()
	self.targetPath = false
	self.targetCurve = false
	self.posControlNode = MOAIScriptNode.new()
	self.posControlNode:reserveAttrs( 1 )
	self.posControlNode.owner = self
	self:setPosition( 0 )
	self.position = 0

	self.evtMsg = 'trigger.on'
	self.evtTime = {}
	self.evtTarget = {}
end

function LinePath2DFollower:onAttach( ent )
	self.evtList = {}
	for i, time in ipairs( self.evtTime ) do
		local target = self.evtTarget[i]
		table.insert( self.evtList, { time, target } )
	end
	table.sort( self.evtList, function( i1, i2 ) return i1[1] < i2[1] end )
	self.posControlNode:setCallback( _posControlNodeCallback )
end

function LinePath2DFollower:onDetach( ent )
	self.posControlNode:setCallback( nilFunc )
end

function LinePath2DFollower:getPosition()
	return self.posControlNode:getAttr( 1 )
end

local clamp = math.clamp
function LinePath2DFollower:setPosition( pos )
	self.posControlNode:setAttr( 1, pos )
end

function LinePath2DFollower:seekPosition( pos, time, easeMode )
	return self.posControlNode:seekAttr( 1, pos, time, easeMode )
end

function LinePath2DFollower:getTargetPath()
	return self.targetPath
end

function LinePath2DFollower:setTargetPath( path )
	self.targetPath = path
	self:updatePosition()
end

function LinePath2DFollower:updatePosition()
	local path = self.targetPath

	local ent = path and path._entity
	if not ent then return end

	local curve = path:getAnimCurve()
	if not curve then return end

	local pos = math.clamp( self:getPosition(), 0, 1 )
	local curve = self.targetPath:getAnimCurve()
	local x, y = curve:getValueAtTime( pos )
	x, y = path:getEntity():modelToWorld( x, y )
	local z = self._entity:getWorldLocZ()
	self._entity:setWorldLoc( x, y, z )

	if #self.evtList > 0 then
		local time, target = unpack( self.evtList[1] )
		if pos >= time then
			target:tell( self.evtMsg )
			table.remove( self.evtList, 1 )
		end
	end
end

function LinePath2DFollower:onBuildGizmo()
	return mock_edit.DrawScriptGizmo()
end

function LinePath2DFollower:onDrawGizmo( selected )
	if selected then
		MOAIDraw.setPenColor( hexcolor'#f67bff' )
	else
		MOAIDraw.setPenColor( hexcolor'#b96b99' )
	end
	local curve = self.targetPath:getAnimCurve()

	local path = self.targetPath:getEntity()
	local z = path:getWorldLocZ()
	for i, time in ipairs( self.evtTime ) do
		local x, y = curve:getValueAtTime( time )
		x, y = path:modelToWorld( x, y )
		y = y + z
		MOAIDraw.drawCircle( x, y, 3 )

		local target = self.evtTarget[i]
		if target then
			local tx, ty, tz = target:getWorldLoc()
			ty = ty + tz
			MOAIDraw.drawArrow( x, y, tx, ty, 10, false )
		end
	end
end
