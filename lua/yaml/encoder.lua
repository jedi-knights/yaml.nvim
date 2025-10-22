---@class YamlEncoder
local M = {}

-- Helper function to check if a table is an array
local function is_array(t)
  if type(t) ~= "table" then
    return false
  end

  local mt = getmetatable(t)
  if mt and mt.__is_array then
    return true
  end

  local count = 0
  for k, _ in pairs(t) do
    count = count + 1
    if type(k) ~= "number" or k < 1 or k > count then
      return false
    end
  end
  return count > 0
end

-- Helper function to escape special characters in strings
local function escape_string(s)
  if type(s) ~= "string" then
    return tostring(s)
  end

  -- Check if string needs quotes
  if s:match("^%d+$") or s:match("^[%d%.]+$") or s:match("^[true|false|yes|no|on|off|null]$") or s:match("[:#%[%]{}]") or
    s:match("^%s") or s:match("%s$") or s:match("\n") then
    -- Use double quotes and escape special chars
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return '"' .. s .. '"'
  end

  return s
end

-- Convert a value to YAML string
local function value_to_yaml(value, indent, options)
  local indent_str = string.rep(" ", indent)

  if value == nil then
    return "null"
  elseif type(value) == "boolean" then
    return tostring(value)
  elseif type(value) == "number" then
    return tostring(value)
  elseif type(value) == "string" then
    -- Handle multi-line strings
    if value:match("\n") and not value:match("[:#%[%]{}]") then
      local lines = {}
      for line in value:gmatch("[^\n]+") do
        table.insert(lines, indent_str .. "  " .. line)
      end
      return "|\n" .. table.concat(lines, "\n")
    end
    return escape_string(value)
  elseif type(value) == "table" then
    if is_array(value) then
      -- Handle arrays
      if #value == 0 then
        return "[]"
      end

      local lines = {}
      for _, v in ipairs(value) do
        if type(v) == "table" and not is_array(v) then
          -- Complex object in array
          local obj_yaml = value_to_yaml(v, indent + 2, options)
          if obj_yaml:match("\n") then
            table.insert(lines, indent_str .. "-")
            for line in obj_yaml:gmatch("[^\n]+") do
              table.insert(lines, indent_str .. "  " .. line)
            end
          else
            table.insert(lines, indent_str .. "- " .. obj_yaml)
          end
        else
          table.insert(lines, indent_str .. "- " .. value_to_yaml(v, indent + 2, options))
        end
      end
      return "\n" .. table.concat(lines, "\n")
    else
      -- Handle objects
      local keys = {}
      for k in pairs(value) do
        table.insert(keys, k)
      end
      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)

      if #keys == 0 then
        return "{}"
      end

      local lines = {}
      for _, k in ipairs(keys) do
        local v = value[k]
        local key_str = escape_string(tostring(k))
        local val_yaml = value_to_yaml(v, indent + 2, options)

        if type(v) == "table" then
          if val_yaml:match("^[\n]") then
            table.insert(lines, indent_str .. key_str .. ":" .. val_yaml)
          else
            table.insert(lines, indent_str .. key_str .. ": " .. val_yaml)
          end
        else
          table.insert(lines, indent_str .. key_str .. ": " .. val_yaml)
        end
      end
      return "\n" .. table.concat(lines, "\n")
    end
  end

  return "null"
end

-- Encode a Lua table to YAML string
---@param data table The Lua table to encode
---@param options? table Optional encoding options
---@return string The YAML string
function M.encode(data, options)
  options = options or {}

  if type(data) ~= "table" then
    return value_to_yaml(data, 0, options)
  end

  local yaml = value_to_yaml(data, 0, options)
  -- Remove leading newline if present
  if yaml:sub(1, 1) == "\n" then
    yaml = yaml:sub(2)
  end

  return yaml
end

-- Write a Lua table to a YAML file
---@param filepath string Path to the output file
---@param data table The Lua table to encode
---@param options? table Optional encoding options
---@return boolean success
---@return string|nil error message
function M.encode_file(filepath, data, options)
  local yaml = M.encode(data, options)

  local file, err = io.open(filepath, "w")
  if not file then
    return false, "Failed to open file for writing: " .. (err or "unknown error")
  end

  file:write(yaml)
  file:close()

  return true, nil
end

return M
