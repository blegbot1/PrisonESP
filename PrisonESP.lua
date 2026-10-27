-- ============================================================
--  PRISON ESP  v3.05  (Combat-only: PeUI + фиксированный фон, без перча)
--  Тюремный RP (заключённые / охрана / преступники).
--
--  Боевка и движение: килл-аура (InflictTarget), прокачка пушки,
--  APOCALYPSE, гильотина/воронка/троны/пепел/призрак, телепорты,
--  полёт/ноклип/спидхак, анти-стан/анти-АФК, детектор админов.
--
--  Консоль:
--    getgenv().PE.Guns()     -- ТТХ всех пушек (Setting-модули)
--    getgenv().PE.Remotes()  -- все ремоуты с путями
--    getgenv().PE.Probe("InflictTarget", часть_врага)
-- ============================================================

local G = getgenv()
if G.PE_LOADED_AT and (os.clock() - G.PE_LOADED_AT) < 5 then
    warn("[PE] just started, wait 5 sec")
    return
end
-- Повторный запуск: глушим прошлый экземпляр, иначе двойные ауры/плашки.
if G.PE_Stop then
    pcall(function() G.PE_Stop() end)
end
G.PE_LOADED_AT = os.clock()

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui          = game:GetService("CoreGui")
local LP               = Players.LocalPlayer

-- ============================================================
--  КОНФИГ (переживает перезапуск через getgenv)
-- ============================================================
G.PE = G.PE or {}
local CFG = G.PE
CFG._ensureBusy = nil

local function pickOpt(v, list, def)
    if type(v) == "string" then
        for _, o in ipairs(list) do
            if o == v then return v end
        end
    end
    return def
end

-- ---------- БОЕВЫЕ ----------
CFG.KillAura       = CFG.KillAura == true
CFG.KillAuraRadius = math.max(0, tonumber(CFG.KillAuraRadius) or 40)
CFG.KillAuraDelay  = tonumber(CFG.KillAuraDelay) or 0.15
-- Цель ауры: «Everyone» или НИК игрока (переживает рестарт скрипта).
-- Whitelist здесь только для «Everyone» — ники принимаем как есть,
-- иначе pickOpt молча сбрасывал сохранённую цель во «Everyone» и
-- после перезагрузки аура внезапно била всех вместо одного.
CFG.KillAuraTeam   = (type(CFG.KillAuraTeam) == "string"
    and CFG.KillAuraTeam ~= "")
    and CFG.KillAuraTeam or "Everyone"
-- АНТИ-СТАН: тазер/наручники/регдолл не должны останавливать.
CFG.AntiStun = CFG.AntiStun ~= false
-- Урон килл-ауры и бесконечные патроны. Подписура InflictTarget взята
-- из декомпиляции GunScript_Local: (Humanoid, RootPart, урон,
-- направление, отдача, вампиризм, поджог).
CFG.KillAuraDamage = math.clamp(tonumber(CFG.KillAuraDamage) or 50, 1, 200)
CFG.ModGunDamage = tonumber(CFG.ModGunDamage) or 250
-- ВАМПИРИЗМ АУРЫ: 6-й аргумент InflictTarget лечит стрелка на эту
-- величину за каждый удар — псевдо-бессмертие, пока аура бьёт.
-- Подброс жертв — 5-й аргумент (отдача вверх).
CFG.AuraLifesteal = CFG.AuraLifesteal ~= false
CFG.AuraFling = CFG.AuraFling == true
CFG.FlingDir = pickOpt(CFG.FlingDir, {
    "Up", "Away from me", "Random" }, "Up")
-- ПОДЖОГ: 7-й аргумент InflictTarget (FlamingBullet) — серверный
-- IgniteScript вешает на цель горение (урон по времени). Аура бьёт
-- в голову (как настоящий хедшот).
CFG.AuraBurn = CFG.AuraBurn ~= false
CFG.GunFire = CFG.GunFire == true
CFG.GunKnockback = tonumber(CFG.GunKnockback) or 0
CFG.GunPiercing = tonumber(CFG.GunPiercing) or 5
-- ПРОКАЧКА v2: полный список полей Setting-модуля (из Studio-копии
-- игры): хедшот-множитель, дробовик, очередь, взрывные пули.
CFG.GunHeadshot = tonumber(CFG.GunHeadshot) or 200
CFG.GunShotgun = CFG.GunShotgun ~= false
CFG.GunPellets = tonumber(CFG.GunPellets) or 8
CFG.GunBurst = tonumber(CFG.GunBurst) or 10
CFG.GunExplosive = CFG.GunExplosive ~= false
CFG.GunBoomRadius = tonumber(CFG.GunBoomRadius) or 25
CFG.GunLifesteal = CFG.GunLifesteal ~= false
-- ХАК ПАТРОНОВ: перезарядка читает Setting.AmmoPerClip в момент
-- отправки пакета (после wait(ReloadTime)) — подсунутый 1e9 уходит
-- серверу ВНУТРИ честной перезарядки. Если сервер сверяет со своей
-- копией Setting — пушка зависнет пустой (переложи её в руки).
CFG.GunAmmoHack = CFG.GunAmmoHack == true
-- АВТО-ПРОКАЧКА: новая пушка в руках (респавн/смена) — апгрейд
-- применяется сам, кнопку жать не надо.
CFG.ModGunAuto = CFG.ModGunAuto ~= false
-- БЕССМЕРТИЕ: сервер самохил ОТВЕРГАЕТ (свой тим-чек, подтверждено
-- вживую), поэтому хил двухтактный: self-пакет (0 урона + 1e6
-- вампиризма — вдруг чек только на урон>0) + РЕАКТИВНЫЙ тап по
-- ближайшему живому врагу при получении урона (1 урона + 1e6
-- вампиризма): вампиризм лечит только по реальной жертве-врагу.
CFG.Immortal = CFG.Immortal == true
-- C00LKIDD MODE (2014): медленное сожжение ВСЕХ — крошечный урон
-- + серверный огонь => все горят и «по тихоньку» умирают.
CFG.C00lMode = CFG.C00lMode == true
CFG.C00lDamage = tonumber(CFG.C00lDamage) or 3
CFG.C00lFling = CFG.C00lFling == true
CFG.C00lTeam = (type(CFG.C00lTeam) == "string"
    and CFG.C00lTeam ~= "") and CFG.C00lTeam or "Everyone"
-- FIRE AURA: театральная аура огня — все в радиусе 15 стадов горят
-- (1 урона + серверный огонь). Карту сервер не поджигает — только
-- игроки (проверка принадлежности, доказано вживую).
CFG.FireAura = CFG.FireAura == true
-- АПОКАЛИПСИС = УБИВАЛКА: один тумблер делает всё сам —
-- 1) команда СБЕЖАВШИЙ, 2) сам берёт M9, 3) телепорт высоко в небо
-- (не достанут; дистанции урона нет — доказано), 4) все игроки
-- получают 100 урона + огонь за тик. Выкл — возврат на землю.
-- Горение частей карты сервер отвергает (проверка принадлежности) —
-- жжём только игроков.
CFG.Apocalypse = CFG.Apocalypse == true
CFG.ApocDamage = tonumber(CFG.ApocDamage) or 100
local apocAt = 0
-- АВТО-ГИВЕР: после смерти сам выдаёт выбранное оружие (если сервер
-- ничего не выдал сам).
CFG.AutoGive = CFG.AutoGive == true
CFG.AutoGiveName = pickOpt(CFG.AutoGiveName, {
    "M9", "AK-74", "M16a4 MOD", "MP5 Short", "SVD", "PPSH-41",
    "MG42", "Kord", "Hammer", "KeyCard", "GIVE ALL" }, "M9")
-- РЕТРИБУЦИЯ: получили урон — мгновенно находим атакующего
-- (вооружённые в приоритете) и сжигаем его.
-- РЕТРИБУЦИЯ с ПЕРЕКЛЮЧАЕМЫМ УРОНОМ: сколько отдавать тому, кто бьёт
-- тебя. nil = «как у ауры» (следует слайдеру Damage per shot).
CFG.Retr = CFG.Retr ~= false
CFG.RetrDamage = tonumber(CFG.RetrDamage) or nil
-- MIRROR: ретрибуция отражает ровно тот урон, которым ударили НАС
-- (бьёт на 80 — получает 80), вместо фиксированного слайдера.
CFG.RetrMirror = CFG.RetrMirror == true
-- АНТИ-АФК: VirtualUser отвечает за нас на idle-проверку Roblox —
-- долгие сессии без кика.
CFG.AntiAFK = CFG.AntiAFK ~= false
-- АВТО-КОМАНДА ПОСЛЕ СМЕРТИ: «Off» или команда, в которую скрипт
-- постоянно возвращает нас (проверка каждую секунду, не один раз).
CFG.AutoTeam = pickOpt(CFG.AutoTeam,
    { "Off", "Guard", "Prisoner", "Escaped" }, "Off")
-- ОБХОД ТИМ-ЧЕКА ДЛЯ АУРЫ: сервер отвергает урон по тиммейтам.
-- Тумблер крутит нас между Prisoner и Escaped каждые 1.5с (каждый
-- респавн возвращает в команду) — тогда аура достаёт и зеков, и
-- охрану. Вызывает респавны — это цена обхода.
CFG.AuraTeamBypass = CFG.AuraTeamBypass == true
-- АУРА: максимум целей за тик (6 = дефолт, 20 = мясорубка).
CFG.AuraMaxHits = tonumber(CFG.AuraMaxHits) or 6

local STOPPED = false
-- Боевые циклы не работают, пока меню не собрано: сохранённый конфиг
-- восстанавливает тогглы колбэками, и без этого гейта аура/полёт/
-- апокалипсис взводились бы до появления окна.
local PE_GUI_READY = false
local PeUI
local auraConn
local UIS = game:GetService("UserInputService")


-- Троттлы на игрока (поджог/подброс). Слабые ключи: ушедшие игроки
-- не копятся, при выходе чистим руками для мгновенности.
local PE_BURN_AT = setmetatable({}, { __mode = "k" })
local PE_FLING_AT = setmetatable({}, { __mode = "k" })

-- UserId админов, вшитые в LocalScript админ-панели игры (u45) +
-- создатель игры (CreatorId). v2.72-2.78: блок случайно выпал при
-- вырезке ESP — детектор админов молчал, вернуть на место.
local PE_ADMINS = {
    [86513279] = true, [4008579942] = true,
    [4865533262] = true, [66120198] = true,
}
local PE_CREATOR_ID = 0
pcall(function() PE_CREATOR_ID = tonumber(game.CreatorId) or 0 end)
local PE_IS_GROUP = false
pcall(function()
    PE_IS_GROUP = game.CreatorType == Enum.CreatorType.Group
end)
local function isAdminP(p)
    if PE_ADMINS[p.UserId] then return true end
    -- Если игру паблишила группа, CreatorId — id ГРУППЫ: совпадение
    -- с UserId игрока = ложный флаг.
    if PE_CREATOR_ID == 0 or PE_IS_GROUP then return false end
    return p.UserId == PE_CREATOR_ID
end

-- ДЕТЕКТОР АДМИНОВ: вход известного админа/создателя — warn + алерт.
local paConn = Players.PlayerAdded:Connect(function(plr)
    if STOPPED then return end
    if isAdminP(plr) then
        warn("[PE] ADMIN ON SERVER: " .. plr.Name
            .. " (userId " .. plr.UserId .. ") - be careful!")
        pcall(function()
            PeUI:Notify({ Title = "ADMIN ON SERVER",
                Content = plr.Name .. " (userId " .. plr.UserId .. ")",
                Duration = 10 })
        end)
    end
end)
-- Вышедшие игроки чистятся из боевых троттлов (поджог/подброс).
local prConn = Players.PlayerRemoving:Connect(function(plr)
    PE_BURN_AT[plr] = nil
    PE_FLING_AT[plr] = nil
end)

-- АВТО-КОМАНДА: ПОСТОЯННАЯ проверка каждую секунду. Выбрал «Escaped» —
-- скрипт возвращает тебя туда и после смерти, и после кика из команды.
-- Пауза, пока работает APOCALYPSE (он сам крутит команды).
task.spawn(function()
    while not STOPPED do
        task.wait(1)
        if not STOPPED and CFG.AutoTeam and CFG.AutoTeam ~= "Off"
           and not CFG.Apocalypse and not CFG.AuraTeamBypass
           and LP.Parent then
            local t = LP.Team
            if t and t.Name ~= CFG.AutoTeam then
                local r = ReplicatedStorage
                    :FindFirstChild("ChooseTeamEvent")
                if r then
                    pcall(function() r:FireServer(CFG.AutoTeam) end)
                    print("[PE TEAM] auto -> " .. CFG.AutoTeam)
                end
            end
        end
    end
end)

-- АВТО-ГИВЕР: после респавна сам выдаём выбранное оружие (если сервер
-- не выдал ничего сам).
local giveConn = LP.CharacterAdded:Connect(function()
    task.spawn(function()
        task.wait(1.5)
        if STOPPED or not CFG.AutoGive then return end
        if type(G.PE.EnsureWeapon) == "function" then
            G.PE.EnsureWeapon("after respawn")
        end
    end)
end)

-- АНТИ-АФК: VirtualUser дёргает контроллер при idle-событии —
-- Roblox не кикает за бездействие.
local afkConn = LP.Idled:Connect(function()
    if STOPPED or not CFG.AntiAFK then return end
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
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
    -- Сначала ЭКИПИРОВАННАЯ пушка (сервер проверяет руки), потом рюкзак.
    grab(LP.Character)
    grab(LP:FindFirstChild("Backpack"))
    return out
end

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
                print("[PE GUN] " .. t.Name .. ": Setting unreadable")
            end
        end
    end
    if n == 0 then
        print("[PE GUN] no guns with Setting in hands/backpack - take a weapon")
    end
end

G.PE.Remotes = function()
    local n = 0
    local function scan(root)
        if not root then return end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                n = n + 1
                print("[PE REMOTE] " .. d.ClassName .. "  " .. tostring(d:GetFullName()))
            end
        end
    end
    scan(ReplicatedStorage)
    scan(LP:FindFirstChild("Backpack"))
    scan(LP.Character)
    print("[PE REMOTE] total: " .. n)
end

G.PE.Probe = function(name, ...)
    local target = tostring(name or "")
    if target == "" then print("[PE PROBE] specify a remote name") return end
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
        print("[PE PROBE] '" .. target .. "' not found (see PE.Remotes())")
        return
    end
    for i, r in ipairs(found) do
        print("[PE PROBE] found: " .. tostring(r:GetFullName()))
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
            print("[PE PROBE] <- response: " .. table.concat(ps, " | "))
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
        print("[PE PROBE] window '" .. target .. "' closed")
    end)
end

-- ============================================================
--  ПРОБЫ В ОДИН КЛИК: урон / патроны / команда. Достаточно ЧАСТИ
--  ника — точное имя игрока вводить не нужно.
-- ============================================================
function findPlayer(namePart)
    local part = string.lower(tostring(namePart or ""))
    if part == "" then return nil end
    local best, bestD
    local myRoot = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local nm = string.lower(p.Name)
            local dn = string.lower(p.DisplayName)
            if string.find(nm, part, 1, true) or string.find(dn, part, 1, true) then
                local root = p.Character
                    and p.Character:FindFirstChild("HumanoidRootPart")
                local d = (myRoot and root)
                    and (root.Position - myRoot.Position).Magnitude or 0
                if not best or d < bestD then best, bestD = p, d end
            end
        end
    end
    return best
end

function myGunRemote(remoteName)
    -- v2.53: кэш на 0.15 с. Раньше функция звалась до троттла в Retr и
    -- Immortal (по 60 раз/с каждая) и внутри ауры — 4-6 полных обходов
    -- toolList за тик (таблица + замыкание + 2 GetChildren на вызов).
    local nowG = os.clock()
    local c = CFG._gunCache
    if c and c.n == remoteName and nowG - c.t < 0.15 then
        return c.r, c.tl
    end
    local res, resTool = nil, nil
    for _, t in ipairs(toolList()) do
        local gs = t:FindFirstChild("GunScript_Server")
        if gs then
            local r = gs:FindFirstChild(remoteName)
            if r and r:IsA("RemoteEvent") then
                res, resTool = r, t
                break
            end
        end
    end
    -- v2.56: СВОЕЙ ПУШКИ НЕТ — берём ЧУЖУЮ. Ремоут InflictTarget лежит в
    -- Workspace/<ник>/<оружие>/GunScript_Server. Логи показали, что
    -- fireclickdetector "true" не кладёт M9 в инвентарь (сервер гивера
    -- требует команду Guard), поэтому весь бой молчал. Пробуем стрелять
    -- через ремоут пушки другого игрока.
    if not res then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local ch = p.Character
                if ch then
                    for _, t in ipairs(ch:GetChildren()) do
                        if t:IsA("Tool") then
                            local gs2 = t:FindFirstChild("GunScript_Server")
                            local r2 = gs2 and gs2:FindFirstChild(remoteName)
                            if r2 and r2:IsA("RemoteEvent") then
                                res, resTool = r2, t
                                if CFG._borrowLogged ~= p.Name .. t.Name then
                                    CFG._borrowLogged = p.Name .. t.Name
                                    print("[PE GUN] no own gun - borrowing "
                                        .. p.Name .. "/" .. t.Name
                                        .. " remote")
                                end
                                break
                            end
                        end
                    end
                end
            end
            if res then break end
        end
    end
    CFG._gunCache = { n = remoteName, t = nowG, r = res, tl = resTool }
    return res, resTool
end

-- PE.Hit("часть ника") — выстрел урона по игроку через пушку в руках.
-- Второй аргумент (необяз.): имя части, по умолчанию Humanoid.
G.PE.Hit = function(namePart, partName)
    if not namePart or namePart == "" then
        print("[PE HIT] pick a player from the list first")
        return
    end
    local plr = findPlayer(namePart)
    if not plr then
        print("[PE HIT] player by '" .. tostring(namePart)
            .. "' not found (partial names work)")
        return
    end
    local ch = plr.Character
    if not ch then
        print("[PE HIT] target " .. plr.Name .. " has no character")
        return
    end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local root = ch:FindFirstChild("HumanoidRootPart")
    if not hum or not root then
        print("[PE HIT] target has no Humanoid/RootPart")
        return
    end
    local remote, tool = myGunRemote("InflictTarget")
    if not remote then
        print("[PE HIT] no gun with InflictTarget in hands/backpack - take a weapon")
        return
    end
    print("[PE HIT] " .. tool.Name .. ".InflictTarget -> " .. plr.Name
        .. " (exact signature, damage " .. (tonumber(CFG.KillAuraDamage) or 50)
        .. "). WATCH TARGET HP!")
    pcall(function()
        remote:FireServer(hum, root,
            math.clamp(tonumber(CFG.KillAuraDamage) or 50, 1, 200),
            Vector3.new(0, 0, 1), 0, false, false)
    end)
end

-- PE.Team("Guard") — проба смены команды.
G.PE.Team = function(teamName)
    local r = ReplicatedStorage:FindFirstChild("ChooseTeamEvent")
    if not r or not r:IsA("RemoteEvent") then
        print("[PE TEAM] ChooseTeamEvent not found")
        return
    end
    print("[PE TEAM] ChooseTeamEvent('" .. tostring(teamName) .. "'). WATCH YOUR TEAM!")
    pcall(function() r:FireServer(teamName) end)
