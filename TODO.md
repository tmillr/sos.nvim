# TODO

- [ ] Handle swapfile option, autowrite option

- [ ] Better handling for buffers whose file doesn't appear to exist on fs
      (see [README](/README.md))

- [x] Teardown on `VimLeavePre` (avoids autocmds/events that occur during
  exit, like `BufNew`)

- [ ] Option to autosave on vim exit? (I think 'autowriteall' does this)

- [ ] Save before sourcing colorscheme? or make opt-in (detect on cmdline or
      via autocmd)

- [x] Parse cmdline for more accurate examination in `CmdlineLeave`

- [ ] Create vim help docs

- [ ] Handle all lsp errors

- [ ] Plugin promotion/exposure so people know about it and can try it if they
      want ;)

- [ ] See if acwrite bufs can/do write themselves when :write is called inside
      nested = false autocmd

- [ ] Pre/post autocmds, and/or hooks passed via opts, for pre and post
      autosave events, enable/disable events

- [ ] Determine if nested = true should be changed to false (but then we have
      to figure out how to handle acwrite bufs, people using format on save,
      or people using any other custom actions taken on write via autocmd;
      note also that currently with nested = true, potentially alot of
      autocmds could fire back-to-back as sos can potentially save/write
      multiple buffers back-to-back)

- [x] Ensure that the current impl for autosaving does not exit insert mode or
      change the current mode (even when having to save a buffer in another/no
      window; see `:h nvim_buf_call`). DONE: `nvim_buf_call()` does not exit
      insert mode

- [x] Assert callbacks detach when buf unloads

- [ ] Locally enable/disable: use `:set ro` to disable autosaving locally;
      this is one of the only ways to disable 'autowrite' at the buffer level
      as well while still allowing manual writes with e.g. `:write`. Also make
      it so that a buf stays readonly even after manually written (can be done
      via autocmds) so that you can manually write a buf but continue to have
      autosaving disabled for it. Readonly can then be disabled with `:set
      noro` or `:SosBufEnable`.

- [ ] Plugin managed options. Certain options, like 'autowrite', are managed
      by the plugin (provide opt to opt-out) meaning that when the plugin is
      disabled with `:SosDisable` so to is `autowrite` and `autowriteall`
      (that way all autosaving is disabled, for consistency). Edit: 'aw' isnt
      as useful as I thought, it does little/nothing when `'hidden'` is set!
      Should we still manage it (i.e. enable it via opt, disable it on
      `:SosDisable`, etc.)?

- [x] Either implement a custom `'autowrite'` mock (and make sure the real
      `'autowrite'` vim options are always disabled) or disable the feature of
      sos that makes it so new files are never created automatically (in order
      to be more consistent with autosaving behavior when `'autowrite'` is
      used alongside sos, because the autowrite vim options will create new
      files). DONE: sos will now create new files

- [ ] Issue msg on new file (if not done already) (edit: actually maybe make
      msgs silent, with potential exception for when new files are created)

- [ ] `:SosStatus` command (can add bang! for extra info)

- [ ] Helper command for creating/setting scratch buf (so it can be named but
      wont be autosaved)?

- [ ] Opt to disable the global buf observer (and basically only use the
      autocmds and/or Vim opts)

- [ ] Opt to set and manage `'autoread'` (edit: actually is enabled by
      default, so maybe just document it). Document and/or suggest vim opts
      that might go well with sos (such as autoread, hidden, noswapfile,
      aw/awa, confirm, backup* opts).

- [ ] Add tests/CI (incl smoke test), linter checks (e.g. luacheck)

- [ ] TEST: `nvim_buf_call()` and `nvim_cmd()` should propagate errors/not be silent

- [ ] IDEA: option to save on new, named buf (when file doesnt exist). Maybe
      not, don't see much point of it and might do more harm than good.

- NOTE: `BufNewFile` doesn't trigger on buf rename. Also, when a buf is
  renamed to a file that exists, Vim will then not let you save the buffer
  without `!` and will otherwise issue an error (or confirmation dialogue if
  `'confirm'` is set).

- [ ] Better error msgs/handling. Currently if write fails a stacktrace is
      printed. Also, throughout this plugin, not many errors are
      handled/caught.

- [ ] TEST: When a save/write happens that errors (prints err msg and aborts
      the `:write`) due to the file changing externally/outside vim, can this
      be detected/caught (e.g. via autocmd or `pcall()`)? If so, maybe
      implement a better recovery process or notification/msg (the default msg
      doesn't include the filename, and sos will arbitrarily write buffers
      that are not the current buffer, making it difficult to know which
      file/buf the err msg is for).

- [ ] Save on command doesn't work with `luafile %`?
