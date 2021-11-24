
local utils = {}


function utils.trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end


function utils.split(s, seperator)
  local tokens = {}

  local ts = 1
  local te = 1

  while te do
    te = s:find(seperator, te, true)

    if te ~= nil then
      table.insert(tokens, s:sub(ts, te - 1))

      te = te + seperator:len()
      ts = te
    end
  end

  if ts < s:len() then
    table.insert(tokens, s:sub(ts, s:len()))
  end

  return tokens
end


function utils.pre_pad(value, length, char)
  for i = value:len(), length - 1 do
    value = char .. value
  end

  return value
end


function utils.escape(value)
  local substitutions = {
     ['&'] = '&amp;',
     ['<'] = '&lt;',
     ['>'] = '&gt;',
     ['"'] = '&quot;',
     ["'"] = '&#x27;',
     ['/'] = '&#x2F;'
  }

  return string.gsub(tostring(value), '.', substitutions)
end


return utils
