local api = vim.api

---@class sos.Type
---@field luatype? "number"|"string"|"boolean"|"table"|"function"|"thread"|"userdata"
---@field luadoc_type_prefix? string prefix for generated type/class names
---@field luadoc_type? string|fun(self, ...): string literal type or type name
---@field luadoc_decl? fun(self, ...): string?
---@field desc? string
---@field message_prefix? string
---Value to use when the provided value is missing or `nil`. Defaults to `nil`.
---@field default? any
---@field default_text? string
---When `true`, it is an error for values of this `Type` to be missing or `nil`.
---@field required? boolean
---@field deprecated? unknown
---@field internal? boolean
local Type = { util = {} }
Type.super = Type

local _overrides = {}

function Type:__index(k)
  local o = _overrides[k]
  if o ~= nil then return o end
  local super = rawget(self, 'super')
  if super == nil then super = Type end
  return rawget(super, k)
end

setmetatable(Type, {
  __call = function(self, def) return self:new(def) end,
})

-- TODO: cleanup desc, deprecations, error func, check for recursion
-- * Example/defaults generator
-- * Doc generator
-- * LSP type generator
-- * Table type where unknown keys are allowed and use index signature
-- * Fn type with strict typechecking of params?
-- * Ordered keys
-- * A generic method for formatting messages?

---@diagnostic disable: unused-vararg

local function extend(...)
  local res = {}
  for i = 1, select('#', ...) do
    for k, v in pairs(select(i, ...)) do
      res[k] = v
    end
  end

  return res
end

function Type:eval(value, overrides, ...)
  if overrides then _overrides = overrides end
  local ok, res = pcall(self.visit, self, value, ...)
  _overrides = {}
  assert(ok, res)
  return res
end

-- Default Implementations

function Type:__tostring() return self:display() end

---How to display or describe the type (e.g. in error messages). Should be
---overriden if `self.luatype` is not defined or descriptive enough.
---@return string
function Type:display() return self.luatype end

function Type:__call(...) return self:call(...) end
function Type:call(...) return self:extend(...) end

---Caller handles description.
---@return string
function Type:print_default()
  if self.default_text then return self.util.trim(self.default_text) end
  -- TODO: Better table serialization
  return vim.inspect(self:get_default())
  -- return tostring(self:get_default())
end

---Visits all types recursively, calling the provided `callback` on each type.
---@param callback fun(self, ...): any?
---@param ... unknown reversed keypath to the type
---@return unknown?
function Type:walk_type(callback, ...) return callback(self, ...) end

function Type:on_error(msg) vim.api.nvim_err_writeln(msg) end

---Retrieves or makes the default value for this `Type`. By default, this method
---is called when the provided value is: of the wrong type, missing, or `nil`.
---The default implementation simply returns `self.default`.
---@param ... string|number|nil reversed keypath
function Type:get_default(...) return self.default end

---Called when the corresponding value is missing or `nil`. Should emit an error
---message if needed. The returned value (if any) will be used instead. The
---default implementation emits an error if `self.required` is truthy and then
---returns the result of `self:get_default(...)`.
---@param ... string|number|nil reversed keypath
---@return unknown? default
function Type:on_nil(...)
  if self.required then
    self:on_error(
      (self.message_prefix or '')
        .. self:fmt_with_keypath(
          ('missing required field: %s'):format((...)),
          ...
        )
    )
  end

  return self:get_default(...)
end

---Called when type-checking fails. Should emit an error message if needed. The
---returned value (if any) will be used in-place of the original `value`.
---@param value any the original value received
---@return unknown? final the value to use instead
---@return string? errmsg
function Type:on_mismatch(value, ...)
  self:on_error(
    (self.message_prefix or '')
      .. self:fmt_with_keypath(
        ('type mismatch: got (%s) %s, expected (%s)'):format(
          type(value),
          type(value) == 'string' and ('%q'):format(value) or value,
          self
        ),
        ...
      )
  )

  return self:get_default(...)
end

function Type:extend(def)
  return Type:new(extend(self, type(def) == 'table' and def or { def }))
end

---Checks whether the provided `value` is of the expected type.
---
---Currently, and by default, this returns `false` only when the `value` is
---entirely unusable and should be thrown away completely (i.e. the validity of
---child types is irrelevant and does not propagate to parent types).
---@param value unknown? the value to be checked by this `Type`
---@param ... string|number|nil the reversed keypath to `value`
---@return boolean valid: whether `value` is of the expected type (not including children)
function Type:check(value, ...) return type(value) == self.luatype end

