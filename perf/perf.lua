local function time_it_once(fn)
    local start = vim.loop.hrtime()
    fn()
    return vim.loop.hrtime() - start
end

local function time_it(fn)
    local res = {}
    local i = 0
    while i < 100 do
        table.insert(res, time_it_once(fn))
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

local function call_it(times, fn)
    local i = 0
    while i < times do
        fn()
        i = i + 1
    end
end

local builtin_args = { bufmodified = 1 }
local function builtin()
    return vim.fn.getbufinfo(builtin_args)
end

local function manual()
    local filtered = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].mod then table.insert(filtered, buf) end
    end

    return filtered
end

local function print_it(lbl, time)
    print(lbl .. " took " .. time .. "ns on avg")
end

call_it(1e3, builtin)
print_it("getbufinfo()", time_it(builtin))

call_it(1e3, manual)
print_it("manual()", time_it(builtin))
