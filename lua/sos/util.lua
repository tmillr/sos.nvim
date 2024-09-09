local api = vim.api
local M = {}

---Displays an error message.
---@param fmt string
---@param ... unknown fmt arguments
---@return nil
function M.errmsg(fmt, ...)
  api.nvim_err_writeln('[sos.nvim]: ' .. (fmt):format(...))
end

function M.notify(fmt, level, opts, ...)
  vim.notify(
    '[sos.nvim]: ' .. (fmt):format(...),
    level or vim.log.levels.INFO,
    opts or {}
  )
end

---@param buf integer
---@return string?
function M.bufnr_to_name(buf)
  local name = vim.fn.bufname(buf)
  return #name > 0 and name or nil
end

---Converts vim boolean to Lua boolean.
---@param val any
---@return boolean
function M.to_bool(val) return val == 1 or val == true end

function M.getbufs()
  local bufs = {}
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if vim.bo[buf].mod and api.nvim_buf_is_loaded(buf) then
      table.insert(bufs, buf)
    end
  end
  return bufs
end

return M
