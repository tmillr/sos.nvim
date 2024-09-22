local action = require 'sos._test.action'
local util = require 'sos._test.util'
local api = vim.api

describe('command', function()
  -- (setup or before)(function() util.await_vim_enter() end)

  describe('bufspec parser', function()
    -- TODO: These should probably test the underlying arg parsing/logic
    -- function instead.
    describe('argument', function()
      pending('accepts bufame', function() end)
      pending('accepts bufame pattern', function() end)
      pending('accepts bufnr', function() end)
      pending('accepts bufnr via arg', function() end)
      pending('rejects 0 bufnr', function() end)
      pending('rejects negative bufnr', function() end)
      pending('accepts % as current buffer', function() end)
      pending('accepts # as alternate buffer', function() end)
      pending(
        'accepts $ as bufname literally (or pattern if no such buffer)',
        function() end
      )
describe('resolve_bufspec()', function()
  local ret, emsg
  api.nvim_create_user_command('SomeCmd', function(info)
    ret = require('sos.commands').resolve_bufspec(info)
    emsg = vim.v.errmsg
    vim.v.errmsg = ''
  end, {
    nargs = '?',
    count = -1,
    addr = 'buffers',
    complete = 'buffer',
    force = true,
  })

  before_each(function()
    ret, emsg, vim.o.write = nil, nil, false
    vim.cmd 'silent! %bw!'
    vim.v.errmsg = ''
  end)

  local function assert_success(buf)
    assert.equals('', emsg)
    assert.equals(buf, ret)
  end

  local function assert_error()
    assert.is_string(emsg)
    assert.does_not_equal('', emsg)
    assert.is_nil(ret)
  end

  local function clear_results()
    ret, emsg, vim.v.errmsg = nil, nil, ''
  end

  describe('command argument', function()
    it('accepts relative bufame', function()
      local path = 'dir/somefile'
      local buf = util.silent_edit(path)
      util.silent_edit(path .. 'a')
      util.silent_edit(path .. '/a')

      action.cmd('SomeCmd ' .. path)
      assert_success(buf)
    end)

    it('accepts relative bufame', function()
      local path = 'dir/somefile'
      local buf = util.silent_edit(path)
      util.silent_edit(path .. '/file')
      util.silent_edit(path .. 'abc')

      action.cmd('SomeCmd ' .. path)
      assert_success(buf)
    end)

    it('accepts absolute bufame', function()
      local path = util.tmpfile()
      local buf = util.silent_edit(path)
      util.silent_edit(path .. '/file')
      util.silent_edit(path .. 'abc')

      action.cmd('SomeCmd ' .. path)
      assert_success(buf)
    end)

    pending('accepts bufame pattern', function() end)
    pending('accepts bufnr', function() end)
    pending('accepts bufnr via arg', function() end)

    it('rejects 0 bufnr and prints error message', function()
      util.silent_edit '0'
      action.cmd 'SomeCmd 0'
      assert_error()
    end)

    it('accepts negative integer as bufname', function()
      -- no match
      action.cmd 'SomeCmd -1'
      assert_error()

      clear_results()
      local buf = util.silent_edit '-1'
      util.silent_edit '-1abc'
      util.silent_edit '-1/file'
      action.cmd 'SomeCmd -1'
      assert_success(buf)
    end)

    it('accepts % as current buffer', function()
      assert.equals('%', vim.fn.bufname((util.silent_edit '%')))
      local buf = util.silent_edit 'current_buffer'
      action.cmd 'SomeCmd %'
      assert_success(buf)
    end)

    it('accepts # as alternate buffer', function()
      local buf = util.silent_edit 'alt_buffer'
      assert.equals('#', vim.fn.bufname((util.silent_edit '#')))
      action.cmd 'SomeCmd #'
      assert_success(buf)
    end)

    it(
      'accepts $ ($ by itself) literally (non-pattern/non-special char) and as bufname',
      function()
        -- exact match
        local buf = util.silent_edit '$'
        assert.equals('$', vim.fn.bufname(buf))
        util.silent_edit 'ab$'
        util.silent_edit '$ab'
        util.silent_edit 'ab$ab'
        action.cmd 'SomeCmd $'
        assert_success(buf)

        api.nvim_buf_delete(buf, { force = true })
        clear_results()
        action.cmd 'SomeCmd $'
        -- error (too many matches)
        assert_error()

        vim.cmd 'silent! %bw!'
        clear_results()
        util.silent_edit 'file'
        action.cmd 'SomeCmd $'
        -- error (no match)
        assert_error()

        vim.cmd 'silent! %bw!'
        clear_results()
        buf = util.silent_edit 'f$ile'
        util.silent_edit 'file1'
        util.silent_edit 'file2'
        action.cmd 'silent enew'
        action.cmd 'SomeCmd $'
        assert_success(buf)
      end
    )
  end)

  describe('command range', function()
    pending('is rejected if it contains 2 parts', function() end)
    pending('accepts bufnr', function() end)
    pending('rejects 0 bufnr', function() end)
    pending('rejects negative bufnr', function() end)
    pending('rejects non-integer', function() end)
  end)

  describe('command argument with', function()
    describe('1-part range', function()
      it('is accepted, but only argument is used and resolved', function()
        local buf1 = util.silent_edit 'f1'
        local buf2 = util.silent_edit 'f2'
        util.silent_edit 'f3'
        util.silent_edit 'f4'

        action.cmd(('%dSomeCmd %d'):format(buf1, buf2))
        assert_success(buf2)
      end)

      it("is rejected if arg isn't a positive integer", function()
        local buf1 = util.silent_edit 'f1'
        util.silent_edit 'f2'
        util.silent_edit 'f3'
        util.silent_edit 'f4'

        action.cmd(('%dSomeCmd f2'):format(buf1))
        assert_error()
        clear_results()
        action.cmd(('%dSomeCmd 0'):format(buf1))
        assert_error()
        clear_results()
        action.cmd(('%dSomeCmd -'):format(buf1))
      end)
    end)

    describe('2-part range', function()
      it('is rejected and prints error message', function()
        action.cmd(
          ('%d,%dSomeCmd %d'):format(
            util.silent_edit 'f1',
            util.silent_edit 'f2',
            util.silent_edit 'f3'
          )
        )

        assert_error()

        clear_results()

        action.cmd(
          ('%d,%dSomeCmd %s'):format(
            util.silent_edit 'f1',
            util.silent_edit 'f2',
            util.silent_edit 'f3' and 'f3'
          )
        )

        assert_error()
      end)
    end)
  end)
end)
