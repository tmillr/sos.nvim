local api = vim.api
local util = require("sos._test.util")

describe("while writing all modified bufs", function()
    before_each(function()
        util.await_vim_enter()
        vim.o.aw = false
        vim.o.awa = false
        vim.o.confirm = false
        vim.cmd("silent %bw!")
    end)

    it("errors are caught (and further bufs may be written)", function()
        local bufs = {}
        util.setup_plugin()

        -- This one will error
        local tmp = util.tmpfile()
        util.silent_edit(tmp)
        table.insert(bufs, api.nvim_get_current_buf())
        vim.bo.bh = "hide"
        util.write_file(tmp)

        util.silent_edit(util.tmpfile(""))
        table.insert(bufs, api.nvim_get_current_buf())
        vim.bo.bh = "hide"

        -- This test relies on the buffers being written in the same order that
        -- they were created (the error must come first). The implementation
        -- iterates over `nvim_list_bufs()` to write all buffers, which should
        -- return all buffers in ascending order.
        do
            local all_bufs = api.nvim_list_bufs()

            for i = 2, #all_bufs do
                assert(all_bufs[i] > all_bufs[i - 1])
            end
        end

        for _, buf in ipairs(bufs) do
            api.nvim_buf_set_lines(buf, 0, -1, true, { "modifications" })
            assert.is.True(vim.bo[buf].mod)
        end

        vim.v.errmsg = ""

        api.nvim_feedkeys(
            api.nvim_replace_termcodes(
                ":lua local _ = nil<CR>",
                true,
                false,
                true
            ),
            "ntx",
            false
        )

        -- Assert that there was an error
        assert(vim.v.errmsg:find("sos.nvim"))

        assert(
            vim.v.errmsg:find("[Vv]im%s*:%s*[Ee]13%s*:"),
            "got the wrong error, expected error E13"
        )

        assert.is.True(vim.bo[bufs[1]].mod)
        assert.is.False(vim.bo[bufs[2]].mod)
    end)
end)
