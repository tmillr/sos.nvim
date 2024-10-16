rockspec_format = '3.0'
package = 'sos.nvim'
version = 'dev-1'

source = {
  url = 'git://github.com/tmillr/sos.nvim.git',
}

description = {
  summary = 'Never manually save/write a buffer again! An autosaver plugin for Neovim.',

  detailed = [[
Never manually save/write a buffer again!

sos is an autosaver plugin for Neovim that automatically saves all of your changed buffers according to a predefined timeout value. Its main goals are:

• To handle conditions/situations that `'autowriteall'` does not
• To offer a complete, set-and-forget autosave/autowrite solution that saves your buffers for you when you need them saved
• To offer at least some customization via options as well as the ability to easily enable/disable
• To be better or more correct than `CursorHold` autosavers and not depend on `CursorHold`

Additional Features

• Has its own independent timer, distinct from `'updatetime'`, which may be set to any value in ms
• Timer is only started/reset on savable buffer changes, not cursor movements or other irrelevant events
• Keeps buffers in sync with the filesystem by frequently running `:checktime` in the background for you (e.g. on `CTRL-Z` or suspend, resume, command, etc.)
• Intelligently ignores `'readonly'` and other such unwritable buffers/files (i.e. the writing of files with insufficient permissions must be attempted manually with `:w`)
• Tested: https://github.com/tmillr/sos.nvim/tree/master/tests
]],

  license = 'MIT',
  homepage = 'http://github.com/tmillr/sos.nvim',
  issues_url = 'http://github.com/tmillr/sos.nvim/issues',
  maintainer = 'Tyler Miller <tmillr@proton.me>',

  labels = {
    'neovim',
    'plugin',
    'file',
    'write',
    'save',
    'autosave',
    'autosaver',
    'autowrite',
    'autowriter',
  },
}

dependencies = { 'lua >= 5.1' }
test_dependencies = { 'plenary.nvim >= 0.1.4' }

build = {
  type = 'builtin',
  copy_directories = {
    -- 'doc',
    'plugin',
    'tests',
  },
}

test = {
  type = 'command',
  command = 'make test',
}
