-- ============================================================
--  PRISON ESP  v0.2
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
    warn("[PE] только что запущен, подожди 5 сек")
    return
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

local BOX_STYLES    = { "Рамка", "Уголки", "3D-коробка" }
local TRACER_ORIGINS = { "Центр", "Низ экрана", "Верх экрана" }

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
CFG.LabelSize  = tonumber(CFG.LabelSize) or 13
CFG.MaxDist    = tonumber(CFG.MaxDist) or 900   -- 0 = без лимита

-- ---------- ESP: коробки ----------
CFG.Boxes     = CFG.Boxes     ~= false
CFG.BoxThick  = math.clamp(tonumber(CFG.BoxThick) or 2, 1, 6)
CFG.BoxPad    = tonumber(CFG.BoxPad) or 4
CFG.BoxMargin = math.clamp(tonumber(CFG.BoxMargin) or 0, 0, 10)
CFG.BoxAlpha  = math.clamp(tonumber(CFG.BoxAlpha) or 0, 0, 0.9)
CFG.BoxStyle  = pickOpt(CFG.BoxStyle, BOX_STYLES, "3D-коробка")
CFG.DistFade  = CFG.DistFade == true

-- ---------- ESP: визуалы ----------
CFG.Skeleton      = CFG.Skeleton == true
CFG.SkeletonThick = tonumber(CFG.SkeletonThick) or 1
CFG.SkelMinDist   = tonumber(CFG.SkelMinDist) or 12
CFG.HealthBars    = CFG.HealthBars ~= false
CFG.HealthBarWidth  = tonumber(CFG.HealthBarWidth) or 40
CFG.HealthBarHeight = tonumber(CFG.HealthBarHeight) or 4
CFG.HPBarText     = CFG.HPBarText ~= false
CFG.HPGradient    = CFG.HPGradient ~= false
CFG.HeadBox       = CFG.HeadBox ~= false
CFG.HeadBoxSize   = tonumber(CFG.HeadBoxSize) or 22
CFG.HeadBoxRole   = CFG.HeadBoxRole ~= false
CFG.HeadBoxColor  = safeColor(CFG.HeadBoxColor, Color3.new(1, 0, 0))
CFG.Snaplines     = CFG.Snaplines ~= false
CFG.SnapArrowThick = math.clamp(tonumber(CFG.SnapArrowThick) or 2, 1, 6)
CFG.SnapFrom      = pickOpt(CFG.SnapFrom, TRACER_ORIGINS, "Низ экрана")
CFG.SnapAlpha     = math.clamp(tonumber(CFG.SnapAlpha) or 1, 0, 1)
CFG.OffArrows     = CFG.OffArrows ~= false
CFG.GroundRing    = CFG.GroundRing ~= false
CFG.MoveVec       = CFG.MoveVec == true
CFG.LiteESP       = CFG.LiteESP == true

-- ---------- ESP: миникарта ----------
CFG.Minimap     = CFG.Minimap == true
CFG.MinimapSize = tonumber(CFG.MinimapSize) or 160
CFG.MinimapSelf = CFG.MinimapSelf ~= false

-- ---------- ESP: предметы на земле ----------
CFG.Items = CFG.Items ~= false

local STOPPED = false
local Rayfield
local mainConn, itemConn
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
    local lbl = gui:FindFirstChild("Lbl")
    if not lbl then
        lbl = Instance.new("TextLabel")
        lbl.Name = "Lbl"
    end
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
    local style = CFG.BoxStyle or "Рамка"

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
    if style == "3D-коробка" then
        local idx = { {1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},
                      {1,5},{2,6},{3,7},{4,8} }
        for i = 1, 12 do
            local ln = b.lines[i]
            local a = proj[idx[i][1]]
            local c = proj[idx[i][2]]
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

    if style == "Уголки" then
        local len = math.clamp(math.min(maxX - minX, maxY - minY) * 0.28, 5, 26)
        local corners = {
            { Vector2.new(minX, minY), Vector2.new(minX + len, minY), Vector2.new(minX, minY + len) },
            { Vector2.new(maxX, minY), Vector2.new(maxX - len, minY), Vector2.new(maxX, minY + len) },
            { Vector2.new(maxX, maxY), Vector2.new(maxX - len, maxY), Vector2.new(maxX, maxY - len) },
            { Vector2.new(minX, maxY), Vector2.new(minX + len, maxY), Vector2.new(minX, maxY - len) },
        }
        for i = 1, 4 do
            local c = corners[i]
            setLine(i * 2 - 1, c[1], c[2])
            setLine(i * 2, c[1], c[3])
        end
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

