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

---@class sos.Timer
---@field start function
---@field stop function

local M = {}
local MultiBufObserver = require 'sos.bufevents'
local autocmds = require 'sos.autocmds'
local cfg = require 'sos.config'
local errmsg = require('sos.util').errmsg
local api = vim.api
local loop = vim.loop
local augroup_init = 'sos-autosaver/init'

local function manage_vim_opts(config, plug_enabled)
  local aw = config.autowrite

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

local function start(verbose)
  manage_vim_opts(cfg, true)
  autocmds.refresh(cfg)
  if __sos_autosaver__.buf_observer ~= nil then return end

  __sos_autosaver__.buf_observer =
    MultiBufObserver:new(cfg, __sos_autosaver__.timer)

  __sos_autosaver__.buf_observer:start()
  if verbose then vim.notify('[sos.nvim]: enabled', vim.log.levels.INFO) end
end

local function stop(verbose)
  manage_vim_opts(cfg, false)
  autocmds.clear()
  if __sos_autosaver__.buf_observer == nil then return end
  __sos_autosaver__.buf_observer:destroy()
  __sos_autosaver__.buf_observer = nil
  if verbose then vim.notify('[sos.nvim]: disabled', vim.log.levels.INFO) end
end

-- Init the global obj
--
-- The point of this is so that we can reload the plugin and persist some
-- things while doing so.
--
-- 1. Don't have to worry about leaking the long-lived timer (although it
--    porbably destroys itself anyway when garbage collected because the
--    timer userdata has a `__gc` handler in its metatable) because it
--    only gets created once and only once.
--
-- 2. It's not really possible/easy to detach `nvim_buf_attach` callbacks
--    after reloading the plugin, and we don't want different callbacks
--    with (potentially) different behavior attached to different buffers
--    (e.g. the plugin is reloaded/re-sourced during development).
if __sos_autosaver__ == nil then
  local t = loop.new_timer()
  loop.unref(t)
  __sos_autosaver__ = {
    timer = t,
    buf_observer = nil,
  }
else
  -- Plugin was reloaded somehow
  rawset(cfg, 'enabled', nil)
  -- Destroy the old observer
  stop()
  -- Cancel potential pending call (if vim hasn't entered yet)
  api.nvim_create_augroup(augroup_init, { clear = true })
end

---@param verbose? boolean
---@return nil
local function main(verbose)
  if vim.v.vim_did_enter == 0 or vim.v.vim_did_enter == false then
    api.nvim_create_augroup(augroup_init, { clear = true })

    api.nvim_create_autocmd('VimEnter', {
      group = augroup_init,
      pattern = '*',
      desc = 'Initialize sos.nvim',
      once = true,
      callback = function() main(false) end,
    })

    return
  end

  if cfg.enabled then
    start(verbose)
  else
    stop(verbose)
  end
end

---Missing keys in `opts` are left untouched and will continue to use their
---current value, or will fallback to their default value if never previously
---set.
---@param opts? sos.Config
---@param reset? boolean Reset all options to their defaults before applying `opts`
---@return nil
function M.setup(opts, reset)
  vim.validate { opts = { opts, 'table', true } }

  if reset then
    for _, k in ipairs(vim.tbl_keys(cfg)) do
      if rawget(cfg, k) ~= nil then rawset(cfg, k, nil) end
    end
  end

  if opts then
    for k, v in pairs(opts) do
      if cfg[k] == nil then
        vim.notify(
          string.format('[sos.nvim]: unrecognized key in options: %s', k),
          vim.log.levels.WARN
        )
      else
        cfg[k] = vim.deepcopy(v)
      end
    end
  end

  main(true)
end

return M
