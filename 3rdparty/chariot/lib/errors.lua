
local utils = require('chariot.lib.utils')

local errors = {}

-- padding error lines
errors.lines = 3


function errors:template_to_lines(template)
  local lines = {}
  local b = 0
  local e = 0

  for i = 1, template:len() do
    if template:sub(i, i) == "\n" then
      b = e
      e = i
      table.insert(lines, template:sub(b + 1, e - 1))
    end
  end

  table.insert(lines, template:sub(e + 1, template:len()))

  return lines
end


function errors:error_lines(template, line)
  local lines = self:template_to_lines(template)
  local ls = math.max(1, line - self.lines)
  local le = math.min(#lines, line + self.lines)
  local length = tostring(le):len()
  local message = ''

  for i = ls, le do
    if i == line then
      message = message .. ' >' ..
        utils.pre_pad(tostring(i), length + 1, ' ') ..
        ' | ' .. lines[i] .. '\n'
    else
      message = message ..
        utils.pre_pad(tostring(i), length + 3, ' ') ..
        ' | ' .. lines[i] .. '\n'
    end
  end

  return message
end


function errors:parse_error(filename, line, template, details)
  local lines = self:template_to_lines(template)

  local message = '\nerrors: ParseError: ' ..
    filename .. ':' .. line .. ': ' .. details .. '\n'

  message = message .. self:error_lines(template, line)

  error(message)
end


function errors:compile_error(filename, template, map, e)
  local src_line = tonumber(e:match(']:(%w+):'))
  local line = map[src_line]

  local message = '\nerrors: CompileError: ' ..
    filename .. ':' .. line .. ': bad lua syntax:\n'

  message = message .. self:error_lines(template, line)

  error(message)
end


function errors:runtime_error(filename, template, map, e)

  -- rethrow
  if e:find('template file does not exist') then
    error(e)
  end

  local details = e:sub(e:find(': ') + 2, e:len())
  local src_line = tonumber(e:match(']:(%w+):'))
  local line = map[src_line]

  local message = '\nerrors: RenderError: ' ..
    filename .. ':' .. line .. ': ' .. details .. ':\n'

  message = message .. self:error_lines(template, line)

  error(message)
end


return errors
