local loop = vim.loop
local tmpdir = assert(loop.fs_mkdtemp(loop.os_tmpdir() .. "/XXXXXX"))
local nfiles = 1e3

-- Create files
for i = 1, nfiles, 1 do
    local fd = assert(
        loop.fs_open(
            tmpdir .. "/" .. tostring(i),
            loop.constants.O_CREAT + loop.constants.O_EXCL,
            511
        )
    )

    assert(loop.fs_close(fd))
end

local t = loop.hrtime()

for i = 1, nfiles, 1 do
    local _stat = assert(loop.fs_stat(tmpdir .. "/" .. tostring(i)))
end

print(
    "time to stat " .. tostring(nfiles) .. " files (sync):",
    (loop.hrtime() - t) / 1e6,
    "ms"
)

local cnt = 0

local function proc_stat(err, stat)
    cnt = cnt + 1
    if cnt == nfiles then
        print(
            "time to stat " .. tostring(nfiles) .. " files (async):",
            (loop.hrtime() - t) / 1e6,
            "ms"
        )
        vim.schedule(function()
            vim.fn.delete(tmpdir, "rf")
        end)
    end
    assert(stat, err)
end

t = loop.hrtime()

for i = 1, nfiles, 1 do
    loop.fs_stat(tmpdir .. "/" .. tostring(i), proc_stat)
end
