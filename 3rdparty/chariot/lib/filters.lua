
local filters = {}


-- table


function filters.first(t)
  return t[1]
end


function filters.last(t)
  return t[#t]
end


function filters.map(t, property)
  local result = {}
  for i, v in ipairs(t) do
    table.insert(result, v[property])
  end
  return result
end


function filters.property(obj, val)
  return obj[val]
end


function filters.length(a)
  if a['len'] then
    return a:len()
  else
    return #a
  end
end


function filters.sort_asc(t)
  table.sort(t, function(a, b) return a < b end)
  return t
end


function filters.sort_dec(t)
  table.sort(t, function(a, b) return a > b end)
  return t
end


function filters.sort_asc_by(t, f)
  table.sort(t, function(a, b) return a[f] < b[f] end)
  return t
end


function filters.sort_dec_by(t, f)
  table.sort(t, function(a, b) return a[f] > b[f] end)
  return t
end


function filters.lowercase(obj)
  return tostring(obj):lower()
end


function filters.uppercase(obj)
  return tostring(obj):upper()
end


function filters.reverse(obj)
  return tostring(obj):reverse()
end


function filters.replace(obj, match, replace)
  return tostring(obj):gsub(match, replace, 1, true)
end


function filters.prepend(obj, val)
  table.insert(obj, 1, val)
  return obj
end


function filters.append(obj, val)
  table.insert(obj, val)
  return obj
end


function filters.truncate(obj, val)
  if type(obj) == 'table' then
    local result = {}
    for i = 1, math.min(val, #obj) do
      table.insert(result, obj[i])
    end
    return result
  else
    obj = tostring(obj)
    return obj:sub(1, #obj - val)
  end
end


function filters.words(a, b)
  local i = 1
  local count = 0
  a = tostring(a)

  while count < b and i < a:len() do
    local char = a:sub(i, i)
    if char == ' ' then
      count = count + 1
    end
    i = i + 1
  end

  return a:sub(1, i - 2)
end


function filters.join(obj, val)
  local val = val or ', '
  return table.concat(obj, val)
end


function filters.add(obj, val)
  return tonumber(obj) + tonumber(val)
end


function filters.subtract(obj, val)
  return tonumber(obj) - tonumber(val)
end


function filters.multiply(obj, val)
  return tonumber(obj) * tonumber(val)
end


function filters.divide(obj, val)
  return tonumber(obj) / tonumber(val)
end


function filters.modulus(obj, val)
  return tonumber(obj) % tonumber(val)
end


function filters.round(obj, val)
  obj = tonumber(obj)
  val = tonumber(val)

  if val < 0 then
    val = 0
  end

  return tonumber(string.format('%.' .. (val or 0) .. 'f', obj))
end


return filters
