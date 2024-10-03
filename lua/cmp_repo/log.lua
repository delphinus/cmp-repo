return {
  ---@param fmt string
  ---@param ... any
  ---@retunr nil
  debug = not not vim.env.CMP_DEBUG and function(fmt, ...)
    require("cmp.utils.debug").log(("[cmp-repo] " .. fmt):format(...))
  end or function() end,
}
