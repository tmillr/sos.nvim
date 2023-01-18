-- TODO: refactor test lib/utils so they can be shared/required and create dirs for each test type (e2e, unit, etc.) so things are better organized, re-usable fn for testing autoread/checktime, seamless rpc requests via metatable

local api = vim.api
local sleep = vim.loop.sleep

local function kill(pid, sig)
    vim.fn.system({ "kill", "-s", sig, pid })
    assert(
        vim.v.shell_error == 0,
        "kill failed with exit code " .. vim.v.shell_error
    )
end

--- spawn an nvim instance
local function start_nvim(opts)
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
        kill(self.pid, "SIGCONT")
    end

    return self
end

describe("test harness", function()
    it("can suspend and resume", function()
        local nvim = start_nvim()

        nvim:req("nvim_create_autocmd", "VimSuspend", {
            pattern = "*",
            once = true,
            nested = false,
            command = "let g:got_suspend = v:true",
        })

        nvim:req("nvim_create_autocmd", "VimResume", {
            pattern = "*",
            once = true,
            nested = false,
            command = "let g:got_resume = v:true",
        })

        nvim:suspend()
        sleep(1000)
        -- local out = vim.fn.system { "ps", "-p", pid, "-o", "state=" }
        -- assert(out:find "^T", "ps output: " .. out)
        nvim:cont()
        sleep(1000)
        assert(nvim:req("nvim_eval", "g:got_suspend") == true)
        assert(nvim:req("nvim_eval", "g:got_resume") == true)
    end)
end)

