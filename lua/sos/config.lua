local Type = require 'sos.type'
local util = require 'sos.util'

---@class sos.config
local M = {}

---@alias sos.Callable table

-- BEGIN GENERATED TYPES

---@class (exact) sos.config.opts
---Whether to enable the plugin.
---@field enabled? boolean
---Timeout in milliseconds for the global timer. Buffer changes debounce the
---timer.
---@field timeout? integer
---Automatically create missing parent directories when writing/autosaving a
---buffer.
---@field create_parent_dirs? boolean
---Whether to set and manage Vim's 'autowrite' option.
---
---### Choices:
---
---  - "all": set and manage 'autowriteall'
---  - true : set and manage 'autowrite'
---  - false: don't set or manage any of Vim's 'autowwrite' options
---@field autowrite? "all"|true|false
---Save all buffers before executing a `:` command on the cmdline (does not
---include `<Cmd>` mappings).
---
---### Choices:
---
---  - "all"                 : save on any cmd that gets executed
---  - "some"                : only for some commands (source, luafile, etc.).
---                            not perfect, but may lead to fewer unnecessary
---                            file writes compared to `"all"`.
---  - table<string, boolean>: map specifying which commands trigger a save
---                            where keys are the full command names
---  - false                 : never/disable
---@field save_on_cmd? "all"|"some"|table<string, boolean>|false
---Save current buffer on `BufLeave`. See `:help BufLeave`.
---@field save_on_bufleave? boolean
---Save all buffers when Neovim loses focus or is suspended.
---@field save_on_focuslost? boolean
---@field should_save? sos.config.opts.should_save
---@field hooks? sos.config.opts.hooks

