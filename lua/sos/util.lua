local api = vim.api
local M = {}

do
    -- TODO
    local msg_type = {}

    --- Display an error message
    ---@param msg string
    ---@param how? "n" | "no"
    ---@return nil
    function M.errmsg(msg, how)
        return (msg_type[how] or api.nvim_err_writeln)("[sos.nvim]: " .. msg)
    end
end

return M
