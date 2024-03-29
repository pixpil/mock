--[[
* Particle Script Helper for MOAI

* Copyright (C) 2012 Tommo Zhou(tommo.zhou@gmail.com).  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local CONST= MOAIParticleScript.packConst
local REG  = MOAIParticleScript.packReg
local SREG = MOAIParticleScript.packSysReg
local M    = MOAIParticleScript

local function getScript()
	return getfenv(3).script
end

local symbolMT,namespaceMT


local function newNode(m)
	return setmetatable(m,symbolMT)
end

local function newBNode(m)
	m.id='node'
	return newNode(m)
end

local function newNamespace(t)
	return setmetatable({
		__ITEMS=t
		},namespaceMT)
end

local MAXREG=32
local function getReg(script,name)
	local regs=script.regs
	local r
	local tmpflag=regs.tmpflag
	local list=regs.list
	local size=#list

	local named=regs.named

	if name then
		r=named[name]
		if not r then
			
			for i=1,size do
				local item=list[i]
				if not item.name and item.flag~=tmpflag then --collectable register
					r=item
					r.name=name
					r.number=i
					r.defined=script
					r.flag=nil
					break
				end
			end

			if not r then
				size=size+1
				if size>MAXREG then error('too many registers..:'..name) end
				r=newNode{id='reg', idx=REG(size), name=name, number=size, defined=script}
				list[size]=r
			end

			named[name]=r
		else
			r.referred=r.defined~=script
		end
	else
		
		for i=1,size do
			local item=list[i]
			if not item.name and item.flag~=tmpflag then --collectable register
				r=item
				r.flag=tmpflag
				break
			end
		end

		if not r then
			size=size+1
			if size>MAXREG then error('too many registers..') end
			r=newNode{id='reg', idx=REG(size), flag=tmpflag}
			list[size]=r
		end
		
	end
	return r
end


local function solve(script,v,reg)
	local vt=type(v)
	assert(vt=='table' or vt=='number')
	
	if vt=='number' then
		v = CONST(v)
		if not reg then 
			return v
		else
			local a,b=reg.idx,v
			script:set(a,b)
			return reg.idx
		end
	end
	
	
	local vid=v.id
	
	if not reg then 
		if vid=='reg' or vid=='node' then return v.idx end
		reg=getReg(script)
	end
	
	if vid=='rand' then
		local a,b,c=reg.idx, solve(script,v.a),solve(script,v.b)
		script:rand(a,b,c)
	elseif vid=='node' or vid=='reg' then --set
		local a,b=reg.idx,solve(script,v)
		script:set(a,b)
	elseif vid=='abs' then
		script:abs(reg.idx, solve(script,v.a))
	elseif vid=='add' then
		script:add(reg.idx, solve(script,v.a),solve(script,v.b))
	elseif vid=='sub' then
		script:sub(reg.idx, solve(script,v.a),solve(script,v.b))
	elseif vid=='mul' then
		script:mul(reg.idx, solve(script,v.a),solve(script,v.b))	
	elseif vid=='div' then
		script:div(reg.idx, solve(script,v.a),solve(script,v.b))
	elseif vid=='vecAngle' then
		script:vecAngle(reg.idx, solve(script,v.a),solve(script,v.b))
	elseif vid=='cycle' then
		script:cycle(reg.idx, solve(script,v.a),solve(script,v.b),solve(script,v.c))
	elseif vid=='wrap' then
		script:wrap(reg.idx, solve(script,v.a),solve(script,v.b),solve(script,v.c))
	elseif vid=='clamp' then
		script:clamp(reg.idx, solve(script,v.a),solve(script,v.b),solve(script,v.c))
	elseif vid=='randSign' then
		script:randSign(reg.idx)
	elseif vid=='time' then
		script:time(reg.idx)
	elseif vid=='age' then
		script:age(reg.idx)
	elseif vid=='ease' then
		script:ease(reg.idx,solve(script,v.a),solve(script,v.b),v.easeType)
	elseif vid=='easeDelta' then
		script:easeDelta(reg.idx,solve(script,v.a),solve(script,v.b),v.easeType)
	elseif vid=='sign' then
		script:sign(reg.idx,solve(script,v.a))
	elseif vid=='sin' then
		script:sin(reg.idx,solve(script,v.a))
	elseif vid=='cos' then
		script:cos(reg.idx,solve(script,v.a))
	elseif vid=='tan' then
		script:tan(reg.idx,solve(script,v.a))
	elseif vid=='pow' then
		script:pow(reg.idx, solve(script,v.a),solve(script,v.b) )
	-- elseif vid=='atan2rot' then
	-- 	script:atan2rot(reg.idx,solve(script,v.a),solve(script,v.b))
	else
		error('todo node type:'..vid)
	end
	
	return reg.idx
	
end


symbolMT={
	__add=function(a,b)
		return newNode{id='add',a=a,b=b}
	end,
	__sub=function(a,b)
		return newNode{id='sub',a=a,b=b}
	end,
	__div=function(a,b)
		return newNode{id='div',a=a,b=b}
	end,
	__mul=function(a,b)
		return newNode{id='mul',a=a,b=b}
	end,
	__neg=function(a)
		return newNode{id='sub',a=CONST(0),b=a}
	end
}

namespaceMT={
	__index=function(t,k)
		local r=t.__ITEMS[k]
		if not r then
			return error('unkown script node name:'..k)
		end
		return r
	end,
	
	__newindex=function(t,k,v)
		local r=t.__ITEMS[k]
		if not r then
			return error('unkown script node name:'..k)
		end
		local script=getScript()
		solve(script,v,r)		
		script.regs.tmpflag={} --new tmp flag
	end
}


local builtinSymbol={
	p = newNamespace{
		x       = newBNode { idx = M.PARTICLE_X     },
		y       = newBNode { idx = M.PARTICLE_Y     },
		z       = newBNode { idx = M.PARTICLE_Z     },
		dx      = newBNode { idx = M.PARTICLE_DX    },
		dy      = newBNode { idx = M.PARTICLE_DY    },
		dz      = newBNode { idx = M.PARTICLE_DZ    },
	},
	
	sp = newNamespace{
		x       = newBNode { idx = M.SPRITE_X_LOC   },
		y       = newBNode { idx = M.SPRITE_Y_LOC   },
		z       = newBNode { idx = M.SPRITE_Z_LOC   },
		rx      = newBNode { idx = M.SPRITE_X_ROT   },
		ry      = newBNode { idx = M.SPRITE_Y_ROT   },
		rz      = newBNode { idx = M.SPRITE_Z_ROT   },
		sx      = newBNode { idx = M.SPRITE_X_SCL   },
		sy      = newBNode { idx = M.SPRITE_Y_SCL   },
		sz      = newBNode { idx = M.SPRITE_Z_SCL   },
		rot     = newBNode { idx = M.SPRITE_ROT     },
		r       = newBNode { idx = M.SPRITE_RED     },
		g       = newBNode { idx = M.SPRITE_GREEN   },
		b       = newBNode { idx = M.SPRITE_BLUE    },
		a       = newBNode { idx = M.SPRITE_OPACITY    },
		glow    = newBNode { idx = M.SPRITE_GLOW    },
		idx     = newBNode { idx = M.SPRITE_IDX     },
		opacity = newBNode { idx = M.SPRITE_OPACITY },
	},
	
	time=newNode{id='time'},
	age =newNode{id='age'},
	
	abs=function(a)
		return newNode{id='abs',a=a}
	end,

	rand=function(a,b)
		return newNode{id='rand',a=a,b=b}
	end,
	
	randSign=function()
		return newNode{id='randSign'}
	end,

	randVec=function(r1,r2,a,b)
		local script=getScript()
		return script:randVec(r1,r2,solve(script,a),solve(script,b))
	end,
	
	vecAngle=function(a,b)
		return newNode{id='vecAngle',a=a,b=b}
	end,
	
	cycle=function(a,b,c)
		return newNode{id='cycle',a=a,b=b,c=c}
	end,
	
	wrap=function(a,b,c)
		return newNode{id='wrap',a=a,b=b,c=c}
	end,

	clamp=function(a,b,c)
		return newNode{id='clamp',a=a,b=b,c=c}
	end,
	
	ease=function(a,b,c)
		return newNode{id='ease',a=a,b=b,easeType=c or MOAIEaseType.LINEAR}
	end,
	
	easeDelta=function(a,b,c)
		return newNode{id='easeDelta',a=a,b=b,easeType=c or MOAIEaseType.LINEAR}
	end,
	
	sprite=function()
		getScript():sprite()
	end,

	-- atan2rot=function(a,b)
	-- 	return newNode{id='atan2rot',a=a,b=b}
	-- end,
	pow=function(a,b)
		return newNode{id='pow',a=a,b=b}
	end,

	cos=function(a)
		return newNode{id='cos',a=a}
	end,
	sin=function(a)
		return newNode{id='sin',a=a}
	end,
	tan=function(a)
		return newNode{id='tan',a=a}
	end,
	sign=function(a)
		return newNode{id='sign',a=a}
	end,

	EaseType={
		EASE_IN			    = MOAIEaseType. EASE_IN,
		EASE_OUT		    = MOAIEaseType. EASE_OUT,
		FLAT			      = MOAIEaseType. FLAT,
		LINEAR			    = MOAIEaseType. LINEAR,
		SHARP_EASE_IN	  = MOAIEaseType. SHARP_EASE_IN,
		SHARP_EASE_OUT	= MOAIEaseType. SHARP_EASE_OUT,
		SHARP_SMOOTH	  = MOAIEaseType. SHARP_SMOOTH,
		SMOOTH			    = MOAIEaseType. SMOOTH,
		SOFT_EASE_IN	  = MOAIEaseType. SOFT_EASE_IN,
		SOFT_EASE_OUT	  = MOAIEaseType. SOFT_EASE_OUT,
		SOFT_SMOOTH		  = MOAIEaseType. SOFT_SMOOTH,
		BACK_IN	        = MOAIEaseType. BACK_IN,
		BACK_OUT	      = MOAIEaseType. BACK_OUT,
		BACK_SMOOTH		  = MOAIEaseType. BACK_SMOOTH,
		ELASTIC_IN	    = MOAIEaseType. ELASTIC_IN,
		ELASTIC_OUT	    = MOAIEaseType. ELASTIC_OUT,
		ELASTIC_SMOOTH  = MOAIEaseType. ELASTIC_SMOOTH,
		BOUNCE_IN	      = MOAIEaseType. BOUNCE_IN,
		BOUNCE_OUT	    = MOAIEaseType. BOUNCE_OUT,
		BOUNCE_SMOOTH	  = MOAIEaseType. BOUNCE_SMOOTH,
	},

	math = math
}

for k, v in pairs( builtinSymbol.EaseType ) do
	builtinSymbol[ k ] = v
end

local scriptEnvMT={
	__index=function(t,k)
		local script=getScript()
		return builtinSymbol[k] or getReg(script,k)
	end,
	
	__newindex=function(t,k,v)
		local script=getScript()
		local r=builtinSymbol[k] or getReg(script,k)
		solve(script,v,r)
		script.regs.tmpflag={}
	end
}

function makeParticleScript( f, regs, ... )
	local script=MOAIParticleScript.new()
	regs = regs or {}
	script.regs = regs

	if not regs.list then regs.list={} end
	if not regs.named then regs.named={} end
	regs.tmpflag={}

	local scriptEnv=setmetatable({
		script=script
	},scriptEnvMT)
	
	setfenv(f,scriptEnv)
	if not pcall( f, ... ) then return nil end
	return script
end

function addParticleScriptBuiltinSymbol(k,v)
	builtinSymbol[k]=v
end