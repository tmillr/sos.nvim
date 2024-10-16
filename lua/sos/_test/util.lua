-- TODO: refactor test lib/utils so they can be shared/required and create
-- dirs for each test type (e2e, unit, etc.) so things are better organized,
-- re-usable fn for testing autoread/checktime

local M = { assert = require 'sos._test.assert' }
local api, co, uv = vim.api, coroutine, vim.uv or vim.loop

---@param schedwrap boolean
function M.coroutine_resumer(schedwrap)
  local curr_co = co.running()
  local function resume(...) assert(co.resume(curr_co, ...)) end
  return schedwrap and vim.schedule_wrap(resume) or resume
end

---@return nil
function M.await_schedule()
  local cur_co = co.running()
  assert(cur_co, 'not running in coroutine')
  local timeout = M.set_timeout(
    5000,
    function()
      assert(
        co.resume(
          cur_co,
          false,
          'timed out waiting for vim.schedule() callback'
        )
      )
    end
  )

  vim.schedule(function()
    timeout:stop()
    co.resume(cur_co, true)
  end)

  assert(co.yield())
end

---Sleep/wait (pause execution) by yielding the current coroutine. In contrast
---to `vim.wait()` and `uv.sleep()`, this will pause the current lua "thread"
---only while still allowing nvim to run completely unhindered. Must be called
---in coroutine context.
---@param ms integer
function M.wait(ms)
  vim.defer_fn(M.coroutine_resumer(false), ms)
  co.yield()
end

function M.wait_until(cond)
  local interval = 100

  for _ = 0, 3000, interval do
    if cond() then return end
    M.wait(interval)
  end

  error 'timed out waiting for condition'
end

function M.wait_then_wait_until(cond)
  M.wait(100)
  return M.wait_until(cond)
end

---@async
function M.setup_plugin(...)
  -- require("sos").setup(nil, true)
  if select('#', ...) > 0 then
    require('sos').setup(...)
  else
    require('sos').setup { enabled = true }
  end

  M.await_vim_enter()
end

function M.bufwritemock(onwrite)
  local state = { writes = {} }

  api.nvim_create_autocmd('BufWriteCmd', {
    -- group = augroup,
    pattern = '*',
    desc = 'Mock buffer writes without actually writing anything',
    once = false,
    nested = false,
    callback = function(info)
      state[info.buf] = info
      table.insert(state.writes, info)
      vim.bo[info.buf].mod = false
      if onwrite then onwrite(info) end
    end,
  })

  return setmetatable({
    clear = function() state = { writes = {} } end,
  }, {
    __index = function(_tbl, k) return state[k] end,
  })
end

---@overload fun(nvim: table, file?: string): integer, string
---@overload fun(file?: string): integer, string
---@return integer bufnr
---@return string output
function M.silent_edit(...)
  local external_nvim_or_api, file = M.nvim_recv_or_api(...)
  local out = external_nvim_or_api.nvim_cmd({
    cmd = 'edit',
    args = { file },
    magic = { file = false, bar = false },
    mods = { silent = true },
  }, { output = true })

  return external_nvim_or_api.nvim_get_current_buf(), out
end

---@param keys string
---@param cb function
function M.handle_prompt(keys, cb)
  local timer = uv.new_timer()
  timer:start(50, 50, function()
    if api.nvim_get_mode().blocking then api.nvim_input(keys) end
    timer:stop()
    timer:close()
  end)
  local ok, result = pcall(cb)
  timer:stop()
  if not timer:is_closing() then timer:close() end
  assert(ok, result)
  return result
end

---@param content? string | (string|number)[]
---@return string fname
function M.tmpfile(content)
  local tmp = vim.fn.tempname()
  assert(tmp and tmp ~= '', 'vim.fn.tempname() returned nil or empty string')

  if content then
    assert(
      vim.fn.writefile(
        type(content) == 'table' and content or { content },
        tmp,
        'bs'
      ) == 0,
      'Error: file write failed'
    )
  end

  return tmp
end