---The entry point and initial/top-level method called on each `Type` instance
---which in-turn delegates to other methods depending upon the provided,
---corresponding `value`.
---@param value unknown? the value to be checked and resolved by this `Type`
---@param ... string|number|nil the reversed keypath to `value`
---@return unknown? final the final value to be used (after checks and post-processing)
function Type:visit(value, ...)
  if value == nil then return self:on_nil(...) end
  if self.deprecated then return self:on_deprecation(value, ...) end
  if self:check(value, ...) then return self:resolve(value, ...) end
  return self:on_mismatch(value, ...)
end

---@param _value unknown
---@param ... string|number|nil the reversed keypath to `value`
---@return unknown? final: the final value to be used
function Type:on_deprecation(_value, ...)
  local msg

  if type(self.deprecated) == 'string' then
    msg = self.deprecated
  elseif type(self.deprecated) == 'table' and self.deprecated.message then
    msg = self.deprecated.message
  elseif select('#', ...) == 0 then
    return
  else
    msg = ('`%s` is deprecated'):format((...))
  end

  vim.notify_once(
    (self.message_prefix or '') .. self:fmt_with_keypath(msg, ...),
    vim.log.levels.WARN
  )
end

---Called for non-nil values of this type which type-check successfully. This
---method may do additional checks and post-processing on the `value`. For
---example, this method is responsible for type-checking and resolving child
---types/values of aggregate types like `Type.Map` and `Type.Table`.
---@param value unknown
---@param ... string|number|nil the reversed keypath to `value`
---@return unknown? final the final value to be used
function Type:resolve(value, ...) return value end

---@param def sos.Type
---@return sos.Type
function Type:new(def)
  vim.validate {
    def = { def, 'table' },
  }

  vim.validate {
    ['def.luatype'] = { def.luatype, 'string', true },
    ['def.luadoc_decl'] = { def.luadoc_decl, 'function', true },
    ['def.required'] = { def.required, 'boolean', true },
    -- ['opts.check'] = { def.check, 'function', true },
    -- ['opts.resolve'] = { def.resolve, 'function', true },
    -- ['opts.on_nil'] = { def.on_nil, 'function', true },
    -- ['opts.on_mismatch'] = { def.on_mismatch, 'function', true },
  }

  if not (def.check or def.luatype) then
    error 'either `check()` or `luatype` must be passed/defined'
  end

  if not (def.display or def.luatype) then
    error 'either `display()` or `luatype` must be passed/defined'
  end

  if self.deprecated then
    if self.required then error 'a deprecated Type cannot be required' end
  end

  local luadoc_type = def.luadoc_type
  if not luadoc_type then
    error '`luadoc_type` must be passed/defined'
  elseif not vim.is_callable(luadoc_type) then
    vim.validate { ['def.luadoc_type'] = { luadoc_type, 'string' } }
    ---@cast luadoc_type string
    def.luadoc_type = function() return luadoc_type end
  end

  return setmetatable(def, self.super)
end

-- Types

---@class sos.Type.Or: sos.Type
---@field [1] sos.Type
---@field [integer] sos.Type
---@field default_from? integer

