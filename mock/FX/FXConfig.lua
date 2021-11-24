module 'mock'

local _FXNodeRegistry = {}

--------------------------------------------------------------------
CLASS: FXNode ()
	:MODEL{}

function FXNode.register( clas, name )
	if _FXNodeRegistry[ name ] then
		_error( 'duplicated FXNode class', name, clas )
		return
	end
	_FXNodeRegistry[ name ] = clas
end


---------------------------------------------------------------------
