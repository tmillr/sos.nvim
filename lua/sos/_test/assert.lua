local api = vim.api
local M = {}

function M.normal_mode_nonblocking(mode)
  local m = mode or api.nvim_get_mode()
  assert.equals('n', m.mode, 'not in regular normal mode')
  assert.is_false(api.nvim_get_mode().blocking, 'mode is blocking')
end

-- function M.all_bufs_saved()
--   assert.same(
--     {},
--     vim.fn.getbufinfo { bufmodified = 1 },
--     'all buffers should be saved, and none modified'
--   )
-- end

---@param buf number
function M.saved(buf)
  vim.validate { buf = { buf, { 'number' }, false } }
  local file = api.nvim_buf_get_name(buf)
  assert.is_false(vim.bo[buf].mod, 'buffer is still modified')
  assert.same(
    api.nvim_buf_get_lines(buf, 0, -1, true),
    vim.fn.readfile(file),
    "buffer wasn't saved"
  )
end

---@param buf number
function M.unsaved(buf)
  vim.validate { buf = { buf, { 'number' }, false } }
  local file = api.nvim_buf_get_name(buf)
  assert.is_true(vim.bo[buf].mod, "buffer shouldn't have been saved")
  local ok, content = pcall(vim.fn.readfile, file)
  if not ok then return end
  assert.not_same(
    api.nvim_buf_get_lines(buf, 0, -1, true),
    content,
    "buffer shouldn't have been saved"
  )
end

return M
