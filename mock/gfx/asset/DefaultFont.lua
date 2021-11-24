module 'mock'

_fontPlaceHolder = false

function getFontPlaceHolder()
	if _fontPlaceHolder then return _fontPlaceHolder end
	-- -- read the font in from the file
	-- local font = require 'mock.gfx.asset.default_font'

	-- -- load the font image back in
	-- local buffer = MOAIDataBuffer.new()
	-- local dataString = require 'mock.gfx.asset.default_font_png'
	-- buffer:setString( dataString )
	-- local image = MOAIImage.new ()
	-- image:loadFromBuffer( buffer )
	-- -- set the font image
	-- font:setCache ()
	-- font:setReader ()
	-- font:setImage ( image )
	-- font.size = 16
	-- -- local font = MOAIFont.new()
	-- _fontPlaceHolder = font
	-- return _fontPlaceHolder
end