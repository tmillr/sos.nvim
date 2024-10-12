vim.opt.rtp:prepend '.'
local f = assert(io.open('lua/sos/config.lua', 'rb'))

local s = f:read('*a'):gsub(
  '(\n%-%-+%s*BEGIN GENERATED TYPES[^\r\n]*\r?\n).-(\r?\n%-%-+%s*END GENERATED TYPES)',
  function(a, b) return a .. '\n' .. require('sos.config').def:to_luadoc() .. b end,
  1
)

assert(f:close())

f = assert(io.open('lua/sos/config.lua', 'wb'))
assert(f:write(s))
