local action = require 'sos._test.action'
local sos = require 'sos'
local util = require 'sos._test.util'
local api = vim.api

describe('disabling the plugin', function()
  it('should stop the timer and not trigger save', function()
    util.setup_plugin {
      enabled = true,
      timeout = 500,
      save_on_cmd = 'all',
    }

    util.silent_edit(util.tmpfile())
    action.buf.modify()

    util.wait(100)
    assert(sos.buf_observer:due_in() > 0, sos.buf_observer:due_in())

    action.cmd 'SosDisable'
    assert.is.True(vim.bo.mod, 'buffer saved on :SosDisable')
    assert.equals(0, sos.buf_observer:due_in())

    util.wait(500)

    assert.equals(0, sos.buf_observer:due_in())
    assert.is.True(vim.bo.mod, 'timer fired and buffer saved AFTER :SosDisable')
    assert.equal('', vim.v.errmsg)
  end)
end)
