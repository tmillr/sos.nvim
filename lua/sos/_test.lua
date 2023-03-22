-- TODO: refactor test lib/utils so they can be shared/required and create
-- dirs for each test type (e2e, unit, etc.) so things are better organized,
-- re-usable fn for testing autoread/checktime, seamless rpc requests via
-- metatable

local M = {}
local api = vim.api
local uv = vim.loop
local sleep = uv.sleep
local tmpfiles

---@return nil
function M.await_schedule()
    local co =
        assert(coroutine.running(), "cannot await outside of coroutine")

    vim.schedule(function()
        coroutine.resume(co, true)
    end)

    M.set_timeout(5000, function()
        coroutine.resume(
            co,
            false,
            "timed out waiting for vim.schedule() callback"
        )
    end)

    assert(coroutine.yield())
end

---@async
function M.setup_plugin(...)
    require("sos").setup(... or { enabled = true })
    M.await_vim_enter()
end

function M.bufwritemock(onwrite)
    local state = { writes = {} }

    api.nvim_create_autocmd("BufWriteCmd", {
        -- group = augroup,
        pattern = "*",
        desc = "Mock buffer writes without actually writing anything",
        once = false,
        nested = false,
        callback = function(info)
            state[info.buf] = info
            table.insert(state.writes, info)
            vim.bo[info.buf].mod = false
            if onwrite then onwrite(info) end
        end,
    })

    return setmetatable({
        clear = function()
            state = { writes = {} }
        end,
    }, {
        __index = function(_tbl, k)
            return state[k]
        end,
    })
end

---@param file? string a file name taken as-is (no magic chars)
---@return string output
function M.silent_edit(file)
    return api.nvim_cmd({
        cmd = "edit",
        args = { file },
        magic = { file = false, bar = false },
        mods = { silent = true },
    }, { output = true })
end

---@param keys string
---@param cb function
function M.handle_prompt(keys, cb)
    local timer = uv.new_timer()
    timer:start(50, 50, function()
        if api.nvim_get_mode().blocking then api.nvim_input(keys) end
        timer:stop()
        timer:close()
    end)
    local ok, result = pcall(cb)
    timer:stop()
    if not timer:is_closing() then timer:close() end
    assert(ok, result)
    return result
end

---@param content? string | (string|number)[]
---@return string fname
function M.tmpfile(content)
    if not tmpfiles then
        tmpfiles = {}

        api.nvim_create_autocmd("VimLeave", {
            pattern = "*",
            desc = "Cleanup temp files",
            nested = false,
            callback = function()
                for _, f in ipairs(tmpfiles) do
                    vim.fn.delete(f)
                end
            end,
        })
    end

    local tmp = vim.fn.tempname()
    table.insert(tmpfiles, tmp)

    assert(
        tmp and tmp ~= "",
        "vim.fn.tempname() returned nil or empty string"
    )

    if content then
        assert(
            vim.fn.writefile(
                type(content) == "table" and content or { content },
                tmp,
                "b"
            ) == 0,
            "Error: file write failed"
        )
    end

    return tmp
end

---@param fname string
---@param content? string|(string|number)[]
---@param flags? string default: bS
---@return string, (string|(string|number)[])?, string? args
function M.write_file(fname, content, flags)
    assert(
        vim.fn.writefile(
            type(content) == "table" and content or { content },
            fname,
            flags or "bS"
        ) == 0,
        "Error: file write failed"
    )

    return fname, content, flags
end

---@param buf? integer
---@return boolean
function M.buf_empty(buf)
    local lines = api.nvim_buf_get_lines(buf or 0, 0, -1, true)
    local t = type(lines)
    assert(t == "table", "expected table, got " .. t)
    local n = #lines
    return n < 2 and (lines[1] == "" or n == 0)
end

---Send signal `sig` to process `pid`.
---@param pid integer
---@param sig string
---@return nil
function M.kill(pid, sig)
    vim.fn.system({ "kill", "-s", sig, pid })

    assert(
        vim.v.shell_error == 0,
        "error: kill(): kill failed with exit code " .. vim.v.shell_error
    )
end