end

-- ============================================================
--  БОЕВЫЕ ФУНКЦИИ: гивер оружия, двери, спринт, килл-аура.
-- ============================================================
local GIVE_ITEMS = {
    "M9", "AK-74", "M16a4 MOD", "MP5 Short", "SVD", "PPSH-41",
    "MG42", "Kord", "Hammer", "KeyCard",
}

-- Гивер: модели оружия на земле с "Item Give script" почти наверняка
-- работают через ClickDetector, а fireclickdetector игнорирует
-- дистанцию и проверки.
G.PE.Give = function(itemName)
    if type(fireclickdetector) ~= "function" then
        warn("[PE GIVE] no fireclickdetector in this executor")
        return false
    end
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m.Name == itemName then
            local cd = m:FindFirstChildWhichIsA("ClickDetector", true)
            if cd then
                -- Серверный "Item Give script" проверяет дистанцию до
                -- модели (~200 st): подлетаем, кликаем и мгновенно
                -- возвращаемся на место.
                local chr = LP.Character
                local root = chr and chr:FindFirstChild("HumanoidRootPart")
                local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
                local origCF = root and root.CFrame
                local teleported = false
                if root and part and origCF and not CFG._giveNoFly
                   and not CFG.Apocalypse and not root.Anchored
                   and (part.Position - root.Position).Magnitude > 60 then
                    root.CFrame = part.CFrame + Vector3.new(0, 4, 0)
                    teleported = true
                    -- v2.57: метка для апокалипсиса — иначе Heartbeat вернёт
                    -- нас на вышку через 16 мс, и клик уйдёт с 400 стадов.
                    CFG._giveFlyAt = os.clock()
                    task.wait(0.12)
                end
                local ok = pcall(fireclickdetector, cd)
                if teleported then
                    task.wait(0.12)
                    local root2 = LP.Character
                        and LP.Character:FindFirstChild("HumanoidRootPart")
                    if root2 then
                        pcall(function() root2.CFrame = origCF end)
                    end
                end
                print("[PE GIVE] " .. itemName .. ": fireclickdetector -> "
                    .. tostring(ok) .. (teleported and " (with fly-in)" or ""))
                return ok
            end
            warn("[PE GIVE] '" .. itemName .. "' has no ClickDetector")
            -- v2.56: НЕ выходим: моделей с одним именем на карте несколько,
            -- и кликабельная может оказаться следующей.
            m = nil
        end
    end
    print("[PE GIVE] model '" .. tostring(itemName) .. "' not found on the ground")
    return false
end

G.PE.GiveAll = function()
    local n = 0
    -- v2.69: без флай-ина. Раньше GIVE ALL телепортировал к каждой модели
    -- и обратно 10 раз подряд внутри колбэка Rayfield — после этого меню
    -- переставало принимать клики (камера/фокус оставались в стене).
    CFG._giveNoFly = true
    for _, nm in ipairs(GIVE_ITEMS) do
        -- pcall на каждый итем: UNLOAD посреди цикла зануляет G.PE.Give —
        -- иначе throw рвал цикл ДО сброса _giveNoFly, и флай-ин гивера
        -- молча отключался навсегда (флаг жил в getgenv).
        pcall(function()
            if G.PE.Give(nm) then n = n + 1 end
        end)
        task.wait(0.25)
        if STOPPED then break end
    end
    CFG._giveNoFly = nil
    print("[PE GIVE] items given: " .. n)
end

-- v2.54: ПОСТОЯННАЯ ПРОВЕРКА ОРУЖИЯ. Раньше авто-гивер срабатывал
-- только на CharacterAdded: выбили пушку наручниками/смертью/сменой
-- команды — скрипт этого не видел и молчал.
G.PE.HasWeapon = function(name)
    name = tostring(name or "")
    if name == "" then return false end
    local chr = LP.Character
    local bp = LP:FindFirstChild("Backpack")
    local function scan(root)
        if not root then return false end
        for _, o in ipairs(root:GetChildren()) do
            if o:IsA("Tool") and o.Name == name then return true end
        end
        return false
    end
    return scan(chr) or scan(bp)
end

-- Какое оружие нужно апокалипсису: "GIVE ALL" — не пушка, берём M9.
G.PE.ApocGunName = function()
    local n = tostring(CFG.AutoGiveName or "M9")
    if n == "" or n == "GIVE ALL" then return "M9" end
    return n
end

G.PE.EnsureWeapon = function(tag)
    if STOPPED or not CFG.AutoGive then return false end
    local want = tostring(CFG.AutoGiveName or "M9")
    if want == "" then return false end
    if want ~= "GIVE ALL" and G.PE.HasWeapon(want) then
        CFG._ensureOk = true
        return true
    end
    -- v2.57: для "GIVE ALL" быстрый выход по HasWeapon не работал → выдавали
    -- 10 итемов каждые 4 с бесконечно (GiveAll сам длится 2.5-5 с).
    if want == "GIVE ALL" then
        local haveAll = true
        for _, nm in ipairs(GIVE_ITEMS) do
            if not G.PE.HasWeapon(nm) then haveAll = false break end
        end
        if haveAll then CFG._ensureOk = true return true end
    end
    local nowE = os.clock()
    -- v2.70: под апокалипсисом гивер не может выдать пушку (тим-чек), а
    -- ретрай каждые 4 с телепортировал игрока к модели и обратно — играть
    -- было невозможно. Теперь редкий ретрай и без телепорта.
    local gap = CFG.Apocalypse and 15 or 4
    if CFG._ensureBusy or nowE - (CFG._ensureGiveAt or 0) < gap then
        return false
    end
    CFG._ensureGiveAt = nowE
    CFG._ensureBusy = true
    print("[PE GIVE] '" .. want .. "' NOT in inventory ("
        .. tostring(tag or "") .. ") - giving")
    -- v2.57: тело в pcall — иначе ошибка (например UNLOAD во время GiveAll,
    -- когда G.PE.Give уже nil) оставляла _ensureBusy=true НАВСЕГДА и глушила
    -- авто-гивер до перезапуска игры.
    task.spawn(function()
        local okE, errE = pcall(function()
            if want == "GIVE ALL" then G.PE.GiveAll() else G.PE.Give(want) end
        end)
        CFG._ensureBusy = nil
        -- Неудача выдачи (модель забрали с земли / нет ClickDetector):
        -- откладываем следующий ретрай на 12с, иначе сторож спамит
        -- попытками каждые 4с, когда пушек на карте просто нет.
        if not okE then
            CFG._ensureGiveAt = os.clock() + 8
            warn("[PE GIVE] ensure failed: " .. tostring(errE))
        end
    end)
    return false
end

-- Открыть ВСЕ двери (включая камеры): Doorscript'ы на клик-детекторах.
-- ЗАМЕНА ТЕКСТУР удалена (v2.37) по запросу.
-- FPS-БУСТ удалён (v2.75) по запросу.

-- ТОЧКИ ТЕЛЕПОРТА: живут в getgenv — переживают перезапуск скрипта.
G.PE_Waypoints = G.PE_Waypoints or {}
G.PE.WP_Save = function(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        print("[PE WP] type a waypoint name first")
        return
    end
    local root = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    G.PE_Waypoints[name] = root.CFrame
    local n = 0
    for _ in pairs(G.PE_Waypoints) do n = n + 1 end
    print("[PE WP] saved '" .. name .. "' (total " .. n .. ")")
end
G.PE.WP_TP = function(name)
    local cf = G.PE_Waypoints[name]
    local root = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    if not cf or not root then
        print("[PE WP] no such waypoint: " .. tostring(name))
        return
    end
    root.CFrame = cf
    print("[PE WP] teleported to '" .. tostring(name) .. "'")
end
-- ТП ПО ПРИЦЕЛУ: мгновенный перенос в точку, куда смотришь.
G.PE.TPCrosshair = function()
    local root = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    local mT = LP:GetMouse().Target
    if not root or not mT then
        print("[PE TP] aim at a surface first (sky has no target)")
        return
    end
    local hit = LP:GetMouse().Hit
    root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
    print("[PE TP] teleported to crosshair")
end

G.PE.ShopInfo = function()
    local f = ReplicatedStorage:FindFirstChild("ShopRemotes")
    local g = f and f:FindFirstChild("GetShopInfo")
    if not g then
        print("[PE SHOP] GetShopInfo not found")
        return
    end
    local ok, res = pcall(function() return g:InvokeServer() end)
    if not ok then
        print("[PE SHOP] invoke failed: " .. tostring(res))
        return
    end
    print("[PE SHOP] catalog: " .. tostring(res))
end

-- МАСКИРОВКА: телепорт к ближайшей Outfit-модели, клик по всем её
-- ClickDetector'ам (та же семья «Item Give», серверный чек ~200
-- стадов обходим подлётом) и возврат домой.
G.PE.WearOutfit = function()
    local root = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        print("[PE OUTFIT] no character")
        return
    end
    local best, bestD
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m.Name == "Outfit" then
            local pp = m:FindFirstChildWhichIsA("BasePart", true)
            if pp then
                local d = (pp.Position - root.Position).Magnitude
                if not bestD or d < bestD then best, bestD = m, d end
            end
        end
    end
    if not best then
        print("[PE OUTFIT] no Outfit models found")
        return
    end
    local pp = best:FindFirstChildWhichIsA("BasePart", true)
    local orig = root.CFrame
    pcall(function() root.CFrame = pp.CFrame + Vector3.new(0, 3, 0) end)
    task.wait(0.15)
    local n = 0
    if type(fireclickdetector) == "function" then
        for _, cd in ipairs(best:GetDescendants()) do
            if cd:IsA("ClickDetector") then
                pcall(function() fireclickdetector(cd) end)
                n = n + 1
            end
        end
    else
        print("[PE OUTFIT] no fireclickdetector in this executor")
    end
    task.wait(0.15)
    pcall(function() root.CFrame = orig end)
    print("[PE OUTFIT] clicked " .. n .. " detectors on nearest Outfit ("
        .. math.floor(bestD) .. " studs away), returned home")
end

-- АВТО-ПОБЕГ: телепорт на ближайшую зону, ждём регистрации касания,
-- возврат домой. Одним тогглом в ESP.
G.PE.EscapeTrip = function()
    local root = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        print("[PE ESCAPE] no character")
        return
    end
    local best, bestD
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "EscapePart" then
            local dd = (d.Position - root.Position).Magnitude
            if not bestD or dd < bestD then best, bestD = d, dd end
        end
    end
    if not best then
        print("[PE ESCAPE] no EscapePart on the map")
        return
    end
    local orig = root.CFrame
    pcall(function() root.CFrame = best.CFrame + Vector3.new(0, 4, 0) end)
    print("[PE ESCAPE] on the zone (" .. math.floor(bestD)
        .. " studs), waiting for escape...")
    task.wait(0.6)
    pcall(function() root.CFrame = orig end)
    print("[PE ESCAPE] returned home")
end

G.PE.Escape = function()
    local root = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then
        print("[PE ESCAPE] no character")
        return
    end
    local best, bestD
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "EscapePart" then
            local dd = (d.Position - root.Position).Magnitude
            if not bestD or dd < bestD then best, bestD = d, dd end
        end
    end
    if not best then
        print("[PE ESCAPE] no EscapePart on the map")
        return
    end
    pcall(function()
        root.CFrame = best.CFrame + Vector3.new(0, 4, 0)
    end)
    print("[PE ESCAPE] teleported to escape zone ("
        .. math.floor(bestD or 0) .. " studs)")
end

G.PE.Doors = function()
    if type(fireclickdetector) ~= "function" then
        warn("[PE DOORS] no fireclickdetector")
        return
    end
    local n = 0
    local f = workspace:FindFirstChild("Doors")
    if not f then
        print("[PE DOORS] no Doors folder")
        return
    end
    for _, d in ipairs(f:GetDescendants()) do
        if d:IsA("ClickDetector") then
            if pcall(fireclickdetector, d) then n = n + 1 end
        end
    end
    print("[PE DOORS] detectors clicked: " .. n)
end

-- Ищем тул с нужным ремоутом/дочерним объектом: сначала экипированный.
-- ВАЖНО: объявлен ДО G.PE.Cuff — иначе имя резолвится в глобал nil
-- и кнопка наручников падает с "attempt to call a nil value".
local function findToolWith(childName)
    local chr = LP.Character
    if chr then
        for _, t in ipairs(chr:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild(childName) then
                return t, true
            end
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild(childName) then
                return t, false
            end
        end
    end
    return nil, false
end

-- Телепорт за спину игрока (как «тот чел»: появился рядом — и сразу
-- наручники/удар). Клиентский телепорт игра не проверяет.
G.PE.TP = function(namePart)
    if not namePart or namePart == "" then
        print("[PE TP] pick a player from the list first")
        return
    end
    local plr = findPlayer(namePart)
    if not plr then
        print("[PE TP] player by '" .. tostring(namePart) .. "' not found")
        return
    end
    local ch = plr.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    local myRoot = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    if root and myRoot then
        myRoot.CFrame = root.CFrame * CFrame.new(0, 0, 2.5)
        print("[PE TP] teleport behind: " .. plr.Name)
    else
        print("[PE TP] target has no character")
    end
end

-- Наручники на игрока: CuffEvent с вариантами аргументов.
-- Handcuffs выдаются за GUARD — сначала кнопка команды.
G.PE.Cuff = function(namePart)
    if not namePart or namePart == "" then
        print("[PE CUFF] pick a player from the list first")
        return
    end
    local plr = findPlayer(namePart)
    if not plr then
        print("[PE CUFF] player by '" .. tostring(namePart) .. "' not found")
        return
    end
    local tool, equipped = findToolWith("CuffEvent")
    if not tool then
        print("[PE CUFF] no handcuffs: press Team: GUARD, respawn and take Handcuffs")
        return
    end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not equipped and hum then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.1)
    end
    local ev = tool:FindFirstChild("CuffEvent")
    local ch = plr.Character
    if not ev then
        print("[PE CUFF] CuffEvent not found in the tool")
        return
    end
    pcall(function() ev:FireServer(plr) end)
    if ch then
        pcall(function() ev:FireServer(ch) end)
        local root = ch:FindFirstChild("HumanoidRootPart")
        local hd = ch:FindFirstChildOfClass("Humanoid")
        if root then pcall(function() ev:FireServer(root) end) end
        if hd then pcall(function() ev:FireServer(hd) end) end
    end
    print("[PE CUFF] CuffEvent -> " .. plr.Name .. " (4 argument variants)")
end

-- ПРОКАЧКА ПУШКИ: Setting-модуль общий с GunScript_Local (require-кеш),
-- правки видны игре сразу — «легитные» выстрелы бьют сильнее.
G.PE.ModGun = function(dmg)
    dmg = math.clamp(tonumber(dmg) or tonumber(CFG.ModGunDamage) or 250,
        10, 2000)
    local chr = LP.Character
    local tool = chr and chr:FindFirstChildOfClass("Tool")
    if not tool or not tool:FindFirstChild("Setting") then
        print("[PE MOD] take a gun in HANDS (Setting not found)")
        return
    end
    local ok, S = pcall(function() return require(tool.Setting) end)
    if not ok or type(S) ~= "table" then
        print("[PE MOD] Setting unreadable: " .. tostring(S))
        return
    end
    S.BaseDamage = dmg
    S.HeadshotEnabled = true
    S.HeadshotDamageMultiplier = math.clamp(
        tonumber(CFG.GunHeadshot) or 200, 2, 200)
    S.Auto = true
    S.FireRate = 0.05
    S.ReloadTime = 0.5
    S.Spread = 0
    S.Piercing = math.clamp(tonumber(CFG.GunPiercing) or 5, 0, 10)
    S.DelayBeforeFiring = 0
    S.DelayAfterFiring = 0
    S.CameraShakingEnabled = false
    S.LimitedClipEnabled = false
    -- Горящие пули: поджигает цель (серверный IgniteScript).
    S.FlamingBullet = CFG.GunFire == true
    -- Отдача: подбрасывает жертву (потолок — не палимся).
    S.Knockback = math.clamp(tonumber(CFG.GunKnockback) or 0, 0, 20000)
    -- Дробовик: N пуль за выстрел (урон умножается).
    if CFG.GunShotgun then
        S.ShotgunEnabled = true
        S.BulletPerShot = math.clamp(tonumber(CFG.GunPellets) or 8, 2, 16)
    end
    -- Очередь: N пуль за клик (0 быть не может — кит замолчит).
    S.BurstFireEnabled = true
    S.BulletPerBurst = math.clamp(tonumber(CFG.GunBurst) or 10, 1, 15)
    S.BurstRate = 0.03
    -- Взрывные пули: урон по площади. Взрыв × дробовик × очередь =
    -- сотни серверных взрывов за клик — гасим множители.
    if CFG.GunExplosive then
        S.ExplosiveEnabled = true
        S.Radius = math.clamp(tonumber(CFG.GunBoomRadius) or 25, 5, 60)
        S.BulletPerShot = 1
        S.BulletPerBurst = math.min(S.BulletPerBurst, 3)
    end
    S.Lifesteal = CFG.GunLifesteal ~= false and 1000 or 0
    -- Патроны: следующая ЧЕСТНАЯ перезарядка унесёт серверу 1e9.
    if CFG.GunAmmoHack then
        S.AmmoPerClip = 1000000000
    end
    pcall(function() tool:SetAttribute("PE_Marked", true) end)
    print("[PE MOD] " .. tool.Name .. " upgraded: damage " .. dmg
        .. ", headshot x" .. (tonumber(CFG.GunHeadshot) or 200)
        .. (CFG.GunShotgun and (", shotgun " .. (tonumber(CFG.GunPellets) or 8)
            .. " pellets") or "")
        .. (CFG.GunExplosive and (", explosive r"
            .. (tonumber(CFG.GunBoomRadius) or 25)) or "")
        .. (CFG.GunFire and ", burning" or "")
        .. (CFG.GunKnockback and (", knockback "
            .. (tonumber(CFG.GunKnockback) or 0)) or "")
        .. ", auto, no spread")
end

-- ФЕЙК-ВЫСТРЕЛ: VisualizeBullet:FireServer(...) — сервер ретранслирует
-- трассер ВСЕМ игрокам (так враги видят чужие пули). Подписура из
-- GunScript_Local; урона нет — чистая психоз-атака: враг видит,
-- как его «расстреливают» откуда угодно.
G.PE.FakeShot = function(atSel)
    local chr = LP.Character
    local tool = chr and chr:FindFirstChildOfClass("Tool")
    if not tool then
        print("[PE FAKE] take any gun in hands")
        return
    end
    local gsl = tool:FindFirstChild("GunScript_Local")
    local vb = tool:FindFirstChild("VisualizeBullet")
    local handle = tool:FindFirstChild("Handle")
    if not (gsl and vb and handle) then
        print("[PE FAKE] " .. tool.Name .. " has no VisualizeBullet")
        return
    end
    local target = nil
    if atSel then
        local p = findPlayer(tostring(atSel))
        local headF = p and p.Character
            and p.Character:FindFirstChild("Head")
        if headF then target = headF.Position end
    end
    if not target then
        local m = LP:GetMouse()
        target = m and m.Hit and m.Hit.Position
    end
    if not target then
        print("[PE FAKE] no target position")
        return
    end
    pcall(function()
        vb:FireServer(handle, Vector3.new(0, 0.625, 1.25), target,
            gsl:FindFirstChild("MuzzleEffect"),
            gsl:FindFirstChild("HitEffect"),
            186809061,
            { false, 8, 0 },
            { 25, Vector3.new(0.25, 0.25, 100),
                BrickColor.new("Bright yellow").Color, 0.25,
                Enum.Material.SmoothPlastic, 0.25 },
            true, false)
    end)
    print("[PE FAKE] tracer sent -> " .. tostring(target))
