local api, uv = vim.api, vim.uv or vim.loop
local util = require 'sos._test.util'

local got_VimSuspend_after_resuming
local got_VimResume_before_resuming

describe('test harness', function()
  it('can suspend and resume', function()
    util.with_nvim(function(nvim)
      local got_suspend = util.tmpfile()
      local got_resume = util.tmpfile()
      local res = {}

      nvim:create_autocmd('VimSuspend', {
        once = true,
        nested = false,
        command = ('lua vim.fn.writefile({}, %q)'):format(got_suspend),
      })

      nvim:create_autocmd('VimResume', {
        once = true,
        nested = false,
        command = ('lua vim.fn.writefile({}, %q)'):format(got_resume),
      })

      nvim:suspend()
      util.wait(250)
      res.got_VimSuspend = util.file_exists(got_suspend)
      got_VimResume_before_resuming = util.file_exists(got_resume)

      -- for extra confirmation of proc state, but doesn't seem to work
      -- local out = vim.fn.system { "ps", "-p", pid, "-o", "state=" }
      -- assert(out:find "^T", "ps output: " .. out)

      nvim:cont()
      util.wait(250)
      res.got_VimResume = util.file_exists(got_resume)
      got_VimSuspend_after_resuming = not res.got_VimSuspend
        and util.file_exists(got_suspend)

      assert.are.same({
        got_VimSuspend = true,
        got_VimResume = true,
      }, res)
    end)
  end)
end)

describe('VimSuspend and VimResume', function()
  it('fire at the correct time', function()
    assert.is.False(
      got_VimSuspend_after_resuming,
      'expected VimSuspend before resuming'
    )
    assert.is.False(
      got_VimResume_before_resuming,
      'expected VimResume after resuming'
    )
  end)
end)

