local M = {}
local api = vim.api

--- NOTE: `:make` is covered by `'autowrite'`
--- @type table<string, true>
M.saveable_cmds = {
    ["!"] = true,
    lua = true, -- because lua often reads files via require() and various other fn's
    luafile = true,
    runtime = true,
    source = true,
}

-- TODO: Allow user to provide custom vim regex via opts/cfg
M.saveable_cmdline = vim.regex [=[system\|systemlist\|:lua\|[Jj][Oo][Bb]]=]

local recognized_buftypes =
    vim.regex [[\%(^$\)\|\%(^\%(acwrite\|help\|nofile\|nowrite\|quickfix\|terminal\|prompt\)$\)]]

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

local write_current_buf_arg1 = { cmd = "write" }
local function write_current_buf()
    api.nvim_cmd(write_current_buf_arg1)
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
    then
        assert(
            wanted_buftype(buf),
            "expected normal buftype of modified buffer " .. buf
        )

        -- NOTE: bufname should point to a valid file that is a file and not
        -- dir
        -- NOTE: filename may appear to not exist if it's remote (buftype =
        -- "acwrite")
        local name = api.nvim_buf_get_name(buf)
        if name == "" then return end
        local ok, res = pcall(vim.fn.resolve, name)

        if ok then
            name = res
        else
            vim.notify_once("[sos.nvim]: " .. res, vim.log.levels.ERROR)
        end

        -- async alternative: loop.fs_access(path, mode)
        -- 0: doesn't exist, or not writeable
        -- 1: exists, is file, and is writeable
        -- 2: Same as 1, but is a dir
        if vim.fn.filewriteable(name) == 1 then
            write_buf(buf)
            return
        end

        -- If we reached here then file either doesn't exist, doesn't have
        -- write perms/isn't writeable, or is dir
        if vim.bo[buf].bt == "acwrite" then write_buf(buf) end
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