end

-- theatreTool: для театра нужен релей с ВИДИМЫМ хэндлом (трассер
-- рисуется от нашей пушки). В руках пусто — экипируем свою пушку
-- из рюкзака сами, а не требуем от игрока «возьми в руки».
local function theatreTool()
    local chr = LP.Character
    local tool = chr and chr:FindFirstChildOfClass("Tool")
    if tool and tool:FindFirstChild("VisualizeBullet") then
        return tool
    end
    local bp = LP:FindFirstChild("Backpack")
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if bp and hum then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild("VisualizeBullet") then
                pcall(function() hum:EquipTool(t) end)
                task.wait(0.05)
                return chr:FindFirstChildOfClass("Tool")
            end
        end
    end
    return nil
end

-- SKY SHOT: театральный «админ-страйк». Трассер рисуется ОТ ХЭНДЛА
-- нашей пушки (сервер ретранслирует как есть), поэтому «с неба»
-- стреляем по-честному: телепорт вверх на 0.4с → залп из 3 трассеров
-- вниз по цели → возврат. Со стороны: вы телепортировались в небо,
-- расстреляли цель и исчезли. Урона нет, палево есть — фича-театр.
G.PE.SkyShot = function(namePart)
    local nowS = os.clock()
    if nowS - (G._skyAt or 0) < 6 then
        print("[PE SKY] cooldown (" ..
            string.format("%.1f", 6 - (nowS - (G._skyAt or 0))) .. "s)")
        return
    end
    local chr = LP.Character
    local rootS = chr and chr:FindFirstChild("HumanoidRootPart")
    if not rootS then print("[PE SKY] no character") return end
    local tool = theatreTool()
    if not tool then
        print("[PE SKY] no gun in hands/backpack")
        return
    end
    local gsl = tool:FindFirstChild("GunScript_Local")
    local vb = tool:FindFirstChild("VisualizeBullet")
    local handle = tool:FindFirstChild("Handle")
    if not (gsl and vb and handle) then
        print("[PE SKY] " .. tool.Name .. " has no VisualizeBullet")
        return
    end
    local target = nil
    if namePart then
        local p = findPlayer(tostring(namePart))
        local headF = p and p.Character
            and p.Character:FindFirstChild("Head")
        if headF then target = headF.Position end
    end
    if not target then
        local m = LP:GetMouse()
        target = m and m.Hit and m.Hit.Position
    end
    if not target then
        print("[PE SKY] no target position")
        return
    end
    local homeCF = rootS.CFrame
    G._skyAt = nowS
    task.spawn(function()
        pcall(function()
            rootS.CFrame = CFrame.new(target
                + Vector3.new(math.random(-10, 10), 160,
                    math.random(-10, 10)))
        end)
        -- 0.5с на репликацию: иначе сервер и чужие клиенты ещё видят
        -- нас на земле, и трассеры уходят со старой позиции.
        task.wait(0.5)
        for _ = 1, 3 do
            pcall(function()
                vb:FireServer(handle, Vector3.new(0, 0.625, 1.25),
                    target,
                    gsl:FindFirstChild("MuzzleEffect"),
                    gsl:FindFirstChild("HitEffect"),
                    186809061,
                    { false, 8, 0 },
                    { 25, Vector3.new(0.25, 0.25, 140),
                        BrickColor.new("Bright yellow").Color, 0.2,
                        Enum.Material.Neon, 0.2 },
                    true, false)
            end)
            task.wait(0.12)
        end
        pcall(function()
            local rB = LP.Character
                and LP.Character:FindFirstChild("HumanoidRootPart")
            if rB then rB.CFrame = homeCF end
        end)
        -- ФИНАЛ СТРАЙКА: цель-игрок вспыхивает (1 урона + серверный
        -- огонь) — «админ сжёг с неба». Тиммейта сервер отклонит сам.
        if namePart then
            local pF = findPlayer(tostring(namePart))
            local humF = pF and pF.Character
                and pF.Character:FindFirstChildOfClass("Humanoid")
            local headF = pF and pF.Character
                and (pF.Character:FindFirstChild("Head")
                    or pF.Character:FindFirstChild("HumanoidRootPart"))
            local remoteF = myGunRemote("InflictTarget")
            if humF and headF and humF.Health > 0 and remoteF then
                pcall(function()
                    remoteF:FireServer(humF, headF, 1,
                        Vector3.new(0, 1, 0), 0, 0, true)
                end)
            end
        end
    end)
    print("[PE SKY] sky strike -> " .. tostring(target))
end

-- SQUAD SHOT: как SKY SHOT, но 5 трассеров с разных точек неба за один
-- блинк — со стороны выглядит как работа целой админ-команды.
G.PE.SquadShot = function(namePart)
    local nowS = os.clock()
    if nowS - (G._squadAt or 0) < 8 then
        print("[PE SQUAD] cooldown (" ..
            string.format("%.1f", 8 - (nowS - (G._squadAt or 0))) .. "s)")
        return
    end
    local chr = LP.Character
    local rootS = chr and chr:FindFirstChild("HumanoidRootPart")
    if not rootS then print("[PE SQUAD] no character") return end
    local tool = theatreTool()
    if not tool then
        print("[PE SQUAD] no gun in hands/backpack")
        return
    end
    local gsl = tool:FindFirstChild("GunScript_Local")
    local vb = tool:FindFirstChild("VisualizeBullet")
    local handle = tool:FindFirstChild("Handle")
    if not (gsl and vb and handle) then
        print("[PE SQUAD] " .. tool.Name .. " has no VisualizeBullet")
        return
    end
    local target = nil
    if namePart then
        local p = findPlayer(tostring(namePart))
        local headF = p and p.Character
            and p.Character:FindFirstChild("Head")
        if headF then target = headF.Position end
    end
    if not target then
        local m = LP:GetMouse()
        target = m and m.Hit and m.Hit.Position
    end
    if not target then
        print("[PE SQUAD] no target position")
        return
    end
    local homeCF = rootS.CFrame
    G._squadAt = nowS
    task.spawn(function()
        pcall(function()
            rootS.CFrame = CFrame.new(target + Vector3.new(0, 180, 0))
        end)
        task.wait(0.5) -- репликация: сервер должен узнать, что мы в небе
        for i = 1, 5 do
            local ang = (i / 5) * math.pi * 2
            local from = target
                + Vector3.new(math.cos(ang) * 25, 120,
                    math.sin(ang) * 25)
            pcall(function()
                vb:FireServer(handle, Vector3.new(0, 0.625, 1.25), from,
                    gsl:FindFirstChild("MuzzleEffect"),
                    gsl:FindFirstChild("HitEffect"),
                    186809061,
                    { false, 8, 0 },
                    { 25, Vector3.new(0.3, 0.3, 200),
                        BrickColor.new("Really red").Color, 0.1,
                        Enum.Material.Neon, 0.2 },
                    true, false)
            end)
            task.wait(0.08)
        end
        pcall(function()
            local rB = LP.Character
                and LP.Character:FindFirstChild("HumanoidRootPart")
            if rB then rB.CFrame = homeCF end
        end)
    end)
    print("[PE SQUAD] 5-man volley -> " .. tostring(target))
end

-- SOUNDBOARD удалён (v2.86) по запросу.

-- ORBITAL BEAM: гигантский неоновый луч с неба в цель (толстый трейл
-- через релей VisualizeBullet — видно ВСЕМ) + поджог цели. Со стороны —
-- орбитальный удар, как будто сервер тебя карает.
G.PE.OrbitalBeam = function(namePart)
    local nowS = os.clock()
    if nowS - (G._orbAt or 0) < 12 then
        print("[PE ORB] cooldown (" ..
            string.format("%.1f", 12 - (nowS - (G._orbAt or 0))) .. "s)")
        return
    end
    local chr = LP.Character
    local rootS = chr and chr:FindFirstChild("HumanoidRootPart")
    if not rootS then print("[PE ORB] no character") return end
    local tool = theatreTool()
    if not tool then
        print("[PE ORB] no gun in hands/backpack")
        return
    end
    local gsl = tool:FindFirstChild("GunScript_Local")
    local vb = tool:FindFirstChild("VisualizeBullet")
    local handle = tool:FindFirstChild("Handle")
    if not (gsl and vb and handle) then
        print("[PE ORB] " .. tool.Name .. " has no VisualizeBullet")
        return
    end
    local target, targetIsPlayer = nil, false
    if namePart then
        local p = findPlayer(tostring(namePart))
        local headF = p and p.Character
            and p.Character:FindFirstChild("Head")
        if headF then
            target = headF.Position
            targetIsPlayer = true
        end
    end
    if not target then
        local m = LP:GetMouse()
        target = m and m.Hit and m.Hit.Position
    end
    if not target then
        print("[PE ORB] no target position")
        return
    end
    local homeCF = rootS.CFrame
    G._orbAt = nowS
    task.spawn(function()
        pcall(function()
            rootS.CFrame = CFrame.new(target + Vector3.new(0, 250, 0))
        end)
        task.wait(0.5) -- репликация позиции до выстрела
        pcall(function()
            vb:FireServer(handle, Vector3.new(0, 0.625, 1.25), target,
                gsl:FindFirstChild("MuzzleEffect"),
                gsl:FindFirstChild("HitEffect"),
                186809061,
                { false, 8, 0 },
                { 60, Vector3.new(6, 6, 500),
                    BrickColor.new("Bright red").Color, 0.05,
                    Enum.Material.Neon, 0.6 },
                true, false)
        end)
        -- Карательный финал: цель-игрок вспыхивает (1 урона + огонь).
        if targetIsPlayer then
            local pF = findPlayer(tostring(namePart))
            local humF = pF and pF.Character
                and pF.Character:FindFirstChildOfClass("Humanoid")
            local headF = pF and pF.Character
                and (pF.Character:FindFirstChild("Head")
                    or pF.Character:FindFirstChild("HumanoidRootPart"))
            local remoteF = myGunRemote("InflictTarget")
            if humF and headF and humF.Health > 0 and remoteF then
                pcall(function()
                    remoteF:FireServer(humF, headF, 1,
                        Vector3.new(0, 1, 0), 0, 0, true)
                end)
            end
        end
        task.wait(0.35)
        pcall(function()
            local rB = LP.Character
                and LP.Character:FindFirstChild("HumanoidRootPart")
            if rB then rB.CFrame = homeCF end
        end)
    end)
    print("[PE ORB] orbital beam -> " .. tostring(target))
end

-- LEVITATE: плавная левитация на глазах у всех — всплываешь на 9
-- стадов, висишь 3с, плавно возвращаешься. Физика наша (клиентская),
-- позиция реплицируется — все видят «антигравитацию админа».
G.PE.Levitate = function()
    local nowS = os.clock()
    if nowS - (G._levAt or 0) < 12 then
        print("[PE LEV] cooldown (" ..
            string.format("%.1f", 12 - (nowS - (G._levAt or 0))) .. "s)")
        return
    end
    local chr = LP.Character
    local root = chr and chr:FindFirstChild("HumanoidRootPart")
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if not (root and hum) or hum.Health <= 0 then
        print("[PE LEV] no character")
        return
    end
    if CFG.Apocalypse then
        print("[PE LEV] paused while APOCALYPSE runs (anchor conflict)")
        return
    end
    G._levAt = nowS
    task.spawn(function()
        local base = root.CFrame
        pcall(function() root.Anchored = true end)
        -- Подъём: 12 шагов по 1.6 стада (~19 стадов), быстрее.
        for i = 1, 12 do
            pcall(function()
                root.CFrame = base + Vector3.new(0, i * 1.6, 0)
            end)
            task.wait(0.08)
        end
        task.wait(2.5)
        for i = 12, 1, -1 do
            pcall(function()
                root.CFrame = base + Vector3.new(0, i * 1.6, 0)
            end)
            task.wait(0.06)
        end
        pcall(function()
            root.CFrame = base
            root.Anchored = false
        end)
    end)
    print("[PE LEV] levitation show started")
