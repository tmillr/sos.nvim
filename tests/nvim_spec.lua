local api = vim.api

describe("buffer callbacks", function()
    it("should detach on unload", function()
        local buf = api.nvim_create_buf(true, false)
        local detached
        vim.api.nvim_buf_attach(buf, false, {
            on_detach = function()
                detached = true
            end,
            on_lines = print,
        })
        vim.cmd.bunload(buf)
        assert(detached, "buf callbacks did not detach")
    end)
end)

describe("vim.api.nvim_buf_call()", function()
    it("shouldn't end insert mode", function()
        local script = [[lua << EOF
local api = vim.api
local tmpdir = assert(vim.loop.fs_mkdtemp(vim.loop.os_tmpdir() .. "/XXXXXX"))

vim.api.nvim_create_autocmd("VimLeavePre", {
    pattern = "*",
    once = true,
    nested = false,
    callback = function()
        vim.fn.delete(tmpdir, "rf")
    end,
})

local function assert(res, msg)
    if not res then
        print("ERROR: " .. msg)
        vim.cmd "1cq"
    end

    return res
end

local no_win = api.nvim_create_buf(true, false)
assert(no_win ~= 0, "buf creation failed")
assert(api.nvim_buf_is_loaded(no_win), "new buf is not loaded")
vim.cmd.new()
assert(#api.nvim_list_wins() == 2, "expected 2 windows")
local did_enter_insert = false
local did_leave_insert = false

api.nvim_create_autocmd("ModeChanged", {
    pattern = "*:i*",
    once = true,
    nested = true,
    callback = function(_info)
        did_enter_insert = true
        assert(#api.nvim_list_bufs() == 3)

        for i, buf in ipairs(api.nvim_list_bufs()) do
            assert(
                api.nvim_buf_is_loaded(no_win),
                "unloaded buf " .. tostring(buf)
            )

            api.nvim_buf_call(buf, function()
                vim.cmd.write(tmpdir .. "delete-me-" .. i)
            end)
        end
    end,
})

api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    callback = function()
        did_leave_insert = true
    end,
})

vim.defer_fn(function()
    assert(did_enter_insert == true, "never entered insert mode")
    assert(did_leave_insert == false, "left insert mode")
    assert(
        vim.startswith(api.nvim_get_mode().mode, "i"),
        "finished in non-insert mode"
    )
    vim.cmd "0cq"
end, 6000)

vim.cmd.startinsert()
EOF]]

        local res = vim.fn.system({
            "nvim",
            "--headless",
            "--clean",
            "--cmd",
            "set noshowcmd noshowmode",
            "+source",
            "-",
        }, script)

        assert(vim.v.shell_error == 0, res)
    end)
end)
