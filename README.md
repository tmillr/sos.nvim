# 🆘 sos.nvim 🆘

Never manually save/write a buffer again!

## Installation

Simply use your preferred method of installing Vim/Neovim plugins.

#### Example using `Plug`

Add the following line to your vimrc/init file, plug file, or any other file that gets sourced during initialization:

```vim
Plug 'tmillr/sos.nvim'
```

## Setup/Options

Listed below are all of the possible options that can be configured along with their default values. Missing options will fallback to their default value. The plugin will not start until it is required (or enabled with `:SosEnable`). If the plugin is started during Neovim's startup/init phase, the plugin will wait until Neovim has finished initializing (before setting up its buffer and option observers).

```lua
require("sos").setup {
    -- Whether to enable the plugin.
    enabled = true,
    
    -- Time in ms after which on_timer() will be called.
    -- By default, on_timer() is called 20 seconds after the last buffer change.
    -- Whenever an observed buffer changes, the global timer is started (or reset, if it was already started),
    -- and a countdown of `timeout` milliseconds begins. Further buffer changes will then debounce the timer.
    -- After firing, the timer is not started again until the next buffer change.
    timeout = 20000,
    
    -- Automatically write all modified buffers before executing a command on the cmdline.
    -- Aborting the cmdline likewise aborts the write.
    -- NOTE: autocmds will be executed as a result of the writing (i.e. `nested = true`).
    -- "all": write on any command executed 
    -- "some": write if certain cmds (source, or luafile, etc.) appear in cmdline (not perfect)
    -- table<string, true>: table that specifies which cmds should trigger write
    --     keys = full/long names of cmds that should trigger write
    --     vals = true
    save_on_cmd = "some",
    
    -- Predicate fn which receives a buf number and returns true if it should be observed for changes.
    -- You probably don't want to change this, but the option is provided anyway for customization purposes.
    -- Setting this option will replace the default fn/behavior.
    -- The default fn/behavior is to observe buffers which have: a normal 'buftype', 'ma', 'noro'.
    -- (bufnr: integer) -> boolean
    -- should_observe_buf = require("sos.impl").should_observe_buf,
    
    -- The function that is called when the global timer fires.
    -- You probably don't want to change this, but the option is provided anyway for customization purposes.
    -- Setting this option will replace the default fn/behavior.
    -- The default fn/behavior simply writes all modified ('mod') buffers.
    -- () -> nil
    -- on_timer = require("sos.impl").on_timer,
}
```

## Tips

- If you've decided to use this plugin and want a more complete autosave experience, then you'll probably want to set the `'autowrite'` or `'autowriteall'` Neovim options as well. I'm using `'autowrite'` myself at the moment.

- Decrease the `timeout` value for more frequent/responsive autosaving behavior (e.g. `10000` for 10 seconds, or `5000` for 5 seconds).
