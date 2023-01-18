vim.api.nvim_create_user_command("SosEnable", function()
    require("sos").setup({ enabled = true })
end, { desc = "Enable sos autosaver" })

vim.api.nvim_create_user_command("SosDisable", function()
    require("sos").setup({ enabled = false })
end, { desc = "Disable sos autosaver" })

vim.api.nvim_create_user_command("SosToggle", function()
    require("sos").setup({ enabled = not require("sos.config").enabled })
end, { desc = "Toggle sos autosaver" })
