---@class CmpRepoOptions
---@field concurrency integer default: 5
---@field git? string default: "git"
---@field keyword_pattern? string default: [[\w\+]]
---@field roots? string[] default: {}
---@field trigger_characters? string[] default: { "." }

---@class CmpRepoRawConfig
---@field concurrency integer
---@field git string
---@field keyword_pattern string
---@field roots string[]
---@field trigger_characters string[]
local default_config = {
  concurrency = 5,
  git = "git",
  keyword_pattern = [[\w\+]],
  roots = {},
  trigger_characters = { "." },
}

---@class CmpRepoConfig: CmpRepoRawConfig
local Config = {}

---@return nil
Config.set = function()
  local cfg = require("cmp.config").get_source_config "repo"
  local extended = vim.tbl_extend("force", default_config, (cfg or {}).option or {})
  vim.iter(pairs(extended)):each(function(k, v)
    Config[k] = v
  end)
end

return Config
