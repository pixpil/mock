local grabFramebufferFlipped = true
function setGrabFramebufferFlip( flipped )
	grabFramebufferFlipped = flipped
end
------------SYSTEM META
function checkOS(...)
	local os=MOAIEnvironment.osBrand
	for i=1, select('#',...) do
		local n=select(i,...)
		if os==n then return true end
	end
	return false
end

function checkLanguage(...)
	local lang=MOAIEnvironment.languageCode or 'en'

	lang=string.lower(lang)
	for i=1, select('#',...) do
		local n=select(i,...)
		if lang==n then return true end
	end
	return false
end

------------RESOLUTION related
function getDeviceScreenSpec()
	local os=string.lower(MOAIEnvironment.osBrand)
	if os=='osx' or os=='windows' or os=='linux' then return os end

	local sw,sh=
						MOAIEnvironment.horizontalResolution
						,MOAIEnvironment.verticalResolution
	
	local deviceName=""

	if os=='ios' then
		if     checkDimension( sw, sh, 320,    480   ) then deviceName = 'iphone' 
		elseif checkDimension( sw, sh, 640,    960   ) then deviceName = 'iphone4' 
		elseif checkDimension( sw, sh, 640,    1136  ) then deviceName = 'iphone5'
		elseif checkDimension( sw, sh, 1024,   768   ) then deviceName = 'ipad'
		elseif checkDimension( sw, sh, 1024*2, 768*2 ) then deviceName = 'ipad3'
		end

	elseif os=='android' then
		deviceName=""
	else --???
		error("what ?")
	end
	return os, deviceName, sw,sh
end

local deviceResolutions={
	iphone  = {320,480},
	iphone4 = {640,960},
	iphone5 = {640,1136},
	ipad    = {768,1024},
	ipad2   = {768,1024},
	ipad3   = {768*2,1024*2},
	ipad4   = {768*2,1024*2},
	android = {480,800},
}

function getResolutionByDevice(simDeviceName,simDeviceOrientation)
	if simDeviceName then
		local w,h=unpack(deviceResolutions[simDeviceName])
		if simDeviceOrientation=='portrait' then 
			return w,h
		else
			return h,w
		end
	end
	return 0,0
end

function getDeviceResolution(simDeviceName,simDeviceOrientation)
	local sw,sh=
						MOAIEnvironment.horizontalResolution
						,MOAIEnvironment.verticalResolution

	if sw and sw and sw*sh~=0 then
		return sw,sh		
	elseif simDeviceName then
		return getResolutionByDevice(simDeviceName,simDeviceOrientation)
	end

	return 0,0
end

--------MOAI class tweak
function extractMoaiInstanceMethods(clas,...)
	local methods={...}
	local funcs={}
	local obj=clas.new()
	for i, m in ipairs(methods) do
		local f=obj[m]
		assert(f,'method not found:'..m)
		funcs[i]=f
	end
	return unpack(funcs)
end


function injectMoaiClass( clas, methods )
	local interfaceTable = clas.getInterfaceTable()
	for k, v in pairs(methods) do
		interfaceTable[ k ] = v
	end
end


----------URL
function openURLInBrowser(url)
	if checkOS('iOS') then
		-- print('open url in safari',url)
		MOAIWebViewIOS.openUrlInSafari(url)

	elseif checkOS('Android') then
		-- print('open url in browser',url)
		MOAIAppAndroid.openURL(url)
	else
		os.execute(string.format('open %q',url))
	end
end

function openRateURL(appID)
	if checkOS('iOS') then
		local url=
			'itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id='
			..appID
		openURLInBrowser(url)
	elseif checkOS('Android') then
		--todo
	end
end

if checkOS('Android') then
	print = MOAILogMgr.log
end

