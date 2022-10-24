--- @class sos.Config                                                      # Plugin options passed to `setup()`.
--- @field enabled boolean | nil                                           # Whether to enable or disable the plugin.
--- @field timeout integer | nil                                           # Timeout in ms. Buffer changes debounce the timer.
--- @field save_on_cmd "all" | "some" | table<string, true> | false | nil  # Save all buffers before executing a command on cmdline
--- @field save_on_bufleave boolean | nil                                  # Save current buffer on `BufLeave` (see `:h BufLeave`)
--- @field should_observe_buf nil | fun(buf: integer): boolean             # Return true to observe/attach to buf.
--- @field on_timer function                                               # The function to call when the timer fires.
local defaults = {
    enabled = true,
    timeout = 20000,
    save_on_cmd = "some",
    save_on_bufleave = true,
    should_observe_buf = require("sos.impl").should_observe_buf,
    on_timer = require("sos.impl").on_timer,
}

return setmetatable({}, { __index = defaults })
