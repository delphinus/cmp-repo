local config = require "cmp_repo.config"

---@class CmpRepo
local source = {}

---@return CmpRepo
source.new = function()
  config.set()
  return setmetatable({}, { __index = source })
end

---@return string
source.get_debug_name = function()
  return "repo"
end

---@return boolean
source.is_available = function()
  return true
end

---@return string
function source:get_keyword_pattern()
  return config.keyword_pattern
end

---@return string[]
function source:get_trigger_characters()
  return config.trigger_characters
end

---@param callback fun(items?: vim.CompletedItem[]): nil
---@return nil
function source:complete(_, callback)
  callback()
end

return source
