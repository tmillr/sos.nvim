local errmsg = require("sos.util").errmsg
local api = vim.api

--- An object which observes multiple buffers for changes at once.
local MultiBufObserver = {}

--- Constructor
--- @param cfg sos.Config
--- @param timer sos.Timer
function MultiBufObserver:new(cfg, timer)
    local did_start = false
    local did_destroy = false

    local instance = {
        autocmds = {},
        listeners = {},
        pending_detach = {},
        buf_callback = {},
        cfg = cfg,
        timer = timer,
    }

    instance.on_timer = vim.schedule_wrap(instance.cfg.on_timer)

    --- Called whenever a buffer incurs a saveable change (i.e.
    --- writing the buffer would change the file's contents on the filesystem).
    --- All this does is debounce the timer.
    --- NOTE: this triggers often, so it should return quickly!
    --- @param buf integer
    --- @return true | nil
    --- @nodiscard
    function instance:on_change(buf)
        if self:should_detach(buf) then return true end -- detach
        local t = self.timer
        local result, err, _ = t:stop()
        assert(result == 0, err)
        result, err, _ = t:start(self.cfg.timeout, 0, self.on_timer)
        assert(result == 0, err)
    end

    --- NOTE: this fires on EVERY single change of the buf
    --- text, even if the text is replaced with the same text,
    --- and fires on every keystroke in insert mode.
    instance.buf_callback.on_lines = function(_, buf)
        return instance:on_change(buf)
    end

    instance.buf_callback.on_detach = function(_, buf)
        instance.listeners[buf] = nil
        instance.pending_detach[buf] = nil
    end

    --- Attach buffer callbacks if not already attached
    --- @param buf integer
    --- @return nil
    function instance:attach(buf)
        self.pending_detach[buf] = nil

        if self.listeners[buf] == nil then
            assert(
                api.nvim_buf_attach(buf, false, {
                    on_lines = instance.buf_callback.on_lines,
                    on_detach = instance.buf_callback.on_detach,
                }),
                "failed to attach to buffer " .. buf
            )

            self.listeners[buf] = true
        end
    end

    --- @param buf integer
    --- @return boolean | nil
    function instance:should_detach(buf)
        -- If/once the observer has been destroyed, we want to always return
        -- true here. This is because of the way that observing is
        -- reenabled/restarted. Instead of trying to restart the observer (if
        -- needed later on), it's probably best/easiest to simply just create
        -- a fresh/new observer. In this case we want the old observer to
        -- discontinue and detach all of its callbacks. `should_detach()` is
        -- what notifies the callbacks to detach themselves the next time they
        -- fire. Currently, the only way to detach Neovim's buffer callbacks
        -- is by notifying them to return true the next time they fire, which
        -- is what `should_detach()` does when it is called inside a callback
        -- and returns true.
        return did_destroy or self.pending_detach[buf]
    end

    --- Detach buffer callbacks if not already detached
    --- @param buf integer
    --- @return nil
    function instance:detach(buf)
        if self.listeners[buf] then self.pending_detach[buf] = true end
    end

    --- Attach or detach buffer callbacks if needed
    --- @param buf integer
    --- @return nil
    function instance:process_buf(buf)
        if buf == 0 then buf = api.nvim_get_current_buf() end

        if self.cfg.should_observe_buf(buf) then
            if api.nvim_buf_is_loaded(buf) then self:attach(buf) end
        else
            self:detach(buf)
        end
    end

    --- Destroy this observer
    --- @return nil
    function instance:destroy()
        did_destroy = true

        for _, id in ipairs(self.autocmds) do
            api.nvim_del_autocmd(id)
        end

        self.autocmds = {}
        self.listeners = {}
        self.pending_detach = {}
    end

    --- Begin observing buffers with this observer.
    function instance:start()
        assert(
            not did_start,
            "unable to start an already running MultiBufObserver"
        )

        assert(
            not did_destroy,
            "unable to start a destroyed MultiBufObserver"
        )

        did_start = true

        vim.list_extend(self.autocmds, {
            api.nvim_create_autocmd("OptionSet", {
                pattern = { "buftype", "readonly", "modifiable" },
                desc = "Handle buffer type and option changes",
                callback = function(info)
                    if not info.buf then
                        errmsg "OptionSet callback: autocmd event info missing `buf` (<abuf>)"
                        return
                    end

                    self:process_buf(info.buf)
                end,
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
            api.nvim_create_autocmd("BufModifiedSet", {
                pattern = "*",
                desc = "Attach buffer callbacks to listen for changes",
                callback = function(info)
                    local buf = info.buf
                    local modified = vim.bo[buf].mod

                    if not buf then
                        errmsg "BufModifiedSet callback: autocmd event info missing `buf` (<abuf>)"
                        return
                    end

                    -- Can only attach if loaded. Also, an unloaded buf should
                    -- not be able to become modified, so this event should
                    -- never fire for unloaded bufs.
                    if not api.nvim_buf_is_loaded(buf) then
                        errmsg "unexpected BufModifiedSet event on unloaded buffer"
                        return
                    end

                    -- Ignore if buf was set to `nomod`, as is the case when
                    -- buf is written
                    if modified then
                        self:process_buf(buf)
                        -- Manually signal saveable change because:
                        --     1. Callbacks/listeners may not have been
                        --        attached when BufModifiedSet fired, in which
                        --        case they will have missed this change.
                        --
                        --     2. `buf` may have incurred a saveable change
                        --        even though no text changed (see `:h
                        --        'mod'`), and that is what made
                        --        BufModifiedSet fire. Since we're not using
                        --        the `on_changedtick` buf listener/callback,
                        --        BufModifiedSet is our only way to detect
                        --        this type of change.
                        self:on_change(buf)
                    end
                end,
            }),
        })

        for _, bufnr in ipairs(api.nvim_list_bufs()) do
            self:process_buf(bufnr)
        end
    end

    return instance
end

return MultiBufObserver
