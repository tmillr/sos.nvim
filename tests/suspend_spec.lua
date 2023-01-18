local api = vim.api
local sleep = vim.loop.sleep
local t = require("sos._test")

describe("test harness", function()
    it("can suspend and resume", function()
        local nvim = t.start_nvim()

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

        -- for extra confirmation of proc state, but doesn't seem to work
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
        local nvim = t.start_nvim()
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
            local nvim = t.start_nvim()
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
        local nvim = t.start_nvim()
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
        local nvim = t.start_nvim({})
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

-- TODO: For FileChangedShell, FileChangedShellPost
-- does it run when trying to save a buffer that has modifications and is out
-- of sync with file on fs? (changed internally and externally)
-- does it still run when autoread happens? (i.e. buffer wasn't modified and there'd be no default prompt)

describe("sos.nvim", function()
    it("should automatically check file times on resume", function()
        local nvim = t.start_nvim({
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
        local nvim = t.start_nvim({
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
