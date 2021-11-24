--------------------------------------------------------------------
project             = 'Mock'
title               = 'Mock API Documentation'
description         = 'A game framework for MOAI'

--------------------------------------------------------------------
-- new_type("member","Member", false, "field")
new_type("enum","Enum")

sort = true

alias( 'p',  {'param', modifiers={type="$1"}} )
alias( 'ret',{'return',modifiers={type="$1"}} )
merge               = true
format              = 'discount'
backtick_references = false
no_lua_ref          = true

--------------------------------------------------------------------
kind_names = {topic = 'Manual',script = 'Programs'}
style               = '!pale'

--------------------------------------------------------------------
dir                 = 'doc'
readme              = 'README.md'

file = {
	'mock/core'
}

-- examples  =  {}