---Spawn an nvim instance.
---@param opts? { xargs: string[] }
---@return table
function M.start_nvim(opts)
    local job_opts = {
        width = 120,
        height = 80,
        detach = false,
        clear_env = false,
        -- env = {},
        pty = true,
        stderr_buffered = true,
        stdout_buffered = true,
    }

    local sock_addr = vim.fn.tempname()

    local jobid = vim.fn.jobstart({
        "nvim",
        "--clean",
        "--listen",
        sock_addr,
        unpack(opts and opts.xargs or {}),
    }, job_opts)

    local chan

    do
        local ok

        for _ = 1, 4 do
            ok, chan = pcall(function()
                return vim.fn.sockconnect("pipe", sock_addr, { rpc = true })
            end)

            if ok then break end
            sleep(500)
        end

        assert(ok, chan)
    end

    assert(
        chan ~= 0,
        "ERROR: sockconnect(): invalid arguments or connection failure"
    )

    local self = { sock = sock_addr, chan = chan, pid = vim.fn.jobpid(jobid) }

    function self:req(...)
        return vim.rpcrequest(self.chan, ...)
    end

    function self:suspend()
        assert(self:req("nvim_input", "<C-Z>") > 0)
    end

    function self:cont()
        M.kill(self.pid, "SIGCONT")
    end

    function self:stop()
        vim.fn.jobstop(jobid)
    end

    assert(
        self:req("nvim_eval", "v:vim_did_enter") == 1,
        "ERROR: vim has not entered yet"
    )

    return self
end

function M.with_nvim(opts, cb)
    if cb == nil then
        cb = opts
        opts = nil
    end

    local nvim = M.start_nvim(opts)
    cb(nvim)
    nvim:stop()
end

---@param autocmd string | string[]
---@param opts? {buffer: integer, pattern: string, once: boolean, nested: boolean, callback: function}
function M.autocmd(autocmd, opts)
    ---@type thread?
    local co
    opts = opts or {}
    local ret = { opts = opts, results = {} }
    if opts.buffer == nil and opts.pattern == nil then opts.pattern = "*" end
    if opts.once == nil then opts.once = false end
    if opts.nested == nil then opts.nested = true end

    api.nvim_create_autocmd(
        autocmd,
        vim.tbl_extend("force", opts, {
            callback = function(info)
                table.insert(ret.results, info)
                if opts.callback then opts.callback() end
                if co then coroutine.resume(co, ret) end
            end,
        })
    )

    -- {
    --     -- group = augroup,
    --     pattern = "*",
    --     -- desc = "",
    --     once = true,
    --     nested = true,
    --     callback = vim.schedule_wrap(function(info)
    --         coroutine.resume(co, info)
    --     end),
    -- })

    function ret:await()
        co = assert(
            coroutine.running(),
            "cannot await, not running in coroutine"
        )

        local timer = M.set_timeout(1e4, function()
            coroutine.resume(co, false, "timed out waiting for autocmd")
        end)

        local result = { coroutine.yield() }
        co = nil
        timer:stop()
        if not timer:is_closing() then timer:close() end
        return assert(unpack(result))
    end

    return ret
end

---@return nil
function M.await_vim_enter()
    if vim.v.vim_did_enter == 1 or vim.v.vim_did_enter == true then return end
    M.autocmd("VimEnter", { once = true }):await()
    M.await_schedule()
end

---@param fn function
---@return number ns
function M.time_it_once(fn)
    local hrtime = vim.loop.hrtime
    local start = hrtime()
    fn()
    return hrtime() - start
end

---@param times integer
---@param fn function
---@return number ns average time in nanoseconds
function M.time_it(times, fn)
    local res = {}
    local i = 0

    while i < times do
        table.insert(res, M.time_it_once(fn))
        i = i + 1
    end

    local sum = 0
    i = 0

    for _, x in ipairs(res) do
        sum = sum + x
        i = i + 1
    end

    return sum / i
end

---@param times integer
---@param fn function
function M.call_it(times, fn)
    for _ = 1, times do
        fn()
    end
end

---@param ms integer
---@param cb function
---@return unknown
function M.set_timeout(ms, cb)
    local timer = vim.loop.new_timer()

    timer:start(ms, 0, function()
        timer:stop()
        timer:close()
        cb()
    end)

    return timer
end

return M