describe('neovim by default', function()
  -- NOTE: However, 'autowriteall' implies 'autowrite'!
  it("doesn't save on suspend when 'autowrite' is off", function()
    local nvim = util.start_nvim()
    local tmp = util.tmpfile()
    nvim:set_option('autowrite', false)
    nvim:set_option('autowriteall', false)
    nvim:buf_set_name(0, tmp)
    nvim:buf_set_lines(0, 0, -1, true, { 'x' })
    nvim:suspend()
    util.wait(500)
    assert(uv.fs_stat(tmp) == nil, 'expected file not to be saved')
  end)

  it(
    "does save on suspend when 'autowrite' is on, even if &bufhidden = hide",
    function()
      local nvim = util.start_nvim()
      local tmp = util.tmpfile()
      nvim:buf_set_option(0, 'bufhidden', 'hide')
      nvim:set_option('autowrite', true)
      nvim:buf_set_name(0, tmp)
      nvim:buf_set_lines(0, 0, -1, true, { 'x' })
      nvim:suspend()
      util.wait(250)
      local stat = assert(uv.fs_stat(tmp))
      assert(stat.type == 'file', "dirent exists but isn't a regular file")
    end
  )

  -- :checktime implicitly triggers re-read of all files that've changed
  -- outside vim which were not also 'modified' in that vim (i.e. had pending
  -- changes which weren't saved yet).
  --
  -- For files which are also 'modified' in the current vim, an err/warn msg
  -- (or prompt asking how to proceed) will print including the filename.
  --
  -- The goal is to autosave often (and in crucial moments such as before
  -- suspending) in order to try to avoid such situations as the latter.
  --
  -- This test here is to make sure that it's ok to implement this ourselves
  -- without duplicating work (e.g. if this feature ever gets implemented in
  -- neovim itself (i.e. upstream) someday), the feature in question being:
  -- the checking of file times on vim resume.
  it("doesn't do `:checktime` nor autoread on resume", function()
    local nvim = util.start_nvim()
    local tmp = util.tmpfile()
    assert(vim.fn.writefile({ 'old' }, tmp, 'b') == 0)
    nvim:set_option('autoread', true)
    nvim:cmd({ cmd = 'edit', args = { tmp } }, { output = false })
    util.wait(500)
    nvim:suspend()
    util.wait(500)
    assert(vim.fn.writefile({ 'new new new' }, tmp, 'b') == 0)
    util.wait(500)
    nvim:cont()
    util.wait(500)
    assert(table.concat(nvim:buf_get_lines(0, 0, -1, true), '') == 'old')
    nvim:cmd({ cmd = 'checktime' }, { output = false })
    assert(
      table.concat(nvim:buf_get_lines(0, 0, -1, true), '') == 'new new new'
    )
  end)

  it("doesn't automatically check file times upon leaving term", function()
    local nvim = util.start_nvim {}
    local tmp = util.tmpfile()
    assert(vim.fn.writefile({ 'old' }, tmp, 'b') == 0)
    nvim:set_option('autoread', true)

    nvim:cmd({ cmd = 'edit', args = { tmp } }, { output = false })

    local tab = nvim:get_current_tabpage()
    local buf = nvim:get_current_buf()
    nvim:cmd({ cmd = 'tabnew' }, { output = false })
    nvim:cmd({ cmd = 'tabnew' }, { output = false })

    -- enter term
    nvim:cmd({ cmd = 'terminal' }, { output = false })
    nvim:cmd({ cmd = 'startinsert' }, { output = false })

    -- modify file
    assert(vim.fn.writefile({ 'new new new' }, tmp, 'b') == 0)
    util.wait(500)

    -- visit different tab thereby leaving term
    nvim:set_current_tabpage(tab) -- trigger sos to check file times (which triggers autoread)

    assert(table.concat(nvim:buf_get_lines(buf, 0, -1, true), '') == 'old')
  end)

  it('fires UIEnter on resume', function()
    util.with_nvim(function(nvim)
      local got_UIEnter = util.tmpfile()
      nvim:create_autocmd('UIEnter', {
        once = true,
        nested = false,
        command = ([[lua vim.fn.writefile({}, %q, 's')]]):format(got_UIEnter),
      })

      nvim:suspend()
      util.wait(250)
      assert.is.False(util.file_exists(got_UIEnter))
      nvim:cont()
      util.wait(250)
      assert.is.True(util.file_exists(got_UIEnter))
    end)
  end)
end)

-- TODO: For FileChangedShell, FileChangedShellPost does it run when trying to
-- save a buffer that has modifications and is out of sync with file on fs?
-- (changed internally and externally) does it still run when autoread happens?
-- (i.e. buffer wasn't modified and there'd be no default prompt)

describe('sos.nvim', function()
  -- TODO: This test currently fails, but this isn't the behavior when actually
  -- running/using nvim normally in a normal terminal. Why?
  --
  -- Maybe these kinds of tests should only be run manually (or, we need to
  -- upgrade the test harness to be able to handle normal/realistic
  -- suspend/resume).
  it('should automatically check file times on resume', function()
    local nvim = util.start_nvim {
      xargs = {
        '-u',
        'tests/min_init.lua',
        [[+lua require'sos'.setup { enabled = true }]],
      },
    }

    local old = { 'old', '' }
    local tmp = util.tmpfile(old)
    assert.are.same(old, vim.fn.readfile(tmp, 'b'))

    nvim:set_option('autoread', true)
    nvim:cmd({ cmd = 'edit', args = { tmp } }, { output = false })
    assert.are.same(old, { nvim:buf_get_lines(0, 0, -1, true)[1], '' })
    util.wait(500)

    nvim:suspend()
    util.wait(500)

    local new = { 'final', '' }
    assert(vim.fn.writefile(new, tmp, 'bs') == 0)
    assert.are.same(new, vim.fn.readfile(tmp, 'b'))
    util.wait(500)

    nvim:cont()
    util.wait(2000)
    util.assert.normal_mode_nonblocking(nvim:get_mode())
    assert.are.same(new, { nvim:buf_get_lines(0, 0, -1, true)[1], '' })
  end)

  it('should automatically check file times upon leaving term', function()
    local nvim = util.start_nvim {
      xargs = {
        '-u',
        'tests/min_init.lua',
        [[+lua require'sos'.setup { enabled = true }]],
      },
    }

    local tmp = util.tmpfile 'old'
    nvim:set_option('autoread', true)

    nvim:cmd({ cmd = 'edit', args = { tmp } }, { output = false })

    local tab = nvim:get_current_tabpage()
    local buf = nvim:get_current_buf()
    nvim:cmd({ cmd = 'tabnew' }, { output = false })
    nvim:cmd({ cmd = 'tabnew' }, { output = false })

    -- enter term
    nvim:cmd({ cmd = 'terminal' }, { output = false })
    nvim:cmd({ cmd = 'startinsert' }, { output = false })

    -- modify file
    assert(vim.fn.writefile({ 'new new new' }, tmp, 'bs') == 0)
    util.wait(500)

    -- visit different tab, thereby leaving term
    nvim:set_current_tabpage(tab) -- trigger sos to check file times (which triggers autoread)
    util.wait(2000)
    util.assert.normal_mode_nonblocking(nvim:get_mode())
    assert.are.same({ 'new new new' }, nvim:buf_get_lines(0, 0, -1, true))
  end)

  it('should save all bufs on suspend', function()
    util.with_nvim({
      xargs = {
        '-u',
        'tests/min_init.lua',
      },
    }, function(nvim)
      local tmp_a = util.tmpfile()
      local tmp_b = util.tmpfile()
      nvim:set_option('awa', false)
      nvim:set_option('aw', false)
      nvim:set_option('hidden', true)
      nvim:silent_edit(tmp_a)
      nvim:buf_set_lines(0, 0, -1, true, { 'changes' })
      nvim:silent_edit(tmp_b)
      nvim:buf_set_lines(0, 0, -1, true, { 'changes' })
      nvim:exec_lua(
        function() return require('sos').setup { enabled = true, timeout = 9e6 } end
      )
      util.wait(200)
      nvim:suspend()
      util.wait(200)
      assert.is.True(util.file_exists(tmp_a))
      assert.is.True(util.file_exists(tmp_b))
    end)
  end)
end)
