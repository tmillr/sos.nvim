local path = 'README.md'
vim.opt.rtp:prepend '.'
local f = assert(io.open('README.md', 'rb'))
local repl = vim.fn.system(
  { 'stylua', '--stdin-filepath', path, '-' },
  [[require('sos').setup ]] .. require('sos.config').def:print_default()
)

assert(vim.v.shell_error == 0, repl)
repl = ('\n\n```lua\n%s\n```\n\n'):format((repl:gsub('%s+$', '')))

local s = f:read('*a'):gsub(
  '(\n[^%S\n]*<!%-%-+%s*BEGIN GENERATED DEFAULTS.-%-%->).-\n([^%S\n]*<!%-%-+%s*END GENERATED DEFAULTS)',
  function(a, b) return a .. repl .. b end,
  1
)

assert(f:close())

f = assert(io.open(path, 'wb'))
assert(f:write(s))
