-- ============================================================
--  PRISON ESP  v2.53
--  Тюремный RP (заключённые / охрана / преступники).
--
--  ESP полностью перенесён из BloodyStreetESP v11.53 и адаптирован
--  под тюрьму: роли (охрана/зеки/преступники), 3D-коробки по
--  габаритам модели, скелет, полоски HP с градиентом, кольцо под
--  целью, стрелки, миникарта + разведка (ТТХ пушек, ремоуты, зонд).
--
--  Консоль:
--    getgenv().PE.Guns()     -- ТТХ всех пушек (Setting-модули)
--    getgenv().PE.Remotes()  -- все ремоуты с путями
--    getgenv().PE.Probe("InflictTarget", часть_врага)
--    getgenv().PE.TeamOf(игрок) -- как скрипт видит роль игрока
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

local function safeColor(v, def)
    if typeof(v) == "Color3" then return v end
    return def
end
local function pickOpt(v, list, def)
    if type(v) == "string" then
        for _, o in ipairs(list) do
            if o == v then return v end
        end
    end
    return def
end

local BOX_STYLES    = { "Frame", "Corners", "3D box" }
local TRACER_ORIGINS = { "Center", "Bottom", "Top" }

-- ---------- ESP: роли ----------
CFG.PlayerESP     = CFG.PlayerESP     ~= false   -- ESP прочих
CFG.GuardESP      = CFG.GuardESP      ~= false
CFG.PrisonerESP   = CFG.PrisonerESP   ~= false
CFG.CriminalESP   = CFG.CriminalESP   ~= false
CFG.ColGuard  = safeColor(CFG.ColGuard, Color3.fromRGB(70, 170, 255))
CFG.ColPris   = safeColor(CFG.ColPris,  Color3.fromRGB(255, 170, 60))
CFG.ColCrim   = safeColor(CFG.ColCrim,  Color3.fromRGB(255, 60, 60))
CFG.ColOther  = safeColor(CFG.ColOther, Color3.fromRGB(200, 200, 200))

-- ---------- ESP: подписи ----------
CFG.Names      = CFG.Names      ~= false
CFG.RoleTags   = CFG.RoleTags   ~= false   -- [ОХР]/[ЗЕК]/[КРИМ] в подписи
CFG.WeaponESP  = CFG.WeaponESP  ~= false
CFG.ShowDist   = CFG.ShowDist   ~= false
CFG.ShowHP     = CFG.ShowHP     ~= false
CFG.HPPercent  = CFG.HPPercent  == true
CFG.ShowSpeed  = CFG.ShowSpeed  == true
CFG.NameHPColor = CFG.NameHPColor == true -- цвет ника по HP
CFG.HideDead   = CFG.HideDead   ~= false
CFG.LabelSize  = math.clamp(tonumber(CFG.LabelSize) or 13, 9, 24)
CFG.MaxDist    = tonumber(CFG.MaxDist) or 900   -- 0 = без лимита

-- ---------- ESP: коробки ----------
CFG.Boxes     = CFG.Boxes     ~= false
CFG.BoxThick  = math.clamp(tonumber(CFG.BoxThick) or 2, 1, 6)
CFG.BoxPad    = tonumber(CFG.BoxPad) or 4
CFG.BoxMargin = math.clamp(tonumber(CFG.BoxMargin) or 0, 0, 10)
CFG.BoxAlpha  = math.clamp(tonumber(CFG.BoxAlpha) or 0, 0, 0.9)
CFG.BoxStyle  = pickOpt(CFG.BoxStyle, BOX_STYLES, "3D box")
CFG.DistFade  = CFG.DistFade == true

-- ---------- ESP: визуалы ----------
CFG.Skeleton      = CFG.Skeleton == true
CFG.SkeletonThick = tonumber(CFG.SkeletonThick) or 1
CFG.SkelMinDist   = tonumber(CFG.SkelMinDist) or 12
CFG.HealthBars    = CFG.HealthBars ~= false
CFG.HealthBarWidth  = math.clamp(tonumber(CFG.HealthBarWidth) or 40, 2, 200)
CFG.HealthBarHeight = math.clamp(tonumber(CFG.HealthBarHeight) or 4, 2, 20)
CFG.HPBarText     = CFG.HPBarText ~= false
CFG.HPGradient    = CFG.HPGradient ~= false
CFG.HeadBox       = CFG.HeadBox ~= false
CFG.HeadBoxSize   = math.clamp(tonumber(CFG.HeadBoxSize) or 22, 4, 100)
CFG.HeadBoxRole   = CFG.HeadBoxRole ~= false
CFG.HeadBoxColor  = safeColor(CFG.HeadBoxColor, Color3.new(1, 0, 0))
CFG.Snaplines     = CFG.Snaplines ~= false
CFG.SnapArrowThick = math.clamp(tonumber(CFG.SnapArrowThick) or 2, 1, 6)
CFG.SnapFrom      = pickOpt(CFG.SnapFrom, TRACER_ORIGINS, "Bottom")
CFG.SnapAlpha     = math.clamp(tonumber(CFG.SnapAlpha) or 1, 0, 1)
CFG.OffArrows     = CFG.OffArrows ~= false
-- Кольцо под целью: по умолчанию ВЫКЛ (круги под ногами у всех
-- раздражали) — включается тумблером во вкладке ESP.
CFG.GroundRing    = CFG.GroundRing == true
CFG.MoveVec       = CFG.MoveVec == true
CFG.LiteESP       = CFG.LiteESP == true

-- ---------- ESP: миникарта ----------
CFG.Minimap     = CFG.Minimap == true
CFG.MinimapSize = math.clamp(tonumber(CFG.MinimapSize) or 160, 40, 400)
CFG.MinimapSelf = CFG.MinimapSelf ~= false

-- ---------- ESP: предметы на земле ----------
CFG.Items = CFG.Items ~= false

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
CFG.KillAuraDamage = tonumber(CFG.KillAuraDamage) or 50
CFG.ModGunDamage = tonumber(CFG.ModGunDamage) or 250
-- ВАМПИРИЗМ АУРЫ: 6-й аргумент InflictTarget лечит стрелка на эту
-- величину за каждый удар — псевдо-бессмертие, пока аура бьёт.
-- Подброс жертв — 5-й аргумент (отдача вверх).
CFG.AuraLifesteal = CFG.AuraLifesteal ~= false
CFG.AuraFling = CFG.AuraFling == true
CFG.FlingDir = pickOpt(CFG.FlingDir, {
    "Up", "Away from me", "Random" }, "Up")
-- БЕСКОНЕЧНЫЙ РАДИУС: сервер не проверяет дистанцию InflictTarget
-- (доказано живым тестом c00lkidd-режима — горело по всему серверу).
CFG.AuraInfRange = CFG.AuraInfRange == true
-- ЗВУК УБИЙСТВА: цели ауры умерли — короткий бип (только у тебя).
CFG.KillSound = CFG.KillSound == true
-- ЧАМСЫ: Highlight-подсветка персонажей цветом роли, сквозь стены.
CFG.Chams = CFG.Chams == true
local chamsScanAt = 0
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
-- Снайперский прицел на ЛЮБОЙ пушке: Setting.SniperEnabled, зум
-- по клавише E (FieldOfView из Setting).
CFG.GunScope = CFG.GunScope == true
-- ОПАСНЫЕ ЗОНЫ: Death Part подсветка + телепорт к зоне побега.
CFG.DangerESP = CFG.DangerESP == true
-- НЕВИДИМЫЕ СТЕНЫ: периметр тюрьмы невидим (132 стены Tr=0.95) —
-- подсветка голубым, чтобы флай не бился в пустоту.
CFG.InvisWall = CFG.InvisWall == true
-- АВТО-ПРОКАЧКА: новая пушка в руках (респавн/смена) — апгрейд
-- применяется сам, кнопку жать не надо.
CFG.ModGunAuto = CFG.ModGunAuto ~= false
-- АДМИНЫ: подсветка магентой + [ADMIN] + алерт в консоль при входе.
CFG.AdminESP = CFG.AdminESP ~= false
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
-- ОГНЕННАЯ КИСТЬ: сервер вешает огонь на 2-й аргумент InflictTarget.
-- Если он не проверяет принадлежность части жертве — можно передать
-- блок стены/пола и РИСОВАТЬ ОГНЁМ курсором. Носитель урона —
-- ближайший враг (урон 1). Если сервер проверяет — огонь останется
-- на враге, просто не получится.
CFG.FirePaint = CFG.FirePaint == true
local paintAt = 0
-- АПОКАЛИПСИС = УБИВАЛКА: один тумблер делает всё сам —
-- 1) команда СБЕЖАВШИЙ, 2) сам берёт M9, 3) телепорт высоко в небо
-- (не достанут; дистанции урона нет — доказано), 4) все игроки
-- получают 100 урона + огонь за тик. Выкл — возврат на землю.
-- Горение частей карты сервер отвергает (проверка принадлежности) —
-- жжём только игроков.
CFG.Apocalypse = CFG.Apocalypse == true
CFG.ApocDamage = tonumber(CFG.ApocDamage) or 100
local apocAt = 0
-- МГНОВЕННЫЙ РЕВАЙН: умер — сами шлём ResetToMenuEvent и возвращаемся
-- в прошлую команду. Даунтайм ~1.5с вместо стандартного респавна.
CFG.FastRespawn = CFG.FastRespawn == true
-- АВТО-ГИВЕР: после смерти сам выдаёт выбранное оружие (если сервер
-- ничего не выдал сам).
CFG.AutoGive = CFG.AutoGive == true
CFG.AutoGiveName = pickOpt(CFG.AutoGiveName, {
    "M9", "AK-74", "M16a4 MOD", "MP5 Short", "SVD", "PPSH-41",
    "MG42", "Kord", "Hammer", "KeyCard", "GIVE ALL" }, "M9")
-- РЕТРИБУЦИЯ: получили урон — мгновенно находим атакующего
-- (вооружённые в приоритете) и сжигаем его.
CFG.Retr = CFG.Retr ~= false
-- АНТИ-АФК: VirtualUser отвечает за нас на idle-проверку Roblox —
-- долгие сессии без кика.
CFG.AntiAFK = CFG.AntiAFK ~= false
-- ПРЫЖОК-БУСТ: физика своего персонажа на клиенте, JumpPower наш.
CFG.JumpBoost = CFG.JumpBoost == true
CFG.JumpPower = tonumber(CFG.JumpPower) or 90
-- ПАКЕТ ДВИЖЕНИЯ: физика персонажа клиентская (доказано прыжком) —
-- скорость/noclip/полёт честно реплицируются серверу позицией.
CFG.SpeedHack = CFG.SpeedHack == true
CFG.SpeedValue = tonumber(CFG.SpeedValue) or 40
CFG.Noclip = CFG.Noclip == true
CFG.Fly = CFG.Fly == true
CFG.FlySpeed = tonumber(CFG.FlySpeed) or 60
-- БЕСКОНЕЧНЫЙ ПРЫЖОК: JumpRequest → Jumping-состояние в воздухе.
CFG.InfJump = CFG.InfJump == true
-- FPS-БУСТ: минимальное качество рендера + без глобальных теней.
-- v2.53: флаг живёт под ОТДЕЛЬНЫМ ключом FPSBoostOn — ключ FPSBoost
-- занят функцией G.PE.FPSBoost(on), раньше они затирали друг друга.
CFG.FPSBoostOn = CFG.FPSBoostOn == true
-- АУРА: максимум целей за тик (6 = дефолт, 20 = мясорубка).
CFG.AuraMaxHits = tonumber(CFG.AuraMaxHits) or 6

local STOPPED = false
-- Боевые циклы не работают, пока меню не собрано: сохранённый конфиг
-- Rayfield восстанавливает тогглы колбэками, и без этого гейта аура/
-- полёт/апокалипсис взводились бы до появления окна.
local PE_GUI_READY = false
local Rayfield
local mainConn, itemConn, auraConn, dangerConn, chamsConn, flyConn, ijConn
local UIS = game:GetService("UserInputService")
local by = {}          -- [Player] = {char, gui, lbl, box, role, vis, roleAt}

-- ============================================================
--  ЭКРАН ПОД ПЛАШКИ (BillboardGui)
-- ============================================================
local Screen = nil
local function screen()
    if Screen and Screen.Parent then
        if not Screen.Enabled then Screen.Enabled = true end
        return Screen
    end
    local sg = Instance.new("ScreenGui")
    sg.Name           = "PE_ESP"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder   = 1   -- ниже окна Rayfield
    -- CoreGui не везде доступен — тогда живём в PlayerGui.
    local okP = pcall(function() sg.Parent = CoreGui end)
    if not okP then
        pcall(function() sg.Parent = LP:FindFirstChildOfClass("PlayerGui")
            or LP:WaitForChild("PlayerGui", 3) end)
    end
    if not sg.Parent then
        sg:Destroy()
        return nil
    end
    Screen = sg
    return sg
end
screen()

local function makeBillboard()
    local scr = screen()
    if not scr then return nil end
    local ok, gui = pcall(function()
        local g = Instance.new("BillboardGui")
        g.Adornee      = nil
        g.Size         = UDim2.new(0, 220, 0, 60)
        g.StudsOffset  = Vector3.new(0, 3.2, 0)
        g.AlwaysOnTop  = true
        g.MaxDistance  = 1500
        g.Parent       = scr
        return g
    end)
    if not ok or not gui then return nil end
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Lbl"
    return gui, lbl
end

-- ============================================================
--  3D-КОРОБКИ (Drawing). При отказе Drawing коробки просто
--  отключаются, скрипт не падает.
-- ============================================================
local DRAW_OK = false
do
    local ok, l = pcall(function() return Drawing.new("Line") end)
    if ok and l then
        l.Visible = false
        pcall(function() l:Remove() end)
        DRAW_OK = true
    end
end

local function makeBox()
    if not DRAW_OK then return nil end
    if os.clock() < (CFG._boxRetryAt or 0) then return nil end
    local b = {}
    b.lines = {}
    for i = 1, 12 do
        local ok, ln = pcall(function() return Drawing.new("Line") end)
        if not ok or not ln then
            for j = 1, i - 1 do
                if b.lines[j] then pcall(function() b.lines[j]:Remove() end) end
            end
            CFG._boxRetryAt = os.clock() + 5
            return nil
        end
        ln.Visible   = false
        ln.Thickness = tonumber(CFG.BoxThick) or 2
        ln.Color     = Color3.new(1, 1, 1)
        b.lines[i] = ln
    end
    return b
end

-- Коробка по Model:GetBoundingBox(): облегает ВСЁ тело и
-- поворачивается вместе с игроком. Стили: рамка / уголки / 3D.
-- Константа рёбер 3D-коробки (модульный скоуп, ДО drawBox — иначе
-- в горячем цикле резолвилась в nil-глобал и коробки молча умирали).
local BOX_EDGES = { {1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},
                    {1,5},{2,6},{3,7},{4,8} }
