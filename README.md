# 🆘 sos.nvim 🆘

Never manually save/write a buffer again!

This plugin is an autosaver for Neovim that automatically saves all of your changed buffers according to a predefined timeout value. The goals are:

- to offer a complete, set-and-forget autosave/autowrite solution that saves your buffers for you when you want/need them saved
- to offer at least some customization via options, as well as the ability to easily enable/disable
- to be better or more correct than `CursorHold` autosavers and not depend on `CursorHold` if possible

**NOTE:** This plugin is still new and has not been used/tested much at this point in time. Please open an issue if you think you've encountered a bug or have a feature/option that you'd like to request.

**NOTE:** Except for `acwrite` type buffers, this plugin does not save buffers that don't already exist on the filesystem. This is the current, default behavior although that may change in the future.

## Installation

Simply use your preferred method of installing Vim/Neovim plugins.

### Example using `Plug`

Add the following line to your vimrc/init file, plug file, or any other file that gets sourced during Neovim's initialization:

```vim
Plug 'tmillr/sos.nvim'
```

After doing this, you will need to then either restart Neovim or execute `:Plug 'tmillr/sos.nvim'` on the cmdline. This registers the plugin with Plug and updates Neovim's `'runtimepath'` option. Next, execute `:PlugInstall` on the cmdline (which will download/install any registered plugins missing from the filesystem). Now you have the plugin, but it is not enabled/running yet. To enable the plugin on-the-fly, use `:lua=require("sos").setup()` or `:SosEnable` on the cmdline, although it is best and standard-practice to simply add the `setup()` call to one of your init files (e.g. add `require("sos").setup()` to your init.lua) so that the plugin is started/enabled automatically during Neovim startup.

## Setup/Options

Listed below are all of the possible options that can be configured along with their default values. Missing options will retain their current value (which will be their default value if never previously set or if this is the first time calling `setup()` in this Neovim session). If the plugin is started during Neovim's startup/init phase, the plugin will wait until Neovim has finished initializing before setting up its buffer and option observers (autocmds, buffer callbacks, etc.).

```lua
require("sos").setup {
    -- Whether to enable the plugin
    enabled = true,

    -- Time in ms after which `on_timer()` will be called. By default, `on_timer()`
    -- is called 20 seconds after the last buffer change. Whenever an observed
    -- buffer changes, the global timer is started (or reset, if it was already
    -- started), and a countdown of `timeout` milliseconds begins. Further buffer
    -- changes will then debounce the timer. After firing, the timer is not
    -- started again until the next buffer change.
    timeout = 20000,

    -- Automatically write all modified buffers before executing a command on
    -- the cmdline. Aborting the cmdline (e.g. via `<Esc>`) also aborts the
    -- write. The point of this is so that you don't have to manually write a
    -- buffer before running commands such as `:luafile`, `:soruce`, or a `:!`
    -- shell command which reads files (such as git or a code formatter).
    -- Autocmds will be executed as a result of the writing (i.e. `nested = true`).
    --
    --     false: don't write changed buffers prior to executing a command
    --
    --     "all": write on any `:` command that gets executed (but not `<Cmd>`
    --            mappings)
    --
    --     "some": write only if certain commands (source/luafile etc.) appear
    --             in the cmdline (not perfect but may lead to fewer unneeded
    --             file writes; implementation needs some work)
    --
    --     table<string, true>: table that specifies which commands should trigger
    --                          a write
    --         keys: the full/long names of commands that should trigger write
    --         values: true
    save_on_cmd = "some",

    -- Save/write a changed buffer before leaving it (i.e. on the `BufLeave`
    -- autocmd event). This will lead to fewer buffers having to be written
    -- at once when the global/shared timer fires. Another reason for this is
    -- the fact that neither `'autowrite'` nor `'autowriteall'` cover this case,
    -- so it combines well with those options too.
    save_on_bufleave = true,

    -- Predicate fn which receives a buf number and should return true if it
    -- should be observed for changes (i.e. whether the buffer should debounce
    -- the shared/global timer). You probably don't want to change this, but the
    -- option is provided anyway for customization purposes. Setting this option
    -- will replace the default fn/behavior which is to observe buffers which
    -- have: a normal 'buftype', 'ma', 'noro'. See lua/sos/impl.lua for the
    -- default behavior/fn.
    --- @type fun(bufnr: integer): boolean
    -- should_observe_buf = require("sos.impl").should_observe_buf,

    -- The function that is called when the shared/global timer fires. You
    -- probably don't want to change this, but the option is provided anyway for
    -- customization purposes. Setting this option will replace the default
    -- fn/behavior, which is simply to write all modified (i.e. 'mod' option is
    -- set) buffers. See lua/sos/impl.lua for the default behavior/fn. Any value
    -- returned by this function is ignored. `vim.api.*` can be used inside this
    -- fn (this fn will be called with `vim.schedule()`).
    -- on_timer = require("sos.impl").on_timer,
}
```

## Tips

- If you've decided to use this plugin and want a more complete autosave experience, then you'll probably want to set the `'autowrite'` or `'autowriteall'` Neovim options as well. I'm using `'autowrite'` myself at the moment.

- Decrease the `timeout` value if you'd like more frequent/responsive autosaving behavior (e.g. `10000` for 10 seconds, or `5000` for 5 seconds). It's probably best not to go below 5 seconds however.

## License

TODO