function grabNextFrameToFile( filepath, frameBuffer, format )
	format = format or MOAIImage.COLOR_FMT_RGB_888
	local image = MOAIImage.new()
	frameBuffer = frameBuffer or MOAIGfxMgr.getFrameBuffer()
	frameBuffer:grabNextFrame(
		image,
		function()
			image:convert( format ):writePNG(filepath)
			io.write('saved:   ',filepath,'\n')
		end,
		grabFramebufferFlipped
	)
end

function grabCurrentFrameToFile( filepath, frameBuffer, format )
	local image = MOAIImage.new()
	game:callOnSyncingRenderState( function()
		format = format or MOAIImage.COLOR_FMT_RGB_888
		frameBuffer = frameBuffer or MOAIGfxMgr.getFrameBuffer()
		frameBuffer:grabCurrentFrame( image, grabFramebufferFlipped )	
		image:convert( format ):writePNG(filepath)
		io.write('saved:   ',filepath,'\n')
	end )
	return image
end

local JSON_FLAG_INDENT         = function( n ) return n > 0x1f and 0x1f or n < 0 and 0 or n end
local JSON_FLAG_COMPACT        = 0x20
local JSON_FLAG_SORT_KEY       = 0x80
local JSON_FLAG_PRESERVE_ORDER = 0x100
local JSON_FLAG_ENCODE_ANY     = 0x200

----
MOAIJsonParser.defaultEncodeFlags = 
	JSON_FLAG_INDENT( 2 ) + JSON_FLAG_SORT_KEY

function encodeJSON( data, compact ) --included default flags
	if compact then
		return MOAIJsonParser.encode( data, JSON_FLAG_SORT_KEY + JSON_FLAG_COMPACT )
	else
		return MOAIJsonParser.encode( data, MOAIJsonParser.defaultEncodeFlags )
	end
end

function decodeJSON( data ) --included default flags
	return MOAIJsonParser.decode( data )
end



--------------------------------------------------------------------
----extract all easetype constant to global env?
--------------------------------------------------------------------

EASE_IN        = MOAIEaseType.EASE_IN
EASE_OUT       = MOAIEaseType.EASE_OUT
FLAT           = MOAIEaseType.FLAT
LINEAR         = MOAIEaseType.LINEAR
SHARP_EASE_IN  = MOAIEaseType.SHARP_EASE_IN
SHARP_EASE_OUT = MOAIEaseType.SHARP_EASE_OUT
SHARP_SMOOTH   = MOAIEaseType.SHARP_SMOOTH
SMOOTH         = MOAIEaseType.SMOOTH
SOFT_EASE_IN   = MOAIEaseType.SOFT_EASE_IN
SOFT_EASE_OUT  = MOAIEaseType.SOFT_EASE_OUT
SOFT_SMOOTH    = MOAIEaseType.SOFT_SMOOTH
BACK_IN        = MOAIEaseType.BACK_IN
BACK_OUT       = MOAIEaseType.BACK_OUT
BACK_SMOOTH    = MOAIEaseType.BACK_SMOOTH
ELASTIC_IN     = MOAIEaseType.ELASTIC_IN
ELASTIC_OUT    = MOAIEaseType.ELASTIC_OUT
ELASTIC_SMOOTH = MOAIEaseType.ELASTIC_SMOOTH
BOUNCE_IN      = MOAIEaseType.BOUNCE_IN
BOUNCE_OUT     = MOAIEaseType.BOUNCE_OUT
BOUNCE_SMOOTH  = MOAIEaseType.BOUNCE_SMOOTH

--------------------------------------------------------------------

function saveMOAIGridTiles( grid )
	local stream = MOAIMemStream.new()
	stream:open()

	local writer64 = MOAIStreamAdapter.new()
	local writerDeflate = MOAIStreamAdapter.new ()
	writer64:openBase64Writer ( stream )
	writerDeflate:openDeflateWriter ( writer64 )
	grid:streamTilesOut( writerDeflate )
	writerDeflate:close()
	writer64:close()

	stream:seek( 0 )
	local encoded = stream:read()
	stream:close()

	return encoded
end


