local config = require 'sos.config'
local api = vim.api

local default_enabled = true
local default_unmodifiable = true
local default_timeout = 1e4

local function ifnil(val, default)
  if val == nil then
    return default
  else
    return val
  end
end

local function assert_shape(expect)
  expect = expect or {}
  assert.is_table(config.opts)
  assert.is_table(config.opts.should_save)
  assert.is_table(config.opts.hooks)
  assert.is_not_nil(next(config.opts.hooks))

  assert.are_equal(ifnil(expect.enabled, default_enabled), config.opts.enabled)

  assert.are_equal(
    ifnil(ifnil(expect.should_save, {}).unmodifiable, default_unmodifiable),
    config.opts.should_save.unmodifiable
  )

  assert.are_equal(ifnil(expect.timeout, default_timeout), config.opts.timeout)
end

describe('sos', function()
  describe('config', function()
    describe('opts', function()
      before_each(function()
        vim.v.statusmsg = ''
        vim.v.warningmsg = ''
        vim.v.errmsg = ''
        api.nvim_cmd({ cmd = 'messages', args = { 'clear' } }, {})
      end)

      it('should not require any opts to be set (uses defaults)', function()
        require('sos').setup()
        assert_shape()

        require('sos').setup {}
        assert_shape()
      end)

      it('should use defaults for missing values', function()
        require('sos').setup { timeout = 123456789, should_save = {} }
        assert_shape { timeout = 123456789 }
      end)

      describe('(when invalid value/type is passed)', function()
        it(
          'should emit error msg, use default, and resolve rest of config',
          function()
            require('sos').setup {
              ---@diagnostic disable-next-line: assign-type-mismatch
              timeout = 'bad',
              should_save = { unmodifiable = false },
            }

            print('vim.v.errmsg:', vim.v.errmsg)
            assert.matches('expected %p?integer%p?', vim.v.errmsg)
            assert.matches('got %p?string%p?', vim.v.errmsg)
            assert_shape { should_save = { unmodifiable = false } }
          end
        )
      end)

      describe('(when deprecated value/type is passed)', function()
        it('should emit deprecation msg', function()
          require('sos').setup {
            should_observe_buf = true,
            should_save = { unmodifiable = not default_unmodifiable },
          }

          local msgs = api.nvim_cmd({ cmd = 'messages' }, { output = true })
          assert.matches('%p?should_observe_buf%p? is deprecated', msgs)
          assert.equals('', vim.v.errmsg)
          assert.is_nil(config.opts.should_observe_buf)
          assert_shape {
            should_save = { unmodifiable = not default_unmodifiable },
          }
        end)
      end)
    end)
  end)
end)
