--[[
Tests to investigate vim sessions and ensure that they:
  * don't do anything too unexpected
  * will play nicely with autosaving

------------------------------------------------------------------------------
Session.vim Files

Thankfully, after investigating a few Session.vim files, it appears that
buf contents don't get stored in them. They basically just restore opts with
`set*` commands, restore windows/tabs, current dir, etc. The non-hidden bufs
are restored with simple/normal `:edit` commands (without bang!). If a sess
is loaded while vim is running and already has bufs open/loaded, there may
be errors, or confirmation prompts (if `set confirm` etc.), if any of those
bufs are modified (and are not saved, whether automatically or manually,
prior to the `:source`). The aforementioned `:edit` commands may trigger
such errs/prompts, or if sessions are configured to close tabs/windows, etc.

------------------------------------------------------------------------------
Original Concern

What happens when loading a session that includes loaded buffers which don’t
match their fs counterparts? E.g. Session was saved when buf was empty (or only
had a couple lines), then that buf/file is worked on extensively and made into
a full/complete file, but Session isn’t updated? Later, Session is restored,
the now-outdated buffer stored in Session is loaded/restored, and maybe sos
kicks in and overwrites the new changes on the fs (which may not have been
committed yet either...also, it could be a brand new nvim instance, in which
case there’s probably no undo history as well? Even if there is undo history,
the user needs to be aware that they need to restore the buf from the undo
history, etc. etc. etc.).

CONCLUSION: this hypothetical scenario shouldn't be an issue/realistic as
buffer contents are not stored in session files. In session files, buffers are
loaded/reloaded with regular commands like `:edit` (i.e. they are read from the
filesystem when the session file is sourced).
--]]

local util = require("sos._test.util")

describe("vim session", function()
    local tmp, sessfile

    before_each(function()
        tmp = util.tmpfile() .. ".lua"
        sessfile = util.tmpfile() .. ".vim"
    end)

    it("doesn't store buf contents (thereby masking fs version)", function()
        local after_lines

        util.with_nvim(function(nvim)
            nvim:silent_edit(tmp)
            nvim:buf_set_lines(0, 0, -1, true, { "initial content" })
            nvim:command("write")

            -- Save session
            nvim:command("mksession " .. sessfile)

            -- Do alot more work on the file...session becomes out of sync?
            nvim:buf_set_lines(
                0,
                0,
                -1,
                true,
                { "new", "content", "and some more" }
            )

            after_lines = nvim:buf_get_lines(0, 0, -1, true)

            -- We save our changes, but forget to update the session. Next
            -- time we restore the session, the buf(s) will be outdated and not
            -- reflective of their current state on the fs?
            nvim:command("write")
        end)

        -- Open new nvim, we restore our session (which we might not realize
        -- is out-of-sync).
        util.with_nvim({ xargs = { "-S", sessfile } }, function(nvim)
            -- nvim:command("SosDisables")
            assert.is.False(nvim:exec_lua("return vim.bo.modified", {}))

            -- NOTE: It actually appears that nvim does not store buf content
            -- in session files. Upon session load, buf content is pulled from
            -- the fs instead.
            -- assert.same(before_lines, nvim:buf_get_lines(0, 0, -1, true))
            assert.same(after_lines, nvim:buf_get_lines(0, 0, -1, true))
            nvim:silent_edit(tmp)
            assert.same(after_lines, nvim:buf_get_lines(0, 0, -1, true))
        end)
    end)

    ---A non-empty buf stored in sess should reload as unmodified, empty buf if
    ---file doesn't exist at session load time.
    it("doesn't store buf contents (nor create files)", function()
        util.with_nvim(function(nvim)
            nvim:silent_edit(tmp)
            nvim:buf_set_lines(0, 0, -1, true, { "initial content" })
            nvim:command("write")
            nvim:command("mksession " .. sessfile)
            --TODO: what if sess is loaded here after deleting the file?
        end)

        assert.equals(0, vim.fn.delete(tmp))

        util.with_nvim({ xargs = { "-S", sessfile } }, function(nvim)
            assert.is.False(nvim:exec_lua("return vim.bo.modified", {}))
            assert.is.False(util.file_exists(tmp))
            assert.is.True(nvim:buf_empty())
        end)
    end)

    ---Should not try to restore empty buf (which might confuse the user, and
    ---would overwrite the file with an empty one when saved)
    it("doesn't store buf contents (or lack thereof)", function()
        util.with_nvim(function(nvim)
            -- New buf with filename
            nvim:silent_edit(tmp)
            nvim:command("mksession " .. sessfile)
        end)

        -- Create file using same filename
        assert.equals(0, vim.fn.writefile({ "initial content" }, tmp))

        -- Session should simply load the file from fs, not an empty buf
        util.with_nvim({ xargs = { "-S", sessfile } }, function(nvim)
            assert.is.False(nvim:exec_lua("return vim.bo.modified", {}))
            assert.same(
                { "initial content" },
                nvim:buf_get_lines(0, 0, -1, true)
            )
        end)
    end)
end)
