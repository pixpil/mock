--[[License
(The MIT License)

Copyright (c) 2013 Chomping Pixels <breakfast@chompingpixels.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local errors = require('chariot.lib.errors')
local filters = require('chariot.lib.filters')
local utils = require('chariot.lib.utils')


local chariot = {}

chariot.cache = true
chariot.debug = false

chariot.open = "{"
chariot.close = "}"

chariot.base = ''
chariot.extension = 'html'

chariot.globals = {}


function chariot:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	-- cache store
	o.store = {}

	o:init()
	return o
end


function chariot:init()
end

function chariot:assign_global(name, value)
	self.globals[name] = value
end

function chariot:parse(filename, path, template)
	local line = 1
	local map = {}
	local src = "function f(self)\nlocal b = ''\nb = b .. '"
	table.insert(map, line)
	table.insert(map, line)
	local i = 1
	while i <= template:len() do
		local char = template:sub(i, i)

		if template:sub(i, i + self.open:len() - 1) == self.open then
			local state = template:sub(i + self.open:len(), i + self.open:len())
			local prefix, postfix, open_pos, close_pos, shortinc

			-- escaped
			if state == '{' then
				prefix = "'\nb = b .. self.__chariot.utils.escape("
				postfix = ")\nb = b .. '"
				close_pos = template:find('}' .. self.close, i, true)
			-- unescaped
			elseif state == '-' then
				prefix = "'\nb = b .. tostring("
				postfix = ")\nb = b .. '"
				close_pos = template:find('-' .. self.close, i, true)
			-- include
			elseif state == '(' then
				prefix = "'\n"
				postfix = "b = b .. '"
				shortinc = true
				close_pos = template:find(')' .. self.close, i, true)
			-- code
			else
				prefix = "'\n"
				postfix = "b = b .. '"
				close_pos = template:find(self.close, i, true)
			end

			if state == '{' or state == '-' or state == '(' then
				i = i + self.open:len() + 1
			else
				i = i + self.open:len()
			end

			if close_pos == nil then
				errors:parse_error(path, line, template, 'missing closing tag')
			end

			open_pos = template:find(self.open, i, true)

			if open_pos and open_pos < close_pos then
				errors:parse_error(path, line, template, 'missing closing tag')
			end

			-- 1 char before close position
			local code = template:sub(i, close_pos - 1)

			src = src .. prefix
			table.insert(map, line)

			-- is it an include
			local include = utils.trim(code):find('include ', 1, true) == 1

			if include then
				local include_filename = utils.trim(code):sub(9)
				src = src .. 'b = b .. self.__chariot.chariot:include("' ..
					tostring(filename) .. '", "' ..
					tostring(include_filename) .. '", self)\n'

				table.insert(map, line)
			end
			
			-- is it a short include
			if shortinc then
				local include_filename = utils.trim(code):sub(2, -2)
				src = src .. 'b = b .. self.__chariot.chariot:include("' ..
					tostring(filename) .. '", "' ..
					tostring(include_filename) .. '", self)\n'

				table.insert(map, line)
			end

			-- is it a filter
			local filter = code:find('|', 1, true)
			local filter_buf = ''

			if filter then

				for i, token in ipairs(utils.split(code, '|')) do
					local params = utils.split(token, ':')

					local scope = 'self.__chariot.filters.'
					local f = utils.trim(params[1])

					if filters[f] then
						filter_buf = scope .. f .. '(' .. filter_buf

						for i = 2, #params do
							filter_buf = filter_buf .. ', ' .. utils.trim(params[i])
						end

						filter_buf = filter_buf .. ')'
					-- first param
					elseif i == 1 then
						filter_buf = filter_buf .. f
					else
						error('unknown filter: ' .. f)
					end
				end

				src = src .. filter_buf

			end

			-- increment line number for new lines in code
			local b = 1
			local e = 1

			while e do
				e = code:find("\n", e, true)
				if e ~= nil then

					if not include and not filter and not shortinc then
						src = src .. utils.trim(code:sub(b, e)) .. "\n"
						table.insert(map, line)
					end

					line = line + 1
					b = e
					e = e + 1
				end
			end

			-- last new line till end of code
			if not include and not filter and not shortinc and b + 1 < code:len() then
				src = src .. utils.trim(code:sub(b, code:len())) .. "\n"
				table.insert(map, line)
			end

			src = src .. postfix

			if state == '{' or state == '-' then
				table.insert(map, line)
			end

			-- move cursor to end of closing tag
			if state == '{' or state == '-' or state == '(' then
				-- is already 1 position ahead
				i = close_pos + self.close:len()
			else
				i = close_pos + self.close:len() - 1
			end

		elseif(char == "\\") then
			if template:sub(i + 1, i + 1 + self.open:len() - 1) == self.open then
				src = src .. self.open
				i = i + 1
			elseif template:sub(i + 1, i + 1 + self.close:len() - 1) == self.close then
				src = src .. self.close
				i = i + 1
			else
				src = src .. "\\\\"
			end
		elseif(char == "'") then
			src = src .. "\\'"
		elseif(char == "\r") then
			-- ignore
		elseif(char == "\n") then
			src = src .. "\\n'\nb = b .. '"
			table.insert(map, line)
			line = line + 1
		else
			src = src .. char
		end

		i = i + 1
	end

	src = src .. '\'\n\nreturn b\nend\n\nreturn f'

	return src, map
end


function chariot:compile(filename, path, template)
	local src, map = self:parse(filename, path, template)
	local fn = nil

	if self.debug then
		print(src)
	end

	local status, e = pcall(function()
		fn = assert(loadstring(src))
		fn = fn()
	end)

	if not status then
		errors:compile_error(path, template, map, e)
	end

	return fn, map
end


function chariot:read_template(path)
	local file = io.open(path, 'r')
	local template

	if file then
		template = file:read('*all')
		file:close()
	else
		error('template file does not exist: ' .. path)
	end

	return template
end


function chariot:include(parent, filename, model)
	local base = ''
	local pos = parent:reverse():find('/', 1, true)

	if pos then
		base = base .. parent:sub(1, parent:len() - pos + 1)
	end

	return self:render(base .. filename, model)
end


-- filename, template, model
function chariot:render(...)
	local path, filename, template, model, fn, map
	
	local arg = {...}

	-- load arguments
	if #arg == 2 then
		filename = arg[1]
		model = arg[2]
	elseif #arg == 3 then
		template = arg[1]
		filename = arg[2]
		model = arg[3]
	end

	-- add global
	path = self.base .. filename

	-- add global extension
	if self.extension and self.extension:len() > 0 then
		 path = path .. '.' .. self.extension
	end

	-- init cache store object
	if self.cache and not self.store[path] then
		self.store[path] = {}
	end

	-- get template if not supplied
	if #arg == 2 then
		-- from cache
		if self.cache then
			if self.store[path].template then
				template = self.store[path].template
			else
				template = self:read_template(path)
				self.store[path].template = template
			end
		-- from disk
		else
			template = self:read_template(path)
		end
	end

	-- get compiled function and map
	if self.cache then

		if self.store[path].fn and self.store[path].map then
			fn = self.store[path].fn
			map = self.store[path].map
		else
			fn, map = self:compile(filename, path, template)
			self.store[path].fn = fn
			self.store[path].map = map
		end
	else
		fn, map = self:compile(filename, path, template)
	end
	
	-- add globals
	for k,v in pairs(self.globals) do model[k] = v end

	-- add functions to model scope
	if not model.__chariot then
		model.__chariot = {}
		model.__chariot.chariot = self
		model.__chariot.utils = utils
		model.__chariot.filters = filters
	end

	local output

	local status, e = pcall(function()
		output = fn(model)
	end)
	if not status then
		errors:runtime_error(filename, template, map, e)
	end

	return output
end


return chariot
