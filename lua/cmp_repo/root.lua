local log = require "cmp_repo.log"
local async = require "plenary.async"
local Path = require "plenary.path"

-- HACK: This hack become unnecessary when this PR will be merged.
-- https://github.com/nvim-lua/plenary.nvim/pull/625
local async_fs_opendir = async.wrap(function(path, entries, callback)
  return vim.uv.fs_opendir(path, callback, entries)
end, 3)

---@class CmpRepoRoot
---@field dir string
---@field for_ghq boolean
local Root = {}

---@param dir string
---@param for_ghq boolean
---@return CmpRepoRoot
Root.new = function(dir, for_ghq)
  return setmetatable({ dir = vim.fs.normalize(dir), for_ghq = for_ghq }, { __index = Root })
end

---@async
---@param tx { send: fun(dir?: string): nil }
function Root:find_repo(tx)
  ---@async
  ---@param tx { send: fun(dir?: string): nil }
  ---@param dir string
  ---@param depth? integer
  local function search_repo(tx, dir, depth)
    if not depth then
      depth = 5
    end
    local err, fd = async_fs_opendir(dir, 1000)
    if err then
      log.debug("search_dir() fs_opendir failed. dir: %s, err: %s", dir, err)
      return
    end
    local entries
    err, entries = async.uv.fs_readdir(fd)
    if err then
      log.debug("search_dir() fs_readdir failed. dir: %s, err: %s", dir, err)
      return
    elseif not entries then
      log.debug("search_dir() fs_readdir failed. dir: %s has no entries", dir)
      return
    end
    err = async.uv.fs_closedir(fd)
    if err then
      log.debug("search_dir() fs_closedir failed. dir: %s, err: %s", dir, err)
      return
    end
    log.debug("dir: %s, entries: %d", dir, #entries)
    local threads = vim
      .iter(entries)
      :filter(function(entry)
        return entry.type == "directory"
      end)
      :map(function(entry)
        return function()
          local repo = Path:new(dir, entry.name)
          local is_repo = not (async.uv.fs_stat((repo / ".git").filename))
          log.debug("dir: %s, is_repo: %s", repo.filename, is_repo)
          if is_repo then
            tx.send(repo:make_relative(self.dir))
          elseif depth > 0 then
            search_repo(tx, repo.filename, depth - 1)
          end
        end
      end)
      :totable()
    async.util.join(threads)
  end

  search_repo(tx, self.dir)
  tx.send()
end

---@param config string
---@return CmpRepoRoot[] roots
Root.from_git_config = function(config)
  ---@type CmpRepoRoot[]
  local roots = {}
  ---@type table<string, { vcs: string, dir: string }>
  local urlmatch_settings = {}
  vim.iter(vim.gsplit(config, "\n", { plain = true, trimempty = true })):each(function(line)
    local key, value = line:match "^([^=]+)=(.*)$"
    if not key or not value then
      return
    elseif key == "ghq.root" then
      table.insert(roots, Root.new(value, false))
      return
    end
    local urlmatch, prop = key:match "^ghq%.(.*)%.(vcs|root)$"
    if not urlmatch or not prop then
      return
    elseif not urlmatch_settings[urlmatch] then
      urlmatch_settings[urlmatch] = {}
    end
    urlmatch_settings[urlmatch][prop] = value
  end)
  if #roots > 0 then
    roots[#roots].for_ghq = true
  end
  vim.iter(urlmatch_settings):each(function(_, setting)
    if (not setting.vcs or setting.vcs == "git") and setting.root then
      table.insert(roots, Root.new(setting.root, false))
    end
  end)
  return roots
end

return Root
