local util = require 'sos._test.util'

local function runtest(nvim, init)
  assert.equals('', nvim:get_vvar 'warningmsg')
  assert.equals('', nvim:get_vvar 'errmsg')
  assert.equals('', nvim:get_vvar 'statusmsg')

  if init then
    assert.does_not_error(function() nvim:exec_lua(unpack(init)) end)
  end

  nvim:set_option_value('awa', false, {})
  nvim:set_option_value('aw', false, {})

  assert.equals('', nvim:get_vvar 'warningmsg')
  assert.equals('', nvim:get_vvar 'errmsg')
  assert.equals('', nvim:get_vvar 'statusmsg')

  local path = util.tmpfile()
  nvim:silent_edit(path)
  assert.is_false(util.file_exists(path))
  nvim:buf_set_lines(0, 0, -1, true, { 'hello world' })
  nvim:cmd({
    cmd = 'tabnew',
    mods = { silent = true },
  }, { output = false })

  assert.is_false(nvim:get_option_value('awa', {}))
  assert.is_false(nvim:get_option_value('aw', {}))
  assert.is_true(util.file_exists(path))
  assert.equals('', nvim:get_vvar 'warningmsg')
  assert.equals('', nvim:get_vvar 'errmsg')
  -- assert.equals('', nvim:get_vvar 'statusmsg')
end

describe('sos', function()
  describe('smoke test', function()
    describe('startup/init', function()
      pending("using `require('sos').setup()` before vim enter", function() end)

      describe("using `require('sos').setup()` after vim enter", function()
        it('should initialize the plugin successfully', function()
          util.with_nvim(
            { xargs = { '--cmd', 'silent set rtp^=.' } },
            function(nvim)
              util.wait_until(
                function() return nvim:get_vvar 'vim_did_enter' == 1 end
              )

              runtest(nvim, { [[require('sos').setup()]] })
            end
          )
        end)
      end)

      pending(
        "using `require('sos').setup {}` before vim enter",
        function() end
      )

      describe("using `require('sos').setup {}` after vim enter", function()
        it('should initialize the plugin successfully', function()
          util.with_nvim(
            { xargs = { '--cmd', 'silent set rtp^=.' } },
            function(nvim)
              util.wait_until(
                function() return nvim:get_vvar 'vim_did_enter' == 1 end
              )

              runtest(nvim, { [[require('sos').setup {}]] })
            end
          )
        end)
      end)

      pending(
        "using `require('sos').enable()` before vim enter",
        function() end
      )

      describe("using `require('sos').enable()` after vim enter", function()
        it('should initialize the plugin successfully', function()
          util.with_nvim(
            { xargs = { '--cmd', 'silent set rtp^=.' } },
            function(nvim)
              util.wait_until(
                function() return nvim:get_vvar 'vim_did_enter' == 1 end
              )

              runtest(nvim, { [[require('sos').enable()]] })
            end
          )
        end)
      end)

      pending('using `:SosEnable` before vim enter', function() end)

      describe('using `:SosEnable` after vim enter', function()
        it('should initialize the plugin successfully', function()
          util.with_nvim(
            { xargs = { '--cmd', 'silent set rtp^=.' } },
            function(nvim)
              util.wait_until(
                function() return nvim:get_vvar 'vim_did_enter' == 1 end
              )

              runtest(nvim, { [[vim.cmd 'silent SosEnable']] })
            end
          )
        end)
      end)
    end)
  end)
end)
