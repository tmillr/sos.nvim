-- TODO: refactor test lib/utils so they can be shared/required and create
-- dirs for each test type (e2e, unit, etc.) so things are better organized,
-- re-usable fn for testing autoread/checktime, seamless rpc requests via
-- metatable

local M = {}
local api = vim.api
local sleep = vim.loop.sleep

function M.write_file(fname, lines)
    assert(
        vim.fn.writefile(lines, fname, "b") == 0,
        "Error: file write failed"
    )
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

return M
