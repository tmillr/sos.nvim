vim.o.updatecount = 0
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.o.more = false
vim.o.shortmessage = "FWI"
vim.opt.rtp:append(vim.fn.expand("<sfile>:h:h"))
-- vim.opt.rtp:append(vim.fn.stdpath("data") .. "/plugged/plenary.nvim")
-- vim.cmd "runtime! plugin/**/*.vim"
-- vim.cmd "runtime! plugin/**/*.lua"

local plenary = vim.env.PLENARY

if not plenary then
    for _, val in ipairs({ "PATH", "DIR" }) do
        plenary = vim.env["PLENARY" .. val] or vim.env["PLENARY_" .. val]
        if plenary then break end
    end
end

if not plenary then
    for _, dir in ipairs({
        vim.fn.stdpath("data"),
        vim.fn.stdpath("data_dirs"),
    }) do
        plenary = vim.fs.find(
            "plenary.nvim",
            { path = dir, limit = 1, type = "directory" }
        ) or {}

        if #plenary > 0 then
            plenary = plenary[1]
            break
        else
            plenary = nil
        end
    end
end

assert(
    plenary,
    "unable to find plenary.nvim, please specify path with PLENARY="
)

vim.opt.rtp:append(plenary)

for _, ext in ipairs({ "vim", "lua" }) do
    vim.cmd("runtime! plugin/plenary." .. ext)
    vim.cmd("runtime! plugin/sos." .. ext)
end
