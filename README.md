# 🆘 sos.nvim 🆘

Never manually save/write a buffer again!

This plugin is an autosaver for Neovim that automatically saves all of your changed buffers according to a predefined timeout value. The goals are:

- to offer a complete, set-and-forget autosave/autowrite solution that saves your buffers for you when you want/need them saved
- to offer at least some customization via options, as well as the ability to easily enable/disable
- to be better or more correct than `CursorHold` autosavers and not depend on `CursorHold` if feasible

**NOTE:** This plugin is still young and has not been extensively used or tested at this point in time.

**NOTE:** Except for `acwrite` type buffers, this plugin does not save buffers that don't already exist on the filesystem (this includes files which merely appear to not exist due to inadequate permissions). The point of this is to err on the conservative side and to try to avoid creating new files unexpectedly (although creating a new file is probably what you want 95% of the time), such as the plugin creating a file after you've deleted the file on purpose but not its corresponding buffer yet. This is the current, default behavior that may change or be improved upon (e.g. warn the user with messages/notifications that the buffer was not autosaved, or simply just handle this case more intelligently) in the future. <ins>**This means that the first write/save after creating a new buffer for a nonexistent file has to be done manually, as that will create the file!**</ins>

For any questions, help with setup, or general help, you can try [discussions][q&a]. For issues, bugs, apparent bugs, or feature requests, feel free to [open an issue][issues] or [create a pull request][prs].

## Installation

Simply use your preferred method of installing Vim/Neovim plugins.

### Example using `Plug`

To install this plugin via Plug, add the following line to your vimrc/init file, plug file, or any other file that gets sourced during Neovim's initialization:

```vim
Plug 'tmillr/sos.nvim'
```

After doing this, you will need to then either restart Neovim or execute `:Plug 'tmillr/sos.nvim'` on the cmdline. That registers the plugin with Plug and updates Neovim's `'runtimepath'` option (which allows you to use `require("sos")` in lua). Next, execute `:PlugInstall` on the cmdline. `PlugInstall` will download/install any registered plugins missing from the filesystem. At this point you will have the plugin/repo, but it is not enabled/running yet. To enable the plugin on-the-fly, use `:lua=require("sos").setup()` or `:SosEnable` on the cmdline, although it is best and standard-practice to simply add the `setup()` call to one of your init files (e.g. add `require("sos").setup()` to your init.lua) so that the plugin is started/enabled automatically during Neovim startup.

## Setup/Options

Listed below are all of the possible options that can be configured, along with their default values. Missing options will retain their current value (which will be their default value if never previously set, or if this is the first time calling `setup()` in this Neovim session). This means that `setup()` can be used later on to change just a single option while not touching/changing/resetting to default any of the other options. You can also pass `true` as a 2nd argument to `setup()` (i.e. `setup(opts, true)`) to reset all options to their default values before applying `opts`. If the plugin is started during Neovim's startup/init phase, the plugin will wait until Neovim has finished initializing before setting up its buffer and option observers (autocmds, buffer callbacks, etc.).

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
    --             in the cmdline (not perfect, but may lead to fewer unneeded
    --             file writes; implementation still needs some work, see
    --             lua/sos/impl.lua)
    --
    --     table<string, true>: table that specifies which commands should trigger
    --                          a write
    --                          keys: the full/long names of commands that should
    --                                trigger write
    --                          values: true
    save_on_cmd = "some",

    -- Save/write a changed buffer before leaving it (i.e. on the `BufLeave`
    -- autocmd event). This will lead to fewer buffers having to be written
    -- at once when the global/shared timer fires. Another reason for this is
    -- the fact that neither `'autowrite'` nor `'autowriteall'` cover this case,
    -- so it combines well with those options too.
    save_on_bufleave = true,

    -- Predicate fn which receives a buf number and should return true if it
    -- should be observed for changes (i.e. whether the buffer should debounce
    -- the shared/global timer). You probably don't want to change this unless
    -- you absolutely need to and know what you're doing. Setting this option
    -- will replace the default fn/behavior which is to observe buffers which
    -- have: a normal 'buftype', 'ma', 'noro'. See lua/sos/impl.lua for the
    -- default behavior/fn.
    --- @type fun(bufnr: integer): boolean
    -- should_observe_buf = require("sos.impl").should_observe_buf,

    -- The function that is called when the shared/global timer fires. You
    -- probably don't want to change this unless you absolutely need to and know
    -- what you're doing. Setting this option will replace the default
    -- fn/behavior, which is simply to write all modified (i.e. 'mod' option is
    -- set) buffers. See lua/sos/impl.lua for the default behavior/fn. Any value
    -- returned by this function is ignored. `vim.api.*` can be used inside this
    -- fn (this fn will be called with `vim.schedule()`).
    -- on_timer = require("sos.impl").on_timer,
}
```

## Commands

All of the available commands are defined [here](/plugin/sos.lua).

## Tips

- If you've decided to use this plugin and want a more complete autosave experience, then you'll probably want to set the `'autowrite'` or `'autowriteall'` Neovim options as well. I'm using `'autowrite'` myself at the moment.

- Decrease the `timeout` value if you'd like more frequent/responsive autosaving behavior (e.g. `10000` for 10 seconds, or `5000` for 5 seconds). It's probably best not to go below 5 seconds however.

## Interaction with format on save

I believe that there are generally 2 main reasons/pros for using format on save:

1. only having to manually save the file instead of manually format and then manually save
2. not having to worry about a file on the filesystem ever being in an unformatted state

If you have Neovim setup to format on save/write via autocmds, you may experience issues as sos will trigger autocmds when saving changed buffers. The issue when using sos is, that now saving occurs at random times, and may occur while you are in insert mode (you likely don't want formatting to occur while you're in insert mode).

TODO: provide (better) fix or suggestions, finish this section

In the meantime, if you are having issues due to a format-on-save setup and until a better solution is discovered, you can try:
- changing which autocmd/event triggers autoformatting (e.g. use `InsertLeave` instead)
- disabling format-on-save altogether

## License

[MIT](/LICENSE)

[issues]: /../../issues
[prs]: /../../pulls
[q&a]: /../../discussions/categories/q-a
