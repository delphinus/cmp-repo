---@class CmpRepoOptions
---@field keyword_pattern? string default: [[\w\+]]
---@field trigger_characters? string[] default: { "." }

---@class CmpRepoRawConfig
---@field keyword_pattern string
---@field trigger_characters string[]
local default_config = {
  keyword_pattern = [[\w\+]],
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