---@param fname string
---@param content? string|(string|number)[]
---@param flags? string default: bS
---@return string, (string|(string|number)[])?, string? args
function M.write_file(fname, content, flags)
  assert(
    vim.fn.writefile(
      type(content) == 'table' and content or { content },
      fname,
      flags or 'bS'
    ) == 0,
    'Error: file write failed'
  )

  return fname, content, flags
end

---@overload fun(nvim: table, buf?: integer): boolean
---@overload fun(buf?: integer): boolean
function M.buf_empty(...)
  local external_nvim_or_api, buf = M.nvim_recv_or_api(...)
  local lines = external_nvim_or_api.nvim_buf_get_lines(buf or 0, 0, -1, true)
  local t = type(lines)
  assert(t == 'table', 'expected table, got ' .. t)
  local n = #lines
  return n < 2 and (lines[1] == '' or n == 0)
end

---@overload fun(nvim: table, cmd: string): boolean
---@overload fun(cmd: string): boolean
function M.non_magic_cmd(...)
  local external_nvim_or_api, cmd = M.nvim_recv_or_api(...)
  local parsed = external_nvim_or_api.nvim_parse_cmd(cmd, {})
  parsed.magic = { file = false, bar = false }
  return external_nvim_or_api.nvim_cmd(parsed, { output = true })
end

---@param path string
---@return boolean
function M.file_exists(path) return vim.fn.getftype(path) ~= '' end

---Send signal `sig` to process `pid`.
---@param pid integer
---@param sig string
---@return nil
function M.kill(pid, sig)
  vim.fn.system { 'kill', '-s', sig, pid }

  assert(
    vim.v.shell_error == 0,
    'error: kill(): kill failed with exit code ' .. vim.v.shell_error
  )
end

---Helper fn that prepends `vim.api` to args if the first arg is not an
---external nvim process.
---
---Enables a pattern for redirecting nvim api calls (to an external nvim
---process) depending upon how the outer/enclosing function was called
---(its arguments). The caller/enclosing function should forward-on its own
---arguments as args to this function.
---@param ... unknown args
---@return table, unknown
function M.nvim_recv_or_api(...)
  local arg1 = ...
  if type(arg1) == 'table' and arg1.is_nvim_proc then return ... end
  return api, ...
end

---Spawns an nvim instance.
---@param opts? { xargs: string[], min_init: boolean|nil }
---@return table
function M.start_nvim(opts)
  opts = opts or {}

  local job_opts = {
    width = 120,
    height = 80,
    detach = false,
    clear_env = false,
    -- env = {},
    pty = true,
    stderr_buffered = true,
    stdout_buffered = true,
  }

  local sock_addr = M.tmpfile()
  local args = {
    'nvim',
    '--clean',
    '-n', -- no swap
    '-i', -- no shada
    'NONE',
    '--listen',
    sock_addr,
    unpack(opts and opts.xargs or {}),
  }

  if opts.min_init then
    table.insert(args, 2, 'tests/min_init.lua')
    table.insert(args, 2, '-u')
  end

  local jobid = vim.fn.jobstart({ 'bash', '--norc', '--noprofile' }, job_opts)
  assert(jobid > 0, 'ERROR: jobstart(): failed to start nvim process')
  local chan
  M.wait(100)

  for i = 2, #args do
    args[i] = "'" .. args[i]:gsub("'", "'\\''") .. "'"
  end

  assert(vim.fn.chansend(jobid, table.concat(args, ' ')) > 0)
  assert(vim.fn.chansend(jobid, '\r') > 0)

  do
    local i, ok = 0, nil

    repeat
      M.wait(50)
      ok, chan = pcall(
        function() return vim.fn.sockconnect('pipe', sock_addr, { rpc = true }) end
      )
      i = i + 1
    until ok or (i == 20 and assert(ok, chan))
  end

  assert(
    chan ~= 0,
    'ERROR: sockconnect(): invalid arguments or connection failure'
  )

  local self = {
    sock = sock_addr,
    chan = chan,
    pid = vim.fn.jobpid(jobid),
    is_nvim_proc = true,
  }

  function self:req(...) return vim.rpcrequest(self.chan, ...) end

  function self:suspend()
    -- assert(self:input '<C-Z>' > 0)
    assert(vim.fn.chansend(jobid, '\26') > 0)
  end

  -- function self:cont() M.kill(self.pid, 'SIGCONT') end
  function self:cont() assert(vim.fn.chansend(jobid, 'fg\r') > 0) end

  function self:stop() vim.fn.jobstop(jobid) end

  function self:exec_lua(f, args)
    if type(f) == 'string' then
      return self:req('nvim_exec_lua', f, args or {})
    end

    return self:req(
      'nvim_exec_lua',
      ('return assert(loadstring(%q))(...)'):format(string.dump(f)),
      args or {}
    )
  end

  -- Where the magic happens!
  setmetatable(self, {
    __index = function(_, key)
      return M[key]
        or setmetatable({}, {
          __call = function(_, ...)
            return self:req(
              'nvim_' .. key:gsub('^nvim_', '', 1),
              select(... == self and 2 or 1, ...)
            )
          end,
        })
    end,
  })

  assert(self:eval 'v:vim_did_enter' == 1, 'ERROR: vim has not entered yet')
  return self
