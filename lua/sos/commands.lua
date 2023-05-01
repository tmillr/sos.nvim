local api = vim.api
local extkeys = { action = true }

-- TODO: types

local function Command(def)
    return setmetatable(def, {
        __call = function(f, ...)
            return f.action(...)
        end,
    })
end

local function filter_extkeys(tbl)
    local ret = {}

    for k, v in pairs(tbl) do
        if extkeys[k] == nil then ret[k] = v end
    end

    return ret
end

local function Commands(parent, ret)
    ret = ret or {}

    for k, v in pairs(parent) do
        if type(v) == "table" and v.action then
            ret[k] = Command(v)
            api.nvim_create_user_command(k, v.action, filter_extkeys(v))
        else
            Commands(v, ret)
        end
    end

    return ret
end

return Commands {
    SosEnable = {
        desc = "Enable sos autosaver",
        action = function()
            require("sos").setup { enabled = true }
        end,
    },

    SosDisable = {
        desc = "Disable sos autosaver",
        action = function()
            require("sos").setup { enabled = false }
        end,
    },

    SosToggle = {
        desc = "Toggle sos autosaver",
        action = function()
            require("sos").setup {
                enabled = not require("sos.config").enabled,
            }
        end,
    },
}
