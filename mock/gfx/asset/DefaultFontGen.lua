-- build the font
local charcodes = ' \"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'
local fontname = 'default_font'
local fontsrc = 'default_font.ttf'
local fontsize = 16

assert( MOAIFileSystem.checkFileExists( fontsrc ) )
font = MOAIFont.new ()
font:setCache ( MOAIDynamicGlyphCache.new ())
font:setReader ( MOAIFreeTypeFontReader.new ())
font:load ( fontsrc )
font:preloadGlyphs ( charcodes, fontsize )

-- yank out the font image
local image = font:getImage()
assert( image )
local TMP_PNG_FILE = 'tmp_font_image.png'
image:writePNG ( TMP_PNG_FILE )

local data = MOAIDataBuffer.new()
data:load( TMP_PNG_FILE )
local s = data:getString()
local output = MOAIDataBuffer.base64Encode( s )

local f = io.open( fontname..'_png.lua', 'w' )
f:write( 'return MOAIDataBuffer.base64Decode("' )
f:write( output )
f:write( '")' )
f:close()
MOAIFileSystem.deleteFile( TMP_PNG_FILE )

-- add the font to the serializer
local src = MOAISerializer.serializeToString( font )
src = src:gsub( '... or ', '' ) --some fix
src = src:gsub( "deserializer:createObject %( 'MOAIFont' %)", 'MOAIFont.new()' )

local f = io.open( fontname..'.lua', 'w' )
f:write( src )
f:close()

print( 'done' )