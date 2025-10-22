-- main module file
local parser = require("yaml.parser")
local encoder = require("yaml.encoder")

---@class Config
---@field indent_width number Number of spaces for indentation (default: 2)
local config = {
  indent_width = 2,
}

---@class Yaml
local M = {}

---@type Config
M.config = config

---@param args Config?
-- Setup function for configuring the YAML plugin
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

-- Parse a YAML string into a Lua table
---@param content string The YAML content to parse
---@return table|nil parsed The parsed YAML as a Lua table, or nil on error
---@return string|nil error Error message if parsing failed
M.parse = function(content)
  return parser.parse(content)
end

-- Parse a YAML file into a Lua table
---@param filepath string Path to the YAML file
---@return table|nil parsed The parsed YAML as a Lua table, or nil on error
---@return string|nil error Error message if parsing failed
M.read = function(filepath)
  return parser.parse_file(filepath)
end

-- Encode a Lua table into a YAML string
---@param data table The Lua table to encode
---@param options? table Optional encoding options
---@return string yaml The YAML string
M.encode = function(data, options)
  return encoder.encode(data, options)
end

-- Write a Lua table to a YAML file
---@param filepath string Path to the output file
---@param data table The Lua table to encode
---@param options? table Optional encoding options
---@return boolean success
---@return string|nil error Error message if writing failed
M.write = function(filepath, data, options)
  return encoder.encode_file(filepath, data, options)
end

-- Load, modify, and save a YAML file
---@param filepath string Path to the YAML file
---@param modifier function Function that takes and returns a table
---@return boolean success
---@return string|nil error Error message if operation failed
M.modify = function(filepath, modifier)
  local data, err = M.read(filepath)
  if not data then
    return false, err
  end

  local modified = modifier(data)
  if not modified then
    return false, "Modifier function returned nil"
  end

  return M.write(filepath, modified)
end

-- Helper function to safely access nested values
---@param data table The table to query
---@param path string Dot-separated path (e.g., "database.host")
---@return any value The value at the path, or nil if not found
M.get = function(data, path)
  local keys = {}
  for key in path:gmatch("[^%.]+") do
    table.insert(keys, key)
  end

  local current = data
  for _, key in ipairs(keys) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[key]
  end

  return current
end

-- Helper function to safely set nested values
---@param data table The table to modify
---@param path string Dot-separated path (e.g., "database.host")
---@param value any The value to set
---@return table data The modified table
M.set = function(data, path, value)
  local keys = {}
  for key in path:gmatch("[^%.]+") do
    table.insert(keys, key)
  end

  local current = data
  for i = 1, #keys - 1 do
    local key = keys[i]
    if type(current[key]) ~= "table" then
      current[key] = {}
    end
    current = current[key]
  end

  current[keys[#keys]] = value
  return data
end

return M
