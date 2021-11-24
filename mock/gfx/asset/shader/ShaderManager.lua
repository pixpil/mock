module 'mock'

local _shaderManager

--------------------------------------------------------------------
CLASS: GlobalUniformBlock ()
	:MODEL{}

function GlobalUniformBlock.register( clas, name )
	_shaderManager:registerGlobalUniformBlock( name, clas )
end

function GlobalUniformBlock:__init()
	self.buffer = MOAIShaderUniformBuffer.new()
end

function GlobalUniformBlock:getBuffer()
	return self.buffer
end

function GlobalUniformBlock:init()
	self:onInit( self.buffer )
end

function GlobalUniformBlock:onInit( buffer )
end


--------------------------------------------------------------------
CLASS: ShaderManager ( GlobalManager )
	:MODEL{}

function ShaderManager:__init()
	_shaderManager = self
	self.ready = false

	self.activeHelper = false
	self.helperRegistry = {}

	self.language = 'glsl3'
	self.UBOBase = false --no manual binding in gl3

	self.globalUniformBlocks = {}
	self.globalUniformBlockClassRegistry = {}

	connectGlobalSignalFunc( 'gfx.context_ready', 
		function() return self:onGraphicsContextDetected() end 
	)

end

function ShaderManager:registerHelperClass( name, clas  )
	table.insert( self.helperRegistry, 1, { name, clas } )
end

function ShaderManager:onGraphicsContextDetected()
	--pick shader helper
	for i, helperEntry in ipairs( self.helperRegistry ) do
		local name ,clas = unpack( helperEntry )
		local helper = clas()
		if helper.isAvailable() then
			_log( 'using shader helper', name )
			self.activeHelper = helper
			break
		end
	end

	self.ready = true

	assert( self.activeHelper )
	self.activeHelper:onInit()

end

function ShaderManager:getHelper()
	return self.activeHelper
end

function ShaderManager:getLanaguage()
	return self.activeHelper:getLanaguage()
end

function ShaderManager:getUBOBindingBase()
	return self.activeHelper:getUBOBindingBase()
end

function ShaderManager:onStart()
	--init common global uniform blocks
	local blocks = {}
	for name, clas in pairs( self.globalUniformBlockClassRegistry ) do
		local block = clas()
		block:init()
		blocks[ name ] = block
	end
	self.globalUniformBlocks = blocks

end

function ShaderManager:registerGlobalUniformBlock( name, clas )
	self.globalUniformBlockClassRegistry[ name ] = clas
end

--------------------------------------------------------------------

ShaderManager()

function getShaderManager()
	return _shaderManager
end
