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

    api.nvim_create_autocmd("VimLeavePre", {
        group = augroup,
        pattern = "*",
        desc = "Cleanup",
        callback = function()
            require("sos").stop()
        end,
    })

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

    if cfg.save_on_focuslost then
        api.nvim_create_autocmd("FocusLost", {
            group = augroup,
            pattern = "*",
            desc = "Save all buffers when Neovim loses focus",
            callback = function(_info)
                cfg.on_timer()
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
                    local cmdline = vim.fn.getcmdline()

                    if
                        cfg.save_on_cmd == "some"
                        and impl.saveable_cmdline:match_str(cmdline)
                    then
                        cfg.on_timer()
                        return
                    end

                    local saveable_cmds = impl.saveable_cmds

                    if type(cfg.save_on_cmd) == "table" then
                        saveable_cmds = cfg.save_on_cmd --[[@as table<string, true>]]
                    end

                    local ok, parsed = pcall(api.nvim_parse_cmd, cmdline)
                    if not ok then return end

                    while true do
                        if saveable_cmds[parsed.cmd] then break end
                        if (parsed.nextcmd or "") == "" then return end
                        ok, parsed = api.nvim_parse_cmd(parsed.nextcmd, {})
                        if not ok then return end
                    end
                end

                cfg.on_timer()
            end,
        })
    end
end

return M
