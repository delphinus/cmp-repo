local config = require "cmp_repo.config"
local git = require "cmp_repo.git"
local log = require "cmp_repo.log"

local lsp = require "cmp.types.lsp"
local Path = require "plenary.path"
local async = require "plenary.async"

---@enum CmpRepoJobStatus
local STATUS = {
  REGISTERED = 0,
  STARTED = 1,
  FINISHED = 2,
}

---@class CmpRepoRepo
---@field is_available boolean
---@field cache table<string, lsp.CompletionItem[]>
---@field jobs table<string, CmpRepoJobStatus>
---@field tx { send: fun(...: any): nil }
local Repo = {}

---@return CmpRepoRepo
Repo.new = function()
  local tx, rx = async.control.channel.mpsc()
  local self = setmetatable(
    { cache = {}, is_available = (pcall(vim.system, { config.ghq })), jobs = {}, tx = tx },
    { __index = Repo }
  )
  async.void(function()
    while true do
      local dir = rx.recv() --[[@as string?]]
      if not dir then
        break
      end
      self.jobs[dir] = STATUS.STARTED
      local ok, result = git.remote(dir)
      if ok then
        self.cache[dir] = self:make_candidate(result)
      else
        log.debug("failed to fetch remote: %s", result)
      end
      self.jobs[dir] = STATUS.FINISHED
    end
  end)()
  return self
end

---@async
---@return string[]?
function Repo:start()
  local err, roots = git.roots()
  if err then
    log.debug("failed to git.roots: %s", err)
    return
  end
  local tx, rx = async.control.channel.mpsc()
  ---@param root CmpRepoRoot
  vim.iter(roots):each(async.void(function(root)
    if root.for_ghq then
      root:find_repo(tx)
    end
  end))
  ---@type lsp.CompletionItem[]
  local items = {}
  ---@type table<string, boolean>
  local seen = {}
  while true do
    local repo = rx.recv()
    log.debug("received: %s", repo)
    if not repo then
      break
    end
    vim.iter(self:make_candidate(repo)):each(function(candidate)
      if not seen[candidate.label] then
        table.insert(items, candidate)
        seen[candidate.label] = true
      end
    end)
  end
  return {
    items = items,
    isIncomplete = not not vim.iter(pairs(self.jobs)):find(function(_, v)
      return v ~= STATUS.FINISHED
    end),
  }
end

---@param dir string
---@return lsp.CompletionItem[]
function Repo:make_candidate(dir)
  local parts = vim.split(dir, Path.path.sep, { plain = true })
  return vim.iter(ipairs(parts)):fold({}, function(items, i, part)
    local function add(label)
      table.insert(items, { label = label, kind = lsp.CompletionItemKind.Folder, documentation = dir })
    end
    if #part > 2 then
      add(part)
    end
    if i < #parts then
      add(table.concat(vim.list_slice(parts, i, #parts), Path.path.sep))
    end
    return items
  end)
end

return setmetatable({}, {
  __index = function(self, key)
    ---@return CmpRepoRepo
    local function instance()
      return rawget(self, "instance")
    end
    if not instance() then
      rawset(self, "instance", Repo.new())
    end
    if key == "is_available" then
      return instance().is_available
    elseif key == "start" then
      return async.void(function(callback)
        callback(instance():start())
      end)
    end
  end,
})
