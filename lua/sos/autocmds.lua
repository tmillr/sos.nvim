local impl = require "sos.impl"
local M = {}
local api = vim.api
local augroup = "sos-autosaver"

--- @return nil
function M.clear()
    api.nvim_create_augroup(augroup, { clear = true })
end

--- Update defined autocmds according to `cfg`
--- @param cfg sos.Config
--- @return nil
function M.refresh(cfg)
    api.nvim_create_augroup(augroup, { clear = true })
    if not cfg.enabled then return end

    if cfg.save_on_bufleave then
        api.nvim_create_autocmd("BufLeave", {
            group = augroup,
            pattern = "*",
            nested = true,
            desc = "Save buffer before leaving it",
            callback = function(info)
                impl.write_buf_if_needed(info.buf)
            end,
        })
    end

    if cfg.save_on_cmd then
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
                    local saveable_cmds = impl.saveable_cmds

                    if type(cfg.save_on_cmd) == "table" then
                        saveable_cmds = cfg.save_on_cmd
                    end

                    local found_cmd = false

                    -- TODO: parse cmdline instead of gmatch
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
    end
end

return M
