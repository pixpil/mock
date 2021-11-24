module 'mock'

function seekFieldValue( obj, fieldId, targetValue, duration, easeType )
	local model = Model.fromObject( obj )
	if not model then return nil end
	local field = model:getField( fieldId )
	local scriptNode = MOAIScriptNode.new()
	local initValue = field:getValue( obj )
	scriptNode:reserveAttrs( 1 )
	scriptNode:setAttr( 1, initValue )
	scriptNode.field = field
	scriptNode.object = obj
	scriptNode:setCallback( function( node )
		return node.field:setValue( node.object, node:getAttr( 1 ) )
	end )
	return scriptNode:seekAttr( 1, targetValue, duration, easeType )
end
