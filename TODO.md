# TODO

- [] Handle swapfile option, autowrite option
- [] Better handling for buffers whose file doesn't appear to exist on fs (see [README](/README.md))
- [x] Teardown on `VimLeavePre` (avoids autocmds/events that occur during exit, like `BufNew`)
- [] Option to autosave on vim exit?
- [] Save before sourcing colorscheme? or make opt-in (detect on cmdline or via autocmd)
- [x] Parse cmdline for more accurate examination in `CmdlineLeave`
- [] Create vim help docs
- [] Handle all lsp errors
- [] Plugin promotion/exposure so people know about it and can try it if they want ;)
- [] See if acwrite bufs can/do write themselves when :write is called inside nested = false autocmd
- [] Pre/post autocmds, and/or hooks passed via opts, for pre and post autosave events
- [] Determine if nested = true should be changed to false (but then we have to figure out how to handle acwrite bufs, people using format on save, or people using any other custom actions taken on write via autocmd; note also that currently with nested = true, potentially alot of autocmds could fire back-to-back as sos can potentially save/write multiple buffers back-to-back)
- [x] Ensure that the current impl for autosaving does not exit insert mode or change the current mode (even when having to save a buffer in another/no window; see `:h nvim_buf_call`). DONE: `nvim_buf_call()` does not exit insert mode
- [x] Assert callbacks detach when buf unloads
