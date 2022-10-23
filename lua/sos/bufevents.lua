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
        cfg = cfg,
        timer = timer,
    }

    --- @return nil
    function instance:on_timer()
        vim.schedule(self.cfg.on_timer)
    end

    --- Called whenever a buffer incurs a saveable change (i.e.
    --- writing the buffer would change the file's contents on the filesystem).
    --- All this does is debounce the timer.
    --- NOTE: this triggers often, so it should return quickly!
    function instance:on_change(buf)
        if self:should_detach(buf) then return true end -- detach
        local t = self.timer
        local result, err, _ = t:stop()
        assert(result == 0, err)
        result, err, _ = t:start(self.cfg.timeout, 0, self.on_timer)
        assert(result == 0, err)
    end

    --- @param buf integer
    --- @return nil
    function instance:attach(buf)
        self.pending_detach[buf] = nil

        if self.listeners[buf] == nil then
            assert(
                api.nvim_buf_attach(buf, false, {
                    -- NOTE: this fires on EVERY single change of the buf
                    -- text, even if the text is replaced with the same text.
                    -- Fires on every keystroke in insert mode.
                    on_lines = function(_, bufnr)
                        return self:on_change(bufnr)
                    end,
                    on_detach = function(_, bufnr)
                        self.listeners[bufnr] = nil
                        self.pending_detach[bufnr] = nil
                    end,
                }),
                "failed to attach to buffer " .. buf
            )

            self.listeners[buf] = true
        end
    end

    --- @param buf integer
    --- @return boolean | nil
    function instance:should_detach(buf)
        return did_destroy or self.pending_detach[buf]
    end

    --- @param buf integer
    --- @return nil
    function instance:detach(buf)
        self.pending_detach[buf] = true
    end

    --- @param buf integer
    --- @return nil
    function instance:process_buf(buf)
        if self.cfg.should_observe_buf(buf) then
            self:attach(buf)
        else
            self:detach(buf)
        end
    end

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

    function instance:start()
        assert(not did_start, "unable to start a running MultiBufObserver")

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
                    assert(info.buf)
                    self:process_buf(info.buf)
                end,
            }),

            -- does the buffer always not have a name? i.e. is the name applied later?
            -- has the file been read yet?
            -- assert that this triggers when a new buffer w/o name gets name via :write
            -- assert that this works for every new buffer incl those with files, and
            -- without
            -- assert that this fires when a buf loses it's filename (renamed to "")
            api.nvim_create_autocmd("BufNew", {
                pattern = "*",
                desc = "Attach buffer callbacks to listen for changes",
                callback = function(info)
                    self:process_buf(info.buf)
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
