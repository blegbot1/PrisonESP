-- PrisonESP Studio dump task: runs inside Studio after the place loads.
-- Builds a full report (remotes, click detectors, tools, ALL script sources)
-- and delivers it: direct io write, else chunked HTTP POST to 127.0.0.1:8777.

local OUTDIR = "C:/Users/citha/Documents/PrisonESP/studio"
local lines = {}
local function w(s) lines[#lines + 1] = tostring(s) end

local function pathOf(inst)
    local parts = {}
    local cur = inst
    while cur and cur ~= game do
        parts[#parts + 1] = cur.Name
        cur = cur.Parent
    end
    local out = {}
    for i = #parts, 1, -1 do out[#out + 1] = parts[i] end
    return table.concat(out, ".")
end

w("=== SERVICES ===")
for _, s in ipairs(game:GetChildren()) do w(s.ClassName) end

w("")
w("=== REMOTES ===")
for _, d in ipairs(game:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction")
        or d:IsA("UnreliableRemoteEvent") then
        w(d.ClassName .. " | " .. pathOf(d))
    end
end

w("")
w("=== CLICK / PROXIMITY ===")
for _, d in ipairs(game:GetDescendants()) do
    if d:IsA("ClickDetector") or d:IsA("ProximityPrompt") then
        w(d.ClassName .. " | " .. pathOf(d))
    end
end

w("")
w("=== TOOLS ===")
for _, d in ipairs(game:GetDescendants()) do
    if d:IsA("Tool") then w(pathOf(d)) end
end

w("")
w("=== SCRIPTS (full source) ===")
local n = 0
for _, d in ipairs(game:GetDescendants()) do
    if d:IsA("BaseScript") or d:IsA("ModuleScript") then
        n = n + 1
        local ok, src = pcall(function() return d.Source end)
        if not ok then src = "-- SOURCE READ FAILED: " .. tostring(src) end
        w("")
        w("===== SCRIPT #" .. n .. " | " .. d.ClassName .. " | "
            .. pathOf(d) .. " =====")
        w(src)
    end
end

local report = table.concat(lines, "\n")

local okFile = false
pcall(function()
    local f = io.open(OUTDIR .. "/pe_studio_report.txt", "w")
    if not f then error("io.open nil") end
    f:write(report)
    f:close()
    okFile = true
end)
pcall(function()
    local f = io.open(OUTDIR .. "/probe_result.txt", "w")
    if f then
        f:write("io=" .. tostring(type(io)) .. " fileWrite="
            .. tostring(okFile))
        f:close()
    end
end)

if okFile then
    pcall(function()
        local f = io.open(OUTDIR .. "/pe_done.txt", "w")
        if f then f:write("ok-io") f:close() end
    end)
else
    local hs = game:GetService("HttpService")
    pcall(function() hs.HttpEnabled = true end)
    local CH = 200000
    for i = 1, #report, CH do
        pcall(function()
            hs:PostAsync("http://127.0.0.1:8777/", report:sub(i, i + CH - 1),
                Enum.HttpContentType.TextPlain, false, 10)
        end)
    end
    pcall(function()
        hs:PostAsync("http://127.0.0.1:8777/", "PE_DONE",
            Enum.HttpContentType.TextPlain, false, 10)
    end)
end
