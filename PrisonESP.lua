-- ============================================================
--  PRISON ESP + РАЗВЕДКА  v0.1
--  Тюремный RP (заключённые / охрана / преступники).
--  GUI на Rayfield. ESP игроков и оружия, дамп ТТХ пушек,
--  список ремоутов и зонд для проверки client-trust дыр
--  (InflictTarget / ChangeAmmoAndClip / ChooseTeamEvent).
--
--  Консоль:
--    getgenv().PE.Guns()     -- ТТХ всех пушек (Setting-модули)
--    getgenv().PE.Remotes()  -- все ремоуты с путями
--    getgenv().PE.Probe("InflictTarget", часть_врага)
--    getgenv().PE.Probe("ChangeAmmoAndClip", 30, 30)
--    getgenv().PE.Probe("ChooseTeamEvent", "Guard")
-- ============================================================

local G = getgenv()
if G.PE_LOADED_AT and (os.clock() - G.PE_LOADED_AT) < 5 then
    warn("[PE] только что запущен, подожди 5 сек")
    return
end
G.PE_LOADED_AT = os.clock()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

-- Конфиг (переживает перезапуск через getgenv).
G.PE = G.PE or {}
local CFG = G.PE
CFG.Players   = CFG.Players   ~= false   -- ESP игроков
CFG.Names     = CFG.Names     ~= false   -- имена
CFG.Dist      = CFG.Dist      == true    -- дистанция
CFG.Weapon    = CFG.Weapon    ~= false   -- оружие в руках
CFG.Items     = CFG.Items     ~= false   -- оружие/ключи на земле
CFG.MaxDist   = tonumber(CFG.MaxDist) or 900

local STOPPED = false
local UI_ERR = {}
local Rayfield
local conn
local byItems = {}   -- Highlight подсветки предметов на земле
local function safeColor(v, def)
    if typeof(v) == "Color3" then return v end
    return def
end
CFG.ColGuard = safeColor(CFG.ColGuard, Color3.fromRGB(70, 170, 255))
CFG.ColPris  = safeColor(CFG.ColPris,  Color3.fromRGB(255, 170, 60))
CFG.ColCrim  = safeColor(CFG.ColCrim,  Color3.fromRGB(255, 60, 60))

local VDRAW
do
    local ok, probe = pcall(function() return Drawing.new("Line") end)
    VDRAW = ok
    if ok and probe then
        pcall(function() probe.Visible = false end)
        pcall(function() probe:Remove() end)
    end
end

local function vLine()
    if not VDRAW then return nil end
    local ok, l = pcall(function() return Drawing.new("Line") end)
    if ok and l then l.Visible = false; return l end
    return nil
end
local function vText()
    if not VDRAW then return nil end
    local ok, t = pcall(function() return Drawing.new("Text") end)
    if ok and t then t.Visible = false; return t end
    return nil
end
local function vProj(cam, pos)
    local ok, sp = pcall(function() return cam:WorldToViewportPoint(pos) end)
    if ok and sp then return sp end
    return nil
end

-- ============================================================
--  ПУЛ ВИЗУАЛОВ НА ИГРОКА: коробка из 4 линий + подпись.
-- ============================================================
local VMAX = 16
local pool = {}
for i = 1, VMAX do
    pool[i] = { l1 = vLine(), l2 = vLine(), l3 = vLine(), l4 = vLine(),
        txt = vText(), plr = nil }
end

local function teamColor(plr)
    -- Преступник: атрибут/лидерстатс, иначе цвет команды.
    pcall(function()
        local c = plr:GetAttribute("Criminal")
        if c == true then error("crim") end
    end)
    local t = plr.Team
    local tn = t and string.lower(t.Name) or ""
    if string.find(tn, "guard", 1, true) or string.find(tn, "cop", 1, true)
       or string.find(tn, "police", 1, true) or string.find(tn, "охра", 1, true) then
        return CFG.ColGuard
    end
    if string.find(tn, "crim", 1, true) then return CFG.ColCrim end
    return CFG.ColPris
end

local function hideSlot(p)
    if not p then return end
    for _, k in ipairs({ "l1", "l2", "l3", "l4" }) do
        if p[k] then p[k].Visible = false end
    end
    if p.txt then p.txt.Visible = false end
end

