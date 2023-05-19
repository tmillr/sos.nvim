local M = {}
local config = {}

---@class sos.Validator
---@field matches fun(self: self, other: unknown): boolean

---@type sos.Config
local defaults = {
    enabled = true,
    timeout = 20000,
    autowrite = true,

    ---Settings for acwrite/protocol buffers
    acwrite = {
        ---A function which receives the buf number of an acwrite buffer and
        ---should return a `boolean` indicating whether it should be autosaved.
        ---`nil` means never.
        ---@type nil | fun(buf: integer): boolean
        should_save = function(buf) ---@diagnostic disable-line: unused-local
            return false
        end,
    },

    save_on_cmd = "some",
    save_on_bufleave = true,
    save_on_focuslost = true,
    should_observe_buf = require("sos.impl").should_observe_buf,
    on_timer = require("sos.impl").on_timer,
}

---Get an arbitrarily-nested value from a table
---@param tbl table table to get the value from
---@param path unknown[] array of keys to follow
---@return unknown? value
local function tbl_keypath_get(tbl, path)
    for _, key in ipairs(path) do
        tbl = tbl[key]
        if tbl == nil then break end
    end

    return tbl
end

---Set an arbitrarily-nested value on a table
---@param tbl table
---@param path unknown[]
---@param val unknown
---@return nil
local function tbl_keypath_set(tbl, path, val)
    vim.validate { path = { path, "t", false } }
    local i = 1

    while i < #path do
        assert(tbl ~= nil, "got nil before reaching final key of keypath")
        tbl = tbl[path[i]]
        i = i + 1
    end

    tbl[path[i]] = val
end

--class sos.TableVisit.State<T>: { root: T }
---@class sos.TableVisit.State
---@field parent table the current table
---@field key unknown the current key of `parent`
---@field value unknown the current value of `parent`
---@field type string the type of `value`
---@field keypath unknown[] path of keys to `value`

---@alias sos.TableVisit.DontRecurse boolean

---Recursively visit all values of a table breadth-first
--generic T: table
---@param tbl table
---@param callback fun(state: sos.TableVisit.State): sos.TableVisit.DontRecurse? return `true` to avoid recursing into the current `value`
---@return nil
local function tbl_visit(tbl, callback)
    vim.validate { tbl = { tbl, "table", false } }
    local state
    local meta = getmetatable(tbl)

    if meta and meta[tbl_visit] then
        state = tbl
        meta = meta.__index
    else
        vim.validate { callback = { callback, "f", false } }
        -- TODO: make encapsulated Keypath class?
        meta = { cb = callback, root = tbl, parent = tbl, keypath = {} }
        state = setmetatable({}, { [tbl_visit] = true, __index = meta })
    end

    for _, k in ipairs(vim.tbl_keys(meta.parent)) do
        local v = meta.parent[k]
        meta.type = type(v)
        meta.key = k
        meta.value = v
        table.insert(meta.keypath, k)

        if meta.cb(state) ~= true and meta.type == "table" then
            local tmp = meta.parent
            meta.parent = v
            tbl_visit(state) ---@diagnostic disable-line:missing-parameter
            meta.parent = tmp
        end

        table.remove(meta.keypath)
    end
end

---Convert an array of values to map from each value to `true`
---@param tbl any
---@return table
local function vals_to_map(tbl)
    local ret = {}

    for _, v in ipairs(tbl) do
        ret[v] = true
    end

    return ret
end

local Validator = {}

---Class constructor to construct a Validator subclass
---@param f fun(self: { matches: fun(self: table, other: unknown): boolean }): nil
---@return table class Validator subclass
function Validator:new(f)
    local instance_metatable = { __index = { [self] = true } }
    local new

    if f then
        local classdef = {}
        f(classdef)

        vim.validate {
            new = { classdef.new, "f", true },
            matches = { classdef.matches, "f", false },
            __index = { classdef.__index, "nil", true },
        }

        new = classdef.new
        classdef.new = nil

        for k, v in pairs(classdef) do
            if k:find "^__" then
                instance_metatable[k] = v
            else
                instance_metatable.__index[k] = v
            end
        end
    end

    -- Define the instance constructor
    local new_wrapped = new
            and function(_self, ...)
                return setmetatable(new(_self, ...), instance_metatable)
            end
        or function(_self, ...)
            return setmetatable({ ... }, instance_metatable)
        end

    -- Return the class object/table (a class which extends/is a Validator)
    return setmetatable({ new = new_wrapped }, { __call = new_wrapped })
end

function Validator:is_Validator(val)
    return type(val) == "table" and val[self] ~= nil
end

setmetatable(Validator, { __call = Validator.new })

local Table = Validator(function(self)
    function self:matches(other)
        if type(other) ~= "table" then return false end

        for k, v in pairs(other) do
            if self[1] and not self[1]:matches(k) then return false end
            if self[2] and not self[2]:matches(v) then return false end
        end

        return true
    end

    function self:__tostring()
        if self[1] == nil and self[2] == nil then return "table" end
        return ("table<%s, %s>"):format(self[1], self[2])
    end
end)

