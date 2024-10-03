local config = require "cmp_repo.config"
local async = require "plenary.async"

local async_system = async.wrap(vim.system, 3)

local semaphore

---@async
---@param cmd string[]
---@param opts? table
---@return string? err
---@return string result
return function(cmd, opts)
  opts = vim.tbl_extend("force", opts or {}, { text = true })
  if not semaphore then
    semaphore = async.control.Semaphore.new(config.concurrency)
  end
  local permit = semaphore:acquire()
  local ok, err_or_result = async.util.apcall(async_system, cmd, opts)
  permit:forget()
  if not ok then
    local err = err_or_result
    return ("[cmp-repo] failed to spawn: %s"):format(err), ""
  end
  local result = err_or_result
  if result.code ~= 0 then
    return ("[cmp-repo] returned error: %s: %s"):format(table.concat(cmd, " "), err_or_result.stderr), ""
  end
  return nil, result.stdout
end
