module 'mock'

local keymap_GII={
	["alt"]        = 205 ;
	["pause"]      = 178 ;
	["menu"]       = 255 ;
	[","]          = 44 ;
	["0"]          = 48 ;
	["4"]          = 52 ;
	["8"]          = 56 ;
	["sysreq"]     = 180 ;
	["@"]          = 64 ;
	["return"]     = 174 ;
	["7"]          = 55 ;
	["\\"]         = 92 ;
	["insert"]     = 176 ;
	["d"]          = 68 ;
	["h"]          = 72 ;
	["l"]          = 76 ;
	["p"]          = 80 ;
	["t"]          = 84 ;
	["x"]          = 88 ;
	["right"]      = 190 ;
	["meta"]       = 204 ;
	["escape"]     = 170 ;
	["home"]       = 186 ;
	["'"]          = 96 ;
	["space"]      = 32 ;
	["3"]          = 51 ;
	["backspace"]  = 173 ;
	["pagedown"]   = 193 ;
	["slash"]      = 47 ;
	[";"]          = 59 ;
	["scrolllock"] = 208 ;
	["["]          = 91 ;
	["c"]          = 67 ;
	["z"]          = 90 ;
	["g"]          = 71 ;
	["shift"]      = 202 ;
	["k"]          = 75 ;
	["o"]          = 79 ;
	["s"]          = 83 ;
	["w"]          = 87 ;
	["delete"]     = 177 ;
	["down"]       = 191 ;
	["."]          = 46 ;
	["2"]          = 50 ;
	["6"]          = 54 ;
	[":"]          = 58 ;
	["b"]          = 66 ;
	["f"]          = 70 ;
	["j"]          = 74 ;
	["pageup"]     = 192 ;
	["up"]         = 189 ;
	["n"]          = 78 ;
	["r"]          = 82 ;
	["v"]          = 86 ;
	["f12"]        = 229 ;
	["f13"]        = 230 ;
	["f10"]        = 227 ;
	["f11"]        = 228 ;
	["f14"]        = 231 ;
	["f15"]        = 232 ;
	["ctrl"]       = 203 ;
	["f1"]         = 218 ;
	["f2"]         = 219 ;
	["f3"]         = 220 ;
	["f4"]         = 221 ;
	["f5"]         = 222 ;
	["f6"]         = 223 ;
	["f7"]         = 224 ;
	["f8"]         = 225 ;
	["f9"]         = 226 ;
	["tab"]        = 171 ;
	["numlock"]    = 207 ;
	["end"]        = 187 ;
	["-"]          = 45 ;
	["1"]          = 49 ;
	["5"]          = 53 ;
	["9"]          = 57 ;
	["="]          = 61 ;
	["]"]          = 93 ;
	["a"]          = 65 ;
	["e"]          = 69 ;
	["i"]          = 73 ;
	["m"]          = 77 ;
	["q"]          = 81 ;
	["u"]          = 85 ;
	["y"]          = 89 ;
	["left"]       = 188 ;
}


local keymap_GLUT={
	-- ['f1']=	1 ;
	-- ['f2']=	2 ;
	-- ['f3']=	3 ;
	-- ['f4']=	4 ;
	-- ['f5']=	5 ;
	-- ['f6']=	6 ;
	-- ['f7']=	7 ;
	['backspace']=	8 ;
	['delete']=	127 ;
	['tab']=	9 ;
	-- ['f10']=	10 ;
	-- ['f11']=	11 ;
	-- ['f12']=	12 ;
	['escape']=	27 ;
	['space']=	32 ;
	['enter']=	13 ;
	--directional key
	['left']=	80 ;
	['up']=	82 ;
	['right']=	79 ;
	['down']=	81 ;
	-- ['pageup']=104 ;
	-- ['pagedown']=105 ;
	-- ['home']=	106 ;
	-- ['end']=	107 ;
	-- ['insert']=	108 ;
	['lctrl']  = 224;
	['lshift'] = 225;
	['lalt']   = 226;
	['lcmd']   = 227;

}

--TODO: fix this
for i=39, 64 do
	keymap_GLUT[ string.char(i) ]=i
end

for i=91, 122 do
	keymap_GLUT[ string.char(i) ]=i
end

function getKeyMap()
	local configuration=MOAIInputMgr.configuration or 'AKUGlut'
	_stat( 'using input configuration:', configuration )
	if configuration=='AKUGlut' then
		return keymap_GLUT
	elseif configuration=='GII' then
		return keymap_GII
	else
		return keymap_GLUT
	end
end

