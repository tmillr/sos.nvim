local api = vim.api
local util = require "sos._test.util"

describe("nvim_buf_attach() buf callbacks", function()
    it("should detach on buf unload", function()
        local buf = api.nvim_create_buf(true, false)
        local detached

        api.nvim_buf_attach(buf, false, {
            on_detach = function()
                detached = true
            end,
            on_lines = print,
        })

        vim.cmd.bunload(buf)
        assert(detached, "buf callbacks did not detach")
    end)
end)

describe("nvim_buf_call()", function()
    before_each(function()
        vim.cmd "silent %bw"
    end)

    it("shouldn't end insert mode", function()
        util.silent_edit(util.tmpfile "")
        local buf1 = api.nvim_get_current_buf()
        vim.cmd "silent tabnew"
        util.silent_edit(util.tmpfile())
        local buf2 = api.nvim_get_current_buf()
        api.nvim_buf_set_lines(buf1, 0, -1, true, { "mods" })
        api.nvim_buf_set_lines(buf2, 0, -1, true, { "mods" })

        vim.cmd.startinsert()

        local mode_changes = util.autocmd("ModeChanged", { pattern = "*" })
            :await()

        for _ = 1, 2 do
            util.await_schedule()
            assert.equals(1, #mode_changes.results, vim.inspect(mode_changes))

            assert.equals(
                "i",
                api.nvim_get_mode().mode:sub(1, 1),
                "expected to be in (i)nsert mode"
            )

            api.nvim_buf_call(buf1, function()
                vim.cmd "silent write"
            end)

            api.nvim_buf_call(buf2, function()
                vim.cmd "silent write"
            end)
        end

        assert.equals(0, #vim.fn.getbufinfo { bufmodified = true })
    end)

    it("shouldn't trigger autocmds", function()
        util.silent_edit(util.tmpfile())
        local buf = api.nvim_get_current_buf()
        vim.cmd "silent tabnew"
        local a = util.autocmd { "BufEnter", "BufLeave" }

        api.nvim_buf_call(buf, function()
            vim.cmd "silent write"
        end)

        util.await_schedule()
        assert.equals(0, #a.results)
    end)
end)