local function vProj(cam, pos)
    local ok, sp = pcall(function() return cam:WorldToViewportPoint(pos) end)
    if not ok or not sp then return nil end
    return sp
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
    if kind == "Низ экрана" then return Vector2.new(cx, vp.Y) end
    if kind == "Верх экрана" then return Vector2.new(cx, 0) end
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
            local links = { {1,2},{2,3},{2,4},{2,5},{3,6},{3,7} }
            local thick = math.max(1, tonumber(CFG.SkeletonThick) or 1)
            for i = 1, 6 do
                local l = p.skeleton[i]
                if not l then
                    l = vLine()
                    p.skeleton[i] = l
                end
                local a = pts[links[i][1]]
                local b = pts[links[i][2]]
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
                    local maxHp = hum.MaxHealth or 100
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
            if mvRoot then
                local feet
                local okF, hitF = pcall(function()
                    GROUND_RAY.FilterDescendantsInstances = { ch }
                    return workspace:Raycast(
                        mvRoot.Position, Vector3.new(0, -8, 0), GROUND_RAY)
                end)
                if okF and hitF then
                    feet = hitF.Position
                else
                    feet = mvRoot.Position - Vector3.new(0, 3, 0)
                end
                local mHum = ch:FindFirstChildOfClass("Humanoid")
                local grounded = mHum
                    and mHum.FloorMaterial ~= Enum.FloorMaterial.Air
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
                    tonumber(CFG.SnapArrowThick) or 3,
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
                local ax = math.clamp(cx + ux * reach, margin, vp.X - margin)
                local ay = math.clamp(cy + uy * reach, margin, vp.Y - margin)
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
local TEAM_CRIM  = { "crim", "преступ", "villain", "злоде", " villain" }
local TEAM_PRIS  = { "pris", "зек", "inmate", "заключ" }

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
local function removePlayer(plr)
    local e = by[plr]
    if not e then return end
    if e.gui then pcall(function() e.gui:Destroy() end) end
    destroyBox(e.box)
    by[plr] = nil
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

Players.PlayerAdded:Connect(function(plr)
    if STOPPED then return end
    task.defer(function() addPlayer(plr) end)
end)
Players.PlayerRemoving:Connect(function(plr)
    removePlayer(plr)
end)