---@param def sos.Type.Or
---@return sos.Type.Or
function Type.Or(def)
  if def.check == nil then
    function def:check(value)
      for _, ty in ipairs(self) do
        if ty:check(value) then
          self._match = ty
          return true
        end
      end

      return false
    end

    function def:resolve(value) return self._match:resolve(value) end
  end

  if def.luadoc_type == nil then
    function def:luadoc_type(...)
      local res = {}
      for _, ty in ipairs(self) do
        table.insert(res, (ty:luadoc_type(...):gsub('fun%b():%s*%S+', '(%0)')))
      end

      return table.concat(res, '|')
    end

    function def:display()
      local res = {}
      for _, ty in ipairs(self) do
        table.insert(res, (ty:display():gsub('fun%b():%s*%S+', '(%0)')))
      end

      return table.concat(res, '|')
    end
  end

  function def:get_default(...)
    if self.default then
      return self.default
    elseif type(self.default_from) == 'number' then
      return self[self.default_from]:get_default(...)
    elseif self.default_from ~= nil then
      return self.default_from:get_default(...)
    end
  end

  function def:walk_type(callback, ...)
    if callback(self, ...) then return end

    for _, v in ipairs(self) do
      v:walk_type(callback, ...)
    end
  end

  ---@return string|nil
  function def:fmt_desc()
    -- TODO: handle deprecated, internal, etc. children; handle code blocks
    local desc = self.super.fmt_desc(self)
    local width, res = 0, {}
    self:walk_type(function(ty)
      if ty.deprecated or ty.internal then
        return true
      elseif #ty < 2 then
        local name = ty:luadoc_type()
        if #name > width then width = #name end
        local desc = ty:fmt_desc()
        table.insert(res, {
          name,
          (desc and desc:gsub('^%-%-+%s*', ''):gsub('(\r?\n)%-%-+%s*', '%1')),
        })
        return true
      end
    end)

    local fmt = '---  - %-' .. width .. 's: %s'
    local remaining = 80 - #fmt:gsub('%%%A*s', '') - width

    for i, v in ipairs(res) do
      local name, desc = unpack(v)

      if desc then
        res[i] = (fmt):format(
          name,
          (
            self.util.wrap(desc, remaining):gsub(
              '\r?\n',
              '%0---' .. (' '):rep(#fmt:gsub('%%%A*s', '') + width - 3)
            )
          )
        )
      else
        res[i] = (fmt:gsub(':.-$', '')):format(name)
      end
    end

    return (desc and (desc .. '\n---\n') or '')
      .. '---### Choices:\n---\n'
      .. table.concat(res, '\n')
  end

  return Type:new(def) --[[@as sos.Type.Or]]
end

-- TODO: how to handle errors/warnings/deprecations emitted by child types?
-- especially key type?

---@class sos.Type.Map: sos.Type
---@field keys sos.Type
---@field values sos.Type
---@field inherit_metatable? boolean
---@field inherit_defaults? boolean extend the provided value with mappings from the default
---@overload fun(def: sos.Type.Map): sos.Type.Map
Type.Map = Type:new {
  inherit_metatable = true,
  inherit_defaults = true,
  luatype = 'table',
  luadoc_type = function(self, ...)
    return ('table<%s, %s>'):format(
      self.keys:luadoc_type(...),
      self.values:luadoc_type(...)
    )
  end,

  get_default = function(self, ...)
    if self.default ~= nil then
      -- TODO: do this in ctor instead?
      -- if not self:check(self.default, 'default', ...) then
      --   self:on_error(
      --     self:fmt_with_keypath(
      --       ('type mismatch: got %s, expected %s'):format(
      --         type(self.default),
      --         self.luatype
      --       ),
      --       'default',
      --       ...
      --     )
      --   )
      --
      --   return {}
      -- end

      local res = {}
      for k, v in pairs(self.default) do
        k = self.keys:visit(k, self:fmt_key(k) .. '(key)', ...)
        if k ~= nil then res[k] = self.values:visit(v, k, ...) end
      end

      return res
    end
  end,

  resolve = function(self, value, ...)
    local res = {}

    for k, v in pairs(value) do
      k = self.keys:visit(k, self:fmt_key(k) .. '(key)', ...)
      if k ~= nil then res[k] = self.values:visit(v, k, ...) end

      -- -- TODO: this skips hook, on_mismatch, etc.
      -- if not self.keys:check(k, k, ...) then
      --   self.keys:on_error(
      --     self:fmt_with_keypath(
      --       ('invalid key type: got %s, expected %s'):format(type(k), self.keys),
      --       k,
      --       ...
      --     )
      --   )
      -- else
      --
      --   -- if not self.values:check(v) then
      --   --   res[k] = self.values:on_mismatch(v, k, ...)
      --   -- else
      --   --   res[k] = self.values:resolve(v, k, ...)
      --   -- end
      -- end
    end

    if self.inherit_metatable then setmetatable(res, getmetatable(value)) end

    if self.inherit_defaults then
      local default = self:get_default(...)

      if default ~= nil then
        for k, v in pairs(default) do
          if res[k] == nil then res[k] = v end
        end
      end
    end

    return res
  end,

  walk_type = function(self, callback, ...)
    if callback(self, ...) then return end
    callback(self.keys, ...)
    callback(self.values, ...)
  end,
} --[[@as sos.Type.Map]]

---@overload fun(def: sos.Type): sos.Type
Type.Boolean = Type:new {
  luatype = 'boolean',
  luadoc_type = function() return 'boolean' end,
}

---@overload fun(def: sos.Type): sos.Type
Type.String = Type:new {
  luatype = 'string',
  luadoc_type = function() return 'string' end,
  -- print_default = function(self)
  --   if self.default_text then return self.super.print_default(self) end
  --   local default = self:get_default()
  --   if default == nil then return self.super.print_default(self) end
  --   return ('%q'):format(default)
  -- end,
}

---@overload fun(def: sos.Type): sos.Type
Type.Function = Type:new {
  luatype = 'function',
  luadoc_type = function() return 'function' end,
}

---@overload fun(def: sos.Type): sos.Type
Type.Number =
  Type:new { luatype = 'number', luadoc_type = function() return 'number' end }

---@overload fun(def: sos.Type): sos.Type
Type.Integer = Type.Number:extend {
  display = function() return 'integer' end,
  luadoc_type = function() return 'integer' end,
  check = function(self, value)
    return Type.check(self, value) and value % 1 == 0
  end,
}

---@overload fun(def: sos.Type): sos.Type
Type.Callable = Type:new {
  display = function() return 'Callable' end,
  luadoc_type = function() return 'Callable' end,
  check = function(_self, value) return vim.is_callable(value) end,
}

---@overload fun(def: sos.Type): sos.Type
Type.Literal = Type:new {
  get_default = function(self) return self[1] end,

  display = function(self)
    return (type(self[1]) == 'string' and '%q' or '%s'):format(self[1])
  end,

  luadoc_type = function(self)
    return (type(self[1]) == 'string' and '%q' or '%s'):format(self[1])
  end,

  check = function(self, value, ...) return value == self[1] end,
}

---@class sos.Type.Table: sos.Type
---@field ignore_extra_keys? boolean whether unknown keys are allowed
---@field fields? table<string|number, sos.Type>
---@overload fun(def: sos.Type.Table, fields: table<string|number, sos.Type>): sos.Type.Table
---@overload fun(fields: table<string|number, sos.Type>): sos.Type.Table
Type.Table = Type:new {
  luatype = 'table',
  ignore_extra_keys = false,
  luadoc_type = function(self, ...)
    if not self.fields then return 'table' end
    return table.concat(self.util.tbl_reverse { ... }, '.')
  end,

  luadoc_decl = function(self, ...)
    if not self.fields then return end
    local res = {}

    do
      local desc = self:fmt_desc()
      if desc then
        table.insert(res, desc)
        table.insert(res, '\n')
      end
    end

    table.insert(res, '---@class (exact) ')
    table.insert(res, (self:luadoc_type(...)))
    table.insert(res, '\n')

    for _, f in ipairs(self.fields) do
      local k, v = f.key, f.type
      if not v.deprecated and not v.internal then
        local desc = v:fmt_desc()
        if desc then
          table.insert(res, desc)
          table.insert(res, '\n')
        end

        table.insert(res, '---@field ')
        -- TODO: What if k isn't a string|number?
        table.insert(res, k)
        if not v.required then table.insert(res, '?') end
        table.insert(res, ' ')
        table.insert(res, v:luadoc_type(k, ...))
        table.insert(res, '\n')
      end
    end

    return table.concat(res)
  end,

  -- call = function(self, ...)
  --   local a = select(1, ...)
  --
  --   if select('#', ...) > 1 then
  --     a.fields = select(2, ...)
  --   else
  --     a = { fields = a }
  --   end
  --
  --   return self:extend(a)
  -- end,

  get_default = function(self, ...)
    if self.default ~= nil then
      return vim.deepcopy(self.default, true)
    elseif self.fields ~= nil then
      local res = {}

      for _, f in ipairs(self.fields) do
        local k, v = f.key, f.type
        -- NOTE: Must avoid deprecation check here
        -- v:hook(nil, k, ...)
        res[k] = v:on_nil(k, ...)
      end

      return res
    end
  end,

  resolve = function(self, value, ...)
    if self.fields ~= nil then
      local res = {}

      for _, f in ipairs(self.fields) do
        local k, v = f.key, f.type
        res[k] = v:visit(value[k], k, ...)
      end

      if not self.ignore_extra_keys then
        if self.map == nil then
          self.map = {}
          for _, f in ipairs(self.fields) do
            self.map[f.key] = true
          end
        end

        for k in pairs(value) do
          if self.map[k] == nil then
            self:on_error(
              (self.message_prefix or '')
                .. self:fmt_with_keypath(
                  ('unexpected key: %s'):format(k),
                  k,
                  ...
                )
            )
          end
        end
      end

      return res
    end

    return vim.deepcopy(value, true)
  end,

  walk_type = function(self, callback, ...)
    if callback(self, ...) then return end

    for _, f in ipairs(self.fields) do
      f.type:walk_type(callback, f.key, ...)
    end
  end,

  print_default = function(self)
    if self.default_text or self.default or not self.fields then
      return self.super.print_default(self)
    end

    local res = { '{' }
    for _, f in ipairs(self.fields) do
      local k, v = f.key, f.type
      if not v.deprecated and not v.internal then
        table.insert(res, '\n')

        local desc = v:fmt_desc()
        if desc then
          table.insert(res, desc)
          table.insert(res, '\n')
        end

        -- TODO: What if k isn't a string|number?
        local fmt
        if type(k) == 'string' then
          fmt = '%s = %s,\n'
        else
          fmt = '[%s] = %s,\n'
        end

        table.insert(res, (fmt):format(k, v:print_default()))
      end
    end

    table.insert(res, '}')
    return table.concat(res)
  end,
} --[[@as sos.Type.Table]]

-- Extras

---@return string luadoc
function Type:to_luadoc()
  local declarations, seen = {}, {}

  local function callback(self, ...)
    if self.deprecated then return true end

    if self.luadoc_decl and not seen[self] then
      seen[self] = true
      local decl = self:luadoc_decl(...)
      if decl then table.insert(declarations, decl) end
    end
  end

  if self.luadoc_type_prefix then
    self:walk_type(callback, self.luadoc_type_prefix)
  else
    self:walk_type(callback)
  end

  return table.concat(declarations, '\n')
end

--[[ Formatting/Strings ]]

function Type:fmt_key(k)
  if type(k) == 'string' then
    return k
  elseif type(k) == 'number' then
    -- k = ('[%s]'):format(k)
    return k
  else
    return ('<%s>'):format(k)
  end
end

function Type:fmt_with_keypath(s, ...)
  if select('#', ...) == 0 then return s end
  local res = {}

  for i = select('#', ...), 1, -1 do
    table.insert(res, self:fmt_key((select(i, ...))))
  end

  return table.concat(res, '.') .. ': ' .. s
end

---@return string|nil
function Type:fmt_desc()
  return self.desc
      and (self.desc
        :gsub('^%s*', '---')
        :gsub('%s+$', '')
        :gsub('\n[^%S\n]*', '\n---'))
    or nil
end

--[[ Utils ]]

function Type.util.trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

function Type.util.tbl_reverse(tbl)
  local res = {}
  for i = #tbl, 1, -1 do
    table.insert(res, tbl[i])
  end

  return res
end

local buf

function Type.util.wrap(str, width)
  -- align = align or 'right'
  if not (buf and api.nvim_buf_is_valid(buf)) then
    buf = api.nvim_create_buf(false, true)
    vim.bo[buf].ft = 'markdown'
    vim.bo[buf].swf = false
    vim.bo[buf].et = true
    api.nvim_set_option_value('undolevels', -1, { buf = buf })
    vim.schedule(function()
      api.nvim_buf_delete(buf, { force = true })
      buf = nil
    end)
  end

  vim.bo[buf].tw = width
  api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    true,
    vim.split(str, '\r?\n', { plain = false })
  )

  api.nvim_buf_call(
    buf,
    function() pcall(vim.cmd, [[silent! %smagic/^\s*$//]]) end
  )
  -- api.nvim_buf_set_text(buf, 0, 0, 0, 0, { (' '):rep(indent or 0) })
  api.nvim_buf_call(buf, function() vim.cmd 'normal! gg0gwG' end)
  -- api.nvim_buf_call(
  --   buf,
  --   function() vim.cmd(([[silent %%%s 80]]):format(align)) end
  -- )
  return table.concat(api.nvim_buf_get_lines(buf, 0, -1, true), '\n')
end

---@diagnostic enable: unused-vararg
return Type
