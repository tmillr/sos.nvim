-- sos.nvim - A plugin for automatically saving changed buffers

--[[
## Strategy

Trigger a timer whenever a buffer changes. This seems better or more correct
than using `CursorHold` and `CursorHoldI` (although those tend to get the job
done too). I'd rather save a changed buffer if it has been 5+ minutes since
last getting changed than not save it just because the cursor hasn't come to a
rest for enough seconds (4 or 5 or 10 or whatever). I'd also rather not try to
get around this by saving files every single time the cursor comes to a rest
for only a single second. So whether the cursor is moving or not is kinda
irrelevant. Not using `CursorHold`.

### The `TextChanged` Autocommand Event

Not ideal. Use buffer events instead of the `TextChanged` autocmd event
because the latter only fires if the buffer's text changes while being the
current buffer (the problem is: background buffers can still change).

### Save All Buffers Together

Instead of saving changed buffers individually, I believe it's best to save
them altogether, so that's what we're going to go with.

Pros
  - If Vim crashes, it's more likely that either "all" unsaved changes are
  lost or none, whereas if files are written separately, then it could be that
  one file gets saved but another doesn't because its timer is still pending
  at the time of the crash (that file/buffer was changed later or after the
  other file was changed). If this happens, it's probably more confusing than
  if you had simply lost all of your unsaved/most recent changes? Although,
  you would have fewer files to redo/recover your changes on. I don't think
  there is too much need for worry however as Vim itself doesn't seem to crash
  often (but the system might).

  - Fewer intermittent write calls as writes are grouped together. Perhaps
  this is more efficient then and/or easier on the fs/kernel? Less
  context-switching etc? Idk.

Cons
  - More files be written at once, so the timeout callback might take longer.
  Maybe this can negated by writing files using non-blocking calls or separate
  threads to do the file writes? Does Vim/Neovim already do this (i.e. for
  `:w` and `:wall` etc.)? One nice thing about using `:w` or `:update` is that
  they automatically integrate with autocmds, buf options, `:checktime`, and
  any other things that I might be forgetting.

TODO: Command/Fn/Opt to enable/disable locally (per buf)
--]]

local MultiBufObserver = require 'sos.observer'
local autocmds = require 'sos.autocmds'
local cfg = require 'sos.config'
local util = require 'sos.util'
local errmsg = util.errmsg
local api = vim.api
local augroup_init = 'sos-autosaver.init'
local did_setup = false

---@class sos
local mt = { buf_observer = MultiBufObserver:new() }

---@type sos
local M = setmetatable({}, { __index = mt })

---@param unset_ok? boolean don't error if the global is unset
---@return table? module # the current module if it was reloaded, otherwise `nil`
local function was_reloaded(unset_ok)
  local m = _G.__sos_autosaver__
  assert(unset_ok or m)
  return m ~= M and m or nil
end

-- local function redirect_call()
--   local current = was_reloaded()
--   if current then setmetatable(M, getmetatable(current)) end
--   return current
-- end

local function manage_vim_opts(plug_enabled)
  local aw = cfg.opts.autowrite

  if aw == 'all' then
    vim.o.autowrite = false
    vim.o.autowriteall = plug_enabled
  elseif aw == true then
    vim.o.autowriteall = false
    vim.o.autowrite = plug_enabled
  elseif aw ~= false then
    errmsg(
      'invalid value `'
        .. vim.inspect(aw)
        .. '` for option `autowrite`: expected "all" | true | false'
    )
    return
  end

  -- If we reached here then cfg.autowrite was set to false, so don't touch
  -- it then.
end

---@return boolean awaiting
local function defer_init()
  if not util.to_bool(vim.v.vim_did_enter) then
    api.nvim_create_augroup(augroup_init, { clear = true })

    api.nvim_create_autocmd('VimEnter', {
      group = augroup_init,
      pattern = '*',
      desc = 'Initialize sos.nvim',
      once = true,
      callback = function()
        if cfg.opts.enabled then
          M.enable(false)
        else
          M.disable(false)
        end
      end,
    })

    return true
  end

  return false
end

