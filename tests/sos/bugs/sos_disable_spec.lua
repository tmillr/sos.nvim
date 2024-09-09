local action = require 'sos._test.action'
local sos = require 'sos'
local util = require 'sos._test.util'
local api = vim.api
local co = coroutine

describe('disabling the plugin', function()
  it('should stop the timer and not trigger save', function()
    util.setup_plugin {
      enabled = true,
      timeout = 1000,
      save_on_cmd = 'all',
    }

    util.silent_edit(util.tmpfile())
    api.nvim_buf_set_lines(0, 0, -1, true, { 'changes' })
    assert.is.True(vim.bo.mod)

    util.set_timeout(100, util.coroutine_resumer(true))
    co.yield()
    assert(sos.buf_observer:due_in() > 0, sos.buf_observer:due_in())

    action.cmd 'SosDisable'
    assert.is.True(vim.bo.mod, 'buffer saved on :SosDisable')

    assert(sos.buf_observer:due_in() > 0)
    util.set_timeout(
      sos.buf_observer:due_in() + 200,
      util.coroutine_resumer(true)
    )
    co.yield()

    assert.equal(0, sos.buf_observer:due_in())
    assert.is.True(vim.bo.mod, 'timer fired and buffer saved AFTER :SosDisable')
    assert.equal('', vim.v.errmsg)
  end)
end)
