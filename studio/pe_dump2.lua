-- Runs inside Studio Command Bar (Current: Server or Current: Client).
-- Serves back: full dump of remotes / click detectors / tools / script sources.
local hs = game:GetService("HttpService")
local RS = game:GetService("RunService")
pcall(function() hs.HttpEnabled = true end)
local URL = "http://127.0.0.1:8777/"
local DM = RS:IsServer() and "SERVER" or "CLIENT"

local function post(t)
    pcall(function()
        hs:PostAsync(URL, t, Enum.HttpContentType.TextPlain, false, 10)
    end)
end

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

w("=== DM: " .. DM .. " ===")
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
w("")
w("=== END OF DUMP (" .. DM .. ") scripts=" .. n .. " ===")

local report = table.concat(lines, "\n")
print("[PE] dump built: " .. #report .. " bytes, " .. n .. " scripts, " .. DM)
post("PE_BEGIN:" .. DM)
local CH = 200000
for i = 1, #report, CH do
    post(report:sub(i, i + CH - 1))
end
post("PE_DONE:" .. DM)
print("[PE] dump sent (" .. DM .. ")")
