local api, uv = vim.api, vim.uv or vim.loop
local M = {}

---@class (exact) sos.bench
---@field [1] function
---@field name string
---@field warmup? boolean|integer warmup iterations
---@field iterations? integer
---@field args? any[]
---@field setup? function
---@field jit? boolean

local function time_it_once(fn, ...)
  local start = uv.hrtime()
  fn(...)
  return uv.hrtime() - start
end

local function fmtnum(n)
  if type(n) ~= 'string' then n = string.format('%d', math.floor(n)) end

  local i, res = #n, {}
  repeat
    table.insert(res, 1, n:sub(math.max(i - 2, 1), i))
    i = i - 3
  until i < 1

  return table.concat(res, ',')
end

local function time_it(fn, opts)
  local iter = opts.iterations or 1e4
  local setup = opts.setup
  local warmup = opts.warmup

  local res = require 'table.new'(iter, 0)
  local retval = setup and { setup() } or {}
  local args = opts.args or retval

  local function run(iterations)
    collectgarbage 'restart'
    collectgarbage 'collect'
    collectgarbage 'stop'
    for _ = 1, iterations do
      table.insert(res, time_it_once(fn, unpack(args)))
    end
  end

  jit[opts.jit == false and 'off' or 'on'](fn, true)
  if warmup then
    run(type(warmup) == 'number' and warmup or iter)
    require 'table.clear'(res)
  end

  run(iter)

  local count, sum = 0, 0
  for _, x in ipairs(res) do
    sum = sum + x
    count = count + 1
  end

  collectgarbage 'restart'
  collectgarbage 'collect'
  return sum / count
end

local nvim_get_option_value = api.nvim_get_option_value
local function manual(bufs)
  local filtered = require 'table.new'(#bufs, 0)
  -- local o = { buf = 0 }
  for _, buf in ipairs(api.nvim_list_bufs()) do
    -- o.buf = buf
    -- if api.nvim_get_option_value('mod', { buf = buf }) then
    if vim.o.write then table.insert(filtered, buf) end
    -- if vim.bo[buf].mod then table.insert(filtered, buf) end
    -- if math.random() > 0.5 then table.insert(filtered, buf) end
  end

  -- local bufs = api.nvim_list_bufs()
  -- local j = 1
  -- for i = 1, #bufs do
  --   local buf = bufs[i]
  --
  --   if vim.bo[buf].mod then
  --     bufs[j] = buf
  --     j = j + 1
  --   end
  -- end

  return filtered
end

local function print_it(label, time)
  -- if not label then debug.getinfo() end
  print(label .. ' took ' .. fmtnum(time) .. 'ns (average)')
  return time
end

---@param def sos.bench
function M.bench(def) print_it(def.name, time_it(def[1], def)) end

-- vim.print(debug.getinfo(M.bench))

M.bench {
  name = 'manual()',
  args = { api.nvim_list_bufs() },
  warmup = true,
  manual,
}

M.bench {
  name = 'getbufinfo()',
  args = { { bufmodified = 1, bufloaded = 1 } },
  warmup = true,
  vim.fn.getbufinfo,
}