function loadMOAIGridTiles( grid, dataString )

	local stream = MOAIMemStream.new()
	stream:write( dataString )
	stream:seek(0)

	local reader64 = MOAIStreamAdapter.new()
	local readerDeflate = MOAIStreamAdapter.new ()
	reader64:openBase64Reader( stream )
	readerDeflate:openDeflateReader( reader64 )

	grid:streamTilesIn( readerDeflate )

	readerDeflate:close()
	reader64:close()
	stream:close()

end


function saveImageBase64( img )
	local stream = MOAIMemStream.new()
	stream:open()
	local writer64 = MOAIStreamAdapter.new()
	local writerDeflate = MOAIStreamAdapter.new ()
	writer64:openBase64Writer ( stream )
	img:write( writer64 )
	stream:seek( 0 )
	local encoded = stream:read()
	stream:close()
	return encoded
end

function loadImageBase64( img, dataString, transform )
	local buffer = MOAIDataBuffer.new()
	buffer:base64Decode( dataString )
	local img = img or MOAIImage.new ()
	img:loadFromBuffer( buffer, transform )
	return img
end


local function _isValidCoord( x, y, w, h )
	if x < 1 then return false end
	if y < 1 then return false end
	if x > w then return false end
	if y > h then return false end
	return true
end

function resizeMOAIGrid( grid, w, h, tw, th ,ox, oy, cw, ch, gx, gy )
	gx = gx or 0
	gy = gy or 0
	local ow, oh = grid:getSize()
	local tmpGrid = MOAIGrid.new()
	tmpGrid:setSize( w, h )
	local w0, h0 = grid:getSize()
	for y = 1, h do
		for x = 1, w do
			local x1, y1 = x + gx, y + gy
			if _isValidCoord( x1, y1, w0, h0 ) then
				tmpGrid:setTile( x, y, grid:getTile( x1, y1 ) )
			end
		end
	end
	grid:setSize( w,h,tw,th,ox,oy,cw,ch )
	for y = 1, h do
		for x = 1, w do
			grid:setTile( x, y, tmpGrid:getTile( x, y ) )
		end
	end
end

function subdivideMOAIGrid( grid, tw, th ,ox, oy, cw, ch )
	local ow, oh = grid:getSize()
	
	local tmpGrid = MOAIGrid.new()
	tmpGrid:setSize( ow, oh )
	for y = 1, oh do
		for x = 1, ow do
			tmpGrid:setTile( x, y, grid:getTile( x, y ) )
		end
	end

	local nw = ow * 2
	local nh = oh * 2
	grid:setSize( nw,nh,tw,th,ox,oy,cw,ch )
	for y = 1, nh do
		for x = 1, nw do
			grid:setTile( x, y, tmpGrid:getTile( x/2, y/2 ) )
		end
	end
	
end


function isMOAIObject( obj, ... )
	local tt = type( obj )
	if tt == 'userdata' then
		local getClass = obj.getClass
		if getClass then
			local clas1 = getClass( obj )
			local n = select( '#', ... )
			if n == 0 then return true end
			for i = 1, n do
				local clas = select( i, ... )
				if clas1 == clas then return true end
			end
		end
	end
	return false
end

local GL_FUNC_ADD               = assert( MOAIGraphicsProp. GL_FUNC_ADD )
local GL_FUNC_SUBTRACT          = assert( MOAIGraphicsProp. GL_FUNC_SUBTRACT )
local GL_FUNC_REVERSE_SUBTRACT  = assert( MOAIGraphicsProp. GL_FUNC_REVERSE_SUBTRACT )
local GL_SRC_ALPHA              = assert( MOAIGraphicsProp. GL_SRC_ALPHA )
local GL_DST_ALPHA              = assert( MOAIGraphicsProp. GL_DST_ALPHA )
local GL_SRC_COLOR              = assert( MOAIGraphicsProp. GL_SRC_COLOR )
local GL_DST_COLOR              = assert( MOAIGraphicsProp. GL_DST_COLOR )
local	GL_ONE_MINUS_SRC_ALPHA    = assert( MOAIGraphicsProp. GL_ONE_MINUS_SRC_ALPHA )
local	GL_ONE_MINUS_DST_ALPHA    = assert( MOAIGraphicsProp. GL_ONE_MINUS_DST_ALPHA )
local GL_ZERO                   = assert( MOAIGraphicsProp. GL_ZERO )
local GL_ONE                    = assert( MOAIGraphicsProp. GL_ONE )


