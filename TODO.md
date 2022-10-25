# TODO

- [] handle swapfile option, autowrite option
- [] better handling for buffers whose file doesn't appear to exist on fs
- [] teardown on `VimLeavePre` (avoids events that occur during exit, like `BufNew`)
- [] option to autosave on vim exit
- [] save before sourcing colorscheme? or make opt-in (detect on cmdline or via autocmd)
- [] parse cmdline for more accurate examination in `CmdlineLeave`
- [] create vim help docs
- [] handle all lsp errors
- [] plugin promotion/exposure so people know about it and can try it if they want ;)
- [] figure out how/when bufs become "loaded" as you can only attach to loaded buffers (currently using `vim.schedule` in `BufNew`)
- [] see if acwrite bufs can/do write themselves when :write is called inside nested = false autocmd
- [] pre/post autocmds, and/or hooks passed via opts, for pre and post autosave events
- [] determine if nested = true should be changed to false (but then we have to figure out how to handle acwrite bufs, people using format on save, or people using any other custom actions taken on write via autocmd; note also that currently with nested = true, potentially alot of autocmds could fire back-to-back as sos can potentially save/write multiple buffers back-to-back)
- [] ensure that the current impl for autosaving does not exit insert mode or change the current mode (even when having to save a buffer in another/no window; see `:h nvim_buf_call`)