local function drawBox(b, root, cam)
    if not b or not b.lines then return end
    local camera = cam or workspace.CurrentCamera
    local function hideAll()
        for i = 1, #b.lines do
            if b.lines[i] then b.lines[i].Visible = false end
        end
    end
    if not camera or not root or not root.Parent then
        hideAll()
        return
    end
    local ch = root.Parent
    local nowB = os.clock()
    -- Габариты пересчитываем при смене персонажа и раз в 0.4 с;
    -- позицию/поворот берём с корня КАЖДЫЙ кадр — коробка не дёргается.
    if b.char ~= ch or nowB - (b.sizeAt or 0) > 0.4 then
        b.char = ch
        b.sizeAt = nowB
        b.size = nil
        b.offLocal = nil
        if ch and ch:IsA("Model") then
            local okB, cfB, szB = pcall(function()
                local c, s = ch:GetBoundingBox()
                return c, s
            end)
            if okB and typeof(cfB) == "CFrame"
               and typeof(szB) == "Vector3" and szB.Magnitude > 0.1 then
                b.size = szB
                local okO, off = pcall(function()
                    return root.CFrame:PointToObjectSpace(cfB.Position)
                end)
                if okO and typeof(off) == "Vector3" then
                    b.offLocal = off
                end
            end
        end
    end
    local cf = root.CFrame * CFrame.new(b.offLocal or Vector3.new(0, 0, 0))
    -- ВПЛОТНУЮ К ЦЕЛИ: проекция рёбер раздувается на весь экран —
    -- коробку прячем (вплотную игрок и так отлично виден).
    local camPosNow = camera.CFrame and camera.CFrame.Position
    if camPosNow and (cf.Position - camPosNow).Magnitude < 7 then
        hideAll()
        return
    end
    local size = b.size or Vector3.new(2.6, 5.8, 2.2)
    local hw = size.X * 0.5 + (tonumber(CFG.BoxMargin) or 0)
    local hh = size.Y * 0.5 + (tonumber(CFG.BoxMargin) or 0)
    local hd = size.Z * 0.5 + (tonumber(CFG.BoxMargin) or 0)
    local C = {
        cf * Vector3.new(-hw, -hh, -hd), cf * Vector3.new(hw, -hh, -hd),
        cf * Vector3.new(hw, -hh, hd), cf * Vector3.new(-hw, -hh, hd),
        cf * Vector3.new(-hw, hh, -hd), cf * Vector3.new(hw, hh, -hd),
        cf * Vector3.new(hw, hh, hd), cf * Vector3.new(-hw, hh, hd),
    }
    local proj = {}
    local anyFront = false
    for i = 1, 8 do
        local sp = camera:WorldToViewportPoint(C[i])
        proj[i] = sp
        if sp.Z > 0 then anyFront = true end
    end
    if not anyFront then
        hideAll()
        return
    end
    -- Затухание по дистанции.
    local fade = 0
    if CFG.DistFade then
        local cpos = camera.CFrame and camera.CFrame.Position
        if cpos then
            local dist = (cf.Position - cpos).Magnitude
            fade = math.clamp((dist - 70) / 180, 0, 0.85)
        end
    end
    local alpha = tonumber(CFG.BoxAlpha) or 0
    if alpha < 0 then alpha = 0 elseif alpha > 0.9 then alpha = 0.9 end
    local trans = math.clamp(fade + alpha, 0, 1)
    local col = b.color or Color3.new(1, 1, 1)
    local thick = tonumber(CFG.BoxThick) or 2
    local style = CFG.BoxStyle or "Frame"

    local function setLine(i, a, c)
        local ln = b.lines[i]
        if not ln then return end
        ln.From = a
        ln.To = c
        ln.Color = col
        ln.Thickness = thick
        ln.Transparency = trans
        ln.Visible = true
    end
    local function hideFrom(i)
        for k = i, #b.lines do
            if b.lines[k] then b.lines[k].Visible = false end
        end
    end

    -- 3D: 12 рёбер, каждое рисуется отдельно — угол за камерой прячет
    -- только своё ребро. Дальние рёбра бледнее и тоньше.
    if style == "3D box" then
        for i = 1, 12 do
            local ln = b.lines[i]
            local a = proj[BOX_EDGES[i][1]]
            local c = proj[BOX_EDGES[i][2]]
            if ln and a.Z > 0 and c.Z > 0 then
                local depth = (a.Z + c.Z) * 0.5
                local far01 = math.clamp((depth - 14) / 70, 0, 1)
                ln.From = Vector2.new(a.X, a.Y)
                ln.To = Vector2.new(c.X, c.Y)
                ln.Color = col
                ln.Thickness = math.max(1, thick - (far01 > 0.6 and 1 or 0))
                ln.Transparency = math.clamp(trans + far01 * 0.4, 0, 0.97)
                ln.Visible = true
            elseif ln then
                ln.Visible = false
            end
        end
        return
    end

    -- Экранный прямоугольник по видимым углам.
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for i = 1, 8 do
        local sp = proj[i]
        if sp.Z > 0 then
            if sp.X < minX then minX = sp.X end
            if sp.X > maxX then maxX = sp.X end
            if sp.Y < minY then minY = sp.Y end
            if sp.Y > maxY then maxY = sp.Y end
        end
    end
    if minX > maxX then hideAll() return end
    local pad = tonumber(CFG.BoxPad) or 4
    if pad < 0 then pad = 0 elseif pad > 60 then pad = 60 end
    minX = minX - pad
    maxX = maxX + pad
    minY = minY - pad
    maxY = maxY + pad
    if maxX - minX < 10 then
        local mid = (minX + maxX) * 0.5
        minX, maxX = mid - 5, mid + 5
    end
    if maxY - minY < 18 then
        local mid = (minY + maxY) * 0.5
        minY, maxY = mid - 9, mid + 9
    end

    if style == "Corners" then
        local len = math.clamp(math.min(maxX - minX, maxY - minY) * 0.28, 5, 26)
        setLine(1, Vector2.new(minX, minY), Vector2.new(minX + len, minY))
        setLine(2, Vector2.new(minX, minY), Vector2.new(minX, minY + len))
        setLine(3, Vector2.new(maxX, minY), Vector2.new(maxX - len, minY))
        setLine(4, Vector2.new(maxX, minY), Vector2.new(maxX, minY + len))
        setLine(5, Vector2.new(maxX, maxY), Vector2.new(maxX - len, maxY))
        setLine(6, Vector2.new(maxX, maxY), Vector2.new(maxX, maxY - len))
        setLine(7, Vector2.new(minX, maxY), Vector2.new(minX + len, maxY))
        setLine(8, Vector2.new(minX, maxY), Vector2.new(minX, maxY - len))
        hideFrom(9)
        return
    end

    -- Рамка со зазором по углам.
    local gap = math.clamp(math.min(maxX - minX, maxY - minY) * 0.12, 2, 12)
    local pts = {
        Vector2.new(minX + gap, minY), Vector2.new(maxX - gap, minY),
        Vector2.new(maxX, minY + gap), Vector2.new(maxX, maxY - gap),
        Vector2.new(maxX - gap, maxY), Vector2.new(minX + gap, maxY),
        Vector2.new(minX, maxY - gap), Vector2.new(minX, minY + gap),
    }
    for i = 1, 4 do
        local a = pts[(i - 1) * 2 + 1]
        local c = pts[(i - 1) * 2 + 2]
        setLine(i, a, c)
    end
    hideFrom(5)
end

local function hideBox(b)
    if not b or not b.lines then return end
    for i = 1, #b.lines do
        if b.lines[i] then b.lines[i].Visible = false end
    end
end

local function destroyBox(b)
    if not b or not b.lines then return end
    for i = #b.lines, 1, -1 do
        if b.lines[i] then pcall(function() b.lines[i]:Remove() end) end
        b.lines[i] = nil
    end
end

-- ============================================================
--  МОДУЛЬ VIS: скелет, полоски HP, стрелки, кольца, миникарта
-- ============================================================
local VIS = {}
do
local VDRAW = DRAW_OK

local function vLine()
    if not VDRAW then return nil end
    local ok, l = pcall(function() return Drawing.new("Line") end)
    if ok and l then l.Visible = false; return l end
    return nil
end
local function vSquare()
    if not VDRAW then return nil end
    local ok, s = pcall(function() return Drawing.new("Square") end)
    if ok and s then s.Visible = false; return s end
    return nil
end
local function vCircle()
    if not VDRAW then return nil end
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then c.Visible = false; return c end
    return nil
end
local function vText()
    if not VDRAW then return nil end
    local ok, t = pcall(function() return Drawing.new("Text") end)
    if ok and t then t.Visible = false; return t end
    return nil
end

-- Луч поиска земли под целью (кольцо ставится на пол).
local GROUND_RAY = RaycastParams.new()
GROUND_RAY.FilterType = Enum.RaycastFilterType.Exclude

local VMAX = 20
local vpool = {}
for i = 1, VMAX do
    vpool[i] = {
        skeleton = {},
        hpBg = vSquare(),
        hpBorder = vSquare(),
        hpFg = vSquare(),
        hpText = vText(),
        arrow = vLine(),
        headBox = vSquare(),
        snap = vLine(),
        snapGlow = vLine(),
        snapOut = vLine(),
        snapH1 = vLine(),
        snapH2 = vLine(),
        arrowOut = vLine(),
        arrowH1 = vLine(),
        arrowH2 = vLine(),
        moveOut = vLine(),
        moveVec = vLine(),
        moveH1 = vLine(),
        moveH2 = vLine(),
        groundRing = vCircle(),
    }
end

-- Плавная полоска HP + вспышка при уроне.
local hpSmooth, hpPrev, hpFlash = {}, {}, {}

-- Миникарта.
local minimapBg = vSquare()
local minimapBorder = vSquare()
local minimapDots = {}
local minimapSelf = vCircle()