function getMoaiBlendMode( blend )
	if blend == 'alpha'                then return GL_FUNC_ADD, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA  end
	if blend == 'add'                  then return GL_FUNC_ADD, GL_SRC_ALPHA, GL_ONE end
	if blend == 'multiply'             then return GL_FUNC_ADD, GL_DST_COLOR, GL_ZERO end
	if blend == 'normal'               then return GL_FUNC_ADD, GL_ONE, GL_ONE_MINUS_SRC_ALPHA end
	if blend == 'mask'                 then return GL_FUNC_ADD, GL_ZERO, GL_SRC_ALPHA end
	if blend == 'solid'                then return GL_FUNC_ADD, GL_ONE, GL_ZERO  end
	if blend == 'dst_alpha'            then return GL_FUNC_ADD, GL_DST_ALPHA, GL_ONE_MINUS_DST_ALPHA  end
	if blend == 'dst_add'              then return GL_FUNC_ADD, GL_DST_ALPHA, GL_ONE end
	if blend == 'alpha_reversed'       then return GL_FUNC_ADD, GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA end
	if blend == 'dst_alpha_reversed'   then return GL_FUNC_ADD, GL_ONE_MINUS_DST_ALPHA, GL_DST_ALPHA end
	if not blend then return nil end						
	error( 'unknown blend mode', blend )
end


_G.MOAITextBox = _G.MOAITextLabel


if table.clear then
	local tclear = table.clear
	function clearMOAIObject( o )
		tclear( o:getMemberTable() )
	end
else
	local pairs
	function clearMOAIObject( o )
		local t = o:getMemberTable()
		for k in pairs( t ) do
			t[ k ] = nil
		end
	end
end



--------------------------------------------------------------------
local _markRenderNode, _createRenderProp
local _markUpdateNode, _createUpdateProp

function markRenderNode( obj )
	return _markRenderNode( obj )
end

function createRenderProp( obj )
	return _createRenderProp()
end


function markUpdateNode( obj )
	return _markUpdateNode( obj )
end

function createUpdateProp( obj )
	return _createUpdateProp()
end

local function _initSyncRenderMode()
	MOAIRenderMgr.setAsync( false )
	_markRenderNode = function( obj ) return obj end
	_markUpdateNode = function( obj ) return obj end
	_createRenderProp = MOAIGraphicsProp.new
	_createUpdateProp = MOAIGraphicsProp.new
end

local function _initAsyncRenderMode()
	MOAIRenderMgr.setAsync( true )

	local _renderGroup = MOAINodeMgr.getRenderGroup()
	local _updateGroup = MOAINodeMgr.getUpdateGroup()
	_markRenderNode = function( obj )
		obj:setNodeGroup( _renderGroup )
		return obj
	end

	_markUpdateNode = function( obj )
		obj:setNodeGroup( _updateGroup )
		return obj
	end

	local newGraphicsProp = MOAIGraphicsProp.new
	_createRenderProp = function()
		local obj = newGraphicsProp()
		obj:setNodeGroup( _renderGroup )
		return obj
	end

	_createUpdateProp = function()
		local obj = newGraphicsProp()
		obj:setNodeGroup( _updateGroup )
		return obj
	end
end

local async = rawget( _G, 'MOCK_ASYNC_RENDER_MODE' ) ~= false
if async then
	_initAsyncRenderMode()
else
	_initSyncRenderMode()
end
