vim.opt.rtp:append(vim.fn.expand("<sfile>:h:h"))
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/plugged/plenary.nvim")
-- vim.cmd "runtime! plugin/**/*.vim"
-- vim.cmd "runtime! plugin/**/*.lua"

for _, ext in ipairs({ "vim", "lua" }) do
    vim.cmd("runtime! plugin/plenary." .. ext)
    vim.cmd("runtime! plugin/sos." .. ext)
end
