-- ============================================================
--  PRISON DUMP — STUDIO EDITION
--
--  КАК ЗАПУСТИТЬ:
--  1) Открой копию игры в Roblox Studio в режиме EDIT (не Play!).
--  2) View -> Command Bar (Alt+V).
--  3) Вставь ВЕСЬ этот текст в Command Bar и нажми Enter
--     (Studio умеет многострочную вставку).
--  4) Появится диалог сохранения — сохрани prison_dump_full.txt
--     и скинь этот файл в чат.
--
--  Только Edit mode даёт доступ к ServerScriptService /
--  ServerStorage и Source всех скриптов. Ничего не меняет,
--  только читает и сохраняет в один файл.
-- ============================================================

local StudioService = game:GetService("StudioService")

local L = {}
local function log(s) L[#L + 1] = tostring(s) end
local function sec(t)
    log("")
    log("########## " .. t .. " ##########")
end

-- Стандартные модули Roblox — пропускаем, чтобы не мусорить.
local function skipPath(path)
    return string.find(path, "PlayerModule", 1, true) ~= nil
        or string.find(path, "RbxCharacterSounds", 1, true) ~= nil
end

-- ---------- 1. Деревья сервисов ----------
local function dumpTree(root)
    local n = 0
    local function walk(inst, depth, path)
        n = n + 1
        if n > 25000 then return end
        if n <= 25000 then
            log(string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "]")
        end
        local ok, ch = pcall(function() return inst:GetChildren() end)
        if not ok or type(ch) ~= "table" then return end
        for _, c in ipairs(ch) do
            local cp = path .. "." .. c.Name
            if not skipPath(cp) then
                walk(c, depth + 1, cp)
            end
        end
    end
    walk(root, 0, root.Name)
    log("--- объектов: " .. n)
end

-- ---------- 2. Исходники всех скриптов ----------
local function dumpSources(root, label)
    sec("ИСХОДНИКИ: " .. label)
    local n = 0
    local okAll, list = pcall(function() return root:GetDescendants() end)
    if not okAll or type(list) ~= "table" then return end
    for _, d in ipairs(list) do
        local cn = d.ClassName
        if cn == "Script" or cn == "LocalScript" or cn == "ModuleScript" then
            local ok, path = pcall(function() return d:GetFullName() end)
            path = ok and path or d.Name
            if not skipPath(path) then
                local okS, src = pcall(function() return d.Source end)
                if okS and type(src) == "string" and #src > 0 then
                    n = n + 1
                    log("")
                    log("=== [" .. n .. "] " .. path .. " (" .. #src .. " байт) ===")
                    if #src > 400000 then
                        log("--ОБРЕЗАНО до 400000 байт--")
                        src = string.sub(src, 1, 400000)
                    end
                    log(src)
                elseif not okS then
                    log("-- " .. path .. ": Source недоступен (" .. tostring(src) .. ")")
                end
            end
        end
    end
    log("")
    log("--- скриптов с исходниками: " .. n)
end

-- ---------- запуск ----------
log("PRISON STUDIO DUMP | " .. game.Name .. " | PlaceId=" .. tostring(game.PlaceId))

for _, svcName in ipairs({
    "Workspace", "ReplicatedStorage", "ServerScriptService",
    "ServerStorage", "StarterGui", "StarterPack", "Teams",
}) do
    local svc = game:FindService(svcName)
    if svc then
        sec("ДЕРЕВО: " .. svcName)
        dumpTree(svc)
    else
        sec("ДЕРЕВО: " .. svcName .. " (сервиса нет)")
    end
end

do
    local sp = game:FindService("StarterPlayer")
    local sps = sp and sp:FindFirstChild("StarterPlayerScripts")
    sec("ДЕРЕВО: StarterPlayerScripts")
    if sps then
        dumpTree(sps)
    else
        log("(пусто)")
    end
end

for _, svcName in ipairs({
    "Workspace", "ReplicatedStorage", "ServerScriptService",
    "ServerStorage", "StarterPack",
}) do
    local svc = game:FindService(svcName)
    if svc then dumpSources(svc, svcName) end
end

do
    local sp = game:FindService("StarterPlayer")
    local sps = sp and sp:FindFirstChild("StarterPlayerScripts")
    if sps then dumpSources(sps, "StarterPlayerScripts") end
end

-- ---------- сохранение ----------
sec("КОНЕЦ")
local text = table.concat(L, "\n")
print("[DUMP] строк=" .. #L .. " байт=" .. #text)

local saved = false
local okExport = pcall(function()
    local chunks = {}
    local i = 1
    while i <= #text do
        chunks[#chunks + 1] = string.sub(text, i, i + 60000)
        i = i + 60000
    end
    saved = StudioService:PromptExportFile(chunks, "prison_dump_full.txt")
end)
if okExport and saved then
    print("[DUMP] Готово: prison_dump_full.txt сохранён.")
else
    print("[DUMP] Диалог не сработал (" .. tostring(saved) .. ") — печатаю в Output, скопируй всё:")
    for i = 1, #L do print(L[i]) end
end