end

function M.with_nvim(opts, cb)
  if cb == nil then
    cb = opts
    opts = nil
  end

  local nvim = M.start_nvim(opts)
  cb(nvim)
  nvim:stop()
end

---@param autocmd string | string[]
---@param opts? {buffer: integer, pattern: string, once: boolean, nested: boolean, callback: function}
function M.autocmd(autocmd, opts)
  ---@type thread?
  local curr_co
  opts = opts or {}
  local ret = { opts = opts, results = {} }
  if opts.buffer == nil and opts.pattern == nil then opts.pattern = '*' end
  if opts.once == nil then opts.once = false end
  if opts.nested == nil then opts.nested = true end

  api.nvim_create_autocmd(
    autocmd,
    vim.tbl_extend('force', opts, {
      callback = function(info)
        table.insert(ret.results, info)
        if opts.callback then opts.callback() end
        if curr_co then co.resume(curr_co, ret) end
      end,
    })
  )

  -- {
  --     -- group = augroup,
  --     pattern = "*",
  --     -- desc = "",
  --     once = true,
  --     nested = true,
  --     callback = vim.schedule_wrap(function(info)
  --         coroutine.resume(co, info)
  --     end),
  -- })

  function ret:await()
    curr_co = assert(co.running(), 'cannot await, not running in coroutine')

    local timer = M.set_timeout(
      1e4,
      function()
        assert(co.resume(curr_co, false, 'timed out waiting for autocmd'))
      end
    )

    local result = { co.yield() }
    curr_co = nil
    timer:stop()
    if not timer:is_closing() then timer:close() end
    return assert(unpack(result))
  end

  return ret
end

---@return nil
function M.await_vim_enter()
  if vim.v.vim_did_enter == 1 or vim.v.vim_did_enter == true then return end
  M.autocmd('VimEnter', { once = true }):await()
  M.wait(100)
end

---@param fn function
---@return number ns
function M.time_it_once(fn)
  local hrtime = uv.hrtime
  local start = hrtime()
  fn()
  return hrtime() - start
end

---@param times integer
---@param fn function
---@return number ns average time in nanoseconds
function M.time_it(times, fn)
  local res = {}
  local i = 0

  while i < times do
    table.insert(res, M.time_it_once(fn))
    i = i + 1
  end

  local sum = 0
  i = 0

  for _, x in ipairs(res) do
    sum = sum + x
    i = i + 1
  end

  return sum / i
end

---@param times integer
---@param fn function
function M.call_it(times, fn)
  for _ = 1, times do
    fn()
  end
end

---@param ms integer
---@param cb function
---@return unknown
function M.set_timeout(ms, cb)
  local timer = uv.new_timer()

  timer:start(ms, 0, function()
    timer:stop()
    timer:close()
    cb()
  end)

  return timer
end

return M
