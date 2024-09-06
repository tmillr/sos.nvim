local api = vim.api
local co = coroutine
local util = require 'sos._test.util'

describe('disabling the plugin', function()
  it('should stop the timer and not trigger save', function()
    util.setup_plugin {
      enable = true,
      timeout = 1000,
      save_on_cmd = 'all',
    }
    local timer = __sos_autosaver__.timer
    util.silent_edit(util.tmpfile())
    api.nvim_buf_set_lines(0, 0, -1, true, { 'changes' })
    assert.is.True(vim.bo.mod)
    util.set_timeout(100, util.coroutine_resumer(true))
    co.yield()
    assert(timer:get_due_in() > 0, timer:get_due_in())
    api.nvim_feedkeys(
      api.nvim_replace_termcodes(
        [[<C-\><C-N>:SosDisable<CR>]],
        true,
        false,
        true
      ),
      'ntx',
      false
    )
    assert.is.True(vim.bo.mod, 'buffer saved on cmd')
    assert(timer:get_due_in() > 0)
    util.set_timeout(timer:get_due_in() + 200, util.coroutine_resumer(true))
    co.yield()
    assert.equal(0, timer:get_due_in())
    assert.is.True(vim.bo.mod, 'timer fired')
    assert.equal('', vim.v.errmsg)
  end)
end)