end
-- Декомпиляция скриптов пушки: по исходникам GunScript_Local видно,
-- с какими аргументами игра честно стреляет InflictTarget.
G.PE.GunSource = function()
    if type(decompile) ~= "function" then
        print("[PE SRC] no decompile function in this executor")
        return
    end
    local any = false
    local allTxt = {}
    for _, t in ipairs(toolList()) do
        for _, scrName in ipairs({ "GunScript_Local", "GunScript_Server",
            "Main", "Cuff server", "LocalScript" }) do
            local scr = t:FindFirstChild(scrName)
            if scr then
                local ok, src = pcall(decompile, scr)
                if ok and type(src) == "string" and #src > 0 then
                    any = true
                    local head = "[PE SRC] ===== " .. t.Name .. "." .. scrName
                        .. " (" .. #src .. " bytes) ====="
                    print(head)
                    allTxt[#allTxt + 1] = head .. "\n" .. src
                else
                    print("[PE SRC] " .. t.Name .. "." .. scrName
                        .. ": decompile failed: " .. tostring(src))
                end
            end
        end
    end
    if not any then
        print("[PE SRC] no guns in hands/backpack - take a weapon")
        return
    end
    if type(writefile) == "function" then
        pcall(writefile, "pe_gunsrc.txt", table.concat(allTxt, "\n\n"))
        print("[PE SRC] fully saved to pe_gunsrc.txt")
    end
end

-- Цель: «Everyone» или ник конкретного игрока (списки с игроками).
-- Тим-фильтр: сервер урон по тиммейтам режет — не тратить слоты.
local function targetAllowed(p, sel, myTeam)
    if myTeam and p.Team == myTeam then return false end
    if sel == nil or sel == "" or sel == "Everyone" then return true end
    return p.Name == sel or p.DisplayName == sel
end

-- Цикл: ретрибуция, анти-стан, килл-аура, прокачка.
local auraAt = 0
local stunAt = 0
local modAt = 0
local immortalAt = 0
local immortalTapAt = 0
local c00lAt = 0
local fireAuraAt = 0
local retAt = 0
local PE_LAST_HP = -1
local PE_HIT_AT = 0
local retTarget, retUntil = nil, 0
local retPrinted = nil -- имя уже напечатанного атакующего (антиспам)
local retHitDmg = 50   -- сколько урона пришло в последнем попадании

-- КТО СТРЕЛЯЛ: сервер ретранслирует ВСЕ трассеры (VisualizeBullet)
-- каждому клиенту. Слушаем их тихо (без отрисовки) и запоминаем,
-- когда и кто стрелял — тогда атрибуция атакующего точная даже с
-- дальней дистанции (старая эвристика «ближайший вооружённый» жгла
-- невиновных рядом, пока дальний стрелок оставался цел).
local recentShots = setmetatable({}, { __mode = "k" })
local hookedVB = setmetatable({}, { __mode = "k" })
local vbConns = {} -- сильные ссылки: PE_Stop дисконнектит всё
local SHOT_MEMORY = 3 -- секунды

local function hookShotRemotes()
    if STOPPED then return end
    for _, cont in ipairs({ workspace, ReplicatedStorage }) do
        for _, d in ipairs(cont:GetDescendants()) do
            if d:IsA("RemoteEvent") and d.Name == "VisualizeBullet"
               and not hookedVB[d] then
                local okC, conn = pcall(function()
                    return d.OnClientEvent:Connect(function(handle)
                        if typeof(handle) ~= "Instance" then return end
                        local tool = handle:FindFirstAncestorOfClass("Tool")
                        local plr = tool
                            and Players:GetPlayerFromCharacter(tool.Parent)
                        if plr and plr ~= LP then
                            recentShots[plr] = os.clock()
                        end
                    end)
                end)
                -- Флаг ПОСЛЕ успешного коннекта: упавший = не помечен.
                if okC and conn then
                    hookedVB[d] = true
                    vbConns[#vbConns + 1] = conn
                end
            end
        end
    end
end
task.spawn(function()
    while not STOPPED do
        pcall(hookShotRemotes)
        task.wait(2)
    end
end)

-- Последний стрелок за окно памяти (plr, время выстрела) или nil.
-- Тиммейты пропускаются, пока нет обхода (сервер их урон режет —
-- лочить retTarget на них впустую).
local function lastShooter()
    local now = os.clock()
    local noFilter = CFG.AuraTeamBypass or CFG.Apocalypse
    local bestP, bestT
    for p, t in pairs(recentShots) do
        if now - t > SHOT_MEMORY then
            recentShots[p] = nil
        elseif p.Parent and (not bestT or t > bestT) then
            if noFilter or p.Team ~= LP.Team then
                bestP, bestT = p, t
            end
        end
    end
    return bestP, bestT
end

-- Поиск атакующего: сначала точная атрибуция по недавним выстрелам
-- (окно стыковки «выстрел → просадка HP» всего 1с — перекрёстный огонь
-- и чужие фейк-трассеры не должны стать «атакующим»), фолбэк —
-- старая эвристика (ближайший, вооружённые −30 стадов).
local function findAttacker(myRoot)
    local shooter, shotAt = lastShooter()
    if shooter and os.clock() - shotAt <= 1 then
        local ch = shooter.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            return shooter
        end
    end
    local bestP, bestS
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local ch = p.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if ch and hum and hum.Health > 0 and root then
                local d = (root.Position - myRoot.Position).Magnitude
                local armed = ch:FindFirstChildOfClass("Tool") ~= nil
                local score = d - (armed and 30 or 0)
                if not bestS or score < bestS then
                    bestP, bestS = p, score
                end
            end
        end
    end
    return bestP
end

local function auraTick()
    if not PE_GUI_READY then return end
    local now = os.clock()

    -- РЕТРИБУЦИЯ: нас ударили/подстрелили — вычисляем атакующего
    -- и сжигаем его (урон ауры + поджог, залп ~1.5с).
    if CFG.Retr then
        local chrR = LP.Character
        local humR = chrR and chrR:FindFirstChildOfClass("Humanoid")
        local rootR = chrR and chrR:FindFirstChild("HumanoidRootPart")
        if humR and rootR then
            local hp = humR.Health
            if PE_LAST_HP >= 0 and hp > 0 and hp < PE_LAST_HP - 0.5
               and now - PE_HIT_AT > 0.3 then
                PE_HIT_AT = now
                -- MIRROR: запоминаем, сколько урона пришло этим ударом.
                retHitDmg = math.clamp(PE_LAST_HP - hp, 1, 200)
                local atk = findAttacker(rootR)
                if atk then
                    retTarget = atk
                    retUntil = now + 1.5
                    -- Печатаем только смену атакующего: при непрерывном
                    -- огне по нам строка дублировалась 10+ раз подряд.
                    if retPrinted ~= atk.Name then
                        retPrinted = atk.Name
                        print("[PE RET] attacker: " .. atk.Name .. " -> BURN")
                    end
                end
            end
            PE_LAST_HP = hp
        else
            PE_LAST_HP = -1
        end
        if retTarget and now < retUntil then
            local chA = retTarget.Character
            local humA = chA and chA:FindFirstChildOfClass("Humanoid")
            local headA = chA and (chA:FindFirstChild("Head")
                or chA:FindFirstChild("HumanoidRootPart"))
            local remoteR = myGunRemote("InflictTarget")
            if remoteR and humA and humA.Health > 0 and headA
               and now - retAt >= 0.1 then
                retAt = now
                local bt = PE_BURN_AT[retTarget]
                local burnR = (not bt or now - bt > 1.5)
                if burnR then PE_BURN_AT[retTarget] = now end
                -- Переключаемый урон: MIRROR отражает полученный урон,
                -- фиксированный режим — слайдер RetrDamage, 0 = как аура.
                local dmgR = math.clamp(
                    CFG.RetrMirror and retHitDmg
                    or tonumber(CFG.RetrDamage)
                    or tonumber(CFG.KillAuraDamage) or 50, 1, 200)
                pcall(function()
                    remoteR:FireServer(humA, headA, dmgR,
                        Vector3.new(0, 1, 0), 0, 0, burnR)
                end)
            end
            if not humA or humA.Health <= 0 then
                retTarget = nil
            end
        else
            retTarget = nil
        end
    end

    -- v2.54: СТОРОЖ ОРУЖИЯ. Раз в 3 с проверяем, что выбранная пушка
    -- реально лежит в руках/рюкзаке; нет — выдаём заново (троттл 4 с
    -- внутри EnsureWeapon). Работает и в бою, и в Апокалипсисе.
    if CFG.AutoGive and now - (CFG._ensureAt or 0) >= 3 then
        CFG._ensureAt = now
        if type(G.PE.EnsureWeapon) == "function" then
            G.PE.EnsureWeapon("watchdog")
        end
    end

    -- АВТО-ПРОКАЧКА: пушка без метки в руках — апгрейдим сразу.
    if CFG.ModGunAuto ~= false and now - modAt >= 1 then
        modAt = now
        local chrM = LP.Character
        local toolM = chrM and chrM:FindFirstChildOfClass("Tool")
        if toolM and toolM:FindFirstChild("Setting")
           and not toolM:GetAttribute("PE_Marked") then
            G.PE.ModGun()
        end
    end

    -- FIRE AURA: театральная аура огня — все, кто подошёл ближе
    -- 15 стадов, вспыхивают (1 урона + серверный огонь). Со стороны
    -- выглядит как «опасный админ», урона почти нет. Карту сервер
    -- не жжёт (проверка принадлежности) — только игроки.
    if CFG.FireAura and now - fireAuraAt >= 2 then
        fireAuraAt = now
        local remoteFA = myGunRemote("InflictTarget")
        local chrFA = LP.Character
        local rootFA = chrFA and chrFA:FindFirstChild("HumanoidRootPart")
        if remoteFA and rootFA then
            for _, pF in ipairs(Players:GetPlayers()) do
                if pF ~= LP then
                    local chF2 = pF.Character
                    local hF2 = chF2
                        and chF2:FindFirstChildOfClass("Humanoid")
                    local headF2 = chF2 and (chF2:FindFirstChild("Head")
                        or chF2:FindFirstChild("HumanoidRootPart"))
                    if chF2 and hF2 and hF2.Health > 0 and headF2
                       and not chF2:FindFirstChildOfClass("ForceField") then
                        local dFA = (headF2.Position
                            - rootFA.Position).Magnitude
                        if dFA <= 15 then
                            local btF = PE_BURN_AT[pF]
                            local burnFA = (not btF or now - btF > 2)
                            if burnFA then PE_BURN_AT[pF] = now end
                            pcall(function()
                                remoteFA:FireServer(hF2, headF2, 1,
                                    Vector3.new(0, 1, 0), 0, 0, burnFA)
                            end)
                        end
                    end
                end
            end
        end
    end

    -- C00LKIDD MODE: медленно сжигаем всех — крошечный урон каждый
    -- тик + серверный огонь раз в 2с. Все горят и умирают медленно.
    if CFG.C00lMode and now - c00lAt >= 1.2 then
        c00lAt = now
        local remoteC = myGunRemote("InflictTarget")
        if remoteC then
            local myRootC = LP.Character
                and LP.Character:FindFirstChild("HumanoidRootPart")
            local hitC = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and hitC < 12 then
                    local ch = p.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local root = ch and ch:FindFirstChild("HumanoidRootPart")
                    if ch and hum and hum.Health > 0 and root
                       and not ch:FindFirstChildOfClass("ForceField")
                       and targetAllowed(p, CFG.C00lTeam or "Everyone",
                           LP.Team) then
                        local bt = PE_BURN_AT[p]
                        local burnC = (not bt or now - bt > 2)
                        if burnC then PE_BURN_AT[p] = now end
                        hitC = hitC + 1
                        local dir = Vector3.new(0, 1, 0)
                        if myRootC then
                            local delta = root.Position - myRootC.Position
                            if delta.Magnitude > 0.01 then
                                dir = delta.Unit
                            end
                        end
                        pcall(function()
                            remoteC:FireServer(hum, root,
                                math.clamp(tonumber(CFG.C00lDamage) or 3,
                                    1, 20),
                                dir,
                                CFG.C00lFling and 20000 or 0, 0, burnC)
                        end)
                    end
                end
            end
        elseif os.clock() - (CFG._noGunWarnAt or 0) > 10 then
            CFG._noGunWarnAt = os.clock()
            warn("[PE] c00lkidd: no gun with InflictTarget")
        end
    end

    -- АПОКАЛИПСИС: автоматическая убивалка.
    -- 1) ВЫШКА: сервер при смене команды РЕСПАВНИТ нас на спавн
    --    команды (пушка выпадает) — поэтому вышку держим ПОСТОЯННО:
    --    каждый цикл проверяем «мы якорнуты и на высоте», нет —
    --    возвращаем на сохранённую точку вышки.
    -- 2) ОРУЖИЕ: после каждого респавна пушка выпадает — авто-гивер
    --    берёт M9. Пока оружия нет — команды НЕ переключаем.
    -- 3) Только когда вышка + пушка на месте: смена команды раз в
    --    секунду (каждый по очереди враг) + урон 100 + огонь всем.
    if CFG.Apocalypse then
        local chrA = LP.Character
        local rootA = chrA and chrA:FindFirstChild("HumanoidRootPart")
        if chrA and rootA then
            -- Точка вышки: сохраняем при первом включении.
            if not CFG._apocPerchCF then
                CFG._apocPerchCF = rootA.CFrame + Vector3.new(0, 400, 0)
                print("[PE APOC] perch point saved (+400 studs)")
            end
            local perched = rootA.Anchored
                and math.abs(rootA.Position.Y
                    - CFG._apocPerchCF.Position.Y) < 30
            if not perched
               and (os.clock() - (CFG._giveFlyAt or 0) > 0.6) then
                pcall(function()
                    rootA.Anchored = true
                    rootA.CFrame = CFG._apocPerchCF
                end)
                -- Троттл re-perch: раньше _giveFlyAt ставился только
                -- в флай-ине гивера (под APOC отключён) — якорь дёргался
                -- каждый Heartbeat в окне «не перчед».
                CFG._giveFlyAt = os.clock()
            end
            -- Оружие: после респавна выпало — берём заново (первая
            -- выдача сразу, без 8-секундной отсрочки). Проверка пушки
            -- кэшируется на 0.5с: myGunRemote каждый кадр дорог.
            if not CFG._apocGunAt or now - CFG._apocGunAt >= 0.5 then
                CFG._apocGunAt = now
                -- v2.54: нужна именно ЗАДАННАЯ пушка (её выдаёт авто-гивер),
                -- а не любая с InflictTarget: без неё апокалипсис молча
                -- стоял на вышке и ничего не делал.
                local want = G.PE.ApocGunName()
                CFG._apocWant = want
                -- v2.57: ИЛИ любая своя пушка с InflictTarget. Раньше требовалось
                -- точное имя AutoGiveName, поэтому с AK/SVD в руках апокалипсис
                -- навсегда считал себя безоружным и стоял на вышке.
                CFG._apocHasGun = G.PE.HasWeapon(want)
                    or myGunRemote("InflictTarget") ~= nil
            end
            local hasGun = CFG._apocHasGun
            if not hasGun then
                if not CFG._apocGiveAt
                   or os.clock() - CFG._apocGiveAt > 4 then
                    CFG._apocGiveAt = os.clock()
                    if type(G.PE.EnsureWeapon) == "function" then
                        G.PE.EnsureWeapon("apocalypse")
                    end
                end
            else
                -- Вышка + пушка на месте: можно воевать.
                if now - (CFG._apocTeamAt or 0) >= 1 then
                    CFG._apocTeamAt = now
                    CFG._apocTeamFlip = not CFG._apocTeamFlip
                    local rT = ReplicatedStorage
                        :FindFirstChild("ChooseTeamEvent")
                    if rT then
                        pcall(function()
                            rT:FireServer(CFG._apocTeamFlip and "Escaped"
                                or "Prisoner")
                        end)
                    end
                end
                if now - apocAt >= 0.5 then
                    apocAt = now
                    local remoteA = myGunRemote("InflictTarget")
                    if remoteA then
                        local dmgA = math.clamp(
                            tonumber(CFG.ApocDamage) or 100, 1, 200)
                        local hitsA = 0
                        for _, p2 in ipairs(Players:GetPlayers()) do
                            if p2 ~= LP and p2.Team ~= LP.Team and hitsA < 20 then
                                local ch2 = p2.Character
                                local h2 = ch2
                                    and ch2:FindFirstChildOfClass("Humanoid")
                                local head2 = ch2
                                    and (ch2:FindFirstChild("Head")
                                        or ch2:FindFirstChild(
                                            "HumanoidRootPart"))
                                if ch2 and h2 and h2.Health > 0 and head2
                                   and not ch2:FindFirstChildOfClass(
                                       "ForceField") then
                                    hitsA = hitsA + 1
                                    local bt = PE_BURN_AT[p2]
                                    local burnA = (not bt or now - bt > 1.5)
                                    if burnA then PE_BURN_AT[p2] = now end
                                    pcall(function()
                                        remoteA:FireServer(h2, head2, dmgA,
                                            Vector3.new(0, 1, 0), 0, 0,
                                            burnA)
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        -- Выключили: отанкориваем (респавн и так вернёт на землю).
        if CFG._apocPerchCF then
            CFG._apocPerchCF = nil
            local rootA = LP.Character
                and LP.Character:FindFirstChild("HumanoidRootPart")
            if rootA then
                pcall(function() rootA.Anchored = false end)
            end
            print("[PE APOC] perch released")
        end
    end

    -- БЕССМЕРТИЕ: вампиризм. Сервер отвергает вызовы по себе, поэтому
    -- два пути хила: self-пакет (0 урона + 1e6 — страховка на случай,
    -- если чек сервера только на урон>0) и при полученном уроне — тап
    -- по ближайшему живому врагу (1 урона + 1e6 вампиризма): это
    -- единственный подтверждённый рабочий способ лечения. Против
    -- ваншотов (100+ за пакет) спасает только убийство атакующего
    -- первым — выбери его ник в «Who to hit».
    -- v3.05: ПАНИК-ПЕРЧ УДАЛЁН по запросу — телепорта вверх при
    -- низком HP больше нет. Бессмертие = только хил (вампир-тап).
    -- Зачистка застревшего _immPerch/_immBack от старых сессий.
    if CFG._immPerch or CFG._immBack then
        CFG._immPerch = nil
        CFG._immBack = nil
        CFG._immUntil = nil
        local rootR2 = LP.Character
            and LP.Character:FindFirstChild("HumanoidRootPart")
        if rootR2 then
            pcall(function() rootR2.Anchored = false end)
        end
    end
    if CFG.Immortal then
        local chrI = LP.Character
        local humI = chrI and chrI:FindFirstChildOfClass("Humanoid")
        local rootI = chrI and chrI:FindFirstChild("HumanoidRootPart")
        local remoteI = myGunRemote("InflictTarget")
        if remoteI and humI and rootI and humI.Health > 0 then
            local damaged = humI.Health < humI.MaxHealth - 0.5
            -- v2.89: лечим ЧАЩЕ. Самохил-пакет: 0.05с при уроне, 0.25с
            -- в бою. Тап по врагу (единственный хил, который сервер
            -- принимает): 0.1с при уроне, 0.25с в бою — HP держится
            -- у максимума даже под непрерывным огнём.
            local inCombat = lastShooter() ~= nil
            local cadence = damaged and 0.05 or (inCombat and 0.25 or 0.5)
            if now - immortalAt >= cadence then
                immortalAt = now
                pcall(function()
                    remoteI:FireServer(humI, rootI, 0,
                        Vector3.new(0, 0, 1), 0, 1000000, false)
                end)
                local tapGap = damaged and 0.1 or 0.25
                if (damaged or inCombat)
                   and now - immortalTapAt >= tapGap then
                    immortalTapAt = now
                    -- Тап по источнику урона: сначала точный lastShooter
                    -- (кто стрелял), фолбэк — ближайший живой враг.
                    local bestP2 = lastShooter()
                    if not (bestP2 and bestP2.Character
                       and bestP2.Character:FindFirstChildOfClass("Humanoid")
                       and bestP2.Character:FindFirstChildOfClass("Humanoid").Health > 0) then
                        local bestD2
                        for _, p3 in ipairs(Players:GetPlayers()) do
                            if p3 ~= LP then
                                local ch3 = p3.Character
                                local h3 = ch3
                                    and ch3:FindFirstChildOfClass("Humanoid")
                                local r3 = ch3
                                    and ch3:FindFirstChild("HumanoidRootPart")
                                if ch3 and h3 and h3.Health > 0 and r3
                                   and not ch3:FindFirstChildOfClass("ForceField")
                                   and targetAllowed(p3, "Everyone", LP.Team) then
                                    local d3 = (r3.Position
                                        - rootI.Position).Magnitude
                                    if not bestD2 or d3 < bestD2 then
                                        bestP2, bestD2 = p3, d3
                                    end
                                end
                            end
                        end
                    end
                    local chB = bestP2 and bestP2.Character
                    local humB = chB
                        and chB:FindFirstChildOfClass("Humanoid")
                    local headB = chB and (chB:FindFirstChild("Head")
                        or chB:FindFirstChild("HumanoidRootPart"))
                    if humB and headB and humB.Health > 0 then
                        pcall(function()
                            remoteI:FireServer(humB, headB, 1,
                                Vector3.new(0, 1, 0), 0, 1000000, false)
                        end)
                    end
                end
            end
        end
    end

    -- АНТИ-СТАН: тазер, наручники и регдолл не держат.
    if CFG.AntiStun and now - stunAt >= 0.12 then
        stunAt = now
        local chrA = LP.Character
        local humA = chrA and chrA:FindFirstChildOfClass("Humanoid")
        if chrA and humA then
            -- 1) Запрет регдолл-состояний (один раз на гуманоида).
            if not humA:GetAttribute("PE_NoRagdoll") then
                for _, stName in ipairs({ "Ragdoll", "FallingDown", "PlatformStanding" }) do
                    pcall(function()
                        humA:SetStateEnabled(Enum.HumanoidStateType[stName], false)
                    end)
                end
                pcall(function() humA:SetAttribute("PE_NoRagdoll", true) end)
            end
            -- 2) Если всё-таки завалило — поднимаемся.
            pcall(function()
                local st = humA:GetState()
                if st and (st.Name == "Physics" or st.Name == "Ragdoll"
                    or st.Name == "FallingDown" or st.Name == "PlatformStanding") then
                    humA:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
            -- 3) Скорость/прыжок/стан-свойства восстанавливаем.
            if (humA.WalkSpeed or 16) < 4 then humA.WalkSpeed = 16 end
            if humA.PlatformStand then humA.PlatformStand = false end
            if humA.JumpPower == 0 then humA.JumpPower = 50 end
            -- 4) Тазер-скрипт в персонаже и регдолл-констрейнты.
            pcall(function()
                local gtb = chrA:FindFirstChild("GetTasedBro")
                if gtb then gtb:Destroy() end
                for _, d in ipairs(chrA:GetDescendants()) do
                    if (d:IsA("BallSocketConstraint") or d:IsA("HingeConstraint"))
                       and string.find(string.lower(d.Name), "ragdoll", 1, true) then
                        d.Enabled = false
                    end
                end
            end)
            -- 5) Наручники: отрываем части из ActiveCuffParts от себя.
            pcall(function()
                local f = workspace:FindFirstChild("ActiveCuffParts")
                if f then
                    for _, cp in ipairs(f:GetChildren()) do
                        if cp:IsA("BasePart") then
                            for _, w in ipairs(cp:GetChildren()) do
                                if w:IsA("WeldConstraint") or w:IsA("Weld") then
                                    local other = (w.Part0 == cp) and w.Part1 or w.Part0
                                    if other and other:IsDescendantOf(chrA) then
                                        w:Destroy()
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end

    if not CFG.KillAura then return end
    if now - auraAt < math.max(0.1,
        tonumber(CFG.KillAuraDelay) or 0.15) then return end
    auraAt = now
    local myRoot = LP.Character
        and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local remote = myGunRemote("InflictTarget")
    if not remote then
        -- Не молчим: «аура иногда не работает» = нет пушки.
        if os.clock() - (CFG._noGunWarnAt or 0) > 10 then
            CFG._noGunWarnAt = os.clock()
            warn("[PE] kill aura: no gun with InflictTarget - take a weapon")
        end
        return
    end
    local radius = tonumber(CFG.KillAuraRadius) or 40
    local mode = CFG.KillAuraTeam or "Everyone"
    local myTeam = LP.Team
    -- ОБХОД ТИМ-ЧЕКА: сервер отвергает урон по тиммейтам. Флип между
    -- Prisoner и Escaped каждые 1.5с — тогда аура достаёт и зеков, и
    -- охрану. Цена: сервер РЕСПАВНИТ нас на каждом флипе (пушка
    -- выпадает — сторож M9 вернёт её в течение 3с).
    if CFG.AuraTeamBypass and not CFG.Apocalypse
       and now - (CFG._bypassAt or 0) >= 1.5 then
        CFG._bypassAt = now
        CFG._bypassFlip = not CFG._bypassFlip
        local rB = ReplicatedStorage:FindFirstChild("ChooseTeamEvent")
        if rB then
            pcall(function()
                rB:FireServer(CFG._bypassFlip and "Escaped" or "Prisoner")
            end)
        end
    end
    local hits = 0
    for _, p in ipairs(Players:GetPlayers()) do
        -- Максимум целей за тик (слайдер AuraMaxHits).
        if p ~= LP and hits
            < math.clamp(tonumber(CFG.AuraMaxHits) or 6, 1, 20) then
            local ch = p.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if ch and hum and hum.Health > 0 and root
               and not ch:FindFirstChildOfClass("ForceField") then
                -- «Выбранный игрок»: бьём только цель из списка,
                -- без ограничения дистанции.
                -- Выбран конкретный игрок — бьём его без лимита
                -- дистанции; «Everyone» — все в радиусе.
                local isSel = (mode ~= "Everyone" and mode ~= ""
                    and (p.Name == mode or p.DisplayName == mode))
                local inRange = (root.Position - myRoot.Position).Magnitude
                    <= radius
                local ok = isSel
                    or ((mode == "Everyone" or mode == "") and inRange)
                if ok then
                    hits = hits + 1
                    -- Урон зажат на месте использования: сохранённые
                    -- консолью/прошлой сессией значения не спамят сервер.
                    local dmg = math.clamp(
                        tonumber(CFG.KillAuraDamage) or 50, 1, 200)
                    local dir = Vector3.new(0, 0, 1)
                    local delta = root.Position - myRoot.Position
                    if delta.Magnitude > 0.01 then dir = delta.Unit end
                    -- Подброс: не чаще 0.5 с на игрока, потолок отдачи
                    -- разумный — невозможная физика сразу палит.
                    local knock = 0
                    if CFG.AuraFling then
                        local ft = PE_FLING_AT[p]
                        if not ft or now - ft > 0.5 then
                            PE_FLING_AT[p] = now
                            knock = 20000
                            -- Направление подброса: вверх / от себя /
                            -- рандом (пинбол).
                            local fd = CFG.FlingDir or "Up"
                            if fd == "Away from me" then
                                -- Цель вплотную: delta.Unit = NaN-вектор,
                                -- уходит в серверный подброс — гард.
                                if delta.Magnitude > 0.01 then
                                    dir = delta.Unit
                                end
                            elseif fd == "Random" then
                                dir = Vector3.new(
                                    math.random() - 0.5,
                                    math.random() * 0.8 + 0.4,
                                    math.random() - 0.5)
                                if dir.Magnitude > 0.01 then
                                    dir = dir.Unit
                                end
                            else
                                dir = Vector3.new(0, 1, 0)
                            end
                        end
                    end
                    local heal = 0
                    if CFG.AuraLifesteal then heal = 1000000 end
                    -- Поджог: не чаще 1.5 с на игрока — серверный
                    -- IgniteScript плодит инстансы на каждое true.
                    local burnNow = false
                    if CFG.AuraBurn ~= false then
                        local bt = PE_BURN_AT[p]
                        if not bt or now - bt > 1.5 then
                            PE_BURN_AT[p] = now
                            burnNow = true
                        end
                    end
                    -- Бьём в голову (как настоящий хедшот); не-BasePart
                    -- по имени Head пропускаем.
                    local aimPart = root
                    local headP = ch:FindFirstChild("Head")
                    if headP and headP:IsA("BasePart") then
                        aimPart = headP
                    end
                    pcall(function()
                        remote:FireServer(hum, aimPart, dmg, dir, knock, heal,
                            burnNow)
                    end)
                end
            end
        end
    end
end

auraConn = RunService.Heartbeat:Connect(function()
    if STOPPED then return end
    local okA, errA = pcall(auraTick)
    if not okA and os.clock() - (CFG._auraErrAt or 0) > 5 then
        CFG._auraErrAt = os.clock()
        warn("[PE] aura loop: " .. tostring(errA))
    end
end)

-- ПОЛЁТ удалён (v2.74) по запросу.

-- БЕСКОНЕЧНЫЙ ПРЫЖОК удалён (v2.75) по запросу.

-- СПИН-БОТ удалён (v2.37) по запросу: при выключении AutoRotate
-- не возвращался и персонаж переставал поворачиваться.


-- ============================================================
--  PE UI v1.0 — СОБСТВЕННЫЙ GUI (Rayfield больше не используется)
--  Вкладки СВЕРХУ, фиолетово-чёрная мягкая тема, шрифт Nunito,
--  плавные твины на всём. Ноль внешних загрузок: библиотека живёт
--  прямо здесь, окно сразу в PlayerGui (клики работают всегда).
-- ============================================================
PeUI = {
    Flags = {},
    _conns = {},
    Translator = nil,
    _destroyed = false,
}

do
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")

    local THEME = {
        Bg           = Color3.fromRGB(17, 11, 28),
        Topbar       = Color3.fromRGB(25, 17, 41),
        TabRow       = Color3.fromRGB(21, 14, 34),
        TabIdle      = Color3.fromRGB(158, 132, 224),
        TabActive    = Color3.fromRGB(212, 188, 255),
        Accent       = Color3.fromRGB(167, 120, 255),
        AccentSoft   = Color3.fromRGB(199, 164, 255),
        Element      = Color3.fromRGB(27, 19, 44),
        ElementHover = Color3.fromRGB(36, 26, 58),
        Stroke       = Color3.fromRGB(54, 38, 88),
        StrokeSoft   = Color3.fromRGB(40, 28, 66),
        Text         = Color3.fromRGB(237, 230, 251),
        TextDim      = Color3.fromRGB(170, 158, 200),
        Off          = Color3.fromRGB(74, 58, 106),
        InputBg      = Color3.fromRGB(22, 15, 36),
        Popup        = Color3.fromRGB(24, 16, 40),
    }
    local FONT = Enum.Font.Nunito
    local TT = 0.18

    local function tr(s)
        if type(s) == "string" and PeUI.Translator then
            return PeUI.Translator(s)
        end
        return s
    end

    local function tween(inst, props, t)
        local tw = TweenService:Create(inst,
            TweenInfo.new(t or TT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            props)
        tw:Play()
        return tw
    end

    local function mk(class, props, parent)
        local inst = Instance.new(class)
        if props then
            for k, v in pairs(props) do inst[k] = v end
        end
        if parent then inst.Parent = parent end
        return inst
    end

    local function corner(r, parent)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r)
        c.Parent = parent
        return c
    end

    local function stroke(col, th, parent)
        local s = Instance.new("UIStroke")
        s.Color = col
        s.Thickness = th or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end

    local function pad(p, t, b, l, r)
        local pa = Instance.new("UIPadding")
        pa.PaddingTop = UDim.new(0, t or 0)
        pa.PaddingBottom = UDim.new(0, b or 0)
        pa.PaddingLeft = UDim.new(0, l or 0)
        pa.PaddingRight = UDim.new(0, r or 0)
        pa.Parent = p
        return pa
    end

    local function keep(c)
        -- Компакция: мёртвые (отвалившиеся инстансы) коннекты выкидываем,
        -- иначе таблица растёт монотонно всю сессию.
        if #PeUI._conns > 400 then
            local alive = {}
            for _, old in ipairs(PeUI._conns) do
                if old.Connected then alive[#alive + 1] = old end
            end
            PeUI._conns = alive
        end
        PeUI._conns[#PeUI._conns + 1] = c
        return c
    end

    local function safeCall(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[PE UI] callback: " .. tostring(err))
        end
    end

    -- ---------- конфиг: writefile-персистентность флагов ----------
    local cfgEnabled = false
    local cfgPath = "PrisonESP/peui_config.json"
    local cfgLoaded = false
    local cfgQueued = false

    local function dumpConfig()
        if not cfgEnabled or not cfgLoaded then return end
        local data = {}
        for flag, el in pairs(PeUI.Flags) do
            if el.Type == "Dropdown" then
                data[flag] = el.CurrentOption[1]
            else
                data[flag] = el.CurrentValue
            end
        end
        pcall(function()
            writefile(cfgPath, HttpService:JSONEncode(data))
        end)
    end

    local function queueSave()
        if not cfgEnabled or not cfgLoaded or cfgQueued then return end
        cfgQueued = true
        task.delay(0.5, function()
            cfgQueued = false
            dumpConfig()
        end)
    end

    -- ---------- уведомления: свой тост-стек справа сверху ----------
    local notifyGui, notifyHolder

    local function ensureNotifyGui()
        if notifyGui and notifyGui.Parent then return end
        notifyGui = Instance.new("ScreenGui")
        notifyGui.Name = "PE_UI_Notify"
        notifyGui.ResetOnSpawn = false
        notifyGui.IgnoreGuiInset = true
        notifyGui.DisplayOrder = 100001
        local okN = pcall(function() notifyGui.Parent = CoreGui end)
        if not okN or not notifyGui.Parent then
            pcall(function()
                notifyGui.Parent = LP:FindFirstChildOfClass("PlayerGui")
                    or LP:WaitForChild("PlayerGui", 3)
            end)
        end
        notifyHolder = mk("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 0, 14),
            Size = UDim2.new(0, 290, 1, -28),
            BackgroundTransparency = 1,
        }, notifyGui)
        mk("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Top,
        }, notifyHolder)
    end

    function PeUI:Notify(data)
        if PeUI._destroyed then return end
        ensureNotifyGui()
        if not notifyGui or not notifyGui.Parent then return end
        data = data or {}
        local card = mk("Frame", {
            BackgroundColor3 = THEME.Popup,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        }, notifyHolder)
        corner(10, card)
        stroke(THEME.StrokeSoft, 1, card)
        pad(card, 10, 10, 12, 12)
        mk("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, card)
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Font = FONT,
            TextSize = 15,
            TextColor3 = THEME.AccentSoft,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tr(tostring(data.Title or "Notify")),
            LayoutOrder = 1,
        }, card)
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Font = FONT,
            TextSize = 13,
            TextColor3 = THEME.TextDim,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tr(tostring(data.Content or "")),
            LayoutOrder = 2,
        }, card)
        tween(card, { BackgroundTransparency = 0 }, 0.22)
        task.delay(math.clamp(tonumber(data.Duration) or 5, 1, 30), function()
            if card.Parent then
                tween(card, { BackgroundTransparency = 1 }, 0.3)
                task.wait(0.32)
                pcall(function() card:Destroy() end)
            end
        end)
    end

    -- ---------- окно ----------
    function PeUI:CreateWindow(opts)
        if PeUI._destroyed then return nil end
        opts = opts or {}
        local cs = opts.ConfigSaving
        if cs and cs.Enabled and type(writefile) == "function"
           and type(makefolder) == "function" then
            cfgEnabled = true
            cfgPath = tostring(cs.FolderName or "PrisonESP")
                .. "/" .. tostring(cs.FileName or "config") .. "_peui.json"
            pcall(function()
                makefolder(tostring(cs.FolderName or "PrisonESP"))
            end)
        end

        local sg = Instance.new("ScreenGui")
        sg.Name = "PE_UI"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.DisplayOrder = 100000
        pcall(function()
            sg.Parent = LP:FindFirstChildOfClass("PlayerGui")
                or LP:WaitForChild("PlayerGui", 3)
        end)
        if not sg.Parent then
            pcall(function() sg.Parent = CoreGui end)
        end
        PeUI._sg = sg

        local root = mk("Frame", {
            Name = "Root",
            Size = UDim2.new(0, 620, 0, 440),
            Position = UDim2.new(0.5, -310, 0.5, -220),
            BackgroundColor3 = THEME.Bg,
            BorderSizePixel = 0,
            Active = true,
            ClipsDescendants = true,
        }, sg)
        corner(12, root)
        stroke(THEME.Stroke, 1, root)

        -- BACKGROUND PHOTO: uploaded to Roblox as a decal
        -- (ID 93512518437052, account kitichek4ek). The decal loads
        -- WITHOUT getcustomasset - the owner always sees own decal.
        -- getgenv().PE_BG_ID overrides when set. The whole
        -- getcustomasset pipeline removed: Real returned empty assets.
        do
            local bgLog = function(step)
                print("[PE UI] bg: " .. step)
            end
            local bgSrc = nil
            -- v2.95: ФОТО С GITHUB через request/http_request (сырой
            -- Body) - проверено живым тестом, PNG рендерится.
            -- Порядок: PNG (выбор пользователя) -> JPG (запасной).
            if type(request) == "function"
               or type(http_request) == "function" then
                pcall(function()
                    local variants = {
                        { file = "pe_bg_img.png",
                          url = "https://raw.githubusercontent.com/"
                              .. "blegbot1/PrisonESP/main/pe_bg.png" },
                        { file = "pe_bg_img.jpg",
                          url = "https://raw.githubusercontent.com/"
                              .. "blegbot1/PrisonESP/main/pe_bg.jpg" },
                    }
                    for _, v in ipairs(variants) do
                        local have = false
                        if type(isfile) == "function" then
                            local okI, exists = pcall(function()
                                return isfile(v.file)
                            end)
                            have = okI and exists
                        end
                        if not have then
                            local okD, data = pcall(function()
                                if type(http_request) == "function" then
                                    return http_request({
                                        Url = v.url, Method = "GET" })
                                end
                                return request({
                                    Url = v.url, Method = "GET" })
                            end)
                            if okD and data and data.Body
                               and #data.Body > 500 then
                                pcall(function()
                                    writefile(v.file, data.Body)
                                end)
                                bgLog("downloaded " .. v.file
                                    .. " " .. #data.Body .. " bytes")
                            end
                        end
                        local okI2, exists2 = pcall(function()
                            return isfile(v.file)
                        end)
                        if okI2 and exists2 then
                            local okA, asset = pcall(function()
                                return getcustomasset(v.file)
                            end)
                            if okA and type(asset) == "string" then
                                bgSrc = asset
                                bgLog("PHOTO OK: " .. v.file)
                                break
                            end
                        end
                        if bgSrc then break end
                    end
                end)
            end
            -- Фолбэк: твой декал на Roblox (загружен, ID 93512518437052).
            if not bgSrc then
                bgSrc = "rbxassetid://93512518437052"
                bgLog("falling back to user decal 93512518437052")
            end
            local manual = getgenv().PE_BG_ID
            if type(manual) == "number" and manual > 0 then
                bgSrc = "rbxassetid://" .. manual
                bgLog("PE_BG_ID override: " .. manual)
            elseif type(manual) == "string" and manual ~= "" then
                bgSrc = manual
                bgLog("PE_BG_ID override")
            end

            if bgSrc then
                -- ДВОЙНОЙ ФОН: фиолетовая база остаётся, фото ложится
                -- ВТОРЫМ СЛОЕМ — портретная панель справа на светлой
                -- подложке (фото — тёмный силуэт на прозрачном фоне,
                -- без светлой подложки он невидим на тёмном окне).
                -- v2.96: ТОЧНАЯ копия рабочего паттерна из pe_bgtest:
                -- Image пустой при создании, ассет присваивается ПОСЛЕ
                -- парентинга; ZIndex обычные (0 ломал отрисовку);
                -- EditableImage-попытка УДАЛЕНА — она перезаписывала
                -- рабочий Image пустым Content'ом.
                local bgImage = mk("ImageLabel", {
                    Name = "BgPhoto",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    Size = UDim2.new(
                        math.clamp(tonumber(CFG.BgWidth) or 1.05, 0.1, 4),
                        0,
                        math.clamp(tonumber(CFG.BgHeight) or 0.7, 0.1, 4),
                        0),
                    BackgroundTransparency = 1,
                    Image = "",
                    ImageTransparency = 0,
                    -- Stretch: ширина и высота настраиваются НЕЗАВИСИМО
                    -- слайдерами в Settings (v3.03).
                    ScaleType = Enum.ScaleType.Stretch,
                    BorderSizePixel = 0,
                }, root)
                PeUI._bgImage = bgImage
                -- Ассет присваиваем ПОСЛЕ парентинга (как в тесте, где
                -- фото рендерилось), с задержкой на строкновение GUI.
                task.delay(0.2, function()
                    pcall(function() bgImage.Image = bgSrc end)
                    print("[PE UI] bg: image assigned, len "
                        .. #tostring(bgSrc))
                end)
                -- Инфо-лог раз в 3с (rect 0,0 у Real — НОРМА для
                -- getcustomasset: в тесте фото рендерилось и с 0,0).
                task.delay(4, function()
                    pcall(function()
                        print("[PE UI] bg: image loaded = "
                            .. tostring(bgImage.IsLoaded)
                            .. " (rect " .. tostring(bgImage.ImageRectSize)
                            .. ", 0,0 on Real is normal)")
                    end)
                end)
            else
                print("[PE UI] bg: photo OFF (no source)")
            end
        end

        -- Топбар: заголовок + свернуть, им же таскаем окно.
        local top = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = THEME.Topbar,
            BorderSizePixel = 0,
            Active = true,
        }, root)
        corner(12, top)
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 0),
            Size = UDim2.new(1, -110, 1, 0),
            Font = FONT,
            TextSize = 16,
            TextColor3 = THEME.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tr(tostring(opts.Name or "PE UI")),
        }, top)

        local minBtn = mk("TextButton", {
            AutoButtonColor = false,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 26, 0, 26),
            BackgroundColor3 = THEME.Element,
            Font = FONT,
            TextSize = 15,
            TextColor3 = THEME.TextDim,
            Text = "-",
            BorderSizePixel = 0,
        }, top)
        corner(8, minBtn)

        local expanded = true
        keep(minBtn.MouseButton1Click:Connect(function()
            expanded = not expanded
            minBtn.Text = expanded and "-" or "+"
            tween(root, { Size = expanded
                and UDim2.new(0, 620, 0, 440)
                or UDim2.new(0, 620, 0, 38) }, 0.25)
        end))

        -- Перетаскивание за топбар.
        local dragging = false
        local dragStart, startPos
        keep(top.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
               or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = inp.Position
                startPos = root.Position
            end
        end))
        keep(UIS.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                or inp.UserInputType == Enum.UserInputType.Touch) then
                local d = inp.Position - dragStart
                root.Position = UDim2.new(startPos.X.Scale,
                    startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end))
        keep(UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
               or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))

        -- K — показать/спрятать окно.
        keep(UIS.InputBegan:Connect(function(inp, gp)
            if gp then return end
            if inp.KeyCode == Enum.KeyCode.K then
                root.Visible = not root.Visible
            end
        end))

        -- ВКЛАДКИ СВЕРХУ: горизонтальный ряд кнопок под топбаром.
        local tabRow = mk("Frame", {
            Position = UDim2.new(0, 0, 0, 38),
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundColor3 = THEME.TabRow,
            BorderSizePixel = 0,
        }, root)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, tabRow)
        pad(tabRow, 0, 0, 10, 10)

        local content = mk("Frame", {
            Position = UDim2.new(0, 0, 0, 80),
            Size = UDim2.new(1, 0, 1, -80),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = true,
        }, root)

        local pages = {}
        local activePopup = nil

        local function closePopup()
            if activePopup then
                local p = activePopup
                activePopup = nil
                tween(p, { BackgroundTransparency = 1 }, 0.12)
                task.delay(0.13, function()
                    -- Гард: попап могли ПЕРЕОТКРЫТЬ (клик по строке)
                    -- — тогда отложенный destroy убивал живой список
                    -- и дропдаун ломался навсегда.
                    if activePopup ~= p then
                        pcall(function() p:Destroy() end)
                    end
                end)
            end
        end

        local function inBounds(inst, x, y)
            local p, s = inst.AbsolutePosition, inst.AbsoluteSize
            return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
        end

        local selectTab
        selectTab = function(p)
            closePopup()
            for _, q in ipairs(pages) do
                local on = (q == p)
                q.frame.Visible = on
                tween(q.btn, { BackgroundColor3 = on and THEME.Element
                    or THEME.TabRow }, 0.15)
                tween(q.btn, { TextColor3 = on and THEME.TabActive
                    or THEME.TabIdle }, 0.15)
                tween(q.bar, { BackgroundTransparency = on and 0 or 1 }, 0.15)
            end
        end

        local win = { Tabs = {} }

        function win:Tab(name)
            local pageFrame = mk("ScrollingFrame", {
                Visible = false,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 6, 0, 6),
                Size = UDim2.new(1, -12, 1, -12),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = THEME.Accent,
            }, content)
            mk("UIListLayout", {
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, pageFrame)
            pad(pageFrame, 2, 6, 2, 6)

            local btn = mk("TextButton", {
                AutoButtonColor = false,
                BackgroundColor3 = THEME.TabRow,
                Size = UDim2.new(0, 0, 0, 28),
                AutomaticSize = Enum.AutomaticSize.X,
                Font = FONT,
                TextSize = 14,
                TextColor3 = THEME.TabIdle,
                Text = tr(tostring(name)),
                BorderSizePixel = 0,
            }, tabRow)
            corner(8, btn)
            pad(btn, 0, 0, 12, 12)
            local bar = mk("Frame", {
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -3),
                Size = UDim2.new(1, -16, 0, 2),
                BackgroundColor3 = THEME.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
            }, btn)
            corner(1, bar)

            local page = { frame = pageFrame, btn = btn, bar = bar }
            pages[#pages + 1] = page
            if #pages == 1 then
                page.frame.Visible = true
                btn.BackgroundColor3 = THEME.Element
                btn.TextColor3 = THEME.TabActive
                bar.BackgroundTransparency = 0
            end
            keep(btn.MouseButton1Click:Connect(function()
                selectTab(page)
            end))

            local tabObj = {}
            local order = 0
            local function ord()
                order = order + 1
                return order
            end

            local function newRow(h)
                local r = mk("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = THEME.Element,
                    Size = UDim2.new(1, 0, 0, h),
                    Text = "",
                    BorderSizePixel = 0,
                    LayoutOrder = ord(),
                }, pageFrame)
                corner(9, r)
                stroke(THEME.StrokeSoft, 1, r)
                keep(r.MouseEnter:Connect(function()
                    tween(r, { BackgroundColor3 = THEME.ElementHover }, 0.12)
                end))
                keep(r.MouseLeave:Connect(function()
                    tween(r, { BackgroundColor3 = THEME.Element }, 0.12)
                end))
                return r
            end

            local function nameLabel(parent, w)
                return mk("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, 0),
                    Size = UDim2.new(w or 1, -(w and (w * 24) or 24), 1, 0),
                    Font = FONT,
                    TextSize = 14,
                    TextColor3 = THEME.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                }, parent)
            end

            function tabObj:CreateSection(name)
                local holder = mk("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 26),
                    LayoutOrder = ord(),
                }, pageFrame)
                mk("Frame", {
                    BackgroundColor3 = THEME.Accent,
                    BackgroundTransparency = 0.35,
                    Position = UDim2.new(0, 2, 0.5, -8),
                    Size = UDim2.new(0, 3, 0, 16),
                    BorderSizePixel = 0,
                }, holder)
                mk("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 14, 0, 0),
                    Size = UDim2.new(1, -20, 1, 0),
                    Font = FONT,
                    TextSize = 14,
                    TextColor3 = THEME.AccentSoft,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = tr(tostring(name)),
                }, holder)
                return nil
            end

            function tabObj:CreateParagraph(data)
                data = data or {}
                local card = mk("Frame", {
                    BackgroundColor3 = THEME.Element,
                    BackgroundTransparency = 0.4,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BorderSizePixel = 0,
                    LayoutOrder = ord(),
                }, pageFrame)
                corner(9, card)
                stroke(THEME.StrokeSoft, 1, card)
                pad(card, 8, 8, 12, 12)
                mk("UIListLayout", {
                    Padding = UDim.new(0, 3),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, card)
                mk("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Font = FONT,
                    TextSize = 14,
                    TextColor3 = THEME.AccentSoft,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = tr(tostring(data.Title or "")),
                    LayoutOrder = 1,
                }, card)
                mk("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = THEME.TextDim,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = tr(tostring(data.Content or "")),
                    LayoutOrder = 2,
                }, card)
                return nil
            end

            function tabObj:CreateToggle(data)
                data = data or {}
                local r = newRow(34)
                nameLabel(r, 0.6).Text = tr(tostring(data.Name or ""))
                local pill = mk("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.new(0, 38, 0, 20),
                    BackgroundColor3 = data.CurrentValue and THEME.Accent
                        or THEME.Off,
                    BorderSizePixel = 0,
                }, r)
                corner(10, pill)
                local knob = mk("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = data.CurrentValue
                        and UDim2.new(1, -18, 0.5, 0)
                        or UDim2.new(0, 2, 0.5, 0),
                    Size = UDim2.new(0, 14, 0, 14),
                    BackgroundColor3 = THEME.Text,
                    BorderSizePixel = 0,
                }, pill)
                corner(7, knob)

                local el = {
                    Type = "Toggle",
                    CurrentValue = data.CurrentValue and true or false,
                }
                el.Apply = function(v)
                    el.CurrentValue = v and true or false
                    tween(pill, { BackgroundColor3 = el.CurrentValue
                        and THEME.Accent or THEME.Off }, 0.15)
                    tween(knob, { Position = el.CurrentValue
                        and UDim2.new(1, -18, 0.5, 0)
                        or UDim2.new(0, 2, 0.5, 0) }, 0.18)
                    safeCall(data.Callback, el.CurrentValue)
                end
                if data.Flag then PeUI.Flags[data.Flag] = el end
                keep(r.MouseButton1Click:Connect(function()
                    el.Apply(not el.CurrentValue)
                    queueSave()
                end))
                return el
            end

            function tabObj:CreateSlider(data)
                data = data or {}
                local r = newRow(50)
                local lo = tonumber(data.Range and data.Range[1]) or 0
                local hi = tonumber(data.Range and data.Range[2]) or 100
                if hi <= lo then hi = lo + 1 end
                local inc = tonumber(data.Increment) or 1
                if inc <= 0 then inc = 1 end
                local suffix = data.Suffix and (" " .. tostring(data.Suffix)) or ""
                local function fmt(v)
                    return tostring(math.floor(v * 100 + 0.5) / 100) .. suffix
                end
                local nl = mk("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, 4),
                    Size = UDim2.new(1, -120, 0, 18),
                    Font = FONT,
                    TextSize = 14,
                    TextColor3 = THEME.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = tr(tostring(data.Name or "")),
                }, r)
                local val = mk("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, -10, 0, 4),
                    Size = UDim2.new(0, 100, 0, 18),
                    BackgroundTransparency = 1,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = THEME.AccentSoft,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Text = fmt(tonumber(data.CurrentValue) or lo),
                }, r)
                local track = mk("Frame", {
                    Position = UDim2.new(0, 12, 0, 30),
                    Size = UDim2.new(1, -24, 0, 6),
                    BackgroundColor3 = THEME.InputBg,
                    BorderSizePixel = 0,
                }, r)
                corner(3, track)
                local fill = mk("Frame", {
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = THEME.Accent,
                    BorderSizePixel = 0,
                }, track)
                corner(3, fill)
                local knobC = mk("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.new(0, 12, 0, 12),
                    BackgroundColor3 = THEME.Text,
                    BorderSizePixel = 0,
                    ZIndex = 2,
                }, track)
                corner(6, knobC)

                local el = {
                    Type = "Slider",
                    CurrentValue = math.clamp(
                        tonumber(data.CurrentValue) or lo, lo, hi),
                }
                local function paint()
                    val.Text = fmt(el.CurrentValue)
                    local f = (el.CurrentValue - lo) / (hi - lo)
                    fill.Size = UDim2.new(f, 0, 1, 0)
                    knobC.Position = UDim2.new(f, 0, 0.5, 0)
                end
                el.Apply = function(v)
                    v = math.clamp(tonumber(v) or lo, lo, hi)
                    v = math.floor(v / inc + 0.5) * inc
                    el.CurrentValue = v
                    paint()
                    safeCall(data.Callback, v)
                end
                if data.Flag then PeUI.Flags[data.Flag] = el end
                local function setFromX(x)
                    local a = track.AbsolutePosition.X + 6
                    local b = track.AbsolutePosition.X
                        + track.AbsoluteSize.X - 6
                    if b <= a then return end
                    local a01 = math.clamp((x - a) / (b - a), 0, 1)
                    local v = math.floor(
                        (lo + a01 * (hi - lo)) / inc + 0.5) * inc
                    v = math.clamp(v, lo, hi)
                    if v ~= el.CurrentValue then
                        el.CurrentValue = v
                        paint()
                        safeCall(data.Callback, v)
                    end
                end
                do
                    local f = (el.CurrentValue - lo) / (hi - lo)
                    fill.Size = UDim2.new(f, 0, 1, 0)
                    knobC.Position = UDim2.new(f, 0, 0.5, 0)
                end
                local dragS = false
                keep(track.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                       or inp.UserInputType == Enum.UserInputType.Touch then
                        dragS = true
                        setFromX(inp.Position.X)
                    end
                end))
                keep(UIS.InputChanged:Connect(function(inp)
                    if dragS and (inp.UserInputType == Enum.UserInputType.MouseMovement
                        or inp.UserInputType == Enum.UserInputType.Touch) then
                        setFromX(inp.Position.X)
                    end
                end))
                keep(UIS.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                       or inp.UserInputType == Enum.UserInputType.Touch then
                        if dragS then
                            dragS = false
                            queueSave()
                        end
                    end
                end))
                return el
            end

            function tabObj:CreateDropdown(data)
                data = data or {}
                local r = newRow(34)
                nameLabel(r, 0.55).Text = tr(tostring(data.Name or ""))
                local sel = mk("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -26, 0.5, 0),
                    Size = UDim2.new(0, 190, 1, 0),
                    BackgroundTransparency = 1,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = THEME.AccentSoft,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = "-",
                }, r)
                mk("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    Size = UDim2.new(0, 16, 1, 0),
                    BackgroundTransparency = 1,
                    Font = FONT,
                    TextSize = 12,
                    TextColor3 = THEME.TextDim,
                    Text = "v",
                }, r)

                local el = { Type = "Dropdown", CurrentOption = {}, Options = {} }
                local optBtns = {}

                local function refreshSelected()
                    if #el.CurrentOption == 0 then
                        sel.Text = "-"
                    elseif #el.CurrentOption == 1 then
                        sel.Text = tostring(el.CurrentOption[1])
                    else
                        sel.Text = "Various"
                    end
                    for o, b in pairs(optBtns) do
                        local on = table.find(el.CurrentOption, o) ~= nil
                        b.BackgroundColor3 = on and THEME.Accent
                            or THEME.Element
                        b.TextColor3 = on and THEME.Text or THEME.TextDim
                    end
                end

                local popup = mk("ScrollingFrame", {
                    Visible = false,
                    BackgroundColor3 = THEME.Popup,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0, 250, 0, 0),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollingDirection = Enum.ScrollingDirection.Y,
                    ScrollBarThickness = 3,
                    ScrollBarImageColor3 = THEME.Accent,
                    ZIndex = 60,
                }, root)
                corner(9, popup)
                stroke(THEME.Stroke, 1, popup)
                mk("UIListLayout", {
                    Padding = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, popup)
                pad(popup, 5, 5, 5, 5)

                local function rebuild(opts)
                    -- Список не изменился — не пересобираем: иначе 5-секундный
                    -- рефрешер мерцает открытым попапом, рвёт клики и копит
                    -- мёртвые коннекты в _conns.
                    local newOpts = opts or {}
                    if #newOpts == #el.Options then
                        local same = true
                        for i, o in ipairs(newOpts) do
                            if el.Options[i] ~= o then same = false break end
                        end
                        if same then
                            refreshSelected()
                            return
                        end
                    end
                    el.Options = newOpts
                    el.CurrentOption = {}
                    for _, o in ipairs(data.CurrentOption or {}) do
                        if table.find(el.Options, o) then
                            el.CurrentOption[#el.CurrentOption + 1] = o
                        end
                    end
                    if not data.MultipleOptions then
                        el.CurrentOption = { el.CurrentOption[1] }
                        if el.CurrentOption[1] == nil then
                            el.CurrentOption = {}
                        end
                    end
                    for _, b in ipairs(optBtns) do
                        pcall(function() b:Destroy() end)
                    end
                    optBtns = {}
                    for _, o in ipairs(el.Options) do
                        local ob = mk("TextButton", {
                            AutoButtonColor = false,
                            BackgroundColor3 = THEME.Element,
                            Size = UDim2.new(1, 0, 0, 26),
                            Font = FONT,
                            TextSize = 13,
                            TextColor3 = THEME.TextDim,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = tostring(o),
                            BorderSizePixel = 0,
                            ZIndex = 61,
                        }, popup)
                        corner(7, ob)
                        pad(ob, 0, 0, 8, 8)
                        optBtns[o] = ob
                        keep(ob.MouseButton1Click:Connect(function()
                            if data.MultipleOptions then
                                local i = table.find(el.CurrentOption, o)
                                if i then
                                    table.remove(el.CurrentOption, i)
                                else
                                    el.CurrentOption[#el.CurrentOption + 1] = o
                                end
                            else
                                el.CurrentOption = { o }
                                closePopup()
                            end
                            refreshSelected()
                            safeCall(data.Callback, el.CurrentOption)
                            queueSave()
                        end))
                    end
                    popup.Size = UDim2.new(0, 250, 0,
                        math.min(#el.Options * 30 + 10, 170))
                    refreshSelected()
                end

                el.Apply = function(v)
                    if type(v) == "table" then
                        el.CurrentOption = v
                    else
                        el.CurrentOption = { v }
                    end
                    if not data.MultipleOptions then
                        el.CurrentOption = { el.CurrentOption[1] }
                        if el.CurrentOption[1] == nil then
                            el.CurrentOption = {}
                        end
                    end
                    refreshSelected()
                    safeCall(data.Callback, el.CurrentOption)
                end
                -- Обновление списка игроков раз в 5с: выбор сохраняем,
                -- если опция ещё существует (как чиненный Rayfield).
                function el:Refresh(opts)
                    data.CurrentOption = el.CurrentOption
                    rebuild(opts or {})
                end
                if data.Flag then PeUI.Flags[data.Flag] = el end
                rebuild(data.Options or {})

                keep(r.MouseButton1Click:Connect(function()
                    if activePopup == popup then
                        closePopup()
                        return
                    end
                    closePopup()
                    -- Открытие вверх, если попап не влезает вниз
                    -- (root.ClipsDescendants резал нижние строки).
                    local openDown = r.AbsolutePosition.Y
                        - root.AbsolutePosition.Y + r.AbsoluteSize.Y + 174
                        <= root.AbsoluteSize.Y
                    local py
                    if openDown then
                        py = r.AbsolutePosition.Y - root.AbsolutePosition.Y
                            + r.AbsoluteSize.Y + 4
                    else
                        py = r.AbsolutePosition.Y - root.AbsolutePosition.Y
                            - popup.AbsoluteSize.Y - 4
                    end
                    popup.Position = UDim2.new(0,
                        r.AbsolutePosition.X - root.AbsolutePosition.X
                            + r.AbsoluteSize.X - 254,
                        0, py)
                    popup.Visible = true
                    popup.BackgroundTransparency = 1
                    tween(popup, { BackgroundTransparency = 0 }, 0.12)
                    activePopup = popup
                end))
                -- Клик мимо попапа и мимо строки — закрыть.
                keep(UIS.InputBegan:Connect(function(inp)
                    if activePopup == popup
                       and inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        local m = UIS:GetMouseLocation()
                        if not inBounds(popup, m.X, m.Y)
                           and not inBounds(r, m.X, m.Y) then
                            closePopup()
                        end
                    end
                end))
                return el
            end

            function tabObj:CreateButton(data)
                data = data or {}
                local r = newRow(32)
                r.Font = FONT
                r.TextSize = 14
                r.TextColor3 = THEME.Text
                r.Text = tr(tostring(data.Name or ""))
                keep(r.MouseButton1Click:Connect(function()
                    tween(r, { BackgroundColor3 = THEME.Accent }, 0.1)
                    task.delay(0.12, function()
                        if r.Parent then
                            tween(r, { BackgroundColor3 = THEME.Element }, 0.2)
                        end
                    end)
                    safeCall(data.Callback)
                end))
                return nil
            end

            function tabObj:CreateInput(data)
                data = data or {}
                local r = newRow(34)
                local nl = mk("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 12, 0, 0),
                    Size = UDim2.new(0.45, -12, 1, 0),
                    Font = FONT,
                    TextSize = 14,
                    TextColor3 = THEME.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = tr(tostring(data.Name or "")),
                }, r)
                local box = mk("TextBox", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.new(0, 240, 0, 24),
                    BackgroundColor3 = THEME.InputBg,
                    Font = FONT,
                    TextSize = 13,
                    TextColor3 = THEME.Text,
                    PlaceholderColor3 = THEME.TextDim,
                    PlaceholderText = tr(tostring(data.PlaceholderText or "")),
                    Text = tostring(data.CurrentValue or ""),
                    ClearTextOnFocus = false,
                    BorderSizePixel = 0,
                }, r)
                corner(7, box)
                pad(box, 0, 0, 8, 8)
                local el = {
                    Type = "Input",
                    CurrentValue = tostring(data.CurrentValue or ""),
                }
                el.Apply = function(v)
                    el.CurrentValue = tostring(v or "")
                    box.Text = el.CurrentValue
                    safeCall(data.Callback, el.CurrentValue)
                end
                if data.Flag then PeUI.Flags[data.Flag] = el end
                keep(box.FocusLost:Connect(function(enter)
                    el.CurrentValue = box.Text
                    safeCall(data.Callback, box.Text)
                    -- Сохраняем и по Enter, и по потере фокуса: иначе
                -- последняя правка пропадала при выгрузке.
                queueSave()
                end))
                return el
            end

            return tabObj
        end

        function win:Destroy()
            PeUI:Destroy()
        end

        -- Восстановление флагов из файла НЕ здесь: вкладки строятся
        -- ПОСЛЕ CreateWindow, флагов ещё нет. ПеUI._loadConfig зовёт
        -- PrisonESP после полной сборки меню.
        PeUI._loadConfig = function()
            if not cfgEnabled then return end
            pcall(function()
                if isfile and isfile(cfgPath) then
                    local data = HttpService:JSONDecode(readfile(cfgPath))
                    if type(data) == "table" then
                        for flag, v in pairs(data) do
                            local el = PeUI.Flags[flag]
                            if el and el.Apply then el.Apply(v) end
                        end
                    end
                end
            end)
            cfgLoaded = true
        end

        return win
    end

    function PeUI:Destroy()
        if PeUI._destroyed then return end
        PeUI._destroyed = true
        for _, c in ipairs(PeUI._conns) do
            pcall(function() c:Disconnect() end)
        end
        PeUI._conns = {}
        if PeUI._sg then
            pcall(function() PeUI._sg:Destroy() end)
            PeUI._sg = nil
        end
        if notifyGui then
            pcall(function() notifyGui:Destroy() end)
            notifyGui = nil
        end
    end
end

-- Дропдауны выбора цели регистрируются здесь при сборке меню,
-- поэтому переменная объявлена ДО GUI-блока (v2.5 падала: #nil).
local targetPickers = {}
-- Списки выбора целей: игроки + «Everyone», обновляются раз в 5с.
local teamPickers = {}
local function teamOpts()
    local o = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then o[#o + 1] = p.Name end
    end
    table.sort(o)
    table.insert(o, 1, "Everyone")
    if #o == 1 then o[1] = "Everyone" end
    return o
end
local guiOK = false
local okGUI, errGUI = pcall(function()
    local W = PeUI:CreateWindow({
        Name = "PRISON ESP",
        -- Сохранение настроек: свой формат peui_config.json (те же
        -- флаги, свой JSON). Дефолты живут в getgenv().
        ConfigSaving = {
            Enabled = type(writefile) == "function"
                and type(makefolder) == "function",
            FolderName = "PrisonESP",
            FileName = "config",
        },
    })

    -- ЯЗЫК МЕНЮ: getgenv().PE_LANG = "en" | "ru" (переживает
    -- перезапуск скрипта). Применяется при загрузке.
    local PE_LANG = "en"
    pcall(function()
        if getgenv().PE_LANG == "ru" then PE_LANG = "ru" end
    end)
    local PE_RU = {
        ["Kill aura (InflictTarget)"] = "Килл-аура (InflictTarget)",
        ["Gun upgrade"] = "Прокачка пушки",
        ["C00LKIDD MODE (2014)"] = "РЕЖИМ C00LKIDD (2014)",
        ["Team & status"] = "Команда и статус",
        ["Movement"] = "Движение",
        ["Anti-AFK (no idle kick)"] = "Анти-АФК (не кикает за бездействие)",
        ["Speed hack (WalkSpeed)"] = "Спидхак (WalkSpeed)",
        ["Speed (studs/s)"] = "Скорость (стадов/с)",
        ["Noclip (walk through walls)"] = "Ноклип (сквозь стены)",
        ["Fly (WASD + Space/Ctrl)"] = "Полёт (WASD + Space/Ctrl)",
        ["Fly speed"] = "Скорость полёта",
        ["TP to crosshair (blink)"] = "ТП по прицелу (блинк)",
        ["Waypoint name"] = "Имя точки",
        ["SAVE waypoint (my position)"] = "СОХРАНИТЬ точку (моя позиция)",
        ["Teleport to waypoint"] = "ТЕЛЕПОРТ к точке",
        ["Jump boost (higher jumps)"] = "Прыжок-буст (выше прыгаешь)",
        ["Jump power"] = "Сила прыжка",
        ["Switch team"] = "Сменить команду",
        ["Weapon giver (click detectors)"] = "Выдача оружия (клик-детекторы)",
        ["Kill aura"] = "Килл-аура", ["Aura radius"] = "Радиус ауры",
        ["Damage per shot"] = "Урон за выстрел", ["Tick delay"] = "Задержка тика",
        ["Max targets per tick"] = "Целей за тик",
        ["Infinite jump (jump in air)"] = "Бесконечный прыжок (в воздухе)",
        ["FPS boost (low graphics)"] = "ФПС-буст (низкая графика)",
        ["C00l fling (throw everyone)"] = "C00l-флинг (швырять всех)",
        ["Who to hit"] = "Кого бить",
        ["Lifesteal (heal self per hit)"] = "Вампиризм (хил за удар)",
        ["Fling targets (mega knockback up)"] = "Подброс жертв (мега-отдача)",
        ["Fling direction"] = "Направление подброса",
        ["Up"] = "Вверх",
        ["Away from me"] = "От себя",
        ["Random"] = "Рандом (пинбол)",
        ["Infinite aura range (whole map)"] = "Бесконечный радиус ауры (вся карта)",
        ["Burn targets (fire DOT)"] = "Поджог целей (огонь по времени)",
        ["Auto-burn attacker (retribution)"] = "Авто-сожжение атакующего",
        ["Immortality (self-heal loop, 0 dmg)"] = "Бессмертие (хил-цикл, 0 урона)",
        ["Upgrade damage"] = "Урон прокачки",
        ["Gun lifesteal (heal per legit shot)"] = "Вампиризм пушки (хил за выстрел)",
        ["Sniper scope on any gun (E key)"] = "Прицел на любой пушке (клавиша E)",
        ["Ammo hack: 1e9 clip via real reload (test)"] = "Хак патронов: 1e9 через перезарядку (тест)",
        ["Headshot multiplier"] = "Множитель хедшота",
        ["Burst bullets per click"] = "Пуль за клик (очередь)",
        ["Shotgun mode (pellets per shot)"] = "Режим дробовика (пуль за выстрел)",
        ["Shotgun pellets"] = "Картечин дробовика",
        ["Explosive bullets (AoE)"] = "Взрывные пули (по площади)",
        ["Explosion radius"] = "Радиус взрыва",
        ["Burning bullets (ignite)"] = "Горящие пули (поджог)",
        ["Knockback (fling victims)"] = "Отдача (подброс жертв)",
        ["Piercing (through bodies)"] = "Прошивание (сквозь тела)",
        ["UPGRADE gun in hands"] = "ПРОКАЧАТЬ пушку в руках",
        ["Auto-upgrade (equip/respawn)"] = "Авто-прокачка (экип/респавн)",
        ["Taser aura (stun everyone near)"] = "Аура тазера (стан всех рядом)",
        ["Taser delay"] = "Задержка тазера",
        ["Who to tase"] = "Кого станить",
        ["TASE selected player (x3)"] = "ТАЗЕР по выбранному (x3)",
        ["Slow burn EVERYONE (server-wide fire)"] = "Сожжение ВСЕХ (огонь на весь сервер)",
        ["Burn damage per tick"] = "Урон горения за тик",
        ["Who burns"] = "Кто горит",
        ["Fire paint (draw with fire at cursor)"] = "Огненная кисть (рисуй огнём курсором)",
        ["APOCALYPSE (auto killer)"] = "АПОКАЛИПСИС (авто-убийца)",
        ["APOCALYPSE (auto killer machine)"] = "АПОКАЛИПСИС (машина-убийца)",
        ["Apocalypse"] = "Апокалипсис",
        ["Apocalypse damage"] = "Урон апокалипсиса",
        ["Team: GUARD"] = "Команда: ОХРАНА",
        ["Team: PRISONER"] = "Команда: ЗАКЛЮЧЁННЫЙ",
        ["Team: ESCAPED (criminal)"] = "Команда: ПОБЕГ (преступник)",
        ["Reset to menu (escape cuffs)"] = "Сброс в меню (снять наручники)",
        ["Fast respawn (instant rejoin)"] = "Быстрый респавн (мгновенный возврат)",
        ["Anti-stun (taser/cuffs/ragdoll)"] = "Анти-стан (тазер/наручники/регдолл)",
        ["Auto-give after death"] = "Авто-выдача после смерти",
        ["Auto-give weapon"] = "Оружие для авто-выдачи",
        ["GIVE ALL (guns + KeyCard)"] = "ВЫДАТЬ ВСЁ (пушки + пропуск)",
        ["Give: "] = "Выдать: ",
        ["Open ALL doors (jail cells)"] = "Открыть ВСЕ двери (камеры)",
        ["Gun source -> console (decompile)"] = "Исходник пушки -> консоль (декомпил)",
        ["Kill aura"] = "Килл-аура",
        ["Upgrade"] = "Прокачка", ["Giver"] = "Гивер",
        ["Zones"] = "Зоны", ["Items"] = "Предметы",
        ["Info"] = "Инфо", ["Version"] = "Версия",
        ["Language"] = "Язык",
        ["RESTART SCRIPT (apply language)"] = "ПЕРЕЗАПУСТИТЬ СКРИПТ (применить язык)",
        ["UNLOAD script (full cleanup)"] = "ВЫГРУЗИТЬ скрипт (полная очистка)",
    }
    local function peTr(s)
        -- Переводим ТОЛЬКО в RU-режиме (PeUI зовёт Translator всегда).
        if PE_LANG == "ru" and PE_RU[s] then return PE_RU[s] end
        return s
    end
    -- Перевод подписей теперь внутри самой PeUI (мягкие колбэки под
    -- pcall тоже там) — прокси-обёртки Rayfield больше не нужны.
    PeUI.Translator = peTr

    local function safeNewTab(Win, name, icon, label)
        return Win:Tab(label or name)
    end

    -- ====================== ВКЛАДКА БОЙ ======================
    local C = safeNewTab(W, "Kill", "swords", "Kill")
    if not C then error("Kill tab failed") end

    C:CreateSection("Kill aura (InflictTarget)")
    C:CreateParagraph({ Title = "Kill aura",
        Content = "Hits exactly like the gun itself: InflictTarget(Humanoid, RootPart, damage, direction, knockback, lifesteal, flame) - signature from the decompiled GunScript_Local. Needs a gun in hands/backpack." })
    C:CreateToggle({ Name = "Kill aura", Flag = "PE_KillAura",
        CurrentValue = CFG.KillAura == true,
        Callback = function(v) CFG.KillAura = v end })
    C:CreateSlider({ Name = "Aura radius", Flag = "PE_KillAuraRadius",
        Range = {10, 120}, Increment = 5,
        CurrentValue = tonumber(CFG.KillAuraRadius) or 40,
        Suffix = " st", Callback = function(v) CFG.KillAuraRadius = v end })
    C:CreateSlider({ Name = "Damage per shot", Flag = "PE_KillAuraDamage",
        Range = {1, 200}, Increment = 5,
        CurrentValue = math.clamp(tonumber(CFG.KillAuraDamage) or 50, 1, 200),
        Callback = function(v) CFG.KillAuraDamage = v end })
    C:CreateSlider({ Name = "Tick delay", Flag = "PE_KillAuraDelay",
        Range = {10, 100}, Increment = 5,
        CurrentValue = math.clamp(
            math.floor((tonumber(CFG.KillAuraDelay) or 0.15) * 100 + 0.5), 10, 100),
        Suffix = " x10ms", Callback = function(v) CFG.KillAuraDelay = v / 100 end })
    C:CreateSlider({ Name = "Max targets per tick", Flag = "PE_AuraMaxHits",
        Range = {1, 20}, Increment = 1,
        CurrentValue = math.clamp(tonumber(CFG.AuraMaxHits) or 6, 1, 20),
        Callback = function(v) CFG.AuraMaxHits = v end })
    local hitDrop = C:CreateDropdown({
        Name = "Who to hit",
        Flag = "PE_KillAuraTeamPick",
        Options = teamOpts(),
        CurrentOption = { CFG.KillAuraTeam },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then
                CFG.KillAuraTeam = picked
                print("[PE] kill aura target: " .. picked)
            end
        end,
    })
    teamPickers[#teamPickers + 1] = hitDrop
    C:CreateToggle({ Name = "Lifesteal (heal self per hit)",
        Flag = "PE_AuraLifesteal",
        CurrentValue = CFG.AuraLifesteal ~= false,
        Callback = function(v) CFG.AuraLifesteal = v end })
    C:CreateToggle({ Name = "Fling targets (mega knockback up)",
        Flag = "PE_AuraFling",
        CurrentValue = CFG.AuraFling == true,
        Callback = function(v) CFG.AuraFling = v end })
    C:CreateDropdown({
        Name = "Fling direction",
        Flag = "PE_FlingDirPick",
        Options = { "Up", "Away from me", "Random" },
        CurrentOption = { CFG.FlingDir },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then CFG.FlingDir = picked end
        end,
    })
    C:CreateToggle({ Name = "Burn targets (fire DOT)",
        Flag = "PE_AuraBurn",
        CurrentValue = CFG.AuraBurn ~= false,
        Callback = function(v) CFG.AuraBurn = v end })
    C:CreateToggle({ Name = "Auto-burn attacker (retribution)",
        Flag = "PE_Retr",
        CurrentValue = CFG.Retr ~= false,
        Callback = function(v) CFG.Retr = v end })
    C:CreateToggle({ Name = "MIRROR mode (reflect the damage dealt to you)",
        Flag = "PE_RetrMirror",
        CurrentValue = CFG.RetrMirror == true,
        Callback = function(v)
            CFG.RetrMirror = v
            print("[PE RET] mirror " .. (v and "ON - he hits 80, gets 80"
                or "OFF - fixed slider damage"))
        end })
    C:CreateSlider({ Name = "Damage back to attacker (0 = same as aura)",
        Flag = "PE_RetrDamage",
        Range = {0, 200}, Increment = 5,
        CurrentValue = CFG.RetrDamage or 0,
        Suffix = " dmg",
        Callback = function(v)
            -- 0 = «следовать урону ауры» (старое поведение).
            CFG.RetrDamage = v > 0 and v or nil
        end })
    C:CreateToggle({ Name = "Immortality (self-heal loop, 0 dmg)",
        Flag = "PE_Immortal",
        CurrentValue = CFG.Immortal == true,
        Callback = function(v)
            CFG.Immortal = v
        end })
    C:CreateToggle({ Name = "Aura team bypass (hit prisoners AND guards)",
        Flag = "PE_AuraTeamBypass",
        CurrentValue = CFG.AuraTeamBypass == true,
        Callback = function(v)
            CFG.AuraTeamBypass = v
            print("[PE] aura team bypass " .. (v and "ON - flipping teams"
                or "OFF"))
        end })

    C = safeNewTab(W, "Weapon", "crosshair", "Weapon")
    if not C then error("Weapon tab failed") end
    C:CreateSection("Gun upgrade")
    C:CreateParagraph({ Title = "Upgrade",
        Content = "Edits the Setting module of the gun in hands (require cache shared with GunScript_Local): damage, auto mode, zero spread, instant reload. Shots look legit but hit upgraded. Resets on weapon change/respawn - press again." })
    C:CreateSlider({ Name = "Upgrade damage", Flag = "PE_ModGunDamage",
        Range = {10, 2000}, Increment = 10,
        CurrentValue = math.clamp(tonumber(CFG.ModGunDamage) or 250, 10, 2000),
        Callback = function(v) CFG.ModGunDamage = v end })
    C:CreateToggle({ Name = "Gun lifesteal (heal per legit shot)",
        Flag = "PE_GunLifesteal",
        CurrentValue = CFG.GunLifesteal ~= false,
        Callback = function(v) CFG.GunLifesteal = v end })
    C:CreateToggle({ Name = "Ammo hack: 1e9 clip via real reload (test)",
        Flag = "PE_GunAmmoHack",
        CurrentValue = CFG.GunAmmoHack == true,
        Callback = function(v) CFG.GunAmmoHack = v end })
    C:CreateSlider({ Name = "Headshot multiplier", Flag = "PE_GunHeadshot",
        Range = {2, 200}, Increment = 1,
        CurrentValue = math.clamp(tonumber(CFG.GunHeadshot) or 200, 2, 200),
        Callback = function(v) CFG.GunHeadshot = v end })
    C:CreateSlider({ Name = "Burst bullets per click", Flag = "PE_GunBurst",
        Range = {1, 15}, Increment = 1,
        CurrentValue = math.clamp(tonumber(CFG.GunBurst) or 10, 1, 15),
        Callback = function(v) CFG.GunBurst = v end })
    C:CreateToggle({ Name = "Shotgun mode (pellets per shot)",
        Flag = "PE_GunShotgun",
        CurrentValue = CFG.GunShotgun ~= false,
        Callback = function(v) CFG.GunShotgun = v end })
    C:CreateSlider({ Name = "Shotgun pellets", Flag = "PE_GunPellets",
        Range = {2, 16}, Increment = 1,
        CurrentValue = math.clamp(tonumber(CFG.GunPellets) or 8, 2, 16),
        Callback = function(v) CFG.GunPellets = v end })
    C:CreateToggle({ Name = "Explosive bullets (AoE)", Flag = "PE_GunExplosive",
        CurrentValue = CFG.GunExplosive ~= false,
        Callback = function(v) CFG.GunExplosive = v end })
    C:CreateSlider({ Name = "Explosion radius", Flag = "PE_GunBoomRadius",
        Range = {5, 60}, Increment = 5,
        CurrentValue = math.clamp(tonumber(CFG.GunBoomRadius) or 25, 5, 60),
        Callback = function(v) CFG.GunBoomRadius = v end })
    C:CreateToggle({ Name = "Burning bullets (ignite)", Flag = "PE_GunFire",
        CurrentValue = CFG.GunFire == true,
        Callback = function(v) CFG.GunFire = v end })
    C:CreateSlider({ Name = "Knockback (fling victims)", Flag = "PE_GunKnockback",
        Range = {0, 20000}, Increment = 500,
        CurrentValue = math.clamp(tonumber(CFG.GunKnockback) or 0, 0, 20000),
        Callback = function(v) CFG.GunKnockback = v end })
    C:CreateSlider({ Name = "Piercing (through bodies)", Flag = "PE_GunPiercing",
        Range = {0, 10}, Increment = 1,
        CurrentValue = math.clamp(tonumber(CFG.GunPiercing) or 5, 0, 10),
        Callback = function(v) CFG.GunPiercing = v end })
    C:CreateButton({ Name = "UPGRADE gun in hands",
        Callback = function() G.PE.ModGun() end })
    C:CreateToggle({ Name = "Auto-upgrade (equip/respawn)",
        Flag = "PE_ModGunAuto",
        CurrentValue = CFG.ModGunAuto ~= false,
        Callback = function(v) CFG.ModGunAuto = v end })

    C = safeNewTab(W, "CHAOS", "flame", "CHAOS")
    if not C then error("CHAOS tab failed") end
    C:CreateSection("Admin theatre")
    C:CreateParagraph({ Title = "Sky strike",
        Content = "Theatrical 'admin strike': you blink into the sky above the target, 3 neon tracers rain down (EVERYONE sees them - server relay), you blink back. No damage, pure legend-building. 6s cooldown, needs any gun in hands." })
    C:CreateButton({ Name = "SKY SHOT at cursor",
        Callback = function() G.PE.SkyShot() end })
    C:CreateButton({ Name = "SKY SHOT at selected player",
        Callback = function() G.PE.SkyShot(CFG.KillAuraTeam) end })
    C:CreateButton({ Name = "SQUAD SHOT at cursor (5 angles)",
        Callback = function() G.PE.SquadShot() end })
    C:CreateButton({ Name = "ORBITAL BEAM at cursor (giant laser)",
        Callback = function() G.PE.OrbitalBeam() end })
    C:CreateButton({ Name = "ORBITAL BEAM at selected player",
        Callback = function() G.PE.OrbitalBeam(CFG.KillAuraTeam) end })
    C:CreateButton({ Name = "LEVITATE (float in front of everyone)",
        Callback = function() G.PE.Levitate() end })
    C:CreateSection("Fire theatre")
    C:CreateParagraph({ Title = "Fire aura",
        Content = "Everyone who walks closer than 15 studs catches FIRE (1 damage + server fire). You look like a burning boss - run through the cafeteria and the whole room is on fire. The map itself cannot burn: the server only allows fire on players." })
    C:CreateToggle({ Name = "FIRE AURA (everyone near you burns)",
        Flag = "PE_FireAura",
        CurrentValue = CFG.FireAura == true,
        Callback = function(v)
            CFG.FireAura = v
            print("[PE] fire aura " .. (v and "ON - stay dangerous"
                or "OFF"))
        end })
    C:CreateSection("C00LKIDD MODE (2014)")
    C:CreateParagraph({ Title = "c00lkidd",
        Content = "Slow-burn EVERYONE: tiny damage every 1.2s + server fire - players burn and die slowly, visible to the whole server (needs a gun). The 2014 legend returns." })
    C:CreateToggle({ Name = "Slow burn EVERYONE (server-wide fire)",
        Flag = "PE_C00lMode",
        CurrentValue = CFG.C00lMode == true,
        Callback = function(v) CFG.C00lMode = v end })
    C:CreateToggle({ Name = "C00l fling (throw everyone)",
        Flag = "PE_C00lFling",
        CurrentValue = CFG.C00lFling == true,
        Callback = function(v) CFG.C00lFling = v end })
    C:CreateSlider({ Name = "Burn damage per tick", Flag = "PE_C00lDamage",
        Range = {1, 20}, Increment = 1,
        CurrentValue = math.clamp(tonumber(CFG.C00lDamage) or 3, 1, 20),
        Callback = function(v) CFG.C00lDamage = v end })
    local burnDrop = C:CreateDropdown({
        Name = "Who burns",
        Flag = "PE_C00lTeamPick",
        Options = teamOpts(),
        CurrentOption = { CFG.C00lTeam },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then
                CFG.C00lTeam = picked
                print("[PE] burn target: " .. picked)
            end
        end,
    })
    teamPickers[#teamPickers + 1] = burnDrop
    C:CreateSection("APOCALYPSE (auto killer)")
    C:CreateParagraph({ Title = "Apocalypse",
        Content = "ONE toggle - the machine does everything: teleports you 400 studs UP and anchors (nobody reaches you), switches team Prisoner<->Escaped every second (everyone becomes a valid target in turn - server team-check bypassed), auto-takes the M9 pistol, then burns and deals 100 damage to EVERY player on the server every 0.5s. Toggle off - you are unanchored and lowered back." })
    C:CreateToggle({ Name = "APOCALYPSE (auto killer machine)",
        Flag = "PE_Apocalypse",
        CurrentValue = CFG.Apocalypse == true,
        Callback = function(v)
            CFG.Apocalypse = v
            -- Взаимоисключение с килл-аурой: вместе они давят 280+
            -- FireServer/с — сеть начинает терять пакеты.
            if v and CFG.KillAura then
                CFG.KillAura = false
                print("[PE APOC] kill aura auto-disabled (mutual excl.)")
            end
        end })
    C:CreateSlider({ Name = "Apocalypse damage", Flag = "PE_ApocDamage",
        Range = {1, 200}, Increment = 5,
        CurrentValue = math.clamp(tonumber(CFG.ApocDamage) or 100, 1, 200),
        Callback = function(v) CFG.ApocDamage = v end })


    C = safeNewTab(W, "Move", "activity", "Move")
    if not C then error("Move tab failed") end
    C:CreateSection("Team & status")
    C:CreateButton({ Name = "Team: GUARD",
        Callback = function() G.PE.Team("Guard") end })
    C:CreateButton({ Name = "Team: PRISONER",
        Callback = function() G.PE.Team("Prisoner") end })
    C:CreateButton({ Name = "Team: ESCAPED (criminal)",
        Callback = function() G.PE.Team("Escaped") end })
    -- Дропдаун «Switch team» удалён (v2.85): восстановление конфига
    -- фаерило его колбэк при СТАРТЕ — ChooseTeamEvent респавнил нас
    -- сразу после загрузки. Кнопки выше покрывают всё.
    C:CreateSection("Auto team on respawn")
    C:CreateParagraph({ Title = "Auto team",
        Content = "Pick a team and the script CONSTANTLY returns you to it - check every second and right after death. Example: set Escaped and any kill puts you back into criminals automatically. Off = never auto-switch. Paused while APOCALYPSE runs (it flips teams itself)." })
    C:CreateDropdown({
        Name = "Auto team (constant check)",
        Flag = "PE_AutoTeamPick",
        Options = { "Off", "Guard", "Prisoner", "Escaped" },
        CurrentOption = { CFG.AutoTeam },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then
                CFG.AutoTeam = picked
                print("[PE TEAM] auto team = " .. picked)
            end
        end,
    })
    C:CreateSection("Idle & stun")
    C:CreateToggle({ Name = "Anti-AFK (no idle kick)",
        Flag = "PE_AntiAFK",
        CurrentValue = CFG.AntiAFK ~= false,
        Callback = function(v) CFG.AntiAFK = v end })
    C:CreateToggle({ Name = "Anti-stun (taser/cuffs/ragdoll)", Flag = "PE_AntiStun",
        CurrentValue = CFG.AntiStun ~= false,
        Callback = function(v) CFG.AntiStun = v end })

    C = safeNewTab(W, "Items", "package", "Items")
    if not C then error("Items tab failed") end
    C:CreateSection("Weapon giver (click detectors)")
    C:CreateParagraph({ Title = "Giver",
        Content = "Gives weapons/keycard via fireclickdetector on ground models. Distance is not checked. If a gun is NOT given - its server script likely requires GUARD team: press 'Team: GUARD' first, then give. Take the weapon from your backpack afterwards." })
    C:CreateToggle({ Name = "Auto-give after death",
        Flag = "PE_AutoGive",
        CurrentValue = CFG.AutoGive == true,
        Callback = function(v) CFG.AutoGive = v end })
    C:CreateDropdown({
        Name = "Auto-give weapon",
        Flag = "PE_AutoGivePick",
        Options = { "M9", "AK-74", "M16a4 MOD", "MP5 Short", "SVD",
            "PPSH-41", "MG42", "Kord", "Hammer", "KeyCard", "GIVE ALL" },
        CurrentOption = { CFG.AutoGiveName },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then CFG.AutoGiveName = picked end
        end,
    })
    C:CreateDropdown({
        Name = "Give weapon",
        Flag = "PE_GivePick",
        Options = (function()
            local o = {}
            for _, nm in ipairs(GIVE_ITEMS) do o[#o + 1] = nm end
            table.insert(o, "GIVE ALL")
            return o
        end)(),
        CurrentOption = { "M9" },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then CFG._givePick = picked end
        end,
    })
    C:CreateButton({ Name = "GIVE selected weapon",
        Callback = function()
            local want = CFG._givePick or "M9"
            if want == "GIVE ALL" then
                G.PE.GiveAll()
            else
                G.PE.Give(want)
            end
        end })
    C:CreateButton({ Name = "Open ALL doors (jail cells)",
        Callback = function() G.PE.Doors() end })
    C:CreateButton({ Name = "Gun source -> console (decompile)",
        Callback = function() G.PE.GunSource() end })
    -- ====================== ВКЛАДКА НАСТРОЙКИ ======================
    local ST = safeNewTab(W, "Settings", "settings", "Settings")
    if ST then
        ST:CreateSection("Language / Язык")
        ST:CreateParagraph({ Title = "Language",
            Content = "Pick a language and press RESTART - the script reloads itself with the translated menu. EN: labels in English. RU: подписи меню на русском. Language survives script restarts." })
        ST:CreateDropdown({
            Name = "Menu language / Язык меню",
            Flag = "PE_LANGPick",
            Options = { "English", "Русский" },
            CurrentOption = {
                PE_LANG == "ru" and "Русский" or "English" },
            MultipleOptions = false,
            Callback = function(selected)
                local picked = selected
                if type(picked) == "table" then picked = picked[1] end
                if picked == "Русский" then
                    getgenv().PE_LANG = "ru"
                else
                    getgenv().PE_LANG = "en"
                end
                print("[PE] language = " .. tostring(picked)
                    .. " - press RESTART SCRIPT to apply")
            end,
        })
        ST:CreateButton({ Name = "RESTART SCRIPT (apply language)",
            Callback = function()
                print("[PE] restarting with new language...")
                loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/blegbot1/PrisonESP/main/PrisonESP.lua",
                    true))()
            end })
        ST:CreateButton({ Name = "UNLOAD script (full cleanup)",
            Callback = function()
                print("[PE] unloading...")
                local stop = G.PE_Stop
                if stop then stop() end
            end })
        ST:CreateSection("Info")
        ST:CreateInput({ Name = "Photo decal ID (background)",
            PlaceholderText = "decal id from roblox.com, e.g. 123456789",
            CurrentValue = tostring(getgenv().PE_BG_ID or ""),
            Flag = "PE_BgIdInput",
            Callback = function(text)
                local id = tonumber(text)
                if id and id > 0 then
                    getgenv().PE_BG_ID = id
                    if PeUI and PeUI._bgImage then
                        pcall(function()
                            PeUI._bgImage.Image = "rbxassetid://" .. id
                        end)
                        print("[PE UI] bg: decal id set LIVE -> " .. id)
                    else
                        print("[PE UI] bg: id saved - RESTART to apply")
                    end
                end
            end })
        ST:CreateParagraph({ Title = "Version",
            Content = "PRISON ESP v2.91 (Combat-only, built-in PeUI). Background: double-layer (purple base + photo panel right). Photo source: pe_bg.png in workspace (auto-download from GitHub) OR decal id above. Console tools: PE.Guns(), PE.Remotes(), PE.GunSource(), PE.Diag(), PE.Probe(...), PE.Hit(name), PE.Team(name), PE.FakeShot(), PE.EscapeTrip(), PE.WearOutfit(), PE.ShopInfo()." })
    end

    guiOK = true
    -- Флаги собраны — теперь можно восстановить сохранённый конфиг
    -- (колбэки проставят CFG, гейт cfgLoaded не даст загрузке писать).
    if PeUI and PeUI._loadConfig then pcall(PeUI._loadConfig) end
    PE_GUI_READY = true
end)
if not okGUI then
    warn("[PE] PE UI MENU BUILD FAILED: " .. tostring(errGUI))
    -- Ломаное полусобранное окно убираем целиком.
    pcall(function()
        if PeUI then PeUI:Destroy() end
    end)
end

-- rescueRayfield удалён: PeUI сразу строит окно в PlayerGui с
-- ResetOnSpawn=false — ни gethui, ни переноса, ни кликов-мёртвых.

-- ============================================================
--  ДИАГНОСТИКА: PE.Diag() + логгер каждого клика.
-- ============================================================
G.PE.Diag = function()
    print("========== [PE DIAG] START ==========")
    do
        local okEx, ex = pcall(function()
            return identifyexecutor and identifyexecutor() or "?"
        end)
        print("[PE DIAG] executor: " .. (okEx and tostring(ex) or "?"))
    end
    print("[PE DIAG] UI=PeUI(built-in)"
        .. " | window=" .. tostring(PeUI._sg ~= nil)
        .. " | flags=" .. tostring(next(PeUI.Flags) ~= nil))
    do
        local hasGethui = typeof(gethui) == "function"
        print("[PE DIAG] gethui: " .. (hasGethui and "yes" or "NO"))
        if hasGethui then
            local okH, h = pcall(gethui)
            print("[PE DIAG] gethui() -> " .. (okH and tostring(h) or ("error: " .. tostring(h))))
        end
    end
    local function dumpCont(label, cont)
        if not cont then
            print("[PE DIAG] " .. label .. ": no container")
            return
        end
        local n = 0
        pcall(function()
            for _, c in ipairs(cont:GetChildren()) do
                if c:IsA("ScreenGui") then
                    n = n + 1
                    print(("[PE DIAG] %s: ScreenGui '%s' | Order=%d | Enabled=%s | children=%d"):format(
                        label, c.Name, c.DisplayOrder, tostring(c.Enabled), #c:GetChildren()))
                end
            end
        end)
        if n == 0 then
            print("[PE DIAG] " .. label .. ": NO ScreenGui")
        end
    end
    dumpCont("PlayerGui", LP:FindFirstChildOfClass("PlayerGui"))
    dumpCont("CoreGui", CoreGui)
    if typeof(gethui) == "function" then
        local okH, h = pcall(gethui)
        if okH and h then dumpCont("gethui", h) end
    end
    print("========== [PE DIAG] END ==========")
end

-- Логгер кликов: выключен по умолчанию (шумит). Включить ПЕРЕД
-- запуском: getgenv().PE_CLICKLOG = true
local clickConn = nil
if G.PE_CLICKLOG == true then
    pcall(function()
        local UIS = game:GetService("UserInputService")
        clickConn = UIS.InputBegan:Connect(function(inp, gp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
               or inp.UserInputType == Enum.UserInputType.Touch then
                local pos = inp.Position
                local x, y = math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5)
                local pg = LP:FindFirstChildOfClass("PlayerGui")
                local found = {}
                if pg then
                    pcall(function()
                        for _, obj in ipairs(pg:GetGuiObjectsAtPosition(x, y)) do
                            if #found < 5 then
                                local chain = obj.Name
                                local p = obj
                                for _ = 1, 4 do
                                    p = p.Parent
                                    if not p then break end
                                    chain = p.Name .. "/" .. chain
                                    if p == pg then break end
                                end
                                found[#found + 1] = chain
                                    .. " [Z=" .. tostring(obj.ZIndex)
                                    .. " Active=" .. tostring(obj.Active) .. "]"
                            end
                        end
                    end)
                end
                local tag = gp and "GUI" or "WORLD"
                if #found > 0 then
                    print("[PE CLICK " .. tag .. "] " .. x .. "," .. y
                        .. " -> " .. table.concat(found, " | "))
                else
                    print("[PE CLICK " .. tag .. "] " .. x .. "," .. y
                        .. " -> no GUI under cursor (in PlayerGui)")
                end
            end
        end)
        print("[PE] click logger ON (disable: getgenv().PE_CLICKLOG=false + restart)")
    end)
end

-- Автодиагностика через 3 секунды после запуска.
task.delay(3, function()
    if not STOPPED then G.PE.Diag() end
end)

-- Меню — собственная PeUI (встроена в файл). Если сборка упала —
-- громко ругаемся в консоль (функции доступны и без меню).
if not guiOK then
    warn("[PE] PE UI failed to build (error above). Console: PE.Hit/PE.Team/PE.Give/PE.Doors etc.")
end

-- ============================================================
--  ВЫБОР ЦЕЛИ: выпадающие списки игроков (обновляются сами).
-- ============================================================
local function playerOpts()
    local opts = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then opts[#opts + 1] = p.Name end
    end
    table.sort(opts)
    return opts
end

-- targetPickers объявлен выше, до GUI-блока.
local function refreshTargetPickers()
    local opts = playerOpts()
    for _, d in ipairs(targetPickers) do
        -- Внимание: в Rayfield обновление списка — :Refresh (а :Set
        -- выбирает опцию). Раньше звали :Set — список не обновлялся.
        pcall(function() d:Refresh(opts) end)
    end
    local topts = teamOpts()
    -- v2.53: выбранный ник ушёл с сервера (или сохранён с прошлой
    -- сессии) — isSel=false у всех, аура молча не била НИКОГО.
    -- Сбрасываем цель на "Everyone", если её больше нет в списке.
    for _, key in ipairs({ "KillAuraTeam", "C00lTeam" }) do
        local sel = CFG[key]
        if type(sel) == "string" and sel ~= "Everyone"
           and not table.find(topts, sel) then
            CFG[key] = "Everyone"
            print("[PE] " .. key .. ": target left the server -> Everyone")
        end
    end
    for _, d in ipairs(teamPickers) do
        pcall(function() d:Refresh(topts) end)
    end
end

task.spawn(function()
    task.wait(3)
    while not STOPPED do
        refreshTargetPickers()
        task.wait(5)
    end
end)

-- ============================================================
--  СТОП
-- ============================================================
G.PE_Stop = function()
    STOPPED = true
    pcall(function() clickConn:Disconnect() end)
    pcall(function() auraConn:Disconnect() end)
    -- Анти-стан запрещал регдолл-состояния навсегда: после выгрузки
    -- возвращаем, иначе тазер/регдолл не валят до следующего респавна.
    pcall(function()
        local chrS = LP.Character
        local humS = chrS and chrS:FindFirstChildOfClass("Humanoid")
        if humS then
            humS:SetAttribute("PE_NoRagdoll", nil)
            for _, stName in ipairs({ "Ragdoll", "FallingDown",
                "PlatformStanding" }) do
                humS:SetStateEnabled(Enum.HumanoidStateType[stName], true)
            end
        end
    end)
    pcall(function() paConn:Disconnect() end)
    pcall(function() prConn:Disconnect() end)
    pcall(function() giveConn:Disconnect() end)
    pcall(function() afkConn:Disconnect() end)
    G.PE.Guns, G.PE.Remotes, G.PE.Probe = nil, nil, nil
    G.PE.Hit, G.PE.Team, G.PE.Diag = nil, nil, nil
    G.PE.Give, G.PE.GiveAll, G.PE.Doors = nil, nil, nil
    G.PE.Escape = nil
    G.PE.EscapeTrip = nil
    G.PE.WearOutfit, G.PE.ShopInfo = nil, nil
    G.PE.GunSource, G.PE.TP, G.PE.Cuff, G.PE.ModGun = nil, nil, nil, nil
    G.PE.FakeShot, G.PE.SkyShot, G.PE.SquadShot = nil, nil, nil
    G.PE.OrbitalBeam, G.PE.Levitate = nil, nil
    G.PE.WP_Save, G.PE.WP_TP, G.PE.TPCrosshair = nil, nil, nil
    G.PE.EnsureWeapon, G.PE.HasWeapon = nil, nil
    G.PE.ApocGunName = nil
    pcall(function()
        if CFG._immPerch then
            CFG._immPerch = nil
            local rImm = LP.Character
                and LP.Character:FindFirstChild("HumanoidRootPart")
            if rImm then
                -- Возвращаем на землю ДО снятия якоря: иначе падение
                -- с +350 стадов и фолл-урон после самой выгрузки.
                if CFG._immBack then
                    rImm.CFrame = CFG._immBack
                end
                rImm.Anchored = false
            end
        end
    end)
    for _, c in ipairs(vbConns) do
        pcall(function() c:Disconnect() end)
    end
    vbConns = {}
    -- FPS-буст удалён (v2.75): функция не существует.
    CFG._ensureBusy = nil
    pcall(function()
        if CFG._apocPerchCF then
            CFG._apocPerchCF = nil
            local rootP2 = LP.Character
                and LP.Character:FindFirstChild("HumanoidRootPart")
            if rootP2 then
                rootP2.Anchored = false
            end
        end
    end)
    local uiOld = PeUI
    PeUI = nil
    if uiOld then task.defer(function() pcall(function() uiOld:Destroy() end) end) end
    -- Заглушка вместо nil: повторный вызов PE_Stop не должен падать.
    G.PE_Stop = function() end
    G.PE_LOADED_AT = nil
    print("[PE] v3.05 stopped")
end

print("[PE] v3.05 started (Combat-only, PeUI built-in)"
    .. " | console: PE.Guns() / PE.Remotes() / PE.Probe(...)"
    .. " / PE.Hit(\"partial name\") / PE.Team(\"Guard\") / PE.Diag()")
