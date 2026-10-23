-- ============================================================
--  PRISON ESP — LOADER
--
--  ОДНА СТРОКА ДЛЯ ЗАПУСКА:
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/PrisonESP/main/PrisonESP.lua",true))()
-- ============================================================

local URL = "https://raw.githubusercontent.com/blegbot1/PrisonESP/main/PrisonESP.lua"

local g = getgenv()
local now = os.clock()
if g.PE_LOADED_AT and (now - g.PE_LOADED_AT) < 5 then
    warn("[PE] только что запущен, подожди 5 сек")
    return
end
g.PE_LOADED_AT = now

print("[PE] загрузка:", URL)

local ok, err = pcall(function()
    local src = game:HttpGet(URL, true)
    if type(src) ~= "string" or #src < 100 then
        error("пустой или битый ответ")
    end
    local chunk = loadstring(src, "PrisonESP")
    if not chunk then error("loadstring вернул nil — синтаксис сломан") end
    chunk()
end)

if not ok then
    g.PE_LOADED_AT = nil
    warn("[PE] ошибка загрузки:", err)
    error("[PE] не удалось загрузить скрипт: " .. tostring(err))
end

print("[PE] готово")
