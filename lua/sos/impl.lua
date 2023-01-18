local M = {}
local api = vim.api

--- @type table<string, boolean>
M.saveable_cmds = setmetatable({
    ["!"] = true,
    lua = true, -- because lua often reads files via require() and various other fn's
    luafile = true,
    make = true,
    runtime = true,
    source = true, -- TODO: Use autocmd instead?
}, {
    __index = function(_tbl, key)
        return vim.startswith(key, "Plenary")
    end,
})

-- TODO: Allow user to provide custom vim regex via opts/cfg?
M.saveable_cmdline = vim.regex([=[system\|systemlist\|:lua\|[Jj][Oo][Bb]]=])

local recognized_buftypes =
    vim.regex([[\%(^$\)\|\%(^\%(acwrite\|help\|nofile\|nowrite\|quickfix\|terminal\|prompt\)$\)]])

--- @param buf integer
--- @return boolean
local function wanted_buftype(buf)
    local buftype = vim.bo[buf].bt

    if not recognized_buftypes:match_str(buftype) then
        vim.notify_once(
            string.format([[[sos.nvim]: unknown buftype: "%s"]], buftype),
            vim.log.levels.WARN
        )

        return false
    end

    return buftype == "" or buftype == "acwrite"
end

local write_current_buf_arg1 = { cmd = "write", mods = { silent = true } }
local function write_current_buf()
    api.nvim_cmd(write_current_buf_arg1, { output = false })
end

--- @param buf integer
local function write_buf(buf)
    api.nvim_buf_call(buf, write_current_buf)
end

--- @param buf integer
function M.write_buf_if_needed(buf)
    if
        vim.bo[buf].mod
        and not vim.bo[buf].ro
        and api.nvim_buf_is_loaded(buf)
        and wanted_buftype(buf)
    then
        local name = api.nvim_buf_get_name(buf)

        -- Cannot write to an empty filename
        if name == "" then return end
        local buftype = vim.bo[buf].bt

        -- If we reached here then file either doesn't exist, doesn't have
        -- write perms/isn't writeable, or is dir
        if buftype == "acwrite" then
            write_buf(buf)
        elseif buftype == "" then
            -- TODO: Make async
            local stat, _errmsg, _errname = vim.loop.fs_stat(name)

            if stat then
                if stat.type == "file" then write_buf(buf) end
            else
                -- TODO: Try stat again on error (or certain errors)?
                write_buf(buf)
            end
        end
    end
end

--- @param buf integer
--- @return boolean: whether to watch/observe buf for changes
function M.should_observe_buf(buf)
    -- NOTE: It's probably best not to try to use filename as hint for whether
    -- buf should be watched (e.g. ignoring nameless buffers) because `BufNew`
    -- won't fire when unnamed buf becomes named, and even when buf is renamed
    -- and `BufNew` fires the name will still be the old name (even if using
    -- vim.api to get the name).
    return wanted_buftype(buf) and vim.bo[buf].ma and not vim.bo[buf].ro
end

--- @return nil
function M.on_timer()
    for _, buf in ipairs(api.nvim_list_bufs()) do
        M.write_buf_if_needed(buf)
    end
end

return M
