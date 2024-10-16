# 🆘 sos.nvim 🆘

<a href="https://github.com/tmillr/sos.nvim/releases/latest"><img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/tmillr/sos.nvim?label=&logo=semver&sort=semver&color=%2328A745&labelColor=%23384047&logoColor=%23959DA5"/></a>
<a href="https://github.com/tmillr/sos.nvim/actions/workflows/format.yml"><img alt="Format" src="https://github.com/tmillr/sos.nvim/actions/workflows/format.yml/badge.svg"/></a>
<a href="https://github.com/tmillr/sos.nvim/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/tmillr/sos.nvim/actions/workflows/ci.yml/badge.svg"/></a>

Never manually save/write a buffer again!

This plugin is an autosaver for Neovim that automatically saves all of your changed buffers according to a predefined timeout value. Its main goals are:

- To handle conditions/situations that `'autowriteall'` does not
- To offer a complete, set-and-forget autosave/autowrite solution that saves your buffers for you when you need them saved
- To offer at least some customization via options, as well as the ability to easily enable/disable
- To be better or more correct than `CursorHold` autosavers and not depend on `CursorHold`

### Additional Features

- Has its own independent timer, distinct from `'updatetime'`, which may be set to any value in ms
- Timer is only started/reset on savable buffer changes, not cursor movements or other irrelevant events
- Keeps buffers in sync with the filesystem by frequently running `:checktime` in the background for you (e.g. on `CTRL-Z` or suspend, resume, command, etc.)
- Intelligently ignores `'readonly'` and other such unwritable buffers/files (i.e. the writing of files with insufficient permissions must be attempted manually with `:w`)
- [Tested](https://github.com/tmillr/sos.nvim/tree/master/tests)

For any questions, help with setup, or general help, you can try [discussions][q&a]. For issues, bugs, apparent bugs, or feature requests, feel free to [open an issue][issues] or [create a pull request][prs].

## Installation

Simply use your preferred method of installing Vim/Neovim plugins.

### LuaRocks (HEAD)

```sh
luarocks install --dev sos.nvim
```

### LuaRocks (latest release)

```sh
luarocks install sos.nvim
```

### Example using `Plug`

To install this plugin via Plug, add the following line to your vimrc/init file, plug file, or any other file that gets sourced during Neovim's initialization:

```vim
Plug 'tmillr/sos.nvim'
```

After doing this, you will need to then either restart Neovim or execute `:Plug 'tmillr/sos.nvim'` on the cmdline. That registers the plugin with Plug and updates Neovim's `'runtimepath'` option (which allows you to use `require("sos")` in lua). Next, execute `:PlugInstall` on the cmdline. `PlugInstall` will download/install any registered plugins missing from the filesystem. At this point you will have the plugin/repo, but it is not enabled/running yet. To enable the plugin on-the-fly, use `:lua=require("sos").setup()` or `:SosEnable` on the cmdline, although it is best and standard-practice to simply add the `setup()` call to one of your init files (e.g. add `require("sos").setup()` to your init.lua) so that the plugin is started/enabled automatically during Neovim startup.

## Setup/Options

Listed below are all of the possible options that can be configured along with their default values. Missing options will use their default value. If the plugin is started during Neovim's startup/init phase, the plugin will wait until Neovim has finished initializing before setting up its buffer and option observers (autocmds, buffer callbacks, etc.).

<!-- BEGIN GENERATED DEFAULTS -->

```lua
require('sos').setup {
  ---Whether to enable the plugin.
  enabled = true,

  ---Timeout in milliseconds for the global timer. Buffer changes debounce the
  ---timer.
  timeout = 10000,

  ---Automatically create missing parent directories when writing/autosaving a
  ---buffer.
  create_parent_dirs = true,

  ---Whether to set and manage Vim's 'autowrite' option.
  ---
  ---### Choices:
  ---
  ---  - "all": set and manage 'autowriteall'
  ---  - true : set and manage 'autowrite'
  ---  - false: don't set or manage any of Vim's 'autowwrite' options
  autowrite = true,

  ---Save all buffers before executing a `:` command on the cmdline (does not
  ---include `<Cmd>` mappings).
  ---
  ---### Choices:
  ---
  ---  - "all"                 : save on any cmd that gets executed
  ---  - "some"                : only for some commands (source, luafile, etc.).
  ---                            not perfect, but may lead to fewer unnecessary
  ---                            file writes compared to `"all"`.
  ---  - table<string, boolean>: map specifying which commands trigger a save
  ---                            where keys are the full command names
  ---  - false                 : never/disable
  save_on_cmd = 'some',

  ---Save current buffer on `BufLeave`. See `:help BufLeave`.
  save_on_bufleave = true,

  ---Save all buffers when Neovim loses focus or is suspended.
  save_on_focuslost = true,

  should_save = {
    ---Whether to autosave buffers which aren't modifiable.
    ---See `:help 'modifiable'`.
    unmodifiable = true,

    ---How to handle `acwrite` type buffers (i.e. where `vim.bo.buftype ==
    ---"acwrite"` or the buffer's name is a URI). These buffers use an autocmd to
    ---perform special actions and side-effects when saved/written.
    acwrite = {
      ---Whether to autosave buffers which perform network actions (such as sending a
      ---request) on save/write. E.g. `scp`, `http`
      net = true,

      ---Whether to autosave buffers which perform git actions (such as staging
      ---buffer content) on save/write. E.g. `fugitive`, `diffview`, `gitsigns`
      git = true,

      ---Whether to autosave buffers which process the file on save/write.
      ---E.g. `tar`, `zip`, `gzip`
      compress = true,

      ---Whether to autosave `acwrite` buffers which don't match any of the other
      ---acwrite criteria/filters.
      other = true,

      ---URI schemes to allow/disallow autosaving for. If a scheme is set to `false`,
      ---any buffer whose name begins with that scheme will not be autosaved.
      ---Provided schemes should be lowercase and will be matched case-insensitively.
      ---Schemes take precedence over other `acwrite` filters.
      ---
      ---Example:
      ---
      ---```lua
      ---schemes = { http = false, octo = false, file = true }
      ---```
      schemes = {
        ---Octo buffers are disabled by default as they can create new
        ---issues, PR's, and comments on write/save.
        octo = false,
        term = false,
        file = true,
      },
    },
  },

  hooks = {
    ---A function – or any other callable value – which is called just before
    ---writing/autosaving a buffer. If `false` is returned, the buffer will not be
    ---written.
    buf_autosave_pre = function(bufnr, bufname) end,

    ---A function – or any other callable value – which is called just after
    ---writing/autosaving a buffer (even if the write failed).
    buf_autosave_post = function(bufnr, bufname, errmsg) end,
  },
}
```

<!-- END GENERATED DEFAULTS -->

## Commands

All of the available commands are defined [here](/lua/sos/commands.lua).

## Tips

- Decrease the `timeout` value if you'd like more frequent/responsive autosaving behavior (e.g. `10000` for 10 seconds, or `5000` for 5 seconds). It's probably best not to go below 5 seconds however.
- Disable swapfiles.

## FAQ

### How do I discard all changes that I have made in a buffer? Before, I could just use or `:e!` or `:q!`.

If you have just finished working on a buffer and the (original) version of the file you need is not staged/committed/stored in your vcs/git (in which case you could also just checkout the file at the version you need, restore the working tree file, etc.), you cannot just use `e!` or `:q!` to discard your changes; instead, use vim's builtin undo (see `:help undo.txt`) ***before*** reloading or discarding the buffer. If you didn't make many changes, you can just use `u` repeatedly (you can even hold it) in normal mode until you get back to the state you are looking for (likewise use `CTRL-R` to redo). To get back the buffer as it was when it was first opened, in one go, you can use the command `:ea 999d`. To make things even easier, you can create your own command or mapping for the following command:

```vim
execute 'earlier' .. v:numbermax
```

> **Note** these `:earlier` commands to get back to the original state of the buffer will not work as expected if you are using `'undofile'` or persisting undo history

> **Note** undo history is lost when the buffer is unloaded

If you feel the need to persist your undo history to the filesystem, checkout `:help persistent-undo` and `:help 'undofile'`. For more precise undo history introspection and traversal, you can install an undo history plugin, such as [undotree].

A custom recovery solution could be devised and added to the plugin (e.g. automatically caching files in RAM, vim buffers, or fs/git), but such a thing seems overkill and unnecessary at the moment. I haven't had any major issues myself utilizing only git and vim's undo history.

## Interaction with format on save

I believe that there are generally 2 main reasons/pros for using format on save:

1. only having to manually save the file instead of manually format and then manually save
2. not having to worry about a file on the filesystem ever being in an unformatted state

If you have Neovim setup to format on save/write via autocmds, you may experience issues as sos will trigger autocmds when saving changed buffers. The issue when using sos is, that now saving occurs at random times, and may occur while you are in insert mode (you likely don't want formatting to occur while you're in insert mode).

TODO: provide (better) fix or suggestions, finish this section

In the meantime, if you are having issues due to a format-on-save setup, and until a better solution is discovered, you can try:

- changing which autocmd/event triggers autoformatting (e.g. use `InsertLeave` instead)
- disabling format-on-save altogether

## License

[MIT](/LICENSE.txt)

[issues]: /../../issues
[prs]: /../../pulls
[q&a]: /../../discussions/categories/q-a
[undotree]: ../../../../mbbill/undotree