-- ============================================================
--  ГЛАВНЫЙ ЦИКЛ ESP
-- ============================================================
local ROLE_TAG = {
    guard = "[ОХР]", prisoner = "[ЗЕК]", criminal = "[КРИМ]",
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
                    e.roleAt = nowT
                    destroyBox(e.box)
                    e.box = nil
                    if e.gui then e.gui.Adornee = ch end
                end
                -- Роль обновляем раз в 0.7 с (команды меняются рантайм).
                if nowT - (e.roleAt or 0) > 0.7 then
                    e.roleAt = nowT
                    e.role = roleOf(plr)
                end

                if e.gui and e.gui.Parent and e.lbl then
                    local role = e.role
                    local vis, color
                    if role == "guard" then
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

                    e.vis = vis
                    if e.gui.Enabled ~= vis then e.gui.Enabled = vis end

                    if vis then
                        local parts = {}
                        if CFG.RoleTags then
                            local tag = ROLE_TAG[role]
                            if tag then parts[#parts + 1] = tag end
                        end
                        if CFG.WeaponESP then
                            local tool = ch:FindFirstChildOfClass("Tool")
                            if tool then parts[#parts + 1] = "[" .. tool.Name .. "]" end
                        end
                        if CFG.Names then parts[#parts + 1] = plr.DisplayName end
                        if CFG.ShowDist and root and myRoot then
                            parts[#parts + 1] = math.floor(
                                (root.Position - myRoot.Position).Magnitude + 0.5) .. " st"
                        end
                        if CFG.ShowHP and humNow then
                            if CFG.HPPercent and (humNow.MaxHealth or 0) > 0 then
                                parts[#parts + 1] = string.format("HP %d%%",
                                    math.floor(humNow.Health / humNow.MaxHealth * 100 + 0.5))
                            else
                                parts[#parts + 1] = "HP " .. math.floor(humNow.Health + 0.5)
                            end
                        end
                        if CFG.ShowSpeed and root then
                            local spd = root.AssemblyLinearVelocity
                            parts[#parts + 1] = math.floor(spd.Magnitude + 0.5) .. " st/s"
                        end
                        local txt = table.concat(parts, "  ")
                        if e.lbl.Text ~= txt then e.lbl.Text = txt end
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
                                drawBox(e.box, root, cam)
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
        pcall(VIS.update, cam, myRoot)
    end)
    if not ok then
        warn("[PE] кадр ESP: " .. tostring(err))
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
    print("[PE REMOTE] всего: " .. n)
end

G.PE.Probe = function(name, ...)
    local target = tostring(name or "")
    if target == "" then print("[PE PROBE] укажи имя ремоута") return end
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
        LoadingSubtitle = "ESP + Разведка v0.2",
        ConfigurationSaving = { Enabled = true },
    })

    local T = W:CreateTab("ESP", "box")

    T:CreateSection("Роли")
    T:CreateParagraph({ Title = "Роли",
        Content = "Охрана — синий, зеки — оранжевый, преступники — красный, прочие — серый. Роль определяется по команде, атрибутам и инструментам." })
    T:CreateToggle({ Name = "ESP охраны", Flag = "PE_GuardESP",
        CurrentValue = CFG.GuardESP ~= false,
        Callback = function(v) CFG.GuardESP = v end })
    T:CreateColorPicker({ Name = "Цвет охраны", Flag = "PE_ColGuard",
        Color = CFG.ColGuard, Callback = function(c) CFG.ColGuard = c end })
    T:CreateToggle({ Name = "ESP зеков", Flag = "PE_PrisonerESP",
        CurrentValue = CFG.PrisonerESP ~= false,
        Callback = function(v) CFG.PrisonerESP = v end })
    T:CreateColorPicker({ Name = "Цвет зеков", Flag = "PE_ColPris",
        Color = CFG.ColPris, Callback = function(c) CFG.ColPris = c end })
    T:CreateToggle({ Name = "ESP преступников", Flag = "PE_CriminalESP",
        CurrentValue = CFG.CriminalESP ~= false,
        Callback = function(v) CFG.CriminalESP = v end })
    T:CreateColorPicker({ Name = "Цвет преступников", Flag = "PE_ColCrim",
        Color = CFG.ColCrim, Callback = function(c) CFG.ColCrim = c end })
    T:CreateToggle({ Name = "ESP прочих", Flag = "PE_PlayerESP",
        CurrentValue = CFG.PlayerESP ~= false,
        Callback = function(v) CFG.PlayerESP = v end })
    T:CreateColorPicker({ Name = "Цвет прочих", Flag = "PE_ColOther",
        Color = CFG.ColOther, Callback = function(c) CFG.ColOther = c end })
    T:CreateSlider({ Name = "Дальность ESP (0 = вся карта)", Flag = "PE_MaxDist",
        Range = {0, 2000}, Increment = 50, CurrentValue = tonumber(CFG.MaxDist) or 900,
        Suffix = " st", Callback = function(v) CFG.MaxDist = v end })

    T:CreateSection("Подписи")
    T:CreateToggle({ Name = "Метки ролей [ОХР]/[ЗЕК]/[КРИМ]", Flag = "PE_RoleTags",
        CurrentValue = CFG.RoleTags ~= false,
        Callback = function(v) CFG.RoleTags = v end })
    T:CreateToggle({ Name = "Ники", Flag = "PE_Names",
        CurrentValue = CFG.Names ~= false,
        Callback = function(v) CFG.Names = v end })
    T:CreateToggle({ Name = "Оружие в руках", Flag = "PE_Weapon",
        CurrentValue = CFG.WeaponESP ~= false,
        Callback = function(v) CFG.WeaponESP = v end })
    T:CreateToggle({ Name = "Дистанция", Flag = "PE_Dist",
        CurrentValue = CFG.ShowDist ~= false,
        Callback = function(v) CFG.ShowDist = v end })
    T:CreateToggle({ Name = "HP", Flag = "PE_HP",
        CurrentValue = CFG.ShowHP ~= false,
        Callback = function(v) CFG.ShowHP = v end })
    T:CreateToggle({ Name = "HP в процентах", Flag = "PE_HPPercent",
        CurrentValue = CFG.HPPercent == true,
        Callback = function(v) CFG.HPPercent = v end })
    T:CreateToggle({ Name = "Скорость цели", Flag = "PE_Speed",
        CurrentValue = CFG.ShowSpeed == true,
        Callback = function(v) CFG.ShowSpeed = v end })
    T:CreateToggle({ Name = "Цвет ника по HP", Flag = "PE_NameHPColor",
        CurrentValue = CFG.NameHPColor == true,
        Callback = function(v) CFG.NameHPColor = v end })
    T:CreateToggle({ Name = "Прятать мёртвых", Flag = "PE_HideDead",
        CurrentValue = CFG.HideDead ~= false,
        Callback = function(v) CFG.HideDead = v end })
    T:CreateSlider({ Name = "Размер текста ESP", Flag = "PE_LabelSize",
        Range = {9, 24}, Increment = 1, CurrentValue = CFG.LabelSize or 13,
        Suffix = " px", Callback = function(v) CFG.LabelSize = v end })

    T:CreateSection("Коробки")
    T:CreateParagraph({ Title = "Коробки",
        Content = "3D-коробка строится по габаритам всей модели: облегает тело целиком и поворачивается вместе с игроком. Есть рамка и уголки." })
    T:CreateToggle({ Name = "Коробки игроков", Flag = "PE_Boxes2",
        CurrentValue = DRAW_OK and CFG.Boxes ~= false,
        Callback = function(v)
            CFG.Boxes = v
            if v and not DRAW_OK then
                CFG.Boxes = false
                warn("[PE] в этом исполнителе нет Drawing — коробки выключены")
            end
        end })
    T:CreateDropdown({
        Name = "Стиль коробки",
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
    T:CreateSlider({ Name = "Толщина коробки", Flag = "PE_BoxThick",
        Range = {1, 6}, Increment = 1, CurrentValue = CFG.BoxThick or 2,
        Callback = function(v) CFG.BoxThick = v end })
    T:CreateSlider({ Name = "Отступ коробки (экран)", Flag = "PE_BoxPad",
        Range = {0, 40}, Increment = 1, CurrentValue = CFG.BoxPad or 4,
        Suffix = " px", Callback = function(v) CFG.BoxPad = v end })
    T:CreateSlider({ Name = "Отступ 3D-коробки (студов)", Flag = "PE_BoxMargin",
        Range = {0, 5}, Increment = 0.1,
        CurrentValue = math.floor((tonumber(CFG.BoxMargin) or 0) * 10 + 0.5) / 10,
        Suffix = " st", Callback = function(v) CFG.BoxMargin = v end })
    T:CreateSlider({ Name = "Прозрачность коробки", Flag = "PE_BoxAlpha",
        Range = {0, 90}, Increment = 5,
        CurrentValue = math.floor((tonumber(CFG.BoxAlpha) or 0) * 100 + 0.5),
        Suffix = " %", Callback = function(v) CFG.BoxAlpha = v / 100 end })
    T:CreateToggle({ Name = "Затухание коробок по дистанции", Flag = "PE_DistFade",
        CurrentValue = CFG.DistFade == true,
        Callback = function(v) CFG.DistFade = v end })

    T:CreateSection("Визуалы игроков")
    T:CreateToggle({ Name = "Скелет ESP", Flag = "PE_Skeleton",
        CurrentValue = CFG.Skeleton == true,
        Callback = function(v) CFG.Skeleton = v end })
    T:CreateSlider({ Name = "Толщина скелета", Flag = "PE_SkeletonThick",
        Range = {1, 4}, Increment = 1, CurrentValue = CFG.SkeletonThick or 1,
        Callback = function(v) CFG.SkeletonThick = v end })
    T:CreateSlider({ Name = "Скелет: ближе не показывать", Flag = "PE_SkelMinDist",
        Range = {0, 60}, Increment = 2, CurrentValue = CFG.SkelMinDist or 12,
        Suffix = " st", Callback = function(v) CFG.SkelMinDist = v end })
    T:CreateToggle({ Name = "Полоска HP над головой", Flag = "PE_HealthBars",
        CurrentValue = CFG.HealthBars ~= false,
        Callback = function(v) CFG.HealthBars = v end })
    T:CreateSlider({ Name = "Ширина полоски HP", Flag = "PE_HealthBarWidth",
        Range = {20, 80}, Increment = 2, CurrentValue = CFG.HealthBarWidth or 40,
        Suffix = " px", Callback = function(v) CFG.HealthBarWidth = v end })
    T:CreateSlider({ Name = "Высота полоски HP", Flag = "PE_HealthBarHeight",
        Range = {2, 10}, Increment = 1, CurrentValue = CFG.HealthBarHeight or 4,
        Suffix = " px", Callback = function(v) CFG.HealthBarHeight = v end })
    T:CreateToggle({ Name = "Цифры HP на полоске", Flag = "PE_HPBarText",
        CurrentValue = CFG.HPBarText ~= false,
        Callback = function(v) CFG.HPBarText = v end })
    T:CreateToggle({ Name = "Градиент полоски HP", Flag = "PE_HPGradient",
        CurrentValue = CFG.HPGradient ~= false,
        Callback = function(v) CFG.HPGradient = v end })
    T:CreateToggle({ Name = "Рамка вокруг головы", Flag = "PE_HeadBox",
        CurrentValue = CFG.HeadBox ~= false,
        Callback = function(v) CFG.HeadBox = v end })
    T:CreateSlider({ Name = "Размер рамки головы", Flag = "PE_HeadBoxSize",
        Range = {10, 50}, Increment = 1, CurrentValue = CFG.HeadBoxSize or 22,
        Suffix = " px", Callback = function(v) CFG.HeadBoxSize = v end })
    T:CreateToggle({ Name = "Рамка головы по цвету роли", Flag = "PE_HeadBoxRole",
        CurrentValue = CFG.HeadBoxRole ~= false,
        Callback = function(v) CFG.HeadBoxRole = v end })
    T:CreateToggle({ Name = "Стрелки к игрокам (snaplines)", Flag = "PE_Snaplines",
        CurrentValue = CFG.Snaplines ~= false,
        Callback = function(v) CFG.Snaplines = v end })
    T:CreateSlider({ Name = "Толщина стрелок", Flag = "PE_SnapArrowThick",
        Range = {1, 6}, Increment = 1,
        CurrentValue = math.clamp(tonumber(CFG.SnapArrowThick) or 2, 1, 6),
        Suffix = " px", Callback = function(v) CFG.SnapArrowThick = v end })
    T:CreateDropdown({
        Name = "Стрелки от: откуда",
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
    T:CreateSlider({ Name = "Прозрачность стрелок", Flag = "PE_SnapAlpha",
        Range = {0, 10}, Increment = 1,
        CurrentValue = math.floor((tonumber(CFG.SnapAlpha) or 1) * 10 + 0.5),
        Suffix = " /10", Callback = function(v) CFG.SnapAlpha = v / 10 end })
    T:CreateToggle({ Name = "Стрелки к целям за экраном", Flag = "PE_OffArrows",
        CurrentValue = CFG.OffArrows ~= false,
        Callback = function(v) CFG.OffArrows = v end })
    T:CreateToggle({ Name = "Кольцо под целью", Flag = "PE_GroundRing",
        CurrentValue = CFG.GroundRing ~= false,
        Callback = function(v) CFG.GroundRing = v end })
    T:CreateToggle({ Name = "Вектор движения цели", Flag = "PE_MoveVec",
        CurrentValue = CFG.MoveVec == true,
        Callback = function(v) CFG.MoveVec = v end })
    T:CreateToggle({ Name = "Лёгкий режим ESP (меньше нагрузки)", Flag = "PE_LiteESP",
        CurrentValue = CFG.LiteESP == true,
        Callback = function(v) CFG.LiteESP = v end })

    T:CreateSection("Миникарта")
    T:CreateToggle({ Name = "Миникарта", Flag = "PE_Minimap",
        CurrentValue = CFG.Minimap == true,
        Callback = function(v) CFG.Minimap = v end })
    T:CreateSlider({ Name = "Размер миникарты", Flag = "PE_MinimapSize",
        Range = {100, 300}, Increment = 10, CurrentValue = CFG.MinimapSize or 160,
        Suffix = " px", Callback = function(v) CFG.MinimapSize = v end })
    T:CreateToggle({ Name = "Точка себя на миникарте", Flag = "PE_MinimapSelf",
        CurrentValue = CFG.MinimapSelf ~= false,
        Callback = function(v) CFG.MinimapSelf = v end })

    local M = W:CreateTab("Мир", "magnet")
    M:CreateSection("Предметы на земле")
    M:CreateParagraph({ Title = "Предметы",
        Content = "Подсветка пушек, кейкарты, ящиков с патронами и молотка на земле (через стены)." })
    M:CreateToggle({ Name = "Пушки/ключи/патроны на земле", Flag = "PE_Items",
        CurrentValue = CFG.Items ~= false,
        Callback = function(v) CFG.Items = v end })

    local R = W:CreateTab("Разведка", "search")
    R:CreateSection("Разведка")
    R:CreateParagraph({ Title = "Как проверять дыры",
        Content = "1) PE.Remotes() в консоль — все ремоуты. 2) PE.Guns() — ТТХ пушек. 3) PE.Probe(\"InflictTarget\", workspace[\"НИК\"].Humanoid) — урон по чужой части. PE.Probe(\"ChangeAmmoAndClip\", 30, 30) — патроны. PE.Probe(\"ChooseTeamEvent\", \"Guard\") — смена команды. PE.TeamOf(игрок) — как скрипт видит роль." })
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
    pcall(function() mainConn:Disconnect() end)
    pcall(function() itemConn:Disconnect() end)
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
    G.PE.Guns, G.PE.Remotes, G.PE.Probe, G.PE.TeamOf = nil, nil, nil, nil
    local rfOld = Rayfield
    Rayfield = nil
    if rfOld then task.defer(function() pcall(function() rfOld:Destroy() end) end) end
    G.PE_Stop = nil
    G.PE_LOADED_AT = nil
    print("[PE] v0.2 остановлен")
end

print("[PE] v0.2 запущен | Drawing=" .. tostring(DRAW_OK)
    .. " | консоль: PE.Guns() / PE.Remotes() / PE.Probe(...) / PE.TeamOf(...)")
