-- Plugin loader for yaml.nvim
-- This file is automatically loaded by Neovim

-- Prevent loading the plugin twice
if vim.g.loaded_yaml_nvim then
  return
end
vim.g.loaded_yaml_nvim = 1

-- Create user commands for easy access
vim.api.nvim_create_user_command("YamlParse", function(opts)
  local yaml = require("yaml")
  local content = table.concat(opts.fargs, " ")
  local result, err = yaml.parse(content)
  if result then
    print(vim.inspect(result))
  else
    print("Error parsing YAML: " .. (err or "unknown error"))
  end
end, { nargs = "+", desc = "Parse YAML string and print result" })

vim.api.nvim_create_user_command("YamlEncode", function(opts)
  local yaml = require("yaml")
  local lua_code = table.concat(opts.fargs, " ")
  local ok, data = pcall(loadstring("return " .. lua_code))
  if ok and data then
    local result = yaml.encode(data)
    print(result)
  else
    print("Error: Invalid Lua table expression")
  end
end, { nargs = "+", desc = "Encode Lua table to YAML string" })