---@class (exact) sos.config.opts.should_save
---Whether to autosave buffers which aren't modifiable.
---See `:help 'modifiable'`.
---@field unmodifiable? boolean
---How to handle `acwrite` type buffers (i.e. where `vim.bo.buftype ==
---"acwrite"` or the buffer's name is a URI). These buffers use an autocmd to
---perform special actions and side-effects when saved/written.
---@field acwrite? sos.config.opts.should_save.acwrite

---How to handle `acwrite` type buffers (i.e. where `vim.bo.buftype ==
---"acwrite"` or the buffer's name is a URI). These buffers use an autocmd to
---perform special actions and side-effects when saved/written.
---@class (exact) sos.config.opts.should_save.acwrite
---Whether to autosave buffers which perform network actions (such as sending a
---request) on save/write. E.g. `scp`, `http`
---@field net? boolean
---Whether to autosave buffers which perform git actions (such as staging
---buffer content) on save/write. E.g. `fugitive`, `diffview`, `gitsigns`
---@field git? boolean
---Whether to autosave buffers which process the file on save/write.
---E.g. `tar`, `zip`, `gzip`
---@field compress? boolean
---Whether to autosave `acwrite` buffers which don't match any of the other
---acwrite criteria/filters.
---@field other? boolean
---URI schemes to allow/disallow autosaving for. If a scheme is set to `false`,
---any buffer whose name begins with that scheme will not be autosaved.
---Provided schemes should be lowercase and will be matched case-insensitively.
---Schemes take precedence over other `acwrite` filters.
---
---Example:
---
---```lua
---schemes = { http = false, octo = false, file = true }
---```
---@field schemes? table<string, boolean>

---@class (exact) sos.config.opts.hooks
---A function – or any other callable value – which is called just before
---writing/autosaving a buffer. If `false` is returned, the buffer will not be
---written.
---@field buf_autosave_pre? sos.Callable|fun(bufnr: integer, bufname: string): boolean?
---A function – or any other callable value – which is called just after
---writing/autosaving a buffer (even if the write failed).
---@field buf_autosave_post? sos.Callable|fun(bufnr: integer, bufname: string, errmsg?: string)

-- END GENERATED TYPES

local assertf = util.assertf_with_mod 'config'

local should_save = Type.Table {
  fields = {
    {
      key = 'unmodifiable',
      type = Type.Boolean {
        default = true,
        desc = [[
    Whether to autosave buffers which aren't modifiable.
    See `:help 'modifiable'`.
]],
      },
    },

    {
      key = 'acwrite',
      type = Type.Table {
        desc = [[
    How to handle `acwrite` type buffers (i.e. where `vim.bo.buftype ==
    "acwrite"` or the buffer's name is a URI). These buffers use an autocmd to
    perform special actions and side-effects when saved/written.
]],
        fields = {
          {
            key = 'net',
            type = Type.Boolean {
              default = true,
              desc = [[
    Whether to autosave buffers which perform network actions (such as sending a
    request) on save/write. E.g. `scp`, `http`
]],
            },
          },

          {
            key = 'git',
            type = Type.Boolean {
              default = true,
              desc = [[
    Whether to autosave buffers which perform git actions (such as staging
    buffer content) on save/write. E.g. `fugitive`, `diffview`, `gitsigns`
]],
            },
          },

          {
            key = 'compress',
            type = Type.Boolean {
              default = true,
              desc = [[
    Whether to autosave buffers which process the file on save/write.
    E.g. `tar`, `zip`, `gzip`
]],
            },
          },

          {
            key = 'other',
            type = Type.Boolean {
              default = true,
              desc = [[
    Whether to autosave `acwrite` buffers which don't match any of the other
    acwrite criteria/filters.
]],
            },
          },

          {
            key = 'schemes',
            type = Type.Map {
              keys = Type.String,
              values = Type.Boolean,
              desc = [[
    URI schemes to allow/disallow autosaving for. If a scheme is set to `false`,
    any buffer whose name begins with that scheme will not be autosaved.
    Provided schemes should be lowercase and will be matched case-insensitively.
    Schemes take precedence over other `acwrite` filters.

    Example:

    ```lua
    schemes = { http = false, octo = false, file = true }
    ```
]],
              default_text = [[{
                ---Octo buffers are disabled by default as they can create new
                ---issues, PR's, and comments on write/save.
                octo = false,
                term = false,
                file = true,
              }]],
              get_default = function(self)
                return assert(loadstring('return ' .. self.default_text))()
              end,
            },
          },
        },
      },
    },
  },
}

M.def = Type.Table {
  luadoc_type_prefix = 'sos.config.opts',
  fields = {
    {
      key = 'enabled',
      type = Type.Boolean {
        default = true,
        desc = [[Whether to enable the plugin.]],
      },
    },

    {
      key = 'timeout',
      type = Type.Integer {
        default = 10000,
        desc = [[
    Timeout in milliseconds for the global timer. Buffer changes debounce the
    timer.
]],
      },
    },

    {
      key = 'create_parent_dirs',
      type = Type.Boolean {
        default = true,
        desc = [[
    Automatically create missing parent directories when writing/autosaving a
    buffer.
]],
      },
    },

    {
      key = 'autowrite',
      type = Type.Or {
        Type.Literal { 'all', desc = [[set and manage 'autowriteall']] },
        Type.Literal { true, desc = [[set and manage 'autowrite']] },
        Type.Literal {
          false,
          desc = [[don't set or manage any of Vim's 'autowwrite' options]],
        },
        default = true,
        desc = [[Whether to set and manage Vim's 'autowrite' option.]],
      },
    },

    {
      key = 'save_on_cmd',
      type = Type.Or {
        Type.Literal {
          'all',
          desc = [[save on any cmd that gets executed]],
        },
        Type.Literal {
          'some',
          desc = [[
    only for some commands (source, luafile, etc.). not perfect, but may lead to
    fewer unnecessary file writes compared to `"all"`.
]],
        },
        Type.Map {
          keys = Type.String,
          values = Type.Boolean,
          -- values = Type.Literal(true),
          desc = [[
    map specifying which commands trigger a save where keys are the full command
    names
]],
        },
        Type.Literal { false, desc = [[never/disable]] },
        default = 'some',
        desc = [[
    Save all buffers before executing a `:` command on the cmdline (does not
    include `<Cmd>` mappings).
]],
      },
    },

    {
      key = 'save_on_bufleave',
      type = Type.Boolean {
        default = true,
        desc = [[Save current buffer on `BufLeave`. See `:help BufLeave`.]],
      },
    },

    {
      key = 'save_on_focuslost',
      type = Type.Boolean {
        default = true,
        desc = [[Save all buffers when Neovim loses focus or is suspended.]],
      },
    },

    {
      key = 'should_observe_buf',
      type = Type.Function {
        deprecated = '`should_observe_buf` is deprecated, please remove it from your config',
        luadoc_type = 'fun(buf: integer): boolean',
        desc = [[Return true to observe/attach to buf.]],
      },
    },

    {
      key = 'on_timer',
      type = Type.Function {
        internal = true,
        default = require('sos.impl').on_timer,
        desc = [[The function to call when the timer fires.]],
      },
    },

    {
      key = 'should_save',
      type = should_save,
    },

    {
      key = 'hooks',
      type = Type.Table {
        fields = {
          {
            key = 'buf_autosave_pre',
            type = Type.Callable {
              luadoc_type = 'sos.Callable|fun(bufnr: integer, bufname: string): boolean?',
              default_text = 'function(bufnr, bufname) end',
              default = util.no_op,
              desc = [[
    A function – or any other callable value – which is called just before
    writing/autosaving a buffer. If `false` is returned, the buffer will not be
    written.
]],
            },
          },

          {
            key = 'buf_autosave_post',
            type = Type.Callable {
              luadoc_type = 'sos.Callable|fun(bufnr: integer, bufname: string, errmsg?: string)',
              default_text = 'function(bufnr, bufname, errmsg) end',
              default = util.no_op,
              desc = [[
    A function – or any other callable value – which is called just after
    writing/autosaving a buffer (even if the write failed).
]],
            },
          },
        },
      },
    },
  },
}

-- local res = {} {{{
-- for _, a in ipairs(vim.api.nvim_get_autocmds {}) do
--   if a.event:lower():find 'cmd$' then
--     table.insert(res, a.event .. ' ' .. a.pattern)
--   end
-- end
-- vim.fn.setreg('+', table.concat(res, '\n'))
--
-- BufReadCmd *.shada
-- BufReadCmd *.shada.tmp.[a-z]
-- BufReadCmd *.tar.gz
-- BufReadCmd *.tar
-- BufReadCmd *.lrp
-- BufReadCmd *.tar.bz2
-- BufReadCmd *.tar.Z
-- BufReadCmd *.tbz
-- BufReadCmd *.tgz
-- BufReadCmd *.tar.lzma
-- BufReadCmd *.tar.xz
-- BufReadCmd *.txz
-- BufReadCmd *.tar.zst
-- BufReadCmd *.tzst
-- BufReadCmd *.aar
-- BufReadCmd *.apk
-- BufReadCmd *.celzip
-- BufReadCmd *.crtx
-- BufReadCmd *.docm
-- BufReadCmd *.docx
-- BufReadCmd *.dotm
-- BufReadCmd *.dotx
-- BufReadCmd *.ear
-- BufReadCmd *.epub
-- BufReadCmd *.gcsx
-- BufReadCmd *.glox
-- BufReadCmd *.gqsx
-- BufReadCmd *.ja
-- BufReadCmd *.jar
-- BufReadCmd *.kmz
-- BufReadCmd *.odb
-- BufReadCmd *.odc
-- BufReadCmd *.odf
-- BufReadCmd *.odg
-- BufReadCmd *.odi
-- BufReadCmd *.odm
-- BufReadCmd *.odp
-- BufReadCmd *.ods
-- BufReadCmd *.odt
-- BufReadCmd *.otc
-- BufReadCmd *.otf
-- BufReadCmd *.otg
-- BufReadCmd *.oth
-- BufReadCmd *.oti
-- BufReadCmd *.otp
-- BufReadCmd *.ots
-- BufReadCmd *.ott
-- BufReadCmd *.oxt
-- BufReadCmd *.potm
-- BufReadCmd *.potx
-- BufReadCmd *.ppam
-- BufReadCmd *.ppsm
-- BufReadCmd *.ppsx
-- BufReadCmd *.pptm
-- BufReadCmd *.pptx
-- BufReadCmd *.sldx
-- BufReadCmd *.thmx
-- BufReadCmd *.vdw
-- BufReadCmd *.war
-- BufReadCmd *.wsz
-- BufReadCmd *.xap
-- BufReadCmd *.xlam
-- BufReadCmd *.xlsb
-- BufReadCmd *.xlsm
-- BufReadCmd *.xlsx
-- BufReadCmd *.xltm
-- BufReadCmd *.xltx
-- BufReadCmd *.xpi
-- BufReadCmd *.zip
-- BufReadCmd man://*
-- BufReadCmd dap-eval://*
-- BufReadCmd index{,.lock}
--
-- BufWriteCmd *.shada
-- BufWriteCmd *.shada.tmp.[a-z]
-- FileAppendCmd *.shada
-- FileAppendCmd *.shada.tmp.[a-z]
--
-- FileReadCmd *.shada
-- FileReadCmd *.shada.tmp.[a-z]
--
--
-- FileWriteCmd *.shada
-- FileWriteCmd *.shada.tmp.[a-z]
-- SourceCmd *.shada
-- SourceCmd *.shada.tmp.[a-z] }}}

---@param opts? sos.config.opts
function M.apply(opts)
  local preset = {
    net = {
      schemes = {
        dav = true,
        davs = true,
        dns = true,
        ftp = true,
        http = true,
        https = true,
        imap = true,
        ldap = true,
        mail = true,
        mailto = true,
        mqtt = true,
        pop = true,
        rcp = true,
        rsync = true,
        scp = true,
        sftp = true,
        smtp = true,
        ssh = true,
        sshfs = true,
        tcp = true,
        udp = true,
        wss = true,
      },
    },

    -- TODO: Finish implementing these. Use builtin plugins/autocmds for ref.
    -- E.g. plugins gzip, tar, zip, etc.
    compress = {
      schemes = {
        gz = true,
        gzip = true,
        tar = true,
        tarfile = true,
        zipfile = true,
      },
    },

    -- TODO: Add/support more git plugins. There must be more?
    git = {
      schemes = {
        fugitive = true,
        diffview = true,
        gitsigns = true,
      },
    },
  }

  M.opts = M.def:eval(opts, { message_prefix = '[sos.config]: ' }, 'config') --[[@as sos.config.opts]]

  local pred = M.opts.should_save
  assertf(pred, 'internal error: config resolution')
  ---@cast pred -?

  local schemes_final = pred.acwrite.schemes
  assertf(schemes_final, 'internal error: config resolution')
  ---@cast schemes_final -?

  function M.predicate(bufnr, _bufname, acwrite_buftype, scheme)
    if vim.bo[bufnr].ma == false then
      if pred.unmodifiable == false then return false end
    end

    if scheme then
      local should = schemes_final[scheme]
      if should ~= nil then return should ~= false end
      return pred.acwrite.other
    end

    if acwrite_buftype then return pred.acwrite.other end
  end

  local function apply_schemes(schemes, enable)
    for sch in pairs(schemes) do
      if schemes_final[sch] == nil then schemes_final[sch] = enable end
    end
  end

  apply_schemes(preset.net.schemes, pred.acwrite.net)
  apply_schemes(preset.git.schemes, pred.acwrite.git)
  apply_schemes(preset.compress.schemes, pred.acwrite.compress)

  for _, k in ipairs(vim.tbl_keys(schemes_final)) do
    local lower = k:lower()
    if schemes_final[lower] == nil then
      schemes_final[lower] = schemes_final[k]
    end
  end
end

return M
