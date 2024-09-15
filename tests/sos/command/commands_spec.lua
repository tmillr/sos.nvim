local api = vim.api
local action = require 'sos._test.action'
local asrt = require 'sos._test.assert'
local sos = require 'sos'
local util = require 'sos._test.util'

describe('command', function()
  before_each(function()
    util.await_vim_enter()
    vim.o.aw = false
    vim.o.awa = false
    vim.o.confirm = false
    vim.cmd 'silent %bw!'
    require('sos').disable()
  end)

  describe(':SosBufToggle', function()
    it('works', function()
      util.setup_plugin()

      assert.is_true(sos.buf_enabled(0))
      local buf = util.silent_edit(util.tmpfile())
      assert.is_true(sos.buf_enabled(0))

      action.buf.modify()
      assert.is_true(sos.buf_enabled(0))

      action.cmd 'SosBufToggle'
      assert.is_false(sos.buf_enabled(0))

      action.trigger_save()
      asrt.unsaved(buf)
      assert.is_false(sos.buf_enabled(buf))

      action.cmd('SosBufToggle ' .. buf)
      assert.is_true(sos.buf_enabled(buf))
      action.trigger_save(buf)

      asrt.saved(buf)
      assert.is_true(sos.buf_enabled(buf))
    end)

    it('works correctly when buf is already modified', function()
      util.setup_plugin()
      local buf = util.silent_edit(util.tmpfile())
      assert.is_true(sos.buf_enabled(0))

      action.cmd 'SosBufToggle'
      assert.is_false(sos.buf_enabled(0))

      assert.equals(0, require('sos').buf_observer:due_in())
      action.buf.modify()
      assert.is_nil(require('sos').buf_observer.listeners[buf])

      action.cmd 'SosBufToggle'
      assert.is_true(sos.buf_enabled(0))
      assert.is_true(require('sos').buf_observer.listeners[buf])

      assert.equals(0, require('sos').buf_observer:due_in())
      action.buf.modify(true)
      assert.does_not_equal(0, require('sos').buf_observer:due_in())
    end)

    it('retains buf status when plugin is toggled', function()
      local buf = api.nvim_get_current_buf()
      action.cmd 'SosBufToggle'
      assert.is_false(sos.buf_enabled(0))

      action.cmd 'SosDisable'
      assert.is_false(sos.buf_enabled(0))

      util.silent_edit(util.tmpfile())
      assert.is_true(sos.buf_enabled(0))

      action.cmd 'SosBufToggle'
      assert.is_false(sos.buf_enabled(0))

      action.cmd 'SosEnable'
      assert.is_false(sos.buf_enabled(0))
      assert.is_false(sos.buf_enabled(buf))
    end)
  end)
end)
