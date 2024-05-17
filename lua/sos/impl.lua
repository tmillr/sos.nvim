local M = {}
local api = vim.api
local uv = vim.loop

---@type table<string, boolean>
M.savable_cmds = setmetatable({
    ["!"] = true,
    ["="] = true, -- alias/shorthand for `lua=`
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
M.savable_cmdline = vim.regex [=[system\|:lua\|[Jj][Oo][Bb]]=]

local recognized_buftypes =
    vim.regex [[\%(^$\)\|\%(^\%(acwrite\|help\|nofile\|nowrite\|quickfix\|terminal\|prompt\)$\)]]

---@param val any
---@return boolean
local function tobool(val)
    return val == true or val == 1
end

---@param buf integer
---@nodiscard
---@return boolean
local function wanted_buftype(buf)
    local buftype = vim.bo[buf].bt

    if not recognized_buftypes:match_str(buftype) then
        vim.notify_once(
            ('[sos.nvim]: ignoring buf with unknown buftype "%s"'):format(
                buftype
            ),
            vim.log.levels.WARN
        )

        return false
    end

    return buftype == "" or buftype == "acwrite"
end

local err

-- TODO:
-- * Consider adding :confirm here (e.g. will error otherwise if user didn't set
--   :confirm manually/globally)
-- * Ignore bufs with "not edited" flag (or ask once then ignore if write is
--   denied, otherwise the user is asked on every timer fire. user is prompted
--   when :confirm is used). This flag is set at least on :read and :file. See
--   :h not-edited.
-- * Use ++p flag to auto create parent dirs? Or prompt?

---@return nil
local function write_current_buf()
    err = nil

    local ok, res = pcall(
        api.nvim_cmd,
        { cmd = "write", mods = { silent = true } },
        { output = false }
    )

    if not ok then err = res end
end

---@param buf integer
---@nodiscard
---@return boolean, string?
local function write_buf(buf)
    api.nvim_buf_call(buf, write_current_buf)
    return not err, err
end

---@param buf integer
---@nodiscard
---@return boolean, string?
function M.write_buf_if_needed(buf)
    if
        vim.bo[buf].mod
        and vim.o.write
        and not vim.bo[buf].ro
        and api.nvim_buf_is_loaded(buf)
        and wanted_buftype(buf)
    then
        local name = api.nvim_buf_get_name(buf)
        -- Cannot write to an empty filename
        if name == "" then return true end
        local buftype = vim.bo[buf].bt

        if buftype == "acwrite" then
            return write_buf(buf)
        elseif buftype == "" then
            local stat, _errmsg, errname = uv.fs_stat(name)

            if stat then
                -- File exists: only write if it's writeable and not a dir.
                if
                    vim.fn.filewritable(name) == 1
                    and not stat.type:find "^dir"
                then
                    return write_buf(buf)
                end

                return true
            elseif errname == "ENOENT" then
                -- TODO: Try stat again on error (or certain errors, like if
                -- EINTR is possible to observe in lua)?
                if name:find "[\\/]$" then
                    -- Unsure what the user would want here, so just return
                    -- success and don't write anything.
                    return true
                end

                local dir = vim.fn.fnamemodify(name, ":h")
                local dir_stat, _dir_errmsg, dir_errname = uv.fs_stat(dir)

                if dir_stat then
                    if vim.fn.filewritable(dir) == 2 then
                        -- Parent is writeable dir
                        return write_buf(buf)
                    end

                    -- Parent dir exists but isn't writeable.
                    return true
                elseif dir_errname == "ENOENT" then
                    if tobool(vim.fn.mkdir(dir, "p")) then
                        return write_buf(buf)
                    end

                    -- Parent dir doesn't exist, failed to create it (e.g.
                    -- perms).
                    return true
                end
            end
        end
    end

    return true
end

---@param buf integer
---@return boolean: whether to watch/observe buf for changes
function M.should_observe_buf(buf)
    -- NOTE: It's probably best not to try to use filename as hint for whether
    -- buf should be watched (e.g. ignoring nameless buffers) because `BufNew`
    -- won't fire when unnamed buf becomes named, and even when buf is renamed
    -- and `BufNew` fires the name will still be the old name (even if using
    -- vim.api to get the name).
    return wanted_buftype(buf) and vim.bo[buf].ma and not vim.bo[buf].ro
end

---@return nil
function M.on_timer()
    local errs = {}

    for _, buf in ipairs(api.nvim_list_bufs()) do
        local ok, res = M.write_buf_if_needed(buf)

        if not ok then
            table.insert(
                errs,
                -- ("%s: %s"):format(
                --     api.nvim_buf_get_name(buf),
                --     res:gsub([[%s*stack traceback:.*]], "")
                --         :gsub([[^.*:%d+:%s*]], "")
                -- )
                ("[sos.nvim]: %s: %s"):format(res, api.nvim_buf_get_name(buf))
            )
        end
    end

    if errs[1] ~= nil then api.nvim_err_writeln(table.concat(errs, "\n")) end
end

return M