local AnyOf = Validator(function(self)
    function self:new(...)
        assert(select("#", ...) == 1, "expected 1 argument")
        vim.validate { or_list = { ..., "t", false } }
        local ret = ...
        assert(#ret > 0, "table arg is empty")
        return ret
    end

    function self:matches(other)
        for _, v in ipairs(self) do
            if v:matches(other) then return true end
        end

        return false
    end

    function self:__tostring()
        return table.concat(self, " | ")
    end
end)

---@type table<"boolean"|"string"|"number"|"function", table>
local Type = Validator(function(self)
    function self:new(k)
        if

            (k ~= "boolean")
            and (k ~= "string")
            and (k ~= "number")
            and (k ~= "function")
        then
            error("invalid type: " .. k)
        end

        return { k }
    end

    function self:matches(other)
        if self[1]:find "^function" then return vim.is_callable(other) end
        return type(other) == self[1]
    end

    function self:__tostring()
        return self[1]
    end
end)

getmetatable(Type).__index = Type.new

---@type fun(lit: true|false|string|number)
local Literal = Validator(function(self)
    function self:new(...)
        assert(select("#", ...) == 1, "expected 1 argument")
        vim.validate { literal = { ..., { "b", "s", "n" }, false } }
        return { ... }
    end

    function self:matches(other)
        return other == self[1]
    end

    function self:__tostring()
        return ("%q"):format(self[1])
    end
end)

local validate = {
    enabled = Type.boolean,
    timeout = Type.number,
    autowrite = Type.boolean,
    acwrite = {
        should_save = Type["function"],
    },
    save_on_cmd = AnyOf {
        Literal "all",
        Literal "some",
        Literal(false),
        Table(Type.string, Type.boolean),
    },
    save_on_bufleave = Type.boolean,
    save_on_focuslost = Type.boolean,
    -- should_observe_buf = require("sos.impl").should_observe_buf,
    -- on_timer = require("sos.impl").on_timer,
}

local function strict_table(tbl)
    return setmetatable({}, {
        __index = function(_self, k)
            assert(validate[k] ~= nil)
            return tbl[k]
        end,
        __newindex = function()
            error("tttt", 2)
        end,
    })
end

---Reset config to default settings
function M:_reset()
    config = vim.deepcopy(defaults)
end

---Apply config to internal config object
---@param new_config table
---@return nil
function M:_apply(new_config)
    tbl_visit(new_config, function(theirs)
        local dont_recurse = true

        ---@type unknown?
        local validator = tbl_keypath_get(validate, theirs.keypath)

        if validator == nil then
            vim.notify(
                ("[sos.nvim]: unrecognized option: %s"):format(theirs.key),
                vim.log.levels.ERROR
            )

        -- If it's not a `Validator` obj, then it must be a plain/regular
        -- table with further nested config keys.
        elseif not Validator.is_Validator(validator) then
            -- TODO: this belongs in/as a test instead?
            assert(type(validator) == "table")

            if theirs.type ~= "table" then
                vim.notify()
            else
                dont_recurse = false

                -- Only set if a table doesn't already exist, otherwise we'd
                -- potentially be overwriting pre-existing values/fields.
                -- if tbl_keypath_get(config, theirs.keypath) == nil then
                --     -- apply to config obj
                --     tbl_keypath_set(
                --         config,
                --         theirs.keypath,
                --         setmetatable({}, {
                --             __index = tbl_keypath_get(
                --                 defaults,
                --                 theirs.keypath
                --             ),
                --         })
                --     )
                -- end
            end

        ---@cast validator sos.Validator
        elseif validator:matches(theirs.value) then
            tbl_keypath_set(
                config,
                theirs.keypath,
                vim.deep_copy(theirs.value)
            )
        else
            vim.notify(
                ("[sos.nvim]: %s: got %s, expected %s"):format(
                    table.concat(theirs.keypath, "."),
                    theirs.value,
                    validator
                ),
                vim.log.levels.ERROR
            )
        end

        return dont_recurse
    end)
end

M:_reset()

---Magical/Proxy object
return setmetatable(M, {
    __index = function(_tbl, key)
        return config[key]
    end,
    __newindex = function()
        error("attempt to assign index of readonly table", 2)
    end,
})

---@class sos.Config                                                      # Plugin options passed to `setup()`.
---@field enabled boolean | nil                                           # Whether to enable or disable the plugin.
---@field timeout integer | nil                                           # Timeout in ms. Buffer changes debounce the timer.
---@field autowrite boolean | "all" | nil                                 # Set and manage Vim's 'autowrite' option.
---@field save_on_cmd "all" | "some" | table<string, true> | false | nil  # Save all buffers before executing a command on cmdline
---@field save_on_bufleave boolean | nil                                  # Save current buffer on `BufLeave` (see `:h BufLeave`)
---@field save_on_focuslost boolean | nil                                 # Save all bufs when Neovim loses focus or is suspended.
---@field should_observe_buf nil | fun(buf: integer): boolean             # Return true to observe/attach to buf.
---@field on_timer function                                               # The function to call when the timer fires.
