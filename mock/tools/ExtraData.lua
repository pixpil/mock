module 'mock'

--------------------------------------------------------------------
CLASS: ExtraData ( Component )
function ExtraData:__init()
	self.data = false
end

function ExtraData:get()
	return self.data
end

function ExtraData:set( data )
	self.data = data
end

--------------------------------------------------------------------
CLASS: ExtraDataString ( ExtraData )
	:MODEL{
		Field 'data' :string()
	}

function ExtraDataString:__init()
	self.data = 'data'
end

function ExtraDataString:set( data )
	self.data = tostring( data )
end


--------------------------------------------------------------------
CLASS: ExtraDataBoolean ( Component )
	:MODEL{
		Field 'data' :boolean()
	}

function ExtraDataBoolean:__init()
	self.data = false
end

function ExtraDataString:set( data )
	self.data = data and true or false
end


--------------------------------------------------------------------
CLASS: ExtraDataNumber ( Component )
	:MODEL{
		Field 'data' :number()
	}

function ExtraDataNumber:__init()
	self.data = 0
end

function ExtraDataNumber:set( data )
	self.data = tonumber( data ) or 0
end


registerComponent( ExtraDataString )
registerComponent( ExtraDataBoolean )
registerComponent( ExtraDataNumber )
