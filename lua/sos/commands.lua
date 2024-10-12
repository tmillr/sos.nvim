local errmsg = require('sos.util').errmsg
local api = vim.api
local extkeys = { [1] = true }
local M = {}

-- TODO: types

---@class (exact) sos.Command: vim.api.keyset.user_command
---@field [1] string|function

local function Command(def)
  return setmetatable(def, {
    __call = function(self, ...) return self[1](...) end,
  })
end

local function filter_extkeys(tbl)
  local ret = {}

  for k, v in pairs(tbl) do
    if extkeys[k] == nil then ret[k] = v end
  end

  return ret
end

---@generic T: table<string, sos.Command>
---@param cmds T
---@return T
local function Commands(cmds)
  local ret = {}

  for k, v in pairs(cmds) do
    ret[k] = Command(v)
    api.nvim_create_user_command(k, v[1], filter_extkeys(v))
  end

  return ret
end

---Verifies and resolves a single buffer from a command invocation. 0 or 1
---buffer may be specified (with current buffer as fallback) via argument or
---range (i.e. bufnr as the range). Accepts bufnr, bufname, bufname pattern, or
---shorthand (e.g. `%`). Attempts to follow the semantics of the builtin
---`:[N]buffer [bufname]` command in terms of resolving the specified buffer.
---@param info table
---@return integer? bufnr # bufnr or nil if specified buffer is invalid
function M.resolve_bufspec(info)
  if #info.fargs > 1 then return errmsg 'only 1 argument is allowed' end
  local buf

  if info.range > 0 then
    -- Here we either have range and int arg, or just range. No way to
    -- decipher between the two. `count` is rightmost of the two on cmdline.
    buf = info.count

    if #info.fargs > 0 then
      return errmsg 'only 1 arg or count is allowed, got both'
    elseif info.range > 1 then
      return errmsg 'only 1 arg or count is allowed, got 2-part range'
    elseif buf < 1 or not api.nvim_buf_is_valid(buf) then
      return errmsg('invalid bufnr: ' .. buf)
    end
  else
    local arg = info.fargs[1]

    -- Use `[$]` for `$`, otherwise we'll get highest bufnr.
    if arg == '$' then
      buf = vim.fn.bufnr '^[$]$'
      buf = buf > 0 and buf or vim.fn.bufnr '*[$]*'
    else
      buf = vim.fn.bufnr(arg or '')
    end

    if buf < 1 then
      return errmsg 'argument matched none or multiple buffers'
    end
  end

  return buf
end

local function verbose(opts)
  if opts.smods.emsg_silent or opts.smods.silent then
    return opts.smods.unsilent
  end

  return true
end

return setmetatable(
  Commands {
    SosEnable = {
      desc = 'Enable sos autosaver',
      nargs = 0,
      force = true,
      function(opts) require('sos').enable(verbose(opts)) end,
    },

    SosDisable = {
      desc = 'Disable sos autosaver',
      nargs = 0,
      force = true,
      function(opts) require('sos').disable(verbose(opts)) end,
    },

    SosToggle = {
      desc = 'Toggle sos autosaver',
      nargs = 0,
      force = true,
      function(opts)
        if require('sos.config').opts.enabled then
          require('sos').disable(verbose(opts))
        else
          require('sos').enable(verbose(opts))
        end
      end,
    },

    SosBufToggle = {
      desc = 'Toggle autosaver for buffer (default: current buffer)',
      nargs = '?',
      count = -1,
      addr = 'buffers',
      complete = 'buffer',
      force = true,
      function(opts)
        local buf = M.resolve_bufspec(opts)
        if buf then require('sos').toggle_buf(buf, verbose(opts)) end
      end,
    },
  },
  {
    __index = M,
  }
)