describe("neovim by default", function()
    -- NOTE: However, 'autowriteall' implies 'autowrite'!
    it("doesn't save on suspend when 'autowrite' is off", function()
        local nvim = start_nvim()
        local tmp = vim.fn.tempname()
        nvim:req("nvim_set_option", "autowrite", false)
        nvim:req("nvim_set_option", "autowriteall", false)
        nvim:req("nvim_buf_set_name", 0, tmp)
        nvim:req("nvim_buf_set_lines", 0, 0, -1, true, { "x" })
        nvim:suspend()
        sleep(500)
        assert(vim.loop.fs_stat(tmp) == nil, "expected file not to be saved")
        vim.fn.delete(tmp)
    end)

    it(
        "does save on suspend when 'autowrite' is on, even if &bufhidden = hide",
        function()
            local nvim = start_nvim()
            local tmp = vim.fn.tempname()
            nvim:req("nvim_buf_set_option", 0, "bufhidden", "hide")
            nvim:req("nvim_set_option", "autowrite", true)
            nvim:req("nvim_buf_set_name", 0, tmp)
            nvim:req("nvim_buf_set_lines", 0, 0, -1, true, { "x" })
            nvim:suspend()
            sleep(500)
            local stat = assert(vim.loop.fs_stat(tmp))
            assert(
                stat.type == "file",
                "dirent exists but isn't a regular file"
            )
            vim.fn.delete(tmp)
        end
    )

    -- :checktime implicitly triggers re-read of all files that've changed
    -- outside vim which were not also 'modified' in that vim (i.e. had pending
    -- changes which weren't saved yet).
    --
    -- For files which are also 'modified' in the current vim, an err/warn msg
    -- (or prompt asking how to proceed) will print including the filename.
    --
    -- The goal is to autosave often (and in crucial moments such as before
    -- suspending) in order to try to avoid such situations as the latter.
    --
    -- This test here is to make sure that it's ok to implement this ourselves
    -- without duplicating work (e.g. if this feature ever gets implemented in
    -- neovim itself (i.e. upstream) someday), the feature in question being:
    -- the checking of file times on vim resume.
    it("doesn't do `:checktime` nor autoread on resume", function()
        local nvim = start_nvim()
        local tmp = vim.fn.tempname()
        assert(vim.fn.writefile({ "old" }, tmp, "b") == 0)
        nvim:req("nvim_set_option", "autoread", true)
        nvim:req(
            "nvim_cmd",
            { cmd = "edit", args = { tmp } },
            { output = false }
        )
        sleep(500)
        nvim:suspend()
        sleep(500)
        assert(vim.fn.writefile({ "new" }, tmp, "b") == 0)
        sleep(500)
        nvim:cont()
        sleep(500)
        assert(
            table.concat(nvim:req("nvim_buf_get_lines", 0, 0, -1, true), "")
                == "old"
        )
        nvim:req("nvim_cmd", { cmd = "checktime" }, { output = false })
        assert(
            table.concat(nvim:req("nvim_buf_get_lines", 0, 0, -1, true), "")
                == "new"
        )
        vim.fn.delete(tmp)
    end)

    it("doesn't automatically check file times upon leaving term", function()
        local nvim = start_nvim({})
        local tmp = vim.fn.tempname()
        assert(vim.fn.writefile({ "old" }, tmp, "b") == 0)
        nvim:req("nvim_set_option", "autoread", true)

        nvim:req(
            "nvim_cmd",
            { cmd = "edit", args = { tmp } },
            { output = false }
        )

        local tab = nvim:req("nvim_get_current_tabpage")
        local buf = nvim:req("nvim_get_current_buf")
        nvim:req("nvim_cmd", { cmd = "tabnew" }, { output = false })
        nvim:req("nvim_cmd", { cmd = "tabnew" }, { output = false })

        -- enter term
        nvim:req("nvim_cmd", { cmd = "terminal" }, { output = false })
        nvim:req("nvim_cmd", { cmd = "startinsert" }, { output = false })

        -- modify file
        assert(vim.fn.writefile({ "new" }, tmp, "b") == 0)
        sleep(500)

        -- visit different tab thereby leaving term
        nvim:req("nvim_set_current_tabpage", tab) -- trigger sos to check file times (which triggers autoread)

        assert(
            table.concat(nvim:req("nvim_buf_get_lines", buf, 0, -1, true), "")
                == "old"
        )

        vim.fn.delete(tmp)
    end)
end)

describe("sos.nvim", function()
    it("should automatically check file times on resume", function()
        local nvim = start_nvim({
            xargs = {
                "-u",
                "tests/min_init.lua",
                "-c",
                [[call v:lua.require'sos'.setup(#{ enabled: v:true })]],
            },
        })
        local tmp = vim.fn.tempname()
        assert(vim.fn.writefile({ "old" }, tmp, "b") == 0)
        nvim:req("nvim_set_option", "autoread", true)
        nvim:req(
            "nvim_cmd",
            { cmd = "edit", args = { tmp } },
            { output = false }
        )
        sleep(500)
        nvim:suspend()
        sleep(500)
        assert(vim.fn.writefile({ "new" }, tmp, "b") == 0)
        sleep(500)
        nvim:cont()
        sleep(500)
        assert(
            table.concat(nvim:req("nvim_buf_get_lines", 0, 0, -1, true), "")
                == "new"
        )
        vim.fn.delete(tmp)
    end)

    it("should automatically check file times upon leaving term", function()
        local nvim = start_nvim({
            xargs = {
                "-u",
                "tests/min_init.lua",
                "-c",
                [[call v:lua.require'sos'.setup(#{ enabled: v:true })]],
            },
        })

        local tmp = vim.fn.tempname()
        assert(vim.fn.writefile({ "old" }, tmp, "b") == 0)
        nvim:req("nvim_set_option", "autoread", true)

        nvim:req(
            "nvim_cmd",
            { cmd = "edit", args = { tmp } },
            { output = false }
        )

        local tab = nvim:req("nvim_get_current_tabpage")
        local buf = nvim:req("nvim_get_current_buf")
        nvim:req("nvim_cmd", { cmd = "tabnew" }, { output = false })
        nvim:req("nvim_cmd", { cmd = "tabnew" }, { output = false })

        -- enter term
        nvim:req("nvim_cmd", { cmd = "terminal" }, { output = false })
        nvim:req("nvim_cmd", { cmd = "startinsert" }, { output = false })

        -- modify file
        assert(vim.fn.writefile({ "new" }, tmp, "b") == 0)
        sleep(500)

        -- visit different tab thereby leaving term
        nvim:req("nvim_set_current_tabpage", tab) -- trigger sos to check file times (which triggers autoread)

        assert(
            table.concat(nvim:req("nvim_buf_get_lines", buf, 0, -1, true), "")
                == "new"
        )

        vim.fn.delete(tmp)
    end)
end)