-- Самопроверка Drawing: сколько каких объектов реально создалось.
-- Если исполнитель не поддерживает тип Square/Circle — будет 0,
-- и полоски HP/кольца/миникарта рисовать нечем (линии — могут).
do
    local nL, nS, nC, nT = 0, 0, 0, 0
    for i = 1, math.min(3, #vpool) do
        local p = vpool[i]
        if p.snap then nL = nL + 1 end
        if p.hpBg then nS = nS + 1 end
        if p.groundRing then nC = nC + 1 end
        if p.hpText then nT = nT + 1 end
    end
    print(("[PE VIS] Drawing objects (3 slots): lines=%d squares=%d circles=%d text=%d")
        :format(nL, nS, nC, nT))
    if nS == 0 then
        warn("[PE VIS] squares (Square) NOT created - HP bars/head frame/minimap will not work")
    end
    if nC == 0 then
        warn("[PE VIS] circles (Circle) NOT created - target ring will not work")
    end
end

-- Константы VIS (были таблицами в горячем цикле: ~15k аллокаций/сек).
local SKEL_LINKS = { {1,2},{2,3},{2,4},{2,5},{3,6},{3,7} }
local GROUND_FILTER = {}

local function vProj(cam, pos)
    -- NaN-позиции (глюк персонажа) отсеиваем сравнением с собой,
    -- без pcall: замыкание на каждый вызов стоило ~18k аллокаций/сек.
    if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
        return nil
    end
    local sp = cam:WorldToViewportPoint(pos)
    if sp then return sp end
    return nil
end

local function vSetLine(l, a, b, color, thickness)
    if not l then return end
    l.From = a
    l.To = b
    l.Color = color
    l.Thickness = thickness or 1
    l.Visible = true
end

local function vHideLine(l) if l then l.Visible = false end end
local function vHideSquare(s) if s then s.Visible = false end end
local function vHideCircle(c) if c then c.Visible = false end end
local function vHideText(t) if t then t.Visible = false end end

-- Откуда идёт линия на экране.
local function screenOrigin(kind, cx, cy, vp)
    if kind == "Bottom" then return Vector2.new(cx, vp.Y) end
    if kind == "Top" then return Vector2.new(cx, 0) end
    return Vector2.new(cx, cy)
end

-- СТРЕЛКА: свечение, тёмная обводка, ствол и наконечник из усов.
local function drawArrowParts(glow, out, shaft, h1, h2, from, to, color, thick, alpha)
    local function hideAll()
        vHideLine(glow); vHideLine(out); vHideLine(shaft)
        vHideLine(h1); vHideLine(h2)
    end
    if not from or not to or not shaft then hideAll() return end
    local dx, dy = to.X - from.X, to.Y - from.Y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 6 then hideAll() return end
    local ux, uy = dx / len, dy / len
    local t = math.clamp(tonumber(thick) or 2, 1, 6)
    local hs = math.clamp(t / 3, 0.5, 1.5)
    local head = math.clamp(len * 0.18, 16, 34) * hs
    local shaftTo = Vector2.new(to.X - ux * head * 0.85, to.Y - uy * head * 0.85)
    vSetLine(glow, from, shaftTo, color, t + 4)
    if glow then glow.Transparency = 0.85 end
    vSetLine(out, from, shaftTo, Color3.new(0, 0, 0), t + 2)
    if out then out.Transparency = 0.5 end
    vSetLine(shaft, from, shaftTo, color, t)
    if shaft then shaft.Transparency = alpha end
    local ang = math.atan2(uy, ux)
    local s1, s2 = ang + math.rad(25), ang - math.rad(25)
    vSetLine(h1, to,
        Vector2.new(to.X - math.cos(s1) * head, to.Y - math.sin(s1) * head),
        color, math.max(t, 1))
    vSetLine(h2, to,
        Vector2.new(to.X - math.cos(s2) * head, to.Y - math.sin(s2) * head),
        color, math.max(t, 1))
    if h1 then h1.Transparency = alpha end
    if h2 then h2.Transparency = alpha end
end

local function drawSnapArrow(p, from, to, color, thick, alpha)
    drawArrowParts(p.snapGlow, p.snapOut, p.snap, p.snapH1, p.snapH2,
        from, to, color, thick, alpha)
end

local function hideSnapArrow(p)
    vHideLine(p.snap); vHideLine(p.snapGlow); vHideLine(p.snapOut)
    vHideLine(p.snapH1); vHideLine(p.snapH2)
end

-- Короткая стрелка у края экрана (цель за кадром).
local function drawEdgeArrow(p, tip, ux, uy, color, thick, alpha)
    local t = math.clamp(tonumber(thick) or 2, 1, 6)
    local len = 22 + t * 3
    local from = Vector2.new(tip.X - ux * len, tip.Y - uy * len)
    vSetLine(p.arrowOut, from, tip, Color3.new(0, 0, 0), t + 2)
    if p.arrowOut then p.arrowOut.Transparency = 0.5 end
    vSetLine(p.arrow, from, tip, color, t)
    if p.arrow then p.arrow.Transparency = alpha end
    local ang = math.atan2(uy, ux)
    local hl = math.clamp(len * 0.4, 6, 16)
    local s1, s2 = ang + math.rad(28), ang - math.rad(28)
    vSetLine(p.arrowH1, tip,
        Vector2.new(tip.X - math.cos(s1) * hl, tip.Y - math.sin(s1) * hl),
        color, t + 1)
    vSetLine(p.arrowH2, tip,
        Vector2.new(tip.X - math.cos(s2) * hl, tip.Y - math.sin(s2) * hl),
        color, t + 1)
    if p.arrowH1 then p.arrowH1.Transparency = alpha end
    if p.arrowH2 then p.arrowH2.Transparency = alpha end
end

local function hideEdgeArrow(p)
    vHideLine(p.arrow); vHideLine(p.arrowOut)
    vHideLine(p.arrowH1); vHideLine(p.arrowH2)
end

-- Цвет роли (общий для всех визуалов).
local function roleColor(role)
    if role == "guard" then
        return safeColor(CFG.ColGuard, Color3.new(0.3, 0.7, 1))
    elseif role == "prisoner" then
        return safeColor(CFG.ColPris, Color3.new(1, 0.65, 0.25))
    elseif role == "criminal" then
        return safeColor(CFG.ColCrim, Color3.new(1, 0.2, 0.2))
    end
    return safeColor(CFG.ColOther, Color3.new(0.8, 0.8, 0.8))
end
VIS.roleColor = roleColor

-- Полное снятие всех Drawing-объектов модуля.
function VIS.destroy()
    local function rm(o)
        if not o then return end
        pcall(function() o:Remove() end)
    end
    for i = 1, #vpool do
        local p = vpool[i]
        for j = 1, #(p.skeleton or {}) do rm(p.skeleton[j]) end
        rm(p.hpBg); rm(p.hpBorder); rm(p.hpFg); rm(p.hpText)
        rm(p.arrow); rm(p.headBox)
        rm(p.snap); rm(p.snapGlow); rm(p.snapOut); rm(p.snapH1); rm(p.snapH2)
        rm(p.arrowOut); rm(p.arrowH1); rm(p.arrowH2)
        rm(p.moveOut); rm(p.moveVec); rm(p.moveH1); rm(p.moveH2)
        rm(p.groundRing)
    end
    for i = 1, #minimapDots do rm(minimapDots[i]) end
    rm(minimapBg); rm(minimapBorder); rm(minimapSelf)
    for k in pairs(hpSmooth) do hpSmooth[k] = nil end
    for k in pairs(hpPrev) do hpPrev[k] = nil end
    for k in pairs(hpFlash) do hpFlash[k] = nil end
    vpool = {}
    minimapDots = {}
end

function VIS.update(cam, myRoot)
    if not VDRAW then return end
    local vp = cam.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local nowT = os.clock()
    local lite = CFG.LiteESP == true

    -- ИГРОКИ: скелет, HP, кольцо, вектор, рамка головы, стрелки
    local idx = 0
    for tPlr, e in pairs(by) do
        idx = idx + 1
        if idx > VMAX then break end
        local ch = e.char
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        local p = vpool[idx]
        local show = (e.vis ~= false)
        local color = roleColor(e.role)

        -- СКЕЛЕТ: дальше SkelMinDist, мёртвые не рисуются.
        local skelOn = false
        if CFG.Skeleton and show and ch and ch.Parent then
            local humS = ch:FindFirstChildOfClass("Humanoid")
            local alive = (not humS) or humS.Health > 0
            local far = true
            if root and cam and cam.CFrame then
                far = (root.Position - cam.CFrame.Position).Magnitude
                    >= (tonumber(CFG.SkelMinDist) or 12)
            end
            skelOn = alive and far
        end
        if skelOn then
            local parts = {
                ch:FindFirstChild("Head"),
                ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso"),
                ch:FindFirstChild("LowerTorso") or ch:FindFirstChild("Torso"),
                ch:FindFirstChild("LeftUpperArm") or ch:FindFirstChild("Left Arm"),
                ch:FindFirstChild("RightUpperArm") or ch:FindFirstChild("Right Arm"),
                ch:FindFirstChild("LeftUpperLeg") or ch:FindFirstChild("Left Leg") or ch:FindFirstChild("LeftLeg"),
                ch:FindFirstChild("RightUpperLeg") or ch:FindFirstChild("Right Leg") or ch:FindFirstChild("RightLeg"),
            }
            local pts = {}
            for i = 1, 7 do
                local sp = parts[i] and vProj(cam, parts[i].Position)
                pts[i] = (sp and sp.Z > 0) and Vector2.new(sp.X, sp.Y) or nil
            end
            local thick = math.max(1, tonumber(CFG.SkeletonThick) or 1)
            for i = 1, 6 do
                local l = p.skeleton[i]
                if not l then
                    l = vLine()
                    p.skeleton[i] = l
                end
                local a = pts[SKEL_LINKS[i][1]]
                local b = pts[SKEL_LINKS[i][2]]
                if a and b then
                    vSetLine(l, a, b, color, thick)
                else
                    vHideLine(l)
                end
            end
        else
            for i = 1, #p.skeleton do vHideLine(p.skeleton[i]) end
        end

        -- ПОЛОСКА HP: подложка, рамка, плавная заливка с градиентом
        -- и белой вспышкой в момент урона.
        if CFG.HealthBars and show and ch and ch.Parent then
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local head = ch:FindFirstChild("Head")
            if hum and head and hum.Health > 0 then
                local sp = vProj(cam, head.Position + Vector3.new(0, 0.5, 0))
                if sp and sp.Z > 0 then
                    local maxHp = tonumber(hum.MaxHealth) or 100
                    if maxHp <= 0 then maxHp = 100 end
                    local hpPct = math.clamp(hum.Health / maxHp, 0, 1)
                    local cur = hpSmooth[tPlr]
                    if cur == nil then
                        cur = hpPct
                    else
                        cur = cur + (hpPct - cur) * 0.2
                    end
                    hpSmooth[tPlr] = cur
                    local prevHp = hpPrev[tPlr]
                    if prevHp ~= nil and hpPct < prevHp - 0.001 then
                        hpFlash[tPlr] = nowT
                    end
                    hpPrev[tPlr] = hpPct

                    local w = tonumber(CFG.HealthBarWidth) or 40
                    local h = tonumber(CFG.HealthBarHeight) or 4
                    local x = sp.X - w * 0.5
                    local y = sp.Y - 18
                    if p.hpBg then
                        p.hpBg.Position = Vector2.new(x, y)
                        p.hpBg.Size = Vector2.new(w, h)
                        p.hpBg.Color = Color3.new(0, 0, 0)
                        p.hpBg.Filled = not lite
                        p.hpBg.Transparency = 0.35
                        p.hpBg.Visible = true
                    end
                    if p.hpBorder and not lite then
                        p.hpBorder.Position = Vector2.new(x - 1, y - 1)
                        p.hpBorder.Size = Vector2.new(w + 2, h + 2)
                        p.hpBorder.Color = Color3.new(1, 1, 1)
                        p.hpBorder.Filled = false
                        p.hpBorder.Thickness = 1
                        p.hpBorder.Transparency = 0.45
                        p.hpBorder.Visible = true
                    else
                        vHideSquare(p.hpBorder)
                    end
                    if p.hpFg then
                        local barCol
                        if CFG.HPGradient ~= false then
                            if hpPct > 0.5 then
                                local k = (hpPct - 0.5) * 2
                                barCol = Color3.fromRGB(80, 220, 110):Lerp(
                                    Color3.fromRGB(255, 205, 70), 1 - k)
                            else
                                local k = hpPct * 2
                                barCol = Color3.fromRGB(255, 205, 70):Lerp(
                                    Color3.fromRGB(255, 80, 80), 1 - k)
                            end
                        elseif hpPct > 0.5 then
                            barCol = Color3.fromRGB(80, 220, 110)
                        elseif hpPct > 0.25 then
                            barCol = Color3.fromRGB(255, 205, 70)
                        else
                            barCol = Color3.fromRGB(255, 80, 80)
                        end
                        local fl = hpFlash[tPlr]
                        if fl and (nowT - fl) < 0.18 then
                            barCol = Color3.new(1, 1, 1)
                        end
                        p.hpFg.Position = Vector2.new(x, y)
                        p.hpFg.Size = Vector2.new(math.max(1, w * cur), h)
                        p.hpFg.Color = barCol
                        p.hpFg.Filled = true
                        p.hpFg.Visible = true
                    end
                    if p.hpText then
                        if CFG.HPBarText then
                            p.hpText.Text = tostring(math.floor(hum.Health + 0.5))
                            p.hpText.Size = 12
                            p.hpText.Color = Color3.new(1, 1, 1)
                            p.hpText.Center = true
                            p.hpText.Outline = true
                            p.hpText.Position = Vector2.new(sp.X, y - 3)
                            p.hpText.Visible = true
                        else
                            vHideText(p.hpText)
                        end
                    end
                else
                    vHideSquare(p.hpBg); vHideSquare(p.hpBorder)
                    vHideSquare(p.hpFg); vHideText(p.hpText)
                end
            else
                vHideSquare(p.hpBg); vHideSquare(p.hpBorder)
                vHideSquare(p.hpFg); vHideText(p.hpText)
            end
        else
            vHideSquare(p.hpBg); vHideSquare(p.hpBorder)
            vHideSquare(p.hpFg); vHideText(p.hpText)
        end

        -- КОЛЬЦО ПОД ЦЕЛЬЮ: точка земли ищется рейкастом вниз; кольцо
        -- только когда цель стоит на земле (под прыгающими висело
        -- в воздухе) и не ближе/дальше порога; вблизи радиус ограничен.
        do
            local mvRoot = (show and ch and ch.Parent)
                and ch:FindFirstChild("HumanoidRootPart") or nil
            local spRing, spRing2
            -- Рейкаст земли нужен только кольцу; mvRoot дальше
            -- использует вектор движения — его не гасим.
            if mvRoot and CFG.GroundRing then
                local feet
                local okF, hitF = pcall(function()
                    GROUND_FILTER[1] = ch
                    GROUND_RAY.FilterDescendantsInstances = GROUND_FILTER
                    return workspace:Raycast(
                        mvRoot.Position, Vector3.new(0, -8, 0), GROUND_RAY)
                end)
                if okF and hitF then
                    feet = hitF.Position
                else
                    feet = mvRoot.Position - Vector3.new(0, 3, 0)
                end
                -- v1.3: Enum.FloorMaterial отсутствует в песочнице части
                -- исполнителей ("FloorMaterial is not a valid member of
                -- Enum") — эта строка роняла ВЕСЬ кадр VIS: часть игроков
                -- успевала отрисоваться, часть нет, стрелки не доходили,
                -- скелеты залипали. Сравниваем по имени без Enum.X.
                local mHum = ch:FindFirstChildOfClass("Humanoid")
                local grounded = false
                if mHum then
                    local okFM, fm = pcall(function()
                        return mHum.FloorMaterial
                    end)
                    grounded = okFM and typeof(fm) == "EnumItem"
                        and fm.Name ~= "Air"
                end
                spRing = vProj(cam, feet)
                if spRing and spRing.Z > 0 and spRing.Z < 180 and grounded then
                    spRing2 = vProj(cam, feet + cam.CFrame.RightVector * 1.6)
                end
            end
            if CFG.GroundRing and p.groundRing then
                if spRing and spRing.Z > 0 and spRing2 and spRing2.Z > 0 then
                    local rr = math.min(math.abs(spRing2.X - spRing.X), 90)
                    if rr >= 4 then
                        p.groundRing.Position = Vector2.new(spRing.X, spRing.Y)
                        p.groundRing.Radius = rr
                        p.groundRing.Color = color
                        p.groundRing.Thickness = lite and 1 or 2
                        p.groundRing.NumSides = lite and 10 or 16
                        p.groundRing.Transparency = 0.35
                        p.groundRing.Visible = true
                    else
                        p.groundRing.Visible = false
                    end
                else
                    p.groundRing.Visible = false
                end
            elseif p.groundRing then
                p.groundRing.Visible = false
            end
            -- ВЕКТОР ДВИЖЕНИЯ: куда бежит цель.
            local spA, spB
            if CFG.MoveVec and mvRoot then
                spA = vProj(cam, mvRoot.Position)
                if spA and spA.Z > 0 and spA.Z < 160 then
                    local vel = mvRoot.AssemblyLinearVelocity
                    if vel and vel.Magnitude > 4 then
                        spB = vProj(cam, mvRoot.Position + vel * 0.45)
                    end
                end
            end
            if spA and spB and spB.Z > 0 then
                local a2 = Vector2.new(spA.X, spA.Y)
                local b2 = Vector2.new(spB.X, spB.Y)
                if not lite then
                    vSetLine(p.moveOut, a2, b2, Color3.new(0, 0, 0), 3)
                    if p.moveOut then p.moveOut.Transparency = 0.6 end
                else
                    vHideLine(p.moveOut)
                end
                vSetLine(p.moveVec, a2, b2, color, lite and 1 or 2)
                local dx, dy = b2.X - a2.X, b2.Y - a2.Y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 6 then
                    local ux, uy = dx / len, dy / len
                    vSetLine(p.moveH1, b2, Vector2.new(
                        b2.X - (ux * 7 - uy * 4), b2.Y - (uy * 7 + ux * 4)),
                        color, 1)
                    vSetLine(p.moveH2, b2, Vector2.new(
                        b2.X - (ux * 7 + uy * 4), b2.Y - (uy * 7 - ux * 4)),
                        color, 1)
                else
                    vHideLine(p.moveH1); vHideLine(p.moveH2)
                end
            else
                vHideLine(p.moveOut); vHideLine(p.moveVec)
                vHideLine(p.moveH1); vHideLine(p.moveH2)
            end
        end

        -- РАМКА ВОКРУГ ГОЛОВЫ.
        if CFG.HeadBox and show and ch and ch.Parent then
            local head = ch:FindFirstChild("Head")
            if head then
                local sp = vProj(cam, head.Position)
                if sp and sp.Z > 0 then
                    local sz = tonumber(CFG.HeadBoxSize) or 22
                    if p.headBox then
                        p.headBox.Position = Vector2.new(sp.X - sz * 0.5, sp.Y - sz * 0.5)
                        p.headBox.Size = Vector2.new(sz, sz)
                        local hbCol = color
                        if CFG.HeadBoxRole == false then
                            hbCol = safeColor(CFG.HeadBoxColor, Color3.new(1, 0, 0))
                        end
                        p.headBox.Color = hbCol
                        p.headBox.Filled = false
                        p.headBox.Visible = true
                    end
                else
                    vHideSquare(p.headBox)
                end
            else
                vHideSquare(p.headBox)
            end
        else
            vHideSquare(p.headBox)
        end

        -- СТРЕЛКА К ИГРОКУ (snapline). Себе не рисуем.
        local isLocal = (tPlr == LP)
        if CFG.Snaplines ~= false and show and not isLocal and root and root.Parent then
            local sp = vProj(cam, root.Position + Vector3.new(0, 2, 0))
            if sp and sp.Z > 0 then
                drawSnapArrow(p,
                    screenOrigin(CFG.SnapFrom, cx, cy, vp),
                    Vector2.new(sp.X, sp.Y),
                    color,
                    tonumber(CFG.SnapArrowThick) or 2,
                    math.clamp(tonumber(CFG.SnapAlpha) or 1, 0, 1))
            else
                hideSnapArrow(p)
            end
        else
            hideSnapArrow(p)
        end

        -- СТРЕЛКА У КРАЯ ЭКРАНА (цель за кадром/за спиной).
        if CFG.OffArrows and show and not isLocal
           and ch and ch.Parent and root and root.Parent then
            local sp = vProj(cam, root.Position)
            local onScreen = sp and sp.Z > 0
                and sp.X >= 0 and sp.X <= vp.X and sp.Y >= 0 and sp.Y <= vp.Y
            if not onScreen then
                local dir
                if sp and sp.Z > 0 then
                    dir = Vector2.new(sp.X - cx, sp.Y - cy)
                else
                    -- За камерой WorldToViewportPoint даёт зеркальные
                    -- координаты — берём систему координат камеры.
                    local okL, rel = pcall(function()
                        return cam.CFrame:PointToObjectSpace(root.Position)
                    end)
                    if okL and rel then
                        dir = Vector2.new(rel.X, -rel.Y)
                    else
                        dir = Vector2.new(0, 1)
                    end
                end
                local mag = dir.Magnitude
                if mag < 0.001 then dir = Vector2.new(0, -1); mag = 1 end
                local ux, uy = dir.X / mag, dir.Y / mag
                local margin = 34
                local reach = math.min(cx, cy) - margin
                if reach < 10 then reach = 10 end
                -- На крошечном вьюпорте max<min — clamp бы упал.
                local maxX = math.max(margin, vp.X - margin)
                local maxY = math.max(margin, vp.Y - margin)
                local ax = math.clamp(cx + ux * reach, margin, maxX)
                local ay = math.clamp(cy + uy * reach, margin, maxY)
                drawEdgeArrow(p, Vector2.new(ax, ay), ux, uy, color, 3,
                    math.clamp(tonumber(CFG.SnapAlpha) or 1, 0, 1))
            else
                hideEdgeArrow(p)
            end
        else
            hideEdgeArrow(p)
        end
    end

    -- Гасим слоты ушедших игроков.
    local usedSlots = math.min(idx, VMAX)
    for k = usedSlots + 1, #vpool do
        local pOld = vpool[k]
        if pOld then
            vHideSquare(pOld.hpBg); vHideSquare(pOld.hpBorder)
            vHideSquare(pOld.hpFg); vHideText(pOld.hpText)
            vHideSquare(pOld.headBox)
            hideSnapArrow(pOld)
            hideEdgeArrow(pOld)
            vHideLine(pOld.moveOut); vHideLine(pOld.moveVec)
            vHideLine(pOld.moveH1); vHideLine(pOld.moveH2)
            if pOld.groundRing then pOld.groundRing.Visible = false end
            if pOld.skeleton then
                for i = 1, #pOld.skeleton do vHideLine(pOld.skeleton[i]) end
            end
        end
    end

    -- МИНИКАРТА: точки игроков относительно себя.
    if CFG.Minimap and myRoot and minimapBg then
        local size = tonumber(CFG.MinimapSize) or 160
        local mx, my = vp.X - size - 20, 20
        minimapBg.Position = Vector2.new(mx, my)
        minimapBg.Size = Vector2.new(size, size)
        minimapBg.Color = Color3.new(0, 0, 0)
        minimapBg.Filled = true
        minimapBg.Transparency = 0.5
        minimapBg.Visible = true
        if minimapBorder then
            minimapBorder.Position = Vector2.new(mx, my)
            minimapBorder.Size = Vector2.new(size, size)
            minimapBorder.Color = Color3.new(1, 1, 1)
            minimapBorder.Filled = false
            minimapBorder.Thickness = 1
            minimapBorder.Visible = true
        end
        local scale = 0.5
        local cx0, cy0 = mx + size * 0.5, my + size * 0.5
        if minimapSelf then
            minimapSelf.Position = Vector2.new(cx0, cy0)
            minimapSelf.Radius = 3
            minimapSelf.Color = Color3.new(0, 1, 0)
            minimapSelf.Filled = true
            minimapSelf.Visible = CFG.MinimapSelf ~= false
        end
        local dotIdx = 0
        for _, e in pairs(by) do
            local ch = e.char
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            if root and root.Parent then
                local rel = root.Position - myRoot.Position
                local px = cx0 + rel.X * scale
                local py = cy0 + rel.Z * scale
                if px >= mx and px <= mx + size and py >= my and py <= my + size then
                    dotIdx = dotIdx + 1
                    if dotIdx <= 20 then
                        local d = minimapDots[dotIdx]
                        if not d then d = vCircle(); minimapDots[dotIdx] = d end
                        if d then
                            d.Position = Vector2.new(px, py)
                            d.Radius = 3
                            d.Color = roleColor(e.role)
                            d.Filled = true
                            d.Visible = true
                        end
                    end
                end
            end
        end
        for i = dotIdx + 1, #minimapDots do vHideCircle(minimapDots[i]) end
    else
        vHideSquare(minimapBg)
        vHideSquare(minimapBorder)
        vHideCircle(minimapSelf)
        for _, d in pairs(minimapDots) do vHideCircle(d) end
    end

    -- Очистка данных ушедших игроков.
    for plr in pairs(hpSmooth) do
        if not by[plr] then
            hpSmooth[plr] = nil
            hpPrev[plr] = nil
            hpFlash[plr] = nil
        end
    end
end
end -- VIS

-- ============================================================
--  РОЛИ: охрана / зек / преступник / прочий
-- ============================================================
local TEAM_GUARD = { "guard", "cop", "police", "охра", "охран", "тюремщ" }
local TEAM_CRIM  = { "crim", "escaped", "escap", "побег", "преступ", "villain", "злоде" }
local TEAM_PRIS  = { "pris", "зек", "inmate", "заключ" }

-- UserId админов, вшитые в LocalScript админ-панели игры (u45) +
-- создатель игры (CreatorId). Команда «Escaped» в Teams — это и есть
-- преступники (бывшая кнопка «Criminal» звала несуществующую команду).
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

local function nameHasRole(n, list)
    for _, k in ipairs(list) do
        if string.find(n, k, 1, true) then return true end
    end
    return false
end

local function roleOf(plr)
    -- 1. Команда (Teams создаются рантайм).
    local t = plr.Team
    local tn = t and string.lower(t.Name) or ""
    if tn ~= "" then
        if nameHasRole(tn, TEAM_GUARD) then return "guard" end
        if nameHasRole(tn, TEAM_CRIM) then return "criminal" end
        if nameHasRole(tn, TEAM_PRIS) then return "prisoner" end
    end
    -- 2. Атрибуты игрока.
    local crim = plr:GetAttribute("Criminal")
    if crim == true then return "criminal" end
    local g = plr:GetAttribute("Guard") or plr:GetAttribute("IsGuard")
    if g == true then return "guard" end
    -- 3. Инструменты: наручники/тазер = охрана.
    local function hasTool(name)
        local bp = plr:FindFirstChild("Backpack")
        if bp then
            for _, tt in ipairs(bp:GetChildren()) do
                if tt:IsA("Tool") and tt.Name == name then return true end
            end
        end
        local ch = plr.Character
        if ch then
            for _, tt in ipairs(ch:GetChildren()) do
                if tt:IsA("Tool") and tt.Name == name then return true end
            end
        end
        return false
    end
    if hasTool("Handcuffs") or hasTool("Taser") then return "guard" end
    -- 4. Пуша в рюкзаке + нет наручников = скорее преступник.
    local bp = plr:FindFirstChild("Backpack")
    if bp then
        for _, tt in ipairs(bp:GetChildren()) do
            if tt:IsA("Tool") and tt:FindFirstChild("GunScript_Server") then
                return "criminal"
            end
        end
    end
    return "other"
end
G.PE.TeamOf = function(p) return roleOf(p) end

-- ============================================================
--  ДОБАВЛЕНИЕ / УДАЛЕНИЕ ИГРОКОВ
-- ============================================================
-- Троттлы на игрока (поджог/подброс). Слабые ключи: ушедшие игроки
-- не копятся, при выходе чистим руками для мгновенности.
local PE_BURN_AT = setmetatable({}, { __mode = "k" })
local PE_FLING_AT = setmetatable({}, { __mode = "k" })

local function removePlayer(plr)
    local e = by[plr]
    if not e then return end
    if e.gui then pcall(function() e.gui:Destroy() end) end
    destroyBox(e.box)
    by[plr] = nil
    PE_BURN_AT[plr] = nil
    PE_FLING_AT[plr] = nil
end

local function addPlayer(plr)
    local ch = plr.Character
    if not ch or by[plr] then return end
    local gui, lbl = makeBillboard()
    if not gui or not lbl then return end
    -- Плашка: тёмная, с закруглёнными углами и рамкой в цвете роли.
    lbl.Size                   = UDim2.new(0, 0, 0, 20)
    lbl.AutomaticSize          = Enum.AutomaticSize.X
    lbl.AnchorPoint            = Vector2.new(0.5, 0.5)
    lbl.Position               = UDim2.new(0.5, 0, 0.5, 0)
    lbl.BackgroundColor3       = Color3.new(0, 0, 0)
    lbl.BackgroundTransparency = 0.45
    lbl.BorderSizePixel        = 1
    lbl.BorderColor3           = Color3.new(1, 1, 1)
    lbl.TextSize               = tonumber(CFG.LabelSize) or 13
    lbl.Font                   = Enum.Font.GothamMedium
    lbl.TextStrokeTransparency = 0.5
    lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
    lbl.TextColor3             = Color3.new(1, 1, 1)
    lbl.Text                   = ""
    lbl.Visible                = false
    lbl.Parent                 = gui
    pcall(function()
        if not lbl:FindFirstChildOfClass("UICorner") then
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 7)
            c.Parent = lbl
        end
    end)
    gui.Adornee = ch
    by[plr] = {
        char = ch, gui = gui, lbl = lbl,
        role = roleOf(plr), roleAt = os.clock(),
        box = nil, vis = false,
    }
end

local paConn = Players.PlayerAdded:Connect(function(plr)
    if STOPPED then return end
    task.defer(function() addPlayer(plr) end)
end)
local prConn = Players.PlayerRemoving:Connect(function(plr)
    removePlayer(plr)
end)

-- АВТО-ГИВЕР: после респавна сам выдаём выбранное оружие (если сервер
-- не выдал ничего сам).
local giveConn = LP.CharacterAdded:Connect(function()
    if STOPPED or not CFG.AutoGive then return end
    task.wait(1.5)
    if STOPPED or not CFG.AutoGive then return end
    local chr = LP.Character
    if not chr then return end
    if chr:FindFirstChildOfClass("Tool") then return end
    if CFG.AutoGiveName == "GIVE ALL" then
        G.PE.GiveAll()
    else
        G.PE.Give(CFG.AutoGiveName)
    end
    print("[PE GIVE] auto-gave " .. tostring(CFG.AutoGiveName)
        .. " after respawn")
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

-- МГНОВЕННЫЙ РЕВАЙН: на смерть — сброс в меню и возврат в команду.
local diedConn = LP.CharacterAdded:Connect(function(ch)
    local humR = ch:WaitForChild("Humanoid", 10)
    if humR then
        humR.Died:Connect(function()
            if STOPPED or not CFG.FastRespawn then return end
            local team = LP.Team and LP.Team.Name
            task.wait(0.3)
            local r = ReplicatedStorage:FindFirstChild("ResetToMenuEvent")
            if r then
                pcall(function() r:FireServer() end)
                print("[PE RESPAWN] instant rejoin (was " ..
                    tostring(team) .. ")")
            end
            if team and team ~= "Undecided" then
                task.wait(0.6)
                local ct = ReplicatedStorage:FindFirstChild("ChooseTeamEvent")
                if ct then
                    pcall(function() ct:FireServer(team) end)
                end
            end
        end)
    end
end)

-- ============================================================
--  ГЛАВНЫЙ ЦИКЛ ESP
-- ============================================================
local ROLE_TAG = {
    guard = "[GUARD]", prisoner = "[PRIS]", criminal = "[CRIM]",
}

mainConn = RunService.RenderStepped:Connect(function()
    if STOPPED then return end
    local ok, err = pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local myRoot = LP.Character
            and LP.Character:FindFirstChild("HumanoidRootPart")

        -- Ленивое добавление: покрывает и вход новых игроков.
        for _, plr in ipairs(Players:GetPlayers()) do
            if not by[plr] and plr.Character then
                addPlayer(plr)
            end
        end

        local nowT = os.clock()
        for plr, e in pairs(by) do
            if not plr.Parent then
                removePlayer(plr)
            elseif not plr.Character or not plr.Character.Parent then
                e.vis = false
                if e.lbl then e.lbl.Visible = false end
                hideBox(e.box)
            else
                local ch = plr.Character
                -- Респавн: обновляем персонажа и коробку.
                if e.char ~= ch then
                    e.char = ch
                    e.role = roleOf(plr)
                    e.admin = isAdminP(plr)
                    e.roleAt = nowT
                    e.lastHP = nil
                    destroyBox(e.box)
                    e.box = nil
                    if e.gui then e.gui.Adornee = ch end
                end
                -- Роль обновляем раз в 0.7 с (команды меняются рантайм).
                if nowT - (e.roleAt or 0) > 0.7 then
                    e.roleAt = nowT
                    e.role = roleOf(plr)
                    e.admin = isAdminP(plr)
                    if e.admin and not e.adminWarned then
                        e.adminWarned = true
                        warn("[PE] ADMIN ON SERVER: " .. plr.Name
                            .. " (userId " .. plr.UserId .. ") - be careful!")
                        pcall(function()
                            Rayfield:Notify({ Title = "ADMIN ON SERVER",
                                Content = plr.Name .. " (userId "
                                    .. plr.UserId .. ")",
                                Duration = 10 })
                        end)
                    end
                end

                if not (e.gui and e.gui.Parent and e.lbl) then
                    -- Плашку уничтожили (респавн/чистка) — пересоздать.
                    removePlayer(plr)
                else
                    local role = e.role
                    local vis, color
                    if e.admin then
                        -- Админ: всегда заметен, магента поверх роли.
                        vis = CFG.AdminESP ~= false
                        color = Color3.fromRGB(255, 0, 255)
                    elseif role == "guard" then
                        vis = CFG.GuardESP ~= false
                        color = safeColor(CFG.ColGuard, Color3.new(0.3, 0.7, 1))
                    elseif role == "prisoner" then
                        vis = CFG.PrisonerESP ~= false
                        color = safeColor(CFG.ColPris, Color3.new(1, 0.65, 0.25))
                    elseif role == "criminal" then
                        vis = CFG.CriminalESP ~= false
                        color = safeColor(CFG.ColCrim, Color3.new(1, 0.2, 0.2))
                    else
                        vis = CFG.PlayerESP ~= false
                        color = safeColor(CFG.ColOther, Color3.new(0.8, 0.8, 0.8))
                    end
                    -- Свой персонаж: ESP не рисуем совсем (круг под
                    -- ногами и скелет на себе не нужны).
                    if plr == LP then vis = false end

                    local root = ch:FindFirstChild("HumanoidRootPart")
                    if root and myRoot and (tonumber(CFG.MaxDist) or 0) > 0 then
                        local d = (root.Position - myRoot.Position).Magnitude
                        if d > (tonumber(CFG.MaxDist) or 0) then vis = false end
                    end

                    -- За спиной ESP не рисуем.
                    if root and cam then
                        local spB = cam:WorldToViewportPoint(root.Position)
                        if spB.Z <= 0 then vis = false end
                    end

                    -- Мёртвых прячем.
                    local humNow = ch:FindFirstChildOfClass("Humanoid")
                    if humNow then
                        if humNow.Health <= 0 and CFG.HideDead ~= false then
                            vis = false
                        end
                    else
                        vis = false
                    end

                    -- Звук убийства: цель ауры умерла — бип (локально).
                    if CFG.KillSound and humNow then
                        local hp = humNow.Health
                        if e.lastHP and e.lastHP > 0 and hp <= 0 then
                            pcall(function()
                                local snd = Instance.new("Sound")
                                snd.SoundId = "rbxassetid://186809061"
                                snd.Volume = 0.5
                                snd.Parent = game:GetService("SoundService")
                                snd:Play()
                                game:GetService("Debris"):AddItem(snd, 3)
                            end)
                        end
                        e.lastHP = hp
                    end

                    e.vis = vis
                    if e.gui.Enabled ~= vis then e.gui.Enabled = vis end

                    if vis then
                        -- Текст лейбла собираем 10 раз/сек, не каждый
                        -- кадр: ~25M аллокаций/час уходило на строки.
                        if nowT - (e.lblAt or 0) > 0.1 then
                            e.lblAt = nowT
                            local parts = {}
                            if e.admin then
                                parts[#parts + 1] = "[ADMIN]"
                            end
                            if CFG.RoleTags then
                                local tag = ROLE_TAG[role]
                                if tag then parts[#parts + 1] = tag end
                            end
                            if CFG.WeaponESP then
                                local tool = ch:FindFirstChildOfClass("Tool")
                                if tool then
                                    parts[#parts + 1] = "[" .. tool.Name .. "]"
                                end
                            end
                            if CFG.Names then
                                parts[#parts + 1] = plr.DisplayName
                            end
                            if CFG.ShowDist and root and myRoot then
                                parts[#parts + 1] = math.floor(
                                    (root.Position - myRoot.Position).Magnitude
                                        + 0.5) .. " st"
                            end
                            if CFG.ShowHP and humNow then
                                if CFG.HPPercent
                                   and (humNow.MaxHealth or 0) > 0 then
                                    parts[#parts + 1] = string.format("HP %d%%",
                                        math.floor(humNow.Health
                                            / humNow.MaxHealth * 100 + 0.5))
                                else
                                    parts[#parts + 1] = "HP "
                                        .. math.floor(humNow.Health + 0.5)
                                end
                            end
                            if CFG.ShowSpeed and root then
                                local spd = root.AssemblyLinearVelocity
                                parts[#parts + 1] =
                                    math.floor(spd.Magnitude + 0.5) .. " st/s"
                            end
                            local txt = table.concat(parts, "  ")
                            if e.lbl.Text ~= txt then e.lbl.Text = txt end
                        end
                        local ts = tonumber(CFG.LabelSize) or 13
                        if e.lbl.TextSize ~= ts then
                            e.lbl.TextSize = ts
                            e.lbl.Size = UDim2.new(0, 0, 0, ts + 8)
                        end
                        local labelColor = color
                        if CFG.NameHPColor and humNow and (humNow.MaxHealth or 0) > 0 then
                            local hp01 = math.clamp(humNow.Health / humNow.MaxHealth, 0, 1)
                            if hp01 > 0.5 then
                                labelColor = Color3.new(1, 1, 1):Lerp(Color3.new(1, 1, 0), (1 - hp01) * 2)
                            else
                                labelColor = Color3.new(1, 1, 0):Lerp(Color3.new(1, 0, 0), 1 - hp01 * 2)
                            end
                        end
                        if e.lbl.TextColor3 ~= labelColor then
                            e.lbl.TextColor3 = labelColor
                        end
                        if e.lbl.BorderColor3 ~= color then
                            e.lbl.BorderColor3 = color
                        end
                        if not e.lbl.Visible then e.lbl.Visible = true end

                        if CFG.Boxes then
                            if not e.box then e.box = makeBox() end
                            if e.box and root then
                                e.box.color = color
                                pcall(drawBox, e.box, root, cam)
                            end
                        elseif e.box then
                            hideBox(e.box)
                        end
                    else
                        e.lbl.Visible = false
                        hideBox(e.box)
                    end
                end
            end
        end

        -- Дополнительные визуалы (скелет/HP/стрелки/кольцо/миникарта).
        -- Ошибку кадра печатаем (не чаще раза в 5 с), а не глотаем:
        -- как выяснилось на меню, молчаливый pcall прячет причину.
        local okV, errV = pcall(VIS.update, cam, myRoot)
        if not okV and os.clock() - (CFG._visErrAt or 0) > 5 then
            CFG._visErrAt = os.clock()
            warn("[PE VIS] frame error: " .. tostring(errV))
        end
    end)
    if not ok and os.clock() - (CFG._frameErrAt or 0) > 5 then
        CFG._frameErrAt = os.clock()
        warn("[PE] ESP frame: " .. tostring(err))
    end
end)

-- ============================================================
--  ПРЕДМЕТЫ НА ЗЕМЛЕ: пушки с "Item Give script", ключи, патроны.
-- ============================================================
local ITEM_NAMES = {
    "AK-74", "M16a4 MOD", "M9", "MP5 Short", "SVD", "Kord", "MG42",
    "PPSH-41", "Hammer", "KeyCard", "Ammo box",
}
local ITEM_COLORS = {
    KeyCard   = Color3.fromRGB(255, 230, 60),
    ["Ammo box"] = Color3.fromRGB(90, 220, 110),
    Hammer    = Color3.fromRGB(120, 200, 255),
}
local byItems = {}
local itemScanAt = 0
itemConn = RunService.Heartbeat:Connect(function()
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
                local hit = false
                for _, nm in ipairs(ITEM_NAMES) do
                    if m.Name == nm then hit = true break end
                end
                if hit then
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
                        local col = ITEM_COLORS[m.Name] or Color3.fromRGB(255, 170, 0)
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

-- ОПАСНЫЕ ЗОНЫ: Death Part (убивает нас) и EscapePart (побег)
-- подсвечиваем через Highlight.
local DANGER_COLORS = {
    ["Death Part"] = Color3.fromRGB(255, 60, 60),
    EscapePart     = Color3.fromRGB(120, 255, 140),
}
local byDanger = {}
local dangerScanAt = 0
local dangerFullAt = 0
dangerConn = RunService.Heartbeat:Connect(function()
    if STOPPED then return end
    if not CFG.DangerESP then
        for k, h in pairs(byDanger) do
            pcall(function() h:Destroy() end)
            byDanger[k] = nil
        end
        return
    end
    local now = os.clock()
    if now - dangerScanAt < 1 then return end
    dangerScanAt = now
    pcall(function()
        -- Полный обход дерева (13k+ инстансов) раз в 12 с; между
        -- обходами только проверяем, что найденные ещё живы.
        local full = now - dangerFullAt > 12
        if full then dangerFullAt = now end
        local seen = {}
        if full then
            for _, m in ipairs(workspace:GetDescendants()) do
                local col
                if m:IsA("BasePart") then
                    col = DANGER_COLORS[m.Name]
                    -- Невидимые коллизионные стены: периметр тюрьмы
                    -- невидим (Smooth Block Model, Tr 0.95) — на флай
                    -- в него врезаются. Подсвечиваем голубым.
                    if not col and CFG.InvisWall
                       and m.Name == "Smooth Block Model"
                       and m.CanCollide and m.Transparency >= 0.9
                       and (m.Size.X + m.Size.Y + m.Size.Z) >= 25 then
                        col = Color3.fromRGB(160, 200, 255)
                    end
                end
                if col then
                    seen[m] = true
                    local h = byDanger[m]
                    if not h or not h.Parent then
                        local ok, nh = pcall(function()
                            return Instance.new("Highlight") end)
                        if ok and nh then
                            nh.Adornee = m
                            nh.Parent = m
                            nh.FillTransparency = 0.45
                            byDanger[m] = nh
                            h = nh
                        end
                    end
                    if h then
                        h.FillColor = col
                        h.OutlineColor = col
                        h.Enabled = true
                    end
                end
            end
        else
            for k in pairs(byDanger) do seen[k] = true end
        end
        for k, h in pairs(byDanger) do
            if not seen[k] or not k.Parent then
                pcall(function() h:Destroy() end)
                byDanger[k] = nil
            end
        end
    end)
end)

-- ЧАМСЫ: Highlight на каждом персонаже, цвет по роли, сквозь стены.
local byChams = setmetatable({}, { __mode = "k" })
-- ВАЖНО: без `local` — коннект должен лечь в переменную, объявленную
-- строкой 254. Иначе PE_Stop отключает nil, а этот Heartbeat остаётся
-- жить после стопа (второй экземпляр после рестарта чистит Highlight'ы
-- у нового).
chamsConn = RunService.Heartbeat:Connect(function()
    if STOPPED then return end
    if not CFG.Chams then
        if next(byChams) then
            for _, h in pairs(byChams) do
                pcall(function() h:Destroy() end)
            end
            byChams = setmetatable({}, { __mode = "k" })
        end
        return
    end
    local nowC = os.clock()
    if nowC - (chamsScanAt or 0) < 0.5 then return end
    chamsScanAt = nowC
    pcall(function()
        local seen = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and p.Character.Parent then
                local chC = p.Character
                seen[chC] = true
                local h = byChams[chC]
                if not h or not h.Parent then
                    local ok, nh = pcall(function()
                        local hl = Instance.new("Highlight")
                        hl.FillTransparency = 0.7
                        hl.OutlineTransparency = 0
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = chC
                        return hl
                    end)
                    if ok and nh then
                        byChams[chC] = nh
                        h = nh
                    end
                end
                if h then
                    local col
                    if isAdminP(p) then
                        col = Color3.fromRGB(255, 0, 255)
                    else
                        local r = roleOf(p)
                        if r == "guard" then
                            col = safeColor(CFG.ColGuard, Color3.new(0.3, 0.7, 1))
                        elseif r == "prisoner" then
                            col = safeColor(CFG.ColPris, Color3.new(1, 0.65, 0.25))
                        elseif r == "criminal" then
                            col = safeColor(CFG.ColCrim, Color3.new(1, 0.2, 0.2))
                        else
                            col = safeColor(CFG.ColOther, Color3.new(0.8, 0.8, 0.8))
                        end
                    end
                    h.FillColor = col
                    h.OutlineColor = col
                    h.Enabled = true
                end
            end
        end
        for k, h in pairs(byChams) do
            if not seen[k] or not k.Parent then
                pcall(function() h:Destroy() end)
                byChams[k] = nil
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
local function findPlayer(namePart)
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

local function myGunRemote(remoteName)
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
            math.clamp(tonumber(CFG.KillAuraDamage) or 50, 1, 5000),
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
                if root and part and origCF
                   and (part.Position - root.Position).Magnitude > 60 then
                    root.CFrame = part.CFrame + Vector3.new(0, 4, 0)
                    teleported = true
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
            return false
        end
    end
    print("[PE GIVE] model '" .. tostring(itemName) .. "' not found on the ground")
    return false
end

G.PE.GiveAll = function()
    local n = 0
    for _, nm in ipairs(GIVE_ITEMS) do
        if G.PE.Give(nm) then n = n + 1 end
        task.wait(0.25)
    end
    print("[PE GIVE] items given: " .. n)
end

-- Открыть ВСЕ двери (включая камеры): Doorscript'ы на клик-детекторах.
-- ЗАМЕНА ТЕКСТУР удалена (v2.37) по запросу.

-- FPS-БУСТ: минимальное качество рендера + без глобальных теней.
-- Оригиналы сохраняем, чтобы RESTORE не затирал пользовательские.
local PE_FPS_ORIG = nil
G.PE.FPSBoost = function(on)
    pcall(function()
        if on then
            -- v2.53: сохраняем оригинал только ОДИН раз. Повторное
            -- включение затирало "оригинал" уже бустнутыми значениями и
            -- RESTORE возвращал Level01 вместо настроек пользователя.
            if not PE_FPS_ORIG then
                PE_FPS_ORIG = {
                    q = settings().Rendering.QualityLevel,
                    sh = game:GetService("Lighting").GlobalShadows,
                }
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            game:GetService("Lighting").GlobalShadows = false
            print("[PE FPS] boost ON (quality 1, shadows off)")
        else
            -- Буст не включали — ничего не трогаем (иначе PE_Stop
            -- сбрасывал графику пользователя на Automatic).
            if not PE_FPS_ORIG then return end
            settings().Rendering.QualityLevel = PE_FPS_ORIG.q
            game:GetService("Lighting").GlobalShadows = PE_FPS_ORIG.sh
            PE_FPS_ORIG = nil
            print("[PE FPS] boost OFF (defaults restored)")
        end
    end)
end

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

-- Сброс в меню: выход из наручников/ареста без смерти.
G.PE.ResetMenu = function()
    local r = ReplicatedStorage:FindFirstChild("ResetToMenuEvent")
    if not r or not r:IsA("RemoteEvent") then
        print("[PE MENU] ResetToMenuEvent not found")
        return
    end
    print("[PE MENU] ResetToMenuEvent:FireServer()")
    pcall(function() r:FireServer() end)
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
    -- Снайперский зум: E включает прицел (FOV из Setting.FieldOfView).
    if CFG.GunScope then
        S.SniperEnabled = true
        if not tonumber(S.FieldOfView) or S.FieldOfView >= 70 then
            S.FieldOfView = 18
        end
    end
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
local function targetAllowed(p, sel, myTeam)
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
local retAt = 0
local jpAt = 0
local PE_LAST_HP = -1
local PE_HIT_AT = 0
-- v2.53: части, у которых ИМЕННО МЫ выключили коллизию. При выключении
-- noclip возвращаем CanCollide только им — раньше ставили true всем
-- частям персонажа, включая шляпы/аксессуары, которым коллизия не нужна.
local noclipParts = setmetatable({}, { __mode = "k" })
local retTarget, retUntil = nil, 0

-- Поиск атакующего: кто вероятнее ударил/выстрелил — ближайший,
-- вооружённые получают приоритет (−30 стадов к счёту дистанции).
local function findAttacker(myRoot)
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
                local atk = findAttacker(rootR)
                if atk then
                    retTarget = atk
                    retUntil = now + 1.5
                    print("[PE RET] attacker: " .. atk.Name .. " -> BURN")
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
                local dmgR = math.clamp(
                    tonumber(CFG.KillAuraDamage) or 50, 1, 5000)
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

    -- СКОРОСТЬ/ПРЫЖОК: применяем раз в 0.25с; при выключении тумблера
    -- возвращаем Vanilla-значения ОДИН раз (флаг _moveWasOn).
    local humJ = LP.Character
        and LP.Character:FindFirstChildOfClass("Humanoid")
    if humJ then
        if now - jpAt >= 0.25 then
            jpAt = now
            pcall(function()
                -- v2.53: каждый эффект откатывается САМ, независимо от
                -- второго тумблера. Раньше SpeedHack-off при живом
                -- JumpBoost оставлял WalkSpeed 150 навсегда (и наоборот).
                if CFG.SpeedHack then
                    CFG._speedWasOn = true
                    humJ.WalkSpeed = math.clamp(
                        tonumber(CFG.SpeedValue) or 40, 16, 150)
                elseif CFG._speedWasOn then
                    CFG._speedWasOn = nil
                    humJ.WalkSpeed = 16
                    print("[PE] speed restored to default (16)")
                end
                if CFG.JumpBoost then
                    CFG._jumpWasOn = true
                    humJ.UseJumpPower = true
                    humJ.JumpPower = math.clamp(
                        tonumber(CFG.JumpPower) or 90, 50, 300)
                elseif CFG._jumpWasOn then
                    CFG._jumpWasOn = nil
                    humJ.UseJumpPower = true
                    humJ.JumpPower = 50
                    print("[PE] jump restored to default (50)")
                end
            end)
        end
    end

    -- NOCLIP: движок возвращает CanCollide на частях каждый физ-шаг,
    -- поэтому выключаем КАЖДЫЙ КАДР (а не раз в 0.25с) — иначе
    -- «работает через раз». При выключении включаем коллизии обратно.
    if CFG.Noclip then
        local chrN = LP.Character
        if chrN then
            for _, p in ipairs(chrN:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                    noclipParts[p] = true
                end
            end
        end
        CFG._noclipWasOn = true
    elseif CFG._noclipWasOn then
        CFG._noclipWasOn = nil
        -- Возвращаем коллизию ТОЛЬКО тем частям, которые сами гасили.
        for p in pairs(noclipParts) do
            if p.Parent then
                pcall(function() p.CanCollide = true end)
            end
        end
        noclipParts = setmetatable({}, { __mode = "k" })
        print("[PE] noclip off - collisions restored")
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

    -- ОГНЕННАЯ КИСТЬ: часть под курсором + ближайший враг-носитель.
    -- Каждые 0.35с обновляем огонь (Duration сервера конечен).
    if CFG.FirePaint and now - paintAt >= 0.35 then
        paintAt = now
        local remoteP = myGunRemote("InflictTarget")
        local mP = LP:GetMouse()
        local partP = mP and mP.Target
        if remoteP and partP and partP:IsA("BasePart")
           and partP:IsDescendantOf(workspace) then
            -- Носитель: ближайший живой враг (урон всего 1).
            local rootP2 = LP.Character
                and LP.Character:FindFirstChild("HumanoidRootPart")
            local carrier, carrierD
            for _, p2 in ipairs(Players:GetPlayers()) do
                if p2 ~= LP then
                    local ch2 = p2.Character
                    local h2 = ch2 and ch2:FindFirstChildOfClass("Humanoid")
                    local r2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")
                    if ch2 and h2 and h2.Health > 0 and r2
                       and not ch2:FindFirstChildOfClass("ForceField")
                       and not (LP.Character
                           and r2:IsDescendantOf(LP.Character)) then
                        -- Носитель: ближайший живой враг (урон всего 1).
                        local d2 = rootP2
                            and (r2.Position - rootP2.Position).Magnitude or 0
                        if targetAllowed(p2,
                               CFG.C00lTeam or "Everyone", LP.Team)
                           and (not carrierD or d2 < carrierD) then
                            carrier, carrierD = h2, d2
                        end
                    end
                end
            end
            if carrier then
                pcall(function()
                    remoteP:FireServer(carrier, partP, 1,
                        Vector3.new(0, 1, 0), 0, 0, true)
                end)
            elseif os.clock() - (CFG._noPaintWarnAt or 0) > 10 then
                CFG._noPaintWarnAt = os.clock()
                warn("[PE PAINT] no enemy alive to carry the fire")
            end
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
            if not perched then
                pcall(function()
                    rootA.Anchored = true
                    rootA.CFrame = CFG._apocPerchCF
                end)
            end
            -- Оружие: после респавна выпало — берём заново (первая
            -- выдача сразу, без 8-секундной отсрочки). Проверка пушки
            -- кэшируется на 0.5с: myGunRemote каждый кадр дорог.
            if not CFG._apocGunAt or now - CFG._apocGunAt >= 0.5 then
                CFG._apocGunAt = now
                CFG._apocHasGun = myGunRemote("InflictTarget") ~= nil
            end
            local hasGun = CFG._apocHasGun
            if not hasGun then
                if not CFG._apocGiveAt
                   or os.clock() - CFG._apocGiveAt > 8 then
                    CFG._apocGiveAt = os.clock()
                    G.PE.Give("M9")
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
                            if p2 ~= LP and hitsA < 20 then
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
    if CFG.Immortal then
        local chrI = LP.Character
        local humI = chrI and chrI:FindFirstChildOfClass("Humanoid")
        local rootI = chrI and chrI:FindFirstChild("HumanoidRootPart")
        local remoteI = myGunRemote("InflictTarget")
        if remoteI and humI and rootI and humI.Health > 0 then
            local damaged = humI.Health < humI.MaxHealth - 0.5
            if (damaged and now - immortalAt >= 0.1)
               or ((not damaged) and now - immortalAt >= 0.5) then
                immortalAt = now
                pcall(function()
                    remoteI:FireServer(humI, rootI, 0,
                        Vector3.new(0, 0, 1), 0, 1000000, false)
                end)
                if damaged and now - immortalTapAt >= 0.3 then
                    immortalTapAt = now
                    -- Ближайший живой враг без ForceField.
                    local bestP2, bestD2
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
                -- Бесконечный радиус: сервер дистанцию InflictTarget
                -- не проверяет (подтверждено c00lkidd-тестом).
                local inRange = CFG.AuraInfRange
                    or ((root.Position - myRoot.Position).Magnitude
                        <= radius)
                local ok = isSel
                    or ((mode == "Everyone" or mode == "") and inRange)
                if ok then
                    hits = hits + 1
                    -- Урон зажат на месте использования: сохранённые
                    -- консолью/прошлой сессией значения не спамят сервер.
                    local dmg = math.clamp(
                        tonumber(CFG.KillAuraDamage) or 50, 1, 5000)
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

-- ПОЛЁТ: каждый Heartbeat задаём скорость от камеры (WASD +
-- Space/Ctrl). Сервер видит только нашу позицию — физика клиентская.
flyConn = RunService.Heartbeat:Connect(function()
    if STOPPED or not PE_GUI_READY or not CFG.Fly then return end
    local chr = LP.Character
    local root = chr and chr:FindFirstChild("HumanoidRootPart")
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local move = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then
        move = move + cam.CFrame.LookVector
    end
    if UIS:IsKeyDown(Enum.KeyCode.S) then
        move = move - cam.CFrame.LookVector
    end
    if UIS:IsKeyDown(Enum.KeyCode.D) then
        move = move + cam.CFrame.RightVector
    end
    if UIS:IsKeyDown(Enum.KeyCode.A) then
        move = move - cam.CFrame.RightVector
    end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then
        move = move + Vector3.new(0, 1, 0)
    end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
        move = move - Vector3.new(0, 1, 0)
    end
    pcall(function()
        if move.Magnitude > 0.01 then
            root.AssemblyLinearVelocity = move.Unit
                * math.clamp(tonumber(CFG.FlySpeed) or 60, 10, 300)
        else
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end)

-- БЕСКОНЕЧНЫЙ ПРЫЖОК: каждый JumpRequest в воздухе перезапускает
-- Jumping-состояние (физика наша — сервер видит только позицию).
ijConn = UIS.JumpRequest:Connect(function()
    if STOPPED or not PE_GUI_READY or not CFG.InfJump then return end
    local hum = LP.Character
        and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end)

-- СПИН-БОТ удалён (v2.37) по запросу: при выключении AutoRotate
-- не возвращался и персонаж переставал поворачиваться.


-- ============================================================
--  GUI (Rayfield)
-- ============================================================
-- Грузим с запасными URL: основной сайт бывает недоступен,
-- тогда молчаливый pcall съедал ошибку и меню просто не появлялось.
local RF_URLS = {
    -- Наша копия Rayfield: окно сразу создаётся в PlayerGui (патч),
    -- а не в gethui-контейнере исполнителя, где клики не работают.
    "https://raw.githubusercontent.com/blegbot1/PrisonESP/main/rayfield.lua",
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}
local rfSource = nil   -- с какого URL загрузился Rayfield
local rfMovedN = 0     -- сколько ScreenGui перенесено в PlayerGui
-- Аварийный флаг: getgenv().PE_SIMPLE = true ДО запуска скрипта —
-- Rayfield пропускается сразу, включается простое меню (если сам
-- Rayfield грузится, но кнопки в нём мёртвые).
if G.PE_SIMPLE == true then
    warn("[PE] PE_SIMPLE=true - Rayfield skipped")
end
if G.PE_SIMPLE ~= true then
for _, u in ipairs(RF_URLS) do
    local ok, res = pcall(function()
        local src = game:HttpGet(u, true)
        if type(src) ~= "string" or #src < 200 then error("empty response") end
        local f = loadstring(src, "Rayfield")
        if type(f) ~= "function" then error("loadstring returned nil") end
        local lib = f()
        if type(lib) ~= "table" then error("not a table: " .. typeof(lib)) end
        return lib
    end)
    if ok and type(res) == "table" then
        Rayfield = res
        rfSource = u
        break
    end
    warn("[PE] Rayfield failed to load (" .. u .. "): " .. tostring(res))
end
end -- PE_SIMPLE check

-- Снапшот UI-контейнера ДО создания окна Rayfield: после создания
-- перенесём его интерфейс в PlayerGui (см. rescueRayfield ниже).
local rfContainer
local rfBefore = {}
do
    local function getCont()
        if typeof(gethui) == "function" then
            local ok, h = pcall(gethui)
            if ok and h and h.Parent then return h end
        end
        return CoreGui
    end
    rfContainer = getCont()
    pcall(function()
        for _, c in ipairs(rfContainer:GetChildren()) do rfBefore[c] = true end
    end)
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
    local W = Rayfield:CreateWindow({
        Name = "PRISON ESP",   -- ОБЯЗАТЕЛЬНО: без него Text=nil и
                               -- CreateWindow умирает на полпути
        LoadingTitle = "PRISON ESP",
        LoadingSubtitle = "ESP + Combat v2.53",
        -- Сохранение настроек Rayfield: включаем только если в
        -- исполнителе есть файловая система (сам Rayfield проверит
        -- и предупредит, если нет). Наши дефолты живут в getgenv().
        ConfigurationSaving = {
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
        ["Roles"] = "Роли", ["Labels"] = "Подписи",
        ["Boxes"] = "Коробки", ["Player visuals"] = "Визуалы игрока",
        ["Minimap"] = "Миникарта", ["Ground items"] = "Предметы на земле",
        ["Escape & danger zones"] = "Побег и опасные зоны",
        ["Kill aura (InflictTarget)"] = "Килл-аура (InflictTarget)",
        ["Cuffs & teleport"] = "Наручники и телепорт",
        ["Gun upgrade"] = "Прокачка пушки",
        ["Taser (stun)"] = "Тазер (стан)",
        ["C00LKIDD MODE (2014)"] = "РЕЖИМ C00LKIDD (2014)",
        ["Client aim (silent)"] = "Клиентский аим (сайлент)",
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
        ["ESP guards"] = "ЕСП охраны", ["ESP prisoners"] = "ЕСП заключённых",
        ["ESP criminals"] = "ЕСП преступников",
        ["ESP others"] = "ЕСП остальных",
        ["Admins highlight + alert"] = "Подсветка админов + алерт",
        ["Names"] = "Имена", ["Distance"] = "Дистанция",
        ["Role tags [GUARD]/[PRIS]/[CRIM]"] = "Теги роли [ОХР]/[ЗЕК]/[КРИМ]",
        ["Weapon in hands"] = "Оружие в руках",
        ["Name color by HP"] = "Цвет ника по HP",
        ["ESP text size"] = "Размер текста ЕСП",
        ["ESP range (0 = whole map)"] = "Дистанция ЕСП (0 = вся карта)",
        ["Hide dead"] = "Скрывать мёртвых",
        ["Player boxes"] = "Коробки игроков", ["Box style"] = "Стиль коробки",
        ["Box thickness"] = "Толщина коробки",
        ["Box transparency"] = "Прозрачность коробки",
        ["Box padding (screen)"] = "Отступ на экране",
        ["Box fade by distance"] = "Затухание по дистанции",
        ["3D box margin (studs)"] = "Отступ 3D-коробки (стады)",
        ["Skeleton ESP"] = "Скелет", ["Skeleton thickness"] = "Толщина скелета",
        ["Skeleton: hide closer than"] = "Скелет: скрывать ближе чем",
        ["Head frame"] = "Рамка головы",
        ["Head frame size"] = "Размер рамки головы",
        ["Head frame in role color"] = "Рамка в цвете роли",
        ["HP bar above head"] = "Полоска HP над головой",
        ["HP bar width"] = "Ширина полоски HP",
        ["HP bar height"] = "Высота полоски HP",
        ["HP bar gradient"] = "Градиент полоски HP",
        ["HP in percent"] = "HP в процентах",
        ["HP numbers on bar"] = "Цифры HP на полоске",
        ["Snaplines to players"] = "Трейсеры к игрокам",
        ["Snapline origin"] = "Начало трейсеров",
        ["Off-screen arrows"] = "Стрелки за экраном",
        ["Arrow thickness"] = "Толщина стрелок",
        ["Arrow transparency"] = "Прозрачность стрелок",
        ["Movement vector"] = "Вектор движения",
        ["Ring under target"] = "Кольцо под целью",
        ["Target speed"] = "Скорость цели",
        ["Lite ESP mode (less load)"] = "Лёгкий режим ЕСП (меньше нагрузки)",
        ["Minimap size"] = "Размер миникарты",
        ["Self dot on minimap"] = "Своя точка на миникарте",
        ["Guard color"] = "Цвет охраны",
        ["Prisoner color"] = "Цвет заключённых",
        ["Criminal color"] = "Цвет преступников",
        ["Others color"] = "Цвет остальных",
        ["Guns/keycards/ammo on ground"] = "Пушки/пропуска/патроны на земле",
        ["Danger/escape zones ESP"] = "ЕСП зон побега и опасности",
        ["Invisible walls ESP (perimeter)"] = "ЕСП невидимых стен (периметр)",
        ["AUTO-ESCAPE (tp to zone and back)"] = "АВТО-ПОБЕГ (тп на зону и назад)",
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
        ["Kill sound (death beep)"] = "Звук убийства (бип при смерти)",
        ["Chams (role highlight, through walls)"] = "Чамсы (подсветка по роли, сквозь стены)",
        ["Burn targets (fire DOT)"] = "Поджог целей (огонь по времени)",
        ["Auto-burn attacker (retribution)"] = "Авто-сожжение атакующего",
        ["Immortality (self-heal loop, 0 dmg)"] = "Бессмертие (хил-цикл, 0 урона)",
        ["Victim (pick a player)"] = "Жертва (выбери игрока)",
        ["TELEPORT to player (behind)"] = "ТЕЛЕПОРТ к игроку (за спину)",
        ["CUFF player"] = "НАРУЧНИКИ на игрока",
        ["TELEPORT + CUFF (combo)"] = "ТЕЛЕПОРТ + НАРУЧНИКИ (комбо)",
        ["Cuff aura (nearest enemy)"] = "Аура наручников (ближний враг)",
        ["Who to cuff"] = "Кого сковывать",
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
        if PE_RU[s] then return PE_RU[s] end
        return s
    end

    -- Каждый элемент в своём pcall: на части исполнителей один
    -- неудачный Create* ронял ВСЮ сборку меню — окно оставалось
    -- видимым, но в нём торчали мёртвые прототипы шаблона
    -- (Toggle/Slider/Button без подключённых обработчиков).
    local function safeTab(tabObj, tabName)
        local proxy = {}
        setmetatable(proxy, {
            __index = function(_, k)
                local v = tabObj[k]
                if type(v) ~= "function" then return v end
                return function(_, ...)
                    local args = { ... }
                    -- Переводим подписи на лету (только RU-режим).
                    if PE_LANG == "ru" then
                        if type(args[1]) == "table" then
                            if type(args[1].Name) == "string" then
                                args[1].Name = peTr(args[1].Name)
                            end
                            if type(args[1].Title) == "string" then
                                args[1].Title = peTr(args[1].Title)
                            end
                        elseif type(args[1]) == "string" then
                            args[1] = peTr(args[1])
                        end
                    end
                    local ok, res = pcall(v, tabObj, unpack(args))
                    if not ok then
                        warn("[PE GUI] " .. tabName .. "." .. tostring(k)
                            .. ": " .. tostring(res))
                    end
                    return res
                end
            end,
        })
        return proxy
    end
    local function safeNewTab(Win, name, icon, label)
        local okT, T0 = pcall(function() return Win:CreateTab(name, icon) end)
        if not okT or not T0 then
            warn("[PE GUI] CreateTab(" .. label .. "): " .. tostring(T0))
            return nil
        end
        return safeTab(T0, label)
    end

    local T = safeNewTab(W, "ESP", "box", "ESP")
    if not T then error("ESP tab failed") end

    T:CreateSection("Roles")
    T:CreateParagraph({ Title = "Roles",
        Content = "Guards are blue, prisoners orange, criminals red, others gray. Role is detected from team, attributes and tools." })
    T:CreateToggle({ Name = "ESP guards", Flag = "PE_GuardESP",
        CurrentValue = CFG.GuardESP ~= false,
        Callback = function(v) CFG.GuardESP = v end })
    T:CreateColorPicker({ Name = "Guard color", Flag = "PE_ColGuard",
        Color = CFG.ColGuard, Callback = function(c) CFG.ColGuard = c end })
    T:CreateToggle({ Name = "ESP prisoners", Flag = "PE_PrisonerESP",
        CurrentValue = CFG.PrisonerESP ~= false,
        Callback = function(v) CFG.PrisonerESP = v end })
    T:CreateColorPicker({ Name = "Prisoner color", Flag = "PE_ColPris",
        Color = CFG.ColPris, Callback = function(c) CFG.ColPris = c end })
    T:CreateToggle({ Name = "ESP criminals", Flag = "PE_CriminalESP",
        CurrentValue = CFG.CriminalESP ~= false,
        Callback = function(v) CFG.CriminalESP = v end })
    T:CreateToggle({ Name = "Admins highlight + alert", Flag = "PE_AdminESP",
        CurrentValue = CFG.AdminESP ~= false,
        Callback = function(v) CFG.AdminESP = v end })
    T:CreateToggle({ Name = "Chams (role highlight, through walls)",
        Flag = "PE_Chams",
        CurrentValue = CFG.Chams == true,
        Callback = function(v) CFG.Chams = v end })
    T:CreateColorPicker({ Name = "Criminal color", Flag = "PE_ColCrim",
        Color = CFG.ColCrim, Callback = function(c) CFG.ColCrim = c end })
    T:CreateToggle({ Name = "ESP others", Flag = "PE_PlayerESP",
        CurrentValue = CFG.PlayerESP ~= false,
        Callback = function(v) CFG.PlayerESP = v end })
    T:CreateColorPicker({ Name = "Others color", Flag = "PE_ColOther",
        Color = CFG.ColOther, Callback = function(c) CFG.ColOther = c end })
    T:CreateSlider({ Name = "ESP range (0 = whole map)", Flag = "PE_MaxDist",
        Range = {0, 2000}, Increment = 50, CurrentValue = tonumber(CFG.MaxDist) or 900,
        Suffix = " st", Callback = function(v) CFG.MaxDist = v end })

    T:CreateSection("Labels")
    T:CreateToggle({ Name = "Role tags [GUARD]/[PRIS]/[CRIM]", Flag = "PE_RoleTags",
        CurrentValue = CFG.RoleTags ~= false,
        Callback = function(v) CFG.RoleTags = v end })
    T:CreateToggle({ Name = "Names", Flag = "PE_Names",
        CurrentValue = CFG.Names ~= false,
        Callback = function(v) CFG.Names = v end })
    T:CreateToggle({ Name = "Weapon in hands", Flag = "PE_Weapon",
        CurrentValue = CFG.WeaponESP ~= false,
        Callback = function(v) CFG.WeaponESP = v end })
    T:CreateToggle({ Name = "Distance", Flag = "PE_Dist",
        CurrentValue = CFG.ShowDist ~= false,
        Callback = function(v) CFG.ShowDist = v end })
    T:CreateToggle({ Name = "HP", Flag = "PE_HP",
        CurrentValue = CFG.ShowHP ~= false,
        Callback = function(v) CFG.ShowHP = v end })
    T:CreateToggle({ Name = "HP in percent", Flag = "PE_HPPercent",
        CurrentValue = CFG.HPPercent == true,
        Callback = function(v) CFG.HPPercent = v end })
    T:CreateToggle({ Name = "Target speed", Flag = "PE_Speed",
        CurrentValue = CFG.ShowSpeed == true,
        Callback = function(v) CFG.ShowSpeed = v end })
    T:CreateToggle({ Name = "Name color by HP", Flag = "PE_NameHPColor",
        CurrentValue = CFG.NameHPColor == true,
        Callback = function(v) CFG.NameHPColor = v end })
    T:CreateToggle({ Name = "Hide dead", Flag = "PE_HideDead",
        CurrentValue = CFG.HideDead ~= false,
        Callback = function(v) CFG.HideDead = v end })
    T:CreateSlider({ Name = "ESP text size", Flag = "PE_LabelSize",
        Range = {9, 24}, Increment = 1, CurrentValue = CFG.LabelSize or 13,
        Suffix = " px", Callback = function(v) CFG.LabelSize = v end })

    T:CreateSection("Boxes")
    T:CreateParagraph({ Title = "Boxes",
        Content = "3D box is built from the whole model bounds: hugs the body and rotates with the player. Frame and corners styles available." })
    T:CreateToggle({ Name = "Player boxes", Flag = "PE_Boxes2",
        CurrentValue = DRAW_OK and CFG.Boxes ~= false,
        Callback = function(v)
            CFG.Boxes = v
            if v and not DRAW_OK then
                CFG.Boxes = false
                warn("[PE] no Drawing in this executor - boxes disabled")
            end
        end })
    T:CreateDropdown({
        Name = "Box style",
        Flag = "PE_BoxStylePick",
        Options = BOX_STYLES,
        CurrentOption = { CFG.BoxStyle },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then CFG.BoxStyle = picked end
        end,
    })
    T:CreateSlider({ Name = "Box thickness", Flag = "PE_BoxThick",
        Range = {1, 6}, Increment = 1, CurrentValue = CFG.BoxThick or 2,
        Callback = function(v) CFG.BoxThick = v end })
    T:CreateSlider({ Name = "Box padding (screen)", Flag = "PE_BoxPad",
        Range = {0, 40}, Increment = 1, CurrentValue = CFG.BoxPad or 4,
        Suffix = " px", Callback = function(v) CFG.BoxPad = v end })
    T:CreateSlider({ Name = "3D box margin (studs)", Flag = "PE_BoxMargin",
        Range = {0, 10}, Increment = 0.1,
        CurrentValue = math.floor((tonumber(CFG.BoxMargin) or 0) * 10 + 0.5) / 10,
        Suffix = " st", Callback = function(v) CFG.BoxMargin = v end })
    T:CreateSlider({ Name = "Box transparency", Flag = "PE_BoxAlpha",
        Range = {0, 90}, Increment = 5,
        CurrentValue = math.floor((tonumber(CFG.BoxAlpha) or 0) * 100 + 0.5),
        Suffix = " %", Callback = function(v) CFG.BoxAlpha = v / 100 end })
    T:CreateToggle({ Name = "Box fade by distance", Flag = "PE_DistFade",
        CurrentValue = CFG.DistFade == true,
        Callback = function(v) CFG.DistFade = v end })

    T:CreateSection("Player visuals")
    T:CreateToggle({ Name = "Skeleton ESP", Flag = "PE_Skeleton",
        CurrentValue = CFG.Skeleton == true,
        Callback = function(v) CFG.Skeleton = v end })
    T:CreateSlider({ Name = "Skeleton thickness", Flag = "PE_SkeletonThick",
        Range = {1, 4}, Increment = 1, CurrentValue = CFG.SkeletonThick or 1,
        Callback = function(v) CFG.SkeletonThick = v end })
    T:CreateSlider({ Name = "Skeleton: hide closer than", Flag = "PE_SkelMinDist",
        Range = {0, 60}, Increment = 2, CurrentValue = CFG.SkelMinDist or 12,
        Suffix = " st", Callback = function(v) CFG.SkelMinDist = v end })
    T:CreateToggle({ Name = "HP bar above head", Flag = "PE_HealthBars",
        CurrentValue = CFG.HealthBars ~= false,
        Callback = function(v) CFG.HealthBars = v end })
    T:CreateSlider({ Name = "HP bar width", Flag = "PE_HealthBarWidth",
        Range = {20, 80}, Increment = 2, CurrentValue = CFG.HealthBarWidth or 40,
        Suffix = " px", Callback = function(v) CFG.HealthBarWidth = v end })
    T:CreateSlider({ Name = "HP bar height", Flag = "PE_HealthBarHeight",
        Range = {2, 10}, Increment = 1, CurrentValue = CFG.HealthBarHeight or 4,
        Suffix = " px", Callback = function(v) CFG.HealthBarHeight = v end })
    T:CreateToggle({ Name = "HP numbers on bar", Flag = "PE_HPBarText",
        CurrentValue = CFG.HPBarText ~= false,
        Callback = function(v) CFG.HPBarText = v end })
    T:CreateToggle({ Name = "HP bar gradient", Flag = "PE_HPGradient",
        CurrentValue = CFG.HPGradient ~= false,
        Callback = function(v) CFG.HPGradient = v end })
    T:CreateToggle({ Name = "Head frame", Flag = "PE_HeadBox",
        CurrentValue = CFG.HeadBox ~= false,
        Callback = function(v) CFG.HeadBox = v end })
    T:CreateSlider({ Name = "Head frame size", Flag = "PE_HeadBoxSize",
        Range = {10, 50}, Increment = 1, CurrentValue = CFG.HeadBoxSize or 22,
        Suffix = " px", Callback = function(v) CFG.HeadBoxSize = v end })
    T:CreateToggle({ Name = "Head frame in role color", Flag = "PE_HeadBoxRole",
        CurrentValue = CFG.HeadBoxRole ~= false,
        Callback = function(v) CFG.HeadBoxRole = v end })
    T:CreateToggle({ Name = "Snaplines to players", Flag = "PE_Snaplines",
        CurrentValue = CFG.Snaplines ~= false,
        Callback = function(v) CFG.Snaplines = v end })
    T:CreateSlider({ Name = "Arrow thickness", Flag = "PE_SnapArrowThick",
        Range = {1, 6}, Increment = 1,
        CurrentValue = math.clamp(tonumber(CFG.SnapArrowThick) or 2, 1, 6),
        Suffix = " px", Callback = function(v) CFG.SnapArrowThick = v end })
    T:CreateDropdown({
        Name = "Snapline origin",
        Flag = "PE_SnapFromPick",
        Options = TRACER_ORIGINS,
        CurrentOption = { CFG.SnapFrom },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then CFG.SnapFrom = picked end
        end,
    })
    T:CreateSlider({ Name = "Arrow transparency", Flag = "PE_SnapAlpha",
        Range = {0, 10}, Increment = 1,
        CurrentValue = math.floor((tonumber(CFG.SnapAlpha) or 1) * 10 + 0.5),
        Suffix = " /10", Callback = function(v) CFG.SnapAlpha = v / 10 end })
    T:CreateToggle({ Name = "Off-screen arrows", Flag = "PE_OffArrows",
        CurrentValue = CFG.OffArrows ~= false,
        Callback = function(v) CFG.OffArrows = v end })
    T:CreateToggle({ Name = "Ring under target", Flag = "PE_GroundRing",
        CurrentValue = CFG.GroundRing ~= false,
        Callback = function(v) CFG.GroundRing = v end })
    T:CreateToggle({ Name = "Movement vector", Flag = "PE_MoveVec",
        CurrentValue = CFG.MoveVec == true,
        Callback = function(v) CFG.MoveVec = v end })
    T:CreateToggle({ Name = "Lite ESP mode (less load)", Flag = "PE_LiteESP",
        CurrentValue = CFG.LiteESP == true,
        Callback = function(v) CFG.LiteESP = v end })

    T:CreateSection("Minimap")
    T:CreateToggle({ Name = "Minimap", Flag = "PE_Minimap",
        CurrentValue = CFG.Minimap == true,
        Callback = function(v) CFG.Minimap = v end })
    T:CreateSlider({ Name = "Minimap size", Flag = "PE_MinimapSize",
        Range = {100, 300}, Increment = 10, CurrentValue = CFG.MinimapSize or 160,
        Suffix = " px", Callback = function(v) CFG.MinimapSize = v end })
    T:CreateToggle({ Name = "Self dot on minimap", Flag = "PE_MinimapSelf",
        CurrentValue = CFG.MinimapSelf ~= false,
        Callback = function(v) CFG.MinimapSelf = v end })

    T:CreateSection("Ground items")
    T:CreateParagraph({ Title = "Items",
        Content = "Highlights guns, keycards, ammo boxes and the hammer on the ground (through walls)." })
    T:CreateToggle({ Name = "Guns/keycards/ammo on ground", Flag = "PE_Items",
        CurrentValue = CFG.Items ~= false,
        Callback = function(v) CFG.Items = v end })
    T:CreateSection("Escape & danger zones")
    T:CreateParagraph({ Title = "Zones",
        Content = "Red = Death Part (kills you on touch), green = EscapePart (prisoner escape). The auto-escape toggle teleports you onto the nearest zone, waits for the escape to register, then brings you back home." })
    T:CreateToggle({ Name = "Danger/escape zones ESP", Flag = "PE_DangerESP",
        CurrentValue = CFG.DangerESP == true,
        Callback = function(v) CFG.DangerESP = v end })
    T:CreateToggle({ Name = "Invisible walls ESP (perimeter)",
        Flag = "PE_InvisWall",
        CurrentValue = CFG.InvisWall == true,
        Callback = function(v) CFG.InvisWall = v end })
    T:CreateToggle({ Name = "AUTO-ESCAPE (tp to zone and back)",
        Flag = "PE_AutoEscape",
        CurrentValue = false,
        Callback = function(v)
            if v then
                task.defer(function() G.PE.EscapeTrip() end)
            end
        end })

    -- ====================== ВКЛАДКА БОЙ ======================
    local C = safeNewTab(W, "Combat", "swords", "Combat")
    if not C then error("Combat tab failed") end

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
        Range = {1, 5000}, Increment = 10,
        CurrentValue = math.clamp(tonumber(CFG.KillAuraDamage) or 50, 1, 5000),
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
    C:CreateToggle({ Name = "Infinite aura range (whole map)",
        Flag = "PE_AuraInfRange",
        CurrentValue = CFG.AuraInfRange == true,
        Callback = function(v) CFG.AuraInfRange = v end })
    C:CreateToggle({ Name = "Kill sound (death beep)",
        Flag = "PE_KillSound",
        CurrentValue = CFG.KillSound == true,
        Callback = function(v) CFG.KillSound = v end })
    C:CreateToggle({ Name = "Burn targets (fire DOT)",
        Flag = "PE_AuraBurn",
        CurrentValue = CFG.AuraBurn ~= false,
        Callback = function(v) CFG.AuraBurn = v end })
    C:CreateToggle({ Name = "Auto-burn attacker (retribution)",
        Flag = "PE_Retr",
        CurrentValue = CFG.Retr ~= false,
        Callback = function(v) CFG.Retr = v end })
    C:CreateToggle({ Name = "Immortality (self-heal loop, 0 dmg)",
        Flag = "PE_Immortal",
        CurrentValue = CFG.Immortal == true,
        Callback = function(v) CFG.Immortal = v end })

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
    C:CreateToggle({ Name = "Sniper scope on any gun (E key)",
        Flag = "PE_GunScope",
        CurrentValue = CFG.GunScope == true,
        Callback = function(v) CFG.GunScope = v end })
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
    C:CreateToggle({ Name = "Fire paint (draw with fire at cursor)",
        Flag = "PE_FirePaint",
        CurrentValue = CFG.FirePaint == true,
        Callback = function(v) CFG.FirePaint = v end })
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

    C:CreateSection("Team & status")
    C:CreateButton({ Name = "Team: GUARD",
        Callback = function() G.PE.Team("Guard") end })
    C:CreateButton({ Name = "Team: PRISONER",
        Callback = function() G.PE.Team("Prisoner") end })
    C:CreateButton({ Name = "Team: ESCAPED (criminal)",
        Callback = function() G.PE.Team("Escaped") end })
    C:CreateDropdown({
        Name = "Switch team",
        Flag = "PE_TeamPick",
        Options = { "Guard", "Prisoner", "Escaped", "Undecided" },
        CurrentOption = { "Guard" },
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then
                G.PE.Team(picked)
                print("[PE] team switch: " .. picked)
            end
        end,
    })
    C:CreateButton({ Name = "Reset to menu (escape cuffs)",
        Callback = function() G.PE.ResetMenu() end })
    C:CreateToggle({ Name = "Fast respawn (instant rejoin)",
        Flag = "PE_FastRespawn",
        CurrentValue = CFG.FastRespawn == true,
        Callback = function(v) CFG.FastRespawn = v end })

    C:CreateSection("Movement")
    C:CreateToggle({ Name = "Speed hack (WalkSpeed)",
        Flag = "PE_SpeedHack",
        CurrentValue = CFG.SpeedHack == true,
        Callback = function(v) CFG.SpeedHack = v end })
    C:CreateSlider({ Name = "Speed (studs/s)", Flag = "PE_SpeedValue",
        Range = {16, 150}, Increment = 2,
        CurrentValue = math.clamp(tonumber(CFG.SpeedValue) or 40, 16, 150),
        Callback = function(v) CFG.SpeedValue = v end })
    C:CreateToggle({ Name = "Noclip (walk through walls)",
        Flag = "PE_Noclip",
        CurrentValue = CFG.Noclip == true,
        Callback = function(v) CFG.Noclip = v end })
    C:CreateToggle({ Name = "Fly (WASD + Space/Ctrl)",
        Flag = "PE_Fly",
        CurrentValue = CFG.Fly == true,
        Callback = function(v)
            CFG.Fly = v
            if not v then
                pcall(function()
                    local r = LP.Character
                        and LP.Character:FindFirstChild("HumanoidRootPart")
                    if r then r.AssemblyLinearVelocity = Vector3.zero end
                end)
            end
        end })
    C:CreateSlider({ Name = "Fly speed", Flag = "PE_FlySpeed",
        Range = {10, 300}, Increment = 10,
        CurrentValue = math.clamp(tonumber(CFG.FlySpeed) or 60, 10, 300),
        Callback = function(v) CFG.FlySpeed = v end })
    C:CreateToggle({ Name = "Infinite jump (jump in air)",
        Flag = "PE_InfJump",
        CurrentValue = CFG.InfJump == true,
        Callback = function(v) CFG.InfJump = v end })
    C:CreateToggle({ Name = "FPS boost (low graphics)",
        Flag = "PE_FPSBoost",
        CurrentValue = CFG.FPSBoostOn == true,
        Callback = function(v)
            CFG.FPSBoostOn = v
            if type(G.PE.FPSBoost) == "function" then G.PE.FPSBoost(v) end
        end })
    C:CreateButton({ Name = "TP to crosshair (blink)",
        Callback = function() G.PE.TPCrosshair() end })
    C:CreateInput({ Name = "Waypoint name",
        PlaceholderText = "e.g. armory",
        CurrentValue = "",
        Flag = "PE_WPName",
        Callback = function(text) CFG._wpName = tostring(text) end })
    local wpDrop
    C:CreateButton({ Name = "SAVE waypoint (my position)",
        Callback = function()
            G.PE.WP_Save(CFG._wpName)
            if wpDrop then
                pcall(function()
                    local o = {}
                    for nm in pairs(G.PE_Waypoints) do o[#o + 1] = nm end
                    table.sort(o)
                    if #o == 0 then o[1] = "(no waypoints)" end
                    wpDrop:Refresh(o)
                end)
            end
        end })
    wpDrop = C:CreateDropdown({
        Name = "Teleport to waypoint",
        Flag = "PE_WPPick",
        Options = (function()
            local o = {}
            for nm in pairs(G.PE_Waypoints) do o[#o + 1] = nm end
            table.sort(o)
            if #o == 0 then o[1] = "(no waypoints)" end
            return o
        end)(),
        CurrentOption = {},
        MultipleOptions = false,
        Callback = function(selected)
            local picked = selected
            if type(picked) == "table" then picked = picked[1] end
            if type(picked) == "string" then
                CFG._wp = picked
                print("[PE WP] selected: " .. picked)
            end
        end,
    })
    C:CreateButton({ Name = "TELEPORT to waypoint",
        Callback = function()
            G.PE.WP_TP(CFG._wp)
            pcall(function()
                local o = {}
                for nm in pairs(G.PE_Waypoints) do o[#o + 1] = nm end
                table.sort(o)
                if #o == 0 then o[1] = "(no waypoints)" end
                wpDrop:Refresh(o)
            end)
        end })
    C:CreateToggle({ Name = "Anti-AFK (no idle kick)",
        Flag = "PE_AntiAFK",
        CurrentValue = CFG.AntiAFK ~= false,
        Callback = function(v) CFG.AntiAFK = v end })
    C:CreateToggle({ Name = "Jump boost (higher jumps)",
        Flag = "PE_JumpBoost",
        CurrentValue = CFG.JumpBoost == true,
        Callback = function(v) CFG.JumpBoost = v end })
    C:CreateSlider({ Name = "Jump power", Flag = "PE_JumpPower",
        Range = {50, 300}, Increment = 5,
        CurrentValue = math.clamp(tonumber(CFG.JumpPower) or 90, 50, 300),
        Callback = function(v) CFG.JumpPower = v end })
    C:CreateToggle({ Name = "Anti-stun (taser/cuffs/ragdoll)", Flag = "PE_AntiStun",
        CurrentValue = CFG.AntiStun ~= false,
        Callback = function(v) CFG.AntiStun = v end })

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
    C:CreateButton({ Name = "GIVE ALL (guns + KeyCard)",
        Callback = function() G.PE.GiveAll() end })
    for _, nm in ipairs(GIVE_ITEMS) do
        C:CreateButton({ Name = "Give: " .. nm,
            Callback = function() G.PE.Give(nm) end })
    end
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
        ST:CreateParagraph({ Title = "Version",
            Content = "PRISON ESP v2.53. ESP + Combat. Console tools: PE.Guns(), PE.Remotes(), PE.GunSource(), PE.Diag(), PE.TeamOf(name), PE.Probe(...), PE.Hit(name), PE.Team(name), PE.FakeShot(), PE.EscapeTrip(), PE.WearOutfit(), PE.ShopInfo()." })
    end

    guiOK = true
    PE_GUI_READY = true
end)
if not okGUI then
    warn("[PE] RAYFIELD MENU BUILD FAILED: " .. tostring(errGUI))
    -- Ломаное полусобранное окно убираем, чтобы не висло вместе
    -- с простым меню (жалоба «два меню»).
    pcall(function()
        if Rayfield and Rayfield.Destroy then Rayfield:Destroy() end
    end)
end

-- ПОЧИНКА КЛИКОВ RAYFIELD: на части исполнителей его интерфейс лежит
-- в контейнере (gethui/CoreGui), который рисуется, но НЕ принимает
-- ввод. Переносим интерфейс в PlayerGui — там клики работают всегда.
local function rescueRayfield()
    if STOPPED then return end
    if not Rayfield then return end
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local function tryMove(sg)
        if not (sg and sg:IsA("ScreenGui")) then return false end
        if sg.Parent == pg then return false end
        local okM, errM = pcall(function()
            sg.ResetOnSpawn = false
            sg.DisplayOrder = 100000
            sg.IgnoreGuiInset = true
            sg.Parent = pg
        end)
        if okM then
            rfMovedN = rfMovedN + 1
            print("[PE] Rayfield ScreenGui '" .. sg.Name
                .. "' MOVED to PlayerGui - clicks should work")
            return true
        end
        warn("[PE] move '" .. sg.Name .. "' failed: " .. tostring(errM))
        return false
    end
    -- 1) Точное имя: Rayfield создаёт ScreenGui с именем "Rayfield"
    --    (DIAG показал: он лежит в gethui-контейнере).
    for _, cont in ipairs({ rfContainer, CoreGui }) do
        if cont and cont ~= pg then
            pcall(function()
                for _, c in ipairs(cont:GetChildren()) do
                    if c:IsA("ScreenGui") and c.Name == "Rayfield" then
                        tryMove(c)
                    end
                end
            end)
        end
    end
    -- 2) Запасной вариант: любые НОВЫЕ ScreenGui в контейнере
    --    (если имя в другой версии библиотеки другое).
    if rfMovedN == 0 and rfContainer and rfContainer ~= pg then
        pcall(function()
            for _, c in ipairs(rfContainer:GetChildren()) do
                if not rfBefore[c] and c:IsA("ScreenGui") then
                    tryMove(c)
                end
            end
        end)
    end
end
task.delay(0.2, rescueRayfield)
-- Долгий HttpGet: интерфейс мог появиться ПОСЛЕ статических проверок —
-- ловим появление ScreenGui до 15 с (наша копия сразу в PlayerGui —
-- выходим сразу, запасные URL кладут в gethui/CoreGui).
task.spawn(function()
    for _ = 1, 15 do
        if STOPPED then break end
        rescueRayfield()
        if rfMovedN > 0 or rfSource == RF_URLS[1] then break end
        task.wait(1)
    end
end)

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
    print("[PE DIAG] Drawing=" .. tostring(DRAW_OK)
        .. " | Rayfield=" .. tostring(Rayfield ~= nil)
        .. " | source=" .. tostring(rfSource or "NOT loaded")
        .. " | ScreenGui moved to PlayerGui=" .. tostring(rfMovedN))
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

-- Простое меню УДАЛЕНО: только Rayfield. Если он не собрался —
-- громко ругаемся в консоль (функции доступны и без меню).
if not Rayfield then
    warn("[PE] Rayfield failed to load - no menu. Console: PE.Hit/PE.Team/PE.Give/PE.Doors etc.")
elseif not guiOK then
    warn("[PE] Rayfield menu failed to build (error above). Console: PE.Hit/PE.Team/PE.Give/PE.Doors etc.")
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
    pcall(function() mainConn:Disconnect() end)
    pcall(function() itemConn:Disconnect() end)
    pcall(function() dangerConn:Disconnect() end)
    pcall(function() chamsConn:Disconnect() end)
    for _, h in pairs(byChams) do pcall(function() h:Destroy() end) end
    byChams = setmetatable({}, { __mode = "k" })
    for k, h in pairs(byDanger) do pcall(function() h:Destroy() end) end
    byDanger = {}
    for plr, e in pairs(by) do
        if e then
            if e.gui then pcall(function() e.gui:Destroy() end) end
            destroyBox(e.box)
        end
    end
    by = {}
    pcall(function() VIS.destroy() end)
    for k, h in pairs(byItems) do pcall(function() h:Destroy() end) end
    byItems = {}
    pcall(function()
        if Screen then Screen:Destroy() end
        Screen = nil
    end)
    pcall(function() clickConn:Disconnect() end)
    pcall(function() auraConn:Disconnect() end)
    pcall(function() flyConn:Disconnect() end)
    pcall(function() ijConn:Disconnect() end)
    pcall(function()
        local chrS = LP.Character
        local humS = chrS and chrS:FindFirstChildOfClass("Humanoid")
        if humS then
            -- v2.53: не сбиваем нестандартную скорость игры, если хак не
            -- включали, и снимаем прыжок-буст (раньше JumpPower до 300
            -- жил после выгрузки).
            if CFG._speedWasOn then
                humS.WalkSpeed = 16
                CFG._speedWasOn = nil
            end
            if CFG._jumpWasOn then
                humS.UseJumpPower = true
                humS.JumpPower = 50
                CFG._jumpWasOn = nil
            end
        end
        -- v2.53: только те части, что гасил noclip (не шляпы/аксессуары).
        for p in pairs(noclipParts) do
            if p.Parent then pcall(function() p.CanCollide = true end) end
        end
        noclipParts = setmetatable({}, { __mode = "k" })
    end)
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
    pcall(function() diedConn:Disconnect() end)
    pcall(function() giveConn:Disconnect() end)
    pcall(function() afkConn:Disconnect() end)
    G.PE.Guns, G.PE.Remotes, G.PE.Probe, G.PE.TeamOf = nil, nil, nil, nil
    G.PE.Hit, G.PE.Team, G.PE.Diag = nil, nil, nil
    G.PE.Give, G.PE.GiveAll, G.PE.Doors, G.PE.ResetMenu = nil, nil, nil, nil
    G.PE.Escape = nil
    G.PE.EscapeTrip = nil
    G.PE.WearOutfit, G.PE.ShopInfo = nil, nil
    G.PE.GunSource, G.PE.TP, G.PE.Cuff, G.PE.ModGun = nil, nil, nil, nil
    G.PE.FakeShot = nil
    G.PE.WP_Save, G.PE.WP_TP, G.PE.TPCrosshair = nil, nil, nil
    if type(G.PE.FPSBoost) == "function" then
        pcall(function() G.PE.FPSBoost(false) end)
    end
    G.PE.FPSBoost = nil
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
    local rfOld = Rayfield
    Rayfield = nil
    if rfOld then task.defer(function() pcall(function() rfOld:Destroy() end) end) end
    -- Заглушка вместо nil: повторный вызов PE_Stop не должен падать.
    G.PE_Stop = function() end
    G.PE_LOADED_AT = nil
    print("[PE] v2.53 stopped")
end

print("[PE] v2.53 started | Drawing=" .. tostring(DRAW_OK)
    .. " | Rayfield=" .. tostring(Rayfield ~= nil)
    .. " | source=" .. tostring(rfSource or "NOT loaded")
    .. " | console: PE.Guns() / PE.Remotes() / PE.Probe(...) / PE.TeamOf(...)"
    .. " / PE.Hit(\"partial name\") / PE.Team(\"Guard\") / PE.Diag()")
if not DRAW_OK then
    warn("[PE] Drawing unavailable in this executor: boxes/skeleton/arrows/HP bars/minimap will NOT be drawn. Only player labels and item highlights work.")
end
