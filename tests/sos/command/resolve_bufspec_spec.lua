local util = require 'sos._test.util'

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
    end)

    describe('range', function()
      pending('is always rejected if it contains 2 parts', function() end)
      pending('accepts bufnr', function() end)
      pending('rejects 0 bufnr', function() end)
      pending('rejects negative bufnr', function() end)
      pending('rejects non-integer', function() end)
    end)

    describe('argument+range', function()
      pending('is accepted, but only argument is used', function() end)
    end)
  end)
end)