-- ============================================================
--  ГЛАВНЫЙ ЦИКЛ ESP
-- ============================================================
conn = RunService.RenderStepped:Connect(function()
    if STOPPED then return end
    local ok, err = pcall(function()
        if not CFG.Players then
            for i = 1, VMAX do hideSlot(pool[i]) end
            return
        end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local myRoot = LP.Character
            and LP.Character:FindFirstChild("HumanoidRootPart")
        local used = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and used < VMAX then
                local ch = plr.Character
                local root = ch and ch:FindFirstChild("HumanoidRootPart")
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if ch and root and hum and hum.Health > 0 then
                    local d = myRoot
                        and (root.Position - myRoot.Position).Magnitude or 0
                    if CFG.MaxDist <= 0 or d <= CFG.MaxDist then
                        used = used + 1
                        local p = pool[used]
                        local head = ch:FindFirstChild("Head")
                        local top = head and head.Position
                            and head.Position + Vector3.new(0, 1.6, 0)
                            or root.Position + Vector3.new(0, 2.2, 0)
                        local bot = root.Position - Vector3.new(0, 2.9, 0)
                        local spT = vProj(cam, top)
                        local spB = vProj(cam, bot)
                        if spT and spB and spT.Z > 0 and spB.Z > 0 then
                            local h = math.abs(spB.Y - spT.Y)
                            if h > 8 then
                                local w = math.max(8, h * 0.55)
                                local x0 = spT.X - w * 0.5
                                local x1 = spT.X + w * 0.5
                                local y0 = math.min(spT.Y, spB.Y)
                                local y1 = math.max(spT.Y, spB.Y)
                                local col = teamColor(plr)
                                local th = 2
                                local L = { p.l1, p.l2, p.l3, p.l4 }
                                local pts = {
                                    { Vector2.new(x0, y0), Vector2.new(x1, y0) },
                                    { Vector2.new(x1, y0), Vector2.new(x1, y1) },
                                    { Vector2.new(x1, y1), Vector2.new(x0, y1) },
                                    { Vector2.new(x0, y1), Vector2.new(x0, y0) },
                                }
                                for i = 1, 4 do
                                    local l = L[i]
                                    if l then
                                        l.From = pts[i][1]
                                        l.To = pts[i][2]
                                        l.Color = col
                                        l.Thickness = th
                                        l.Transparency = 0.1
                                        l.Visible = true
                                    end
                                end
                                if p.txt then
                                    local parts = {}
                                    if CFG.Names then
                                        parts[#parts + 1] = plr.DisplayName
                                    end
                                    if CFG.Weapon then
                                        local tool = ch:FindFirstChildOfClass("Tool")
                                        if tool then
                                            parts[#parts + 1] = "[" .. tool.Name .. "]"
                                        end
                                    end
                                    if CFG.Dist then
                                        parts[#parts + 1] = math.floor(d + 0.5) .. " st"
                                    end
                                    p.txt.Text = table.concat(parts, "  ")
                                    p.txt.Size = 13
                                    p.txt.Color = col
                                    p.txt.Center = true
                                    p.txt.Outline = true
                                    p.txt.Position = Vector2.new(
                                        (x0 + x1) * 0.5, y0 - 18)
                                    p.txt.Visible = #parts > 0
                                end
                            else
                                hideSlot(p)
                            end
                        else
                            hideSlot(p)
                        end
                    end
                end
            end
        end
        for i = used + 1, VMAX do hideSlot(pool[i]) end
    end)
    if not ok then
        UI_ERR[#UI_ERR + 1] = tostring(err)
    end
end)

-- ============================================================
--  ПРЕДМЕТЫ НА ЗЕМЛЕ: пушки с "Item Give script", ключи, патроны.
-- ============================================================
local ITEM_NAMES = {
    "AK-74", "M16a4 MOD", "M9", "MP5 Short", "SVD", "Kord", "MG42",
    "PPSH-41", "Hammer", "KeyCard", "Ammo box", "Taser", "Handcuffs",
}
local itemScanAt = 0
local itemConn = RunService.Heartbeat:Connect(function()
    if STOPPED then return end
    if not CFG.Items then
        for k, h in pairs(byItems) do
            pcall(function() h:Destroy() end)
            byItems[k] = nil
        end
        return
    end
    local now = os.clock()
    if now - itemScanAt < 2 then return end
    itemScanAt = now
    pcall(function()
        local seen = {}
        for _, m in ipairs(workspace:GetChildren()) do
            if m:IsA("Model") then
                local hit
                for _, nm in ipairs(ITEM_NAMES) do
                    if m.Name == nm then hit = nm break end
                end
                if hit and m:FindFirstChild("Item Give script") or hit then
                    seen[m] = true
                    local h = byItems[m]
                    if not h or not h.Parent then
                        local ok, nh = pcall(function()
                            return Instance.new("Highlight") end)
                        if ok and nh then
                            nh.Adornee = m
                            nh.Parent = m
                            nh.FillTransparency = 0.4
                            byItems[m] = nh
                            h = nh
                        end
                    end
                    if h then
                        local col = Color3.fromRGB(255, 170, 0)
                        if m.Name == "KeyCard" then
                            col = Color3.fromRGB(255, 230, 60)
                        elseif m.Name == "Ammo box" then
                            col = Color3.fromRGB(90, 220, 110)
                        elseif m.Name == "Taser" or m.Name == "Handcuffs" then
                            col = Color3.fromRGB(120, 200, 255)
                        end
                        h.FillColor = col
                        h.OutlineColor = col
                        h.Enabled = true
                    end
                end
            end
        end
        for k, h in pairs(byItems) do
            if not seen[k] or not k.Parent then
                pcall(function() h:Destroy() end)
                byItems[k] = nil
            end
        end
    end)
end)

-- ============================================================
--  РАЗВЕДКА: ТТХ пушек, список ремоутов, зонд.
-- ============================================================
local function toolList()
    local out = {}
    local function grab(parent)
        if not parent then return end
        for _, t in ipairs(parent:GetChildren()) do
            if t:IsA("Tool") then out[#out + 1] = t end
        end
    end
    grab(LP:FindFirstChild("Backpack"))
    grab(LP.Character)
    return out
end

G.PE = G.PE or {}
G.PE.Guns = function()
    local n = 0
    for _, t in ipairs(toolList()) do
        local st = t:FindFirstChild("Setting")
        if st then
            local ok, m = pcall(function() return require(st) end)
            if ok and type(m) == "table" then
                n = n + 1
                print("[PE GUN] === " .. t.Name .. " ===")
                for k, v in pairs(m) do
                    if type(v) ~= "table" then
                        print("  " .. tostring(k) .. " = " .. tostring(v))
                    else
                        local parts = {}
                        for k2, v2 in pairs(v) do
                            if #parts < 8 then
                                parts[#parts + 1] = tostring(k2) .. "="
                                    .. tostring(v2)
                            end
                        end
                        print("  " .. tostring(k) .. " = {"
                            .. table.concat(parts, ", ") .. "}")
                    end
                end
            else
                print("[PE GUN] " .. t.Name .. ": Setting не читается")
            end
        end
    end
    if n == 0 then
        print("[PE GUN] пушек с Setting нет в руках/рюкзаке — возьми оружие")
    end
end

G.PE.Remotes = function()
    local n = 0
    local function scan(root, label)
        if not root then return end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                n = n + 1
                local path = tostring(d:GetFullName())
                print("[PE REMOTE] " .. d.ClassName .. "  " .. path)
            end
        end
    end
    scan(ReplicatedStorage, "RS")
    scan(LP:FindFirstChild("Backpack"), "backpack")
    scan(LP.Character, "character")
    print("[PE REMOTE] всего: " .. n)
end

G.PE.Probe = function(name, ...)
    local target = tostring(name or "")
    if target == "" then print("[PE PROBE] укажи имя ремоута") return end
    -- Ищем во всех местах: ремоуты пушек лежат внутри самих тулов.
    local found = {}
    local function scan(root)
        if not root then return end
        for _, d in ipairs(root:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction"))
               and d.Name == target then
                found[#found + 1] = d
                if #found >= 5 then return end
            end
        end
    end
    scan(ReplicatedStorage)
    scan(LP:FindFirstChild("Backpack"))
    scan(LP.Character)
    if #found == 0 then
        print("[PE PROBE] '" .. target .. "' не найден (см. PE.Remotes())")
        return
    end
    for i, r in ipairs(found) do
        print("[PE PROBE] найден: " .. tostring(r:GetFullName()))
    end
    local ev = found[1]
    local args = table.pack(...)
    local parts = {}
    for i = 1, math.min(args.n, 4) do
        local v = args[i]
        parts[#parts + 1] = typeof(v) == "Instance"
            and tostring(v:GetFullName()) or tostring(v)
    end
    print("[PE PROBE] -> " .. ev.Name .. "(" .. table.concat(parts, ", ") .. ")")
    local listener
    if ev:IsA("RemoteEvent") then
        listener = ev.OnClientEvent:Connect(function(...)
            local a = table.pack(...)
            local ps = {}
            for i = 1, math.min(a.n, 5) do
                local v = a[i]
                ps[#ps + 1] = type(v) == "table" and "{table}" or tostring(v)
            end
            print("[PE PROBE] <- ответ: " .. table.concat(ps, " | "))
        end)
    end
    if ev:IsA("RemoteEvent") then
        pcall(function() ev:FireServer(table.unpack(args, 1, args.n)) end)
    else
        pcall(function()
            local res = ev:InvokeServer(table.unpack(args, 1, args.n))
            print("[PE PROBE] <- InvokeServer: " .. tostring(res))
        end)
    end
    task.delay(5, function()
        if listener then pcall(function() listener:Disconnect() end) end
        print("[PE PROBE] окно '" .. target .. "' закрыто")
    end)
end

-- ============================================================
--  GUI (Rayfield)
-- ============================================================
pcall(function()
    Rayfield = loadstring(game:HttpGet(
        "https://sirius.menu/rayfield", true))()
    local W = Rayfield:CreateWindow({
        LoadingTitle = "PRISON ESP",
        LoadingSubtitle = "ESP + Разведка v0.1",
        ConfigurationSaving = { Enabled = true },
    })
    local T = W:CreateTab("ESP", "box")
    T:CreateSection("Игроки")
    T:CreateToggle({ Name = "ESP игроков", Flag = "PE_Players",
        CurrentValue = CFG.Players ~= false,
        Callback = function(v) CFG.Players = v end })
    T:CreateToggle({ Name = "Имена", Flag = "PE_Names",
        CurrentValue = CFG.Names ~= false,
        Callback = function(v) CFG.Names = v end })
    T:CreateToggle({ Name = "Оружие в руках", Flag = "PE_Weapon",
        CurrentValue = CFG.Weapon ~= false,
        Callback = function(v) CFG.Weapon = v end })
    T:CreateToggle({ Name = "Дистанция", Flag = "PE_Dist",
        CurrentValue = CFG.Dist == true,
        Callback = function(v) CFG.Dist = v end })
    T:CreateSection("Мир")
    T:CreateToggle({ Name = "Пушки/ключи на земле", Flag = "PE_Items",
        CurrentValue = CFG.Items ~= false,
        Callback = function(v) CFG.Items = v end })
    T:CreateSlider({ Name = "Дальность ESP", Flag = "PE_MaxDist",
        Range = {100, 2000}, Increment = 50, CurrentValue = CFG.MaxDist,
        Suffix = " st", Callback = function(v) CFG.MaxDist = v end })

    local R = W:CreateTab("Разведка", "search")
    R:CreateSection("Разведка")
    R:CreateParagraph({ Title = "Как проверять дыры",
        Content = "1) PE.Remotes() в консоль — все ремоуты. 2) PE.Guns() — ТТХ пушек. 3) PE.Probe(\"InflictTarget\", workspace[\"НИК\"].HumanoidRootPart) — проверка урона по чужой части. PE.Probe(\"ChangeAmmoAndClip\", 30, 30) — патроны. PE.Probe(\"ChooseTeamEvent\", \"Guard\") — смена команды." })
    R:CreateButton({ Name = "ТТХ пушек (в консоль)", Callback = function()
        G.PE.Guns()
    end })
    R:CreateButton({ Name = "Список ремоутов (в консоль)", Callback = function()
        G.PE.Remotes()
    end })
end)

-- ============================================================
--  СТОП
-- ============================================================
G.PE_Stop = function()
    STOPPED = true
    pcall(function() conn:Disconnect() end)
    pcall(function() itemConn:Disconnect() end)
    for i = 1, VMAX do
        local p = pool[i]
        if p then
            for _, k in ipairs({ "l1", "l2", "l3", "l4" }) do
                if p[k] then pcall(function() p[k]:Remove() end) end
            end
            if p.txt then pcall(function() p.txt:Remove() end) end
        end
    end
    for k, h in pairs(byItems) do pcall(function() h:Destroy() end) end
    byItems = {}
    G.PE.Guns, G.PE.Remotes, G.PE.Probe = nil, nil, nil
    local rfOld = Rayfield
    Rayfield = nil
    if rfOld then task.defer(function() pcall(function() rfOld:Destroy() end) end) end
    G.PE_Stop = nil
    G.PE_LOADED_AT = nil
    print("[PE] v0.1 остановлен")
end

print("[PE] v0.1 запущен | Drawing=" .. tostring(VDRAW)
    .. " | консоль: PE.Guns() / PE.Remotes() / PE.Probe(...)"
    .. (#UI_ERR > 0 and (" | ошибок GUI=" .. #UI_ERR) or ""))
