local api = vim.api
local t = require("sos._test")
local CR = api.nvim_replace_termcodes("<CR>", true, false, true)
local ESC = api.nvim_replace_termcodes("<Esc>", true, false, true)
local state

local function assert_preconditions()
    assert(vim.o.mod, "buffer not modified, can't run test")
    assert.are.equal("n", api.nvim_get_mode().mode)
end

local function create_test_fn(opts)
    return function()
        assert_preconditions()

        api.nvim_feedkeys(
            opts.cmdline .. (opts.abort_cmdline and ESC or CR),
            "mtx",
            false
        )

        -- Should be done with cmdline and back in normal mode now
        assert.are.equal("n", api.nvim_get_mode().mode)

        if opts.expect_autocmd ~= nil then
            assert(
                (state.autocmd_ran or false) == opts.expect_autocmd,
                "autocmd did, or didn't, run, mismatching expectation"
            )

            if opts.expect_save_before_cmdline_exec then
                assert(
                    state.buf_saved_prior_to_cmdline_exec,
                    "buf wasn't saved prior to cmdline execution"
                )
            end
        end

        if opts.expect_save then
            assert.is_false(vim.o.mod)
        else
            assert.is_true(vim.o.mod)
        end
    end
end

describe("save on cmd", function()
    local tmp
    -- vim.cmd("SosEnable")
    require("sos").setup({ enabled = true, timeout = 600000 })

    -- Cmdlines which should trigger a save prior to executing
    local should_save = { ":luafile %", ":source %" }
    local shouldnt_save = { ":SosDisable", ":SosToggle" }

    before_each(function()
        vim.cmd("bw!")
        state = {}
        tmp = vim.fn.tempname() .. ".lua"
        vim.cmd.edit(tmp)
        vim.cmd.write()
        api.nvim_buf_set_lines(0, 0, -1, true, {})
        -- Ensure that we're in normal mode
        api.nvim_feedkeys(ESC .. ESC, "ntx", false)
    end)

    after_each(function()
        vim.fn.delete(tmp)
    end)

    it("wait for VimEnter", function()
        t.autocmd("VimEnter"):await()

        api.nvim_create_autocmd("CmdlineLeave", {
            -- group = augroup,
            pattern = ":",
            once = false,
            nested = false,
            callback = function(_info)
                state.autocmd_ran = true
                state.buf_saved_prior_to_cmdline_exec = not vim.o.mod
                print("Command Line:", vim.fn.getcmdline())
            end,
        })
    end)

    for _, cmdline in ipairs(should_save) do
        it(
            string.format("should save on: %s<CR>", cmdline),
            create_test_fn({
                cmdline = cmdline,
                abort_cmdline = false,
                expect_autocmd = true,
                expect_save = true,
                expect_save_before_cmdline_exec = true,
            })
        )
    end

    for _, cmdline in ipairs(should_save) do
        it(
            string.format(
                "shouldn't save if cmdline aborted: %s<Esc>",
                cmdline
            ),
            create_test_fn({
                cmdline = cmdline,
                abort_cmdline = true,
                expect_autocmd = true,
                expect_save = false,
            })
        )
    end

    for _, cmdline in ipairs(shouldnt_save) do
        it(
            string.format("shouldn't save on: %s<CR>", cmdline),
            create_test_fn({
                cmdline = cmdline,
                abort_cmdline = false,
                expect_autocmd = true,
                expect_save = false,
            })
        )
    end
end)