---@param verbose? boolean
function mt.enable(verbose)
  assert(not was_reloaded())
  if not did_setup then return M.setup { enabled = true } end
  cfg.opts.enabled = true
  if defer_init() then return end
  manage_vim_opts(true)
  autocmds.refresh(cfg.opts)
  M.buf_observer:start {
    should_observe_buf = require('sos.impl').should_observe_buf,
    timeout = cfg.opts.timeout,
    on_timer = cfg.opts.on_timer,
  }
  if verbose then util.notify 'enabled' end
end

---@param verbose? boolean
function mt.disable(verbose)
  assert(not was_reloaded())
  if not did_setup then return M.setup { enabled = false } end
  cfg.opts.enabled = false
  if defer_init() then return end
  manage_vim_opts(false)
  autocmds.clear()
  M.buf_observer:stop()
  if verbose then util.notify 'disabled' end
end

---@param config? sos.config.opts
function mt.setup(config)
  cfg.apply(config)
  did_setup = true

  if not defer_init() then
    if cfg.opts.enabled then
      M.enable(false)
    else
      M.disable(false)
    end
  end
end

---Enables/whitelists a buffer so that it may be autosaved. This is the default
---initial state of all buffers.
---
---NOTE: An enabled buffer that becomes modified is not necessarily guaranteed
---to be saved (e.g. it won't be saved if the `'readonly'` vim option is set).
---@param buf integer
---@param verbose? boolean
function mt.enable_buf(buf, verbose)
  local ignored = M.buf_observer:ignore_buf(buf, false)
  if verbose then
    util.notify(
      'buffer %s: #%d %s',
      nil,
      nil,
      ignored and 'disabled' or 'enabled',
      buf == 0 and api.nvim_get_current_buf() or buf,
      util.bufnr_to_name(buf) or ''
    )
  end
end

---Disables/blacklists a buffer so that it will not be autosaved.
---@param buf integer
---@param verbose? boolean
function mt.disable_buf(buf, verbose)
  local ignored = M.buf_observer:ignore_buf(buf, true)
  if verbose then
    util.notify(
      'buffer %s: #%d %s',
      nil,
      nil,
      ignored and 'disabled' or 'enabled',
      buf == 0 and api.nvim_get_current_buf() or buf,
      util.bufnr_to_name(buf) or ''
    )
  end
end

---@param buf integer
---@param verbose? boolean
function mt.toggle_buf(buf, verbose)
  local ignored = M.buf_observer:toggle_ignore_buf(buf)
  if verbose then
    util.notify(
      'buffer %s: #%d %s',
      nil,
      nil,
      ignored and 'disabled' or 'enabled',
      buf == 0 and api.nvim_get_current_buf() or buf,
      util.bufnr_to_name(buf) or ''
    )
  end
end

---Returns `false` if `buf` is completely ignored/blacklisted for autosaving.
---
---NOTE: An enabled buffer that becomes modified is not necessarily guaranteed
---to be saved (e.g. it won't be saved if the `'readonly'` vim option is set).
---@param buf integer
function mt.buf_enabled(buf) return not M.buf_observer:buf_ignored(buf) end

do
  require 'sos.commands'

  -- Init the global obj
  --
  -- The point of this is so that we can reload the plugin and persist some
  -- things while doing so.
  --
  -- 1. Don't have to worry about leaking the long-lived timer (although it
  --    probably destroys itself anyway when garbage collected because the
  --    timer userdata has a `__gc` handler in its metatable) because it
  --    only gets created once and only once.
  --
  -- 2. It's not really possible/easy to detach `nvim_buf_attach` callbacks
  --    after reloading the plugin, and we don't want different callbacks
  --    with (potentially) different behavior attached to different buffers
  --    (e.g. the plugin is reloaded/re-sourced during development).
  local old = was_reloaded(true)

  if old then
    -- Plugin was reloaded somehow
    rawset(cfg.opts, 'enabled', nil)

    -- TODO: Forcefully detach buf callbacks? Emit a warning?
    old.stop()

    -- Cancel potential pending call (if vim hasn't entered yet)
    api.nvim_create_augroup(augroup_init, { clear = true })
  end

  _G.__sos_autosaver__ = M
end

return M
