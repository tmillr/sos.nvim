local asrt = require 'sos._test.assert'
local util = require 'sos._test.util'
local api = vim.api
local M = { buf = {} }

function M.input(keys)
  api.nvim_feedkeys(
    api.nvim_replace_termcodes(keys, true, true, true),
    -- 'mtx',
    'L',
    false
  )

  util.await_schedule()
end

function M.cmd(cmd)
  asrt.normal_mode_nonblocking()
  M.input(':' .. cmd .. '<CR>')
  asrt.normal_mode_nonblocking()
end

---NOTE: May change the current buffer!
function M.trigger_save(buf)
  if buf and buf ~= 0 and buf ~= api.nvim_get_current_buf() then
    assert(api.nvim_buf_is_valid(buf), 'invalid buffer number: ' .. buf)
    local ei = vim.o.ei
    vim.o.ei = 'all'
    api.nvim_set_current_buf(buf)
    vim.o.ei = ei
  end

  M.cmd 'tabnew'
end

---@param expect_mod? boolean
function M.buf.modify(expect_mod)
  if expect_mod then
    assert.is_true(vim.bo.mod, "buffer isn't modified")
  else
    assert.is_false(vim.bo.mod, 'buffer is already modified')
  end

  local before = {
    tick = api.nvim_buf_get_changedtick(0),
    lines = api.nvim_buf_get_lines(0, 0, -1, true),
  }

  M.input 'ochanges<Esc>'

  assert.is_true(vim.bo.mod, 'modification unsuccessful')
  assert.are.not_same(before, {
    tick = api.nvim_buf_get_changedtick(0),
    lines = api.nvim_buf_get_lines(0, 0, -1, true),
  })
end

return M
