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

TODO: Handle ModifiedSet event or something similar to handle the case where
buffer is considered modified and/or needs to be written even though the
buffer text didn't change (e.g. 'eol' or 'fileformat' changed etc, see `:h
'mod'`)

TODO: Command/Fn/Opt to enable/disable locally (per buf)
--]]

--- @class sos.Timer
--- @field start function
--- @field stop function

local M = {}
local cfg = require "sos.config"
local MultiBufObserver = require "sos.bufevents"
local api = vim.api
local loop = vim.loop
local augroup = vim.api.nvim_create_augroup("sos-autosaver", { clear = true })

-- NOTE: `:make` is covered by `'autowrite'`
local _saveable_cmds = {
    ["!"] = true,
    lua = true,
    luafile = true,
    runtime = true,
    source = true,
    system = true,
    systemlist = true,
}

local function start()
    if __sos_autosaver__.buf_observer ~= nil then return end

    __sos_autosaver__.buf_observer =
        MultiBufObserver:new(cfg, __sos_autosaver__.timer)

    __sos_autosaver__.buf_observer:start()

    -- NOTE: will not catch file reading/sourcing done in
    -- mappings/timers/autocmds/via functions/etc.
    api.nvim_create_autocmd("CmdlineLeave", {
        group = augroup,
        pattern = ":",
        nested = true,
        desc = "Save all buffers before running a command",
        callback = function(_info)
            if
                cfg.enabled == false
                or cfg.save_on_cmd == false
                or vim.v.event.abort == 1
                or vim.v.event.abort == true
            then
                return
            end

            if cfg.save_on_cmd ~= "all" then
                local saveable_cmds = _saveable_cmds

                if type(cfg.save_on_cmd) == "table" then
                    saveable_cmds = cfg.save_on_cmd
                end

                local found_cmd = false

                for word in vim.fn.getcmdline():gmatch "%S+" do
                    if saveable_cmds[vim.fn.fullcommand(word)] then
                        found_cmd = true
                        break
                    end
                end

                if not found_cmd then return end
            end

            __sos_autosaver__.buf_observer.cfg.on_timer()
        end,
    })

    vim.notify("[sos.nvim]: enabled", vim.log.levels.INFO)
end

local function stop()
    if __sos_autosaver__.buf_observer == nil then return end
    api.nvim_clear_autocmds { group = augroup }
    __sos_autosaver__.buf_observer:destroy()
    __sos_autosaver__.buf_observer = nil
    vim.notify("[sos.nvim]: disabled", vim.log.levels.INFO)
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
    -- Plugin was reloaded somehow, destroy old observer
    stop()
end

--- @return nil
local function main()
    if vim.v.vim_did_enter == 0 or vim.v.vim_did_enter == false then
        local augroup_init = vim.api.nvim_create_augroup(
            "sos-autosaver/init",
            { clear = true }
        )

        api.nvim_create_autocmd("VimEnter", {
            group = augroup_init,
            pattern = "*",
            desc = "Initialize sos.nvim",
            once = true,
            callback = main,
        })

        return
    end

    if cfg.enabled == true then
        start()
    elseif cfg.enabled == false then
        stop()
    end
end

--- @param opts sos.Config | nil
--- @return nil
function M.setup(opts)
    vim.validate { opts = { opts, "table", true } }
    if not opts then return end

    for k, v in pairs(opts) do
        if cfg[k] == nil then
            vim.notify(
                string.format(
                    "[sos.nvim]: unrecognized key in options: %s",
                    k
                ),
                vim.log.levels.WARN
            )
        else
            cfg[k] = vim.deepcopy(v)
        end
    end

    main()
end

main()

return M
