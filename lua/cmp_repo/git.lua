local async_system = require "cmp_repo.async_system"
local config = require "cmp_repo.config"
local Root = require "cmp_repo.root"

---@class CmpRepoRoot
---@field ghq table<string, boolean>
---@field normal string[]

---@async
---@return string? err
---@return CmpRepoRoot[] result
local function roots()
  local err, result = async_system { config.git, "config", "-l" }
  if err then
    return ("failed to git config -l: %s"):format(result), {}
  end
  return nil, Root.from_git_config(result)
end

---@async
---@param dir string
---@return boolean ok
---@return string result
local function remote(dir)
  local ok, result = async_system({ config.git, "remote", "-v" }, { cwd = dir })
  if not ok then
    return false, ("failed to git remote -v: %s"):format(result)
  end
  local entry = vim.iter(vim.gsplit(result, "\n", { plain = true })):find(function(line)
    return not not line:match "^origin"
  end)
  local url = entry:match "^%S+%s+(%S+)"
  if not url then
    return false, ("url not found: %s"):format(entry)
  end
  return true, (url:gsub("%.git$", ""):gsub("^[^:]+://", ""):gsub("^[^@]+@", ""))
end

return { remote = remote, roots = roots }
