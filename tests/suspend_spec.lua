local api = vim.api
local sleep = vim.loop.sleep
local util = require("sos._test.util")

describe("test harness", function()
    it("can suspend and resume", function()
        local nvim = util.start_nvim()
        local got_suspend = util.tmpfile()
        local got_resume = util.tmpfile()
        local res = {}

        nvim:create_autocmd("VimSuspend", {
            once = true,
            nested = false,
            command = ("lua vim.fn.writefile({}, [[%s]])"):format(
                got_suspend
            ),
        })

        nvim:create_autocmd("VimResume", {
            once = true,
            nested = false,
            command = ("lua vim.fn.writefile({}, [[%s]])"):format(got_resume),
        })

        nvim:suspend()
        sleep(500)
        res.got_VimSuspend = util.file_exists(got_suspend)

        -- for extra confirmation of proc state, but doesn't seem to work
        -- local out = vim.fn.system { "ps", "-p", pid, "-o", "state=" }
        -- assert(out:find "^T", "ps output: " .. out)

        nvim:cont()
        sleep(500)
        res.got_VimResume = util.file_exists(got_resume)
        res.got_VimSuspend_after_resuming = not res.got_VimSuspend
            and util.file_exists(got_suspend)

        assert.are.same({
            got_VimSuspend = true,
            got_VimResume = true,
            got_VimSuspend_after_resuming = false,
        }, res)
    end)
end)

describe("neovim by default", function()
    -- NOTE: However, 'autowriteall' implies 'autowrite'!
    it("doesn't save on suspend when 'autowrite' is off", function()
        local nvim = util.start_nvim()
        local tmp = vim.fn.tempname()
        nvim:set_option("autowrite", false)
        nvim:set_option("autowriteall", false)
        nvim:buf_set_name(0, tmp)
        nvim:buf_set_lines(0, 0, -1, true, { "x" })
        nvim:suspend()
        sleep(500)
        assert(vim.loop.fs_stat(tmp) == nil, "expected file not to be saved")
        vim.fn.delete(tmp)
    end)

    it(
        "does save on suspend when 'autowrite' is on, even if &bufhidden = hide",
        function()
            local nvim = util.start_nvim()
            local tmp = vim.fn.tempname()
            nvim:buf_set_option(0, "bufhidden", "hide")
            nvim:set_option("autowrite", true)
            nvim:buf_set_name(0, tmp)
            nvim:buf_set_lines(0, 0, -1, true, { "x" })
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
        local nvim = util.start_nvim()
        local tmp = vim.fn.tempname()
        assert(vim.fn.writefile({ "old" }, tmp, "b") == 0)
        nvim:set_option("autoread", true)
        nvim:cmd({ cmd = "edit", args = { tmp } }, { output = false })
        sleep(500)
        nvim:suspend()
        sleep(500)
        assert(vim.fn.writefile({ "new" }, tmp, "b") == 0)
        sleep(500)
        nvim:cont()
        sleep(500)
        assert(table.concat(nvim:buf_get_lines(0, 0, -1, true), "") == "old")
        nvim:cmd({ cmd = "checktime" }, { output = false })
        assert(table.concat(nvim:buf_get_lines(0, 0, -1, true), "") == "new")
        vim.fn.delete(tmp)
    end)

    it("doesn't automatically check file times upon leaving term", function()
        local nvim = util.start_nvim({})
        local tmp = vim.fn.tempname()
        assert(vim.fn.writefile({ "old" }, tmp, "b") == 0)
        nvim:set_option("autoread", true)

        nvim:cmd({ cmd = "edit", args = { tmp } }, { output = false })

        local tab = nvim:get_current_tabpage()
        local buf = nvim:get_current_buf()
        nvim:cmd({ cmd = "tabnew" }, { output = false })
        nvim:cmd({ cmd = "tabnew" }, { output = false })

        -- enter term
        nvim:cmd({ cmd = "terminal" }, { output = false })
        nvim:cmd({ cmd = "startinsert" }, { output = false })

        -- modify file
        assert(vim.fn.writefile({ "new" }, tmp, "b") == 0)
        sleep(500)

        -- visit different tab thereby leaving term
        nvim:set_current_tabpage(tab) -- trigger sos to check file times (which triggers autoread)

        assert(
            table.concat(nvim:buf_get_lines(buf, 0, -1, true), "") == "old"
        )

        vim.fn.delete(tmp)
    end)
end)

-- TODO: For FileChangedShell, FileChangedShellPost
-- does it run when trying to save a buffer that has modifications and is out
-- of sync with file on fs? (changed internally and externally)
-- does it still run when autoread happens? (i.e. buffer wasn't modified and there'd be no default prompt)

describe("sos.nvim", function()
    it("should automatically check file times on resume", function()
        local nvim = util.start_nvim({
            xargs = {
                "-u",
                "tests/min_init.lua",
                "-c",
                [[call v:lua.require'sos'.setup(#{ enabled: v:true })]],
            },
        })

        local tmp = util.tmpfile("old")
        nvim:set_option("autoread", true)
        nvim:cmd({ cmd = "edit", args = { tmp } }, { output = false })
        sleep(500)
        nvim:suspend()
        sleep(500)
        assert(vim.fn.writefile({ "new" }, tmp, "b") == 0)
        sleep(500)
        nvim:cont()
        sleep(500)
        assert.are.same({ "new" }, nvim:buf_get_lines(0, 0, -1, true))
    end)

    it("should automatically check file times upon leaving term", function()
        local nvim = util.start_nvim({
            xargs = {
                "-u",
                "tests/min_init.lua",
                "-c",
                [[call v:lua.require'sos'.setup(#{ enabled: v:true })]],
            },
        })

        local tmp = util.tmpfile("old")
        nvim:set_option("autoread", true)

        nvim:cmd({ cmd = "edit", args = { tmp } }, { output = false })

        local tab = nvim:get_current_tabpage()
        local buf = nvim:get_current_buf()
        nvim:cmd({ cmd = "tabnew" }, { output = false })
        nvim:cmd({ cmd = "tabnew" }, { output = false })

        -- enter term
        nvim:cmd({ cmd = "terminal" }, { output = false })
        nvim:cmd({ cmd = "startinsert" }, { output = false })

        -- modify file
        assert(vim.fn.writefile({ "new" }, tmp, "b") == 0)
        sleep(500)

        -- visit different tab thereby leaving term
        nvim:set_current_tabpage(tab) -- trigger sos to check file times (which triggers autoread)
        assert.are.same({ "new" }, nvim:buf_get_lines(0, 0, -1, true))
    end)
end)
