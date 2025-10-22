---@class YamlParser
local M = {}

-- Helper function to trim whitespace
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Helper function to count leading spaces
local function count_indent(line)
  local spaces = line:match("^(%s*)")
  return #spaces
end

-- Helper function to parse a YAML value
local function parse_value(value)
  value = trim(value)

  -- Handle null/nil values
  if value == "null" or value == "~" or value == "" then
    return nil
  end

  -- Handle booleans
  if value == "true" or value == "yes" or value == "on" then
    return true
  end
  if value == "false" or value == "no" or value == "off" then
    return false
  end

  -- Handle numbers
  local num = tonumber(value)
  if num then
    return num
  end

  -- Handle quoted strings
  if value:match('^".*"$') or value:match("^'.*'$") then
    return value:sub(2, -2)
  end

  -- Return as string
  return value
end

-- Parse a YAML document
---@param content string The YAML content to parse
---@return table|nil The parsed YAML as a Lua table, or nil on error
---@return string|nil Error message if parsing failed
function M.parse(content)
  if not content or content == "" then
    return {}, nil
  end

  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local result = {}
  local stack = { { data = result, indent = -1 } }
  local i = 1

  while i <= #lines do
    local line = lines[i]
    local trimmed = trim(line)

    -- Skip empty lines and comments
    if trimmed == "" or trimmed:match("^#") then
      i = i + 1
      goto continue
    end

    local indent = count_indent(line)

    -- Pop stack until we find the right level
    while #stack > 1 and indent <= stack[#stack].indent do
      table.remove(stack)
    end

    local current = stack[#stack].data

    -- Handle list items
    if trimmed:match("^%- ") then
      local value_str = trimmed:sub(3)
      local value = parse_value(value_str)

      -- Ensure current is an array
      if not current[1] and next(current) == nil then
        -- Empty object, convert to array
        setmetatable(current, { __is_array = true })
      end

      if value_str:match(":") then
        -- List item with key-value
        local new_obj = {}
        table.insert(current, new_obj)
        local key, val = value_str:match("^([^:]+):%s*(.*)$")
        if key then
          key = trim(key)
          new_obj[key] = parse_value(val)
          table.insert(stack, { data = new_obj, indent = indent })
        end
      else
        table.insert(current, value)
      end
    -- Handle key-value pairs
    elseif trimmed:match(":") then
      local key, value = trimmed:match("^([^:]+):%s*(.*)$")
      if key then
        key = trim(key)
        value = trim(value or "")

        if value == "" or value == "|" or value == ">" then
          -- Multi-line string or nested object
          if value == "|" or value == ">" then
            -- Multi-line string
            local str_lines = {}
            i = i + 1
            while i <= #lines do
              local next_line = lines[i]
              local next_indent = count_indent(next_line)
              if next_indent <= indent then
                break
              end
              table.insert(str_lines, next_line:sub(indent + 3))
              i = i + 1
            end
            current[key] = table.concat(str_lines, "\n")
            i = i - 1
          else
            -- Check if next line is indented (nested structure)
            if i < #lines then
              local next_line = lines[i + 1]
              local next_indent = count_indent(next_line)
              if next_indent > indent then
                local next_trimmed = trim(next_line)
                if next_trimmed:match("^%- ") then
                  -- Next line is a list
                  current[key] = {}
                  setmetatable(current[key], { __is_array = true })
                else
                  -- Next line is an object
                  current[key] = {}
                end
                table.insert(stack, { data = current[key], indent = indent })
              else
                current[key] = nil
              end
            else
              current[key] = nil
            end
          end
        else
          current[key] = parse_value(value)
        end
      end
    end

    i = i + 1
    ::continue::
  end

  return result, nil
end

-- Parse a YAML file
---@param filepath string Path to the YAML file
---@return table|nil The parsed YAML as a Lua table, or nil on error
---@return string|nil Error message if parsing failed
function M.parse_file(filepath)
  local file, err = io.open(filepath, "r")
  if not file then
    return nil, "Failed to open file: " .. (err or "unknown error")
  end

  local content = file:read("*a")
  file:close()

  return M.parse(content)
end

return M
