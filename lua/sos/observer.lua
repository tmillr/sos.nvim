local api, uv = vim.api, vim.uv or vim.loop

---An object which observes multiple buffers for changes at once.
local MultiBufObserver = {}

---Constructor
---@return sos.MultiBufObserver
function MultiBufObserver:new()
  local running = false
  local timer = uv.new_timer()
  uv.unref(timer)

  ---@class sos.MultiBufObserver
  local instance = {
    autocmds = {},
    ---@type table<integer, true|nil>
    listeners = {},
    ---@type table<integer, true|nil>
    pending_detach = {},
  }

  function instance:debounce()
    local result, err, _ = timer:start(self.timeout, 0, self.on_timer)
    assert(result == 0, err)
  end

  ---Called whenever a buffer incurs a savable change (i.e. writing the buffer
  ---would change the file's contents on the filesystem). All this does is
  ---debounce the timer.
  ---
  ---NOTE: this triggers often, so it should return quickly!
  ---@param buf integer
  ---@return true | nil
  function instance:on_change(buf)
    if not running or self.pending_detach[buf] then return true end -- detach
    self:debounce()
  end

  ---Attach buffer callbacks if not already attached
  ---@param buf integer
  ---@return nil
  function instance:attach(buf)
    self.pending_detach[buf] = nil

    if self.listeners[buf] == nil then
      assert(
        api.nvim_buf_attach(buf, false, {
          ---NOTE: this fires on EVERY single change of the buf text, even if
          ---the text is replaced with the same text, and fires on every
          ---keystroke in insert mode.
          on_lines = function(_, buf) return instance:on_change(buf) end,

          ---TODO: Could this leak memory? A new fn/closure is created every
          ---time a new observer is created. The closure references `instance`,
          ---while nvim refs the closure (even after the observer is destroyed).
          ---The ref to the closure isn't/can't be dropped until the next time
          ---`on_lines` triggers, which may be awhile or never even. A buildup
          ---of allocated memory might happen simply by disabling and enabling
          ---sos over and over again as new callbacks/closures are attached and
          ---old ones aren't detached.
          on_detach = function(_, buf)
            instance.listeners[buf], instance.pending_detach[buf] = nil, nil
          end,
        }),
        '[sos.nvim]: failed to attach to buffer ' .. buf
      )

      self.listeners[buf] = true
    end
  end

  ---Detaches any attached buffer callbacks.
  ---@param buf integer
  ---@return nil
  function instance:detach(buf)
    if self.listeners[buf] then self.pending_detach[buf] = true end
  end

  ---@param buf integer
  function instance:should_observe_buf(buf)
    -- TODO: Should we skip nameless bufs too?
    return not vim.b[buf].sos_ignore and self.should_observe_buf_cb(buf)
  end

  ---Attaches or detaches buffer callbacks as needed.
  ---@param buf integer
  ---@return boolean observed whether the buffer will be observed
  function instance:process_buf(buf)
    if buf == 0 then buf = api.nvim_get_current_buf() end

    if not self:should_observe_buf(buf) then
      self:detach(buf)
    elseif api.nvim_buf_is_loaded(buf) then
      self:attach(buf)
      return true
    end

    return false
  end

  ---@param buf integer
  ---@return boolean ignored whether the buffer is now ignored
  function instance:toggle_ignore_buf(buf)
    return self:ignore_buf(buf, not self:buf_ignored(buf))
  end

  ---@param buf integer
  ---@param ignore boolean
  ---@return boolean ignored whether the buffer is now ignored
  function instance:ignore_buf(buf, ignore)
    if buf == 0 then buf = api.nvim_get_current_buf() end
    assert(api.nvim_buf_is_valid(buf), 'invalid buffer number: ' .. buf)
    vim.b[buf].sos_ignore = ignore or nil
    if running then self:process_buf(buf) end
    return ignore
  end

  ---@param buf integer
  ---@return boolean ignored whether the buffer is ignored
  function instance:buf_ignored(buf)
    if buf == 0 then buf = api.nvim_get_current_buf() end
    assert(api.nvim_buf_is_valid(buf), 'invalid buffer number: ' .. buf)
    return vim.b[buf].sos_ignore == true
  end

  ---Destroy this observer
  ---@return nil
  function instance:stop()
    -- Only way to reset timeout/time left value.
    timer:start(0, 0, function() end)
    timer:stop()
    running = false

    for _, id in ipairs(self.autocmds) do
      api.nvim_del_autocmd(id)
    end

    self.autocmds = {}
  end

  ---@class sos.MultiBufObserver.opts
  ---@field timeout integer timeout in milliseconds
  ---@field on_timer function
  ---@field should_observe_buf fun(buf: integer): boolean

  ---Begin observing buffers with this observer. Ok to call when already
  ---running.
  ---@param opts sos.MultiBufObserver.opts
  function instance:start(opts)
    self.timeout = opts.timeout
    self.on_timer = vim.schedule_wrap(opts.on_timer)
    self.should_observe_buf_cb = opts.should_observe_buf

    if running then
      -- Timeout may have changed
      if self:due_in() > 0 then self:debounce() end
      return
    end

    running = true

    vim.list_extend(self.autocmds, {
      api.nvim_create_autocmd('OptionSet', {
        pattern = { 'buftype', 'readonly', 'modifiable' },
        desc = 'Handle buffer type and option changes',
        callback = function(info) self:process_buf(info.buf) end,
      }),

      -- `BufNew` event
      -- does the buffer always not have a name? i.e. is the name applied later?
      -- has the file been read yet?
      -- assert that this triggers when a new buffer w/o name gets name via :write
      -- assert that this works for every new buffer incl those with files, and
      -- without
      -- assert that this fires when a buf loses it's filename (renamed to "")
      --
      -- After a loaded buf is changed ('mod' is changed), but not for
      -- scratch buffers. No longer using `BufNew` because:
      --     * it fires before buf is loaded sometimes
      --     * sometimes a buf is created but not loaded (e.g. `:badd`)
      api.nvim_create_autocmd('BufModifiedSet', {
        pattern = '*',
        desc = 'Lazily attach buffer callbacks to listen for changes',
        callback = function(info)
          local buf = info.buf
          local modified = vim.bo[buf].mod
          if buf == 0 then buf = api.nvim_get_current_buf() end

          -- Can only attach if loaded. Can only write/save if loaded.
          if not api.nvim_buf_is_loaded(buf) then return end

          -- Ignore if buf was set to `nomod`, as is the case when buf is
          -- written
          if modified then
            if self:process_buf(buf) then
              -- Manually signal savable change because:
              --     1. Callbacks/listeners may not have been attached when
              --        BufModifiedSet fired, in which case they will have missed
              --        this change.
              --
              --     2. `buf` may have incurred a savable change even though no
              --        text changed (see `:h 'mod'`), and that is what made
              --        BufModifiedSet fire. Since we're not using the
              --        `on_changedtick` buf listener/callback, BufModifiedSet is
              --        our only way to detect this type of change. TODO: This
              --        will miss non-textual changes that occurr while buf is
              --        already `modified`?
              self:on_change(buf)
            end
          end
        end,
      }),
    })

    for _, bufnr in ipairs(api.nvim_list_bufs()) do
      self:process_buf(bufnr)
    end
  end

  ---Returns the number of milliseconds until the next timer fire. Returns `0`
  ---if the timer has already fired/expired or has been stopped.
  ---@return integer ms
  function instance:due_in() return timer:get_due_in() end

  return instance
end

return MultiBufObserver
