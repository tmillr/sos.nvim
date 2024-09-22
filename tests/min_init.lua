local api = vim.api

xpcall(function()
  vim.o.updatecount = 0
  vim.o.swapfile = false
  vim.o.shadafile = 'NONE'
  vim.o.aw = false
  vim.o.awa = false
  vim.o.more = false
  vim.o.shortmess = 'FWI'
  vim.o.showmode = false
  vim.o.showcmd = false

  local plenary = vim.env.PLENARY
    or (function()
      for _, val in ipairs { 'PATH', 'DIR' } do
        local v = vim.env['PLENARY' .. val] or vim.env['PLENARY_' .. val]
        if v then return v end
      end

      local searchpath = {
        vim.fn.stdpath 'data',
        vim.fn.stdpath 'config',
        vim.fn.expand '~' .. '/.luarocks',
        vim.fn.stdpath 'data_dirs',
      }

      searchpath = vim.tbl_filter(
        function(v) return vim.fn.getftype(v) == 'dir' end,
        vim.tbl_flatten(searchpath)
      )

      for _, dir in ipairs(searchpath) do
        local paths = vim.fs.find(
          'plenary.nvim',
          { path = dir, limit = math.huge, type = 'directory' }
        ) or {}

        for _, path in ipairs(paths) do
          if
            vim.fn.filereadable(path .. '/plugin/plenary.vim') == 1
            or vim.fn.filereadable(path .. '/plugin/plenary.lua') == 1
          then
            return path
          end
        end
      end
    end)()

  assert(
    plenary,
    "unable to find plenary.nvim, please specify path with `PLENARY='"
  )

  vim.opt.rtp:append(plenary)
  vim.opt.rtp:prepend '.'

  for _, ext in ipairs { 'vim', 'lua' } do
    vim.cmd('runtime! plugin/plenary.' .. ext)
    vim.cmd('runtime! plugin/sos.' .. ext)
  end
end, function(e)
  api.nvim_chan_send(vim.v.stderr, '\027[31mError: ' .. e .. '\027[0m\n')
  vim.cmd 'cq'
end)
