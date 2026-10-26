# 8 новых фич для PrisonESP (v2.56+)

Прочитано: `PrisonESP.lua` (4674 строки, v2.56), `GAME_REPORT.md`, `BUGHUNT.md`, `studio/gunscript_m16_full.txt`, `studio/pe_remotes.txt`, git-история. Всё ниже — только то, чего в текущем скрипте **нет**; удалённые по просьбе фичи (наручники, тазер, сайлент-аим, текстур-свап, спинбот) и старый punch-ауру не предлагаю.

Сортировка — по «эпичность × дешевизна»: Э (1–10) / цена (S=1, M=2). Чем выше — тем больше вау за меньше кода.

| # | Фича | Что даёт | Э | Цена | Э/Ц | Палево |
|---|------|----------|---|------|-----|--------|
| 1 | **Гильотина** | убийство чужими руками: толчок в Death Part | 9 | S | **9.0** | среднее |
| 2 | **Эхолот** | радар всех выстрелов на карте, 0 пакетов | 8 | S | **8.0** | нет |
| 3 | **Жирные хитбоксы** | локально увеличенные Head/Torso — больше хедшотов | 8 | S | **8.0** | низкое* |
| 4 | **Воронка** | притянуть толпу в точку / в зону смерти | 7 | S | **7.0** | среднее |
| 5 | **Розыск** | снять/повесить CriminalStatusRemote | 7 | S | **7.0** | среднее |
| 6 | **Призрачные троны** | сеть 97 невидимых сидений-вышек | 8 | M | **4.0** | среднее |
| 7 | **Пепел** | паник-очистка при входе админа | 8 | M | **4.0** | нет |
| 8 | **Мститель** | авто-реванш после смерти | 7 | M | **3.5** | высокое |

\* «Жирные хитбоксы» — не сайлент-аим: наведения нет, только локальная геометрия. Если правило «никакой аим-помощи» распространяется и на это — вычеркните, останется 7 идей + запасная.

> По чистой пользе для выживания «Пепел» — №1, но по метрике он ниже: M и без вау-эффекта.

---

## 1. «ГИЛЬОТИНА» — толчок в Death Part

**Что делает.** Берёт выбранную жертву, находит ближайшую Death Part (9 невидимых полос на Y=28, 4.8×5.5, `CanCollide=false`, убивают по `Touched`; в BUGHUNT местами ×10 — не хардкодь число, ищи по имени) и двумя пакетами `InflictTarget` забрасывает тело на полосу: сначала подброс вверх, потом толчок в сторону полосы. Смерть наступает от касания карты, а не от твоего урона → анти-ТК-счётчик «3 невинных», скорее всего, не получает атрибуции (у Death Part нет killer'а — проверить на живом сервере). Режимы: «ближайшая Death Part», «EscapePart» (пометить зеком-беглецом), «за край» (сброс вниз).

**На чём держится.**
- `InflictTarget(Humanoid, Part, damage, dir, knockback, lifesteal, flame)` — 4-й аргумент задаёт направление отдачи, 5-й — силу; сервер дистанцию не проверяет (`GAME_REPORT.md` §2–3).
- Death Part ×9 на Y=28, `CanCollide=false`, урон по `Touched` (`BUGHUNT.md`, «Геометрия карты»; в отчёте местами ×10, поэтому число не хардкодим).
- Тип-чек сервера есть → если цель тиммейт, сначала `ChooseTeamEvent` на вражескую команду и 0.4–0.5 с паузы (как в Apocalypse).
- v2.56 умеет брать **чужой** `InflictTarget`-ремоут, так что своя пушка не обязательна.

**Риск палева: средний.** Тело красиво летит, но пакет выглядит как обычная отдача пушки: урон 1, огня нет, вампиризма нет. Если сервер логирует knockback — видно аномалию, но в игре такого лога нет. Это не «ещё один флинг»: флинг уже есть, а здесь карта используется как оружие — цель умирает от Death Part, и убийство не приписывается тебе.

**Сложность: S** (~50–70 строк + слайдер импульса).

```lua
-- CFG.DeathImpulse (3000..12000), CFG.DeathRange = 120
local function nearestDeathPart(pos, maxD) local best, bestD
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "Death Part" then
            local dd = (d.Position - pos).Magnitude
            if dd <= (maxD or 120) and (not bestD or dd < bestD) then best, bestD = d, dd end
        end
    end
    return best end
local function guillotine(plr)
    local _, hum, root = char(plr)              -- живые Humanoid + HRP
    local part = hum and root and hum.Health > 0 and nearestDeathPart(root.Position)
    if not part then return end
    if sameTeam(plr) then switchTeamForAttack(); task.wait(0.5) end
    local r = myGunRemote("InflictTarget"); if not r then return end
    r:FireServer(hum, root, 1, Vector3.new(0, 1, 0), 3500, 0, false)  -- отрыв
    task.wait(0.28); local dir = (part.Position + Vector3.new(0, 1, 0) - root.Position).Unit
    r:FireServer(hum, root, 1, dir, CFG.DeathImpulse or 6000, 0, false) -- в полосу
    print("[PE GUILLOTINE] " .. plr.Name .. " -> " .. part.Name)
end
```

Проверка: включить Danger-ESP, встать в 30–60 стадах от стены, толкнуть бота; если не долетает — поднять импульс/сделать два толчка с интервалом 0.12 с.

---

## 2. «ЭХОЛОТ» — радар всех выстрелов

**Что делает.** Слушает `VisualizeBullet` у каждой экипированной пушки и рисует трассер от ствола до точки попадания на 1–2 с: кто, откуда и куда стрелял. Если точка попадания ближе 10–12 стадов к тебе — алерт «SHOT AT YOU» и стрелка направления. На миникарте — вспышка стрелка. Работает сквозь стены и на всю карту, потому что сервер ретранслирует трассер всем.

**На чём держится.**
- `VisualizeBullet:FireServer(handle, MuzzleOffset, hitPos, MuzzleEffect, HitEffect, soundId, {взрыв}, {визуал}, true, false)`; сервер ретранслирует трассер всем (`BUGHUNT.md` §«Вторая смена», `GAME_REPORT.md` п.19).
- Пушки лежат в `Workspace/<ник>/<оружие>/`, `VisualizeBullet` — прямой ребёнок тулзы (как `tool:FindFirstChild("VisualizeBullet")` в `FakeShot`); `handle` — часть пушки, по её предку находится игрок.
- Скрипт уже умеет рисовать линии/трейсеры (`vLine`, `drawSnapArrow`), так что новый рендер не нужен.

**Риск палева: ноль.** Только чтение `OnClientEvent`, ни одного лишнего пакета, ничего не реплицируется.

**Сложность: S** (~60–80 строк с рендером и алертом).

```lua
local function hookAll()
    for _, d in ipairs(workspace:GetDescendants()) do
        local vb = d:IsA("Tool") and d:FindFirstChild("VisualizeBullet")
        if vb and not vb:GetAttribute("PE_Hooked") then
            vb:SetAttribute("PE_Hooked", true)
            vb.OnClientEvent:Connect(function(handle, off, hitPos)
                local plr = handle and Players:GetPlayerFromCharacter(handle:FindFirstAncestorOfClass("Model"))
                if not handle or plr == LP then return end
                addTracer((handle.CFrame * CFrame.new(off)).Position, hitPos,
                    plr and roleColor(roleOf(plr)) or Color3.new(1, 1, 1), 1.5)
                if (hitPos - myRoot().Position).Magnitude < 12 then
                    notify("[SHOT] " .. (plr and plr.Name or "?") .. " -> YOU")
                end
            end)
        end
    end
end
task.spawn(function()
    while not STOPPED do hookAll(); task.wait(2) end
end)
```

Бонус: тем же хуком можно слушать `casing`/`reload` (если сервер их тоже ретранслирует) — «кто перезаряжается» и «кто рядом». Если релей на сервере выключен, фича молча умрёт: добавь счётчик `[PE RADAR] events/min` в консоль для проверки.

---

## 3. «ЖИРНЫЕ ХИТБОКСЫ» — локальный размер головы

**Что делает.** Локально увеличивает `Head`/`Torso` врагов (например, Head ×2.2, Torso ×1.4). Клиентский `GunScript_Local` сам делает `FindPartOnRay` по воркспейсу и отправляет серверу уже готовую пару `(Humanoid, Part, damage)`: увеличенная голова ловит больше лучей, хедшоты летят чаще, а пакеты остаются «честными» — как будто ты просто хорошо стреляешь. Никакого наведения и никаких доп. пакетов.

**На чём держится.**
- Весь урон и попадание считаются в `GunScript_Local` (`RayCast` → `FindPartOnRay`), сервер доверяет аргументу `Part`; хедшот = часть с именем `Head` (`studio/gunscript_m16_full.txt`, `BUGHUNT.md`).
- Изменение `Size` у чужой части — локальное, сервер и другие клиенты его не видят.
- Модели R6/R15: `Head` + `Torso`/`UpperTorso`/`LowerTorso`.

**Риск палева: низкий\***. Ноль сетевых пакетов, ноль изменений на сервере; заметно только по «слишком частым» хедшотам. Если сервер когда-нибудь добавит проверку дистанции/части — фича отвалится. \*Это аим-помощь по духу; если она противоречит твоему правилу после удаления сайлент-аима — не включай.

**Сложность: S** (~40–60 строк).

```lua
-- CFG.HitboxHead = 2.2, CFG.HitboxBody = 1.4
local orig = {}
local function scalePart(part, mult)
    if not orig[part] then orig[part] = part.Size end
    part.Size = orig[part] * mult
end
local function hitboxTick()
    for _, p in ipairs(Players:GetPlayers()) do
        local ch = p ~= LP and not isAdminP(p) and p.Character
        if ch then
            for _, nm in ipairs({ "Head", "Torso", "UpperTorso", "LowerTorso" }) do
                local part = ch:FindFirstChild(nm)
                if part and part:IsA("BasePart") then
                    scalePart(part, nm == "Head" and CFG.HitboxHead or CFG.HitboxBody)
                end
            end
        end
    end
end
-- off: for part, sz in pairs(orig) do if part.Parent then part.Size = sz end end
```

Не трогай `CanCollide`, `Massless` и свои части — только `Size` чужих `Head/Torso`; при выходе игрока чисти `orig` (слабые ключи).

---

## 4. «ВОРОНКА» — гравитационный пул

**Что делает.** Тянет всех врагов в радиусе к выбранной точке: `dir = (point - victim).Unit`, `knockback` 1500–4000. Режимы: «ко мне» (собрать в кучу под AoE/ауру), «в Death Part» (комбо с Гильотиной), «в EscapePart» (пометить беглецом), «в камеру» (затащить и закрыть дверь), «разбросать» (обратный вектор). В отличие от нынешнего флинга (Up / Away / Random), это **притяжение**, а не отталкивание.

**На чём держится.**
- 4-й аргумент `dir` управляет направлением отдачи, 5-й — силой; c00lkidd уже швыряет всех через `dir = delta.Unit` + `20000` (`PrisonESP.lua`, c00l-блок).
- Сервер не проверяет дистанцию до цели (доказано c00lkidd-тестом); импульс применяет серверная физика, поэтому вектор `dir` и сила реально двигают тело.
- Серверный тим-чек: по тиммейтам пакет не пройдёт → либо цель враг, либо авто-смена команды.

**Риск палева: средний.** Толпа, ползущая в одну точку, выглядит странно; держи радиус 40–60, до 6 целей, импульс 1500–4000, без урона и огня. Это не флинг «от себя»: вектор считается **к точке**, поэтому можно не разбрасывать, а собирать — этого в текущем меню нет.

**Сложность: S** (~50–70 строк).

```lua
-- point: myRoot.Position | deathPart.Position | escapePart.Position | cell
local function vortex(point, radius, impulse)
    local r = myGunRemote("InflictTarget"); if not r or not point then return end
    local n = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and n < 6 then
            local ch, hum, root = char(p)
            if ch and hum and hum.Health > 0 and root
               and not root.Anchored and not hum.Sit
               and (root.Position - point).Magnitude <= radius then
                local dir = point - root.Position
                dir = dir.Magnitude > 2 and dir.Unit or Vector3.new(0, 1, 0)
                r:FireServer(hum, root, 1, dir, impulse, 0, false)
                n = n + 1
            end
        end
    end
    print("[PE VORTEX] pulled " .. n .. " -> " .. tostring(point))
end
```

Комбо: «Воронка ко мне» → аура/дробовик; «Воронка в дверь» → `fireclickdetector` на двери камеры (закрыть) — это уже есть, просто свяжи кнопкой.

---

## 5. «РОЗЫСК» — CriminalStatusRemote

**Что делает.** Две кнопки: **«снять с себя»** (после ТК/побега отправить `false/0/nil` варианты; если сервер слушает — сбрасывает `Criminal`, и охрана перестаёт видеть тебя преступником) и **«повесить на цель»** (отправить игрока/ник + `true`; если слушает — охрана охотится на него). Плюс слушатель `OnClientEvent`, который один раз покажет реальный протокол — по нему и выбирается правильный вариант.

**На чём держится.**
- `CriminalStatusRemote` реально существует (`pe_remotes.txt`, №42; ищи рекурсивно: `ReplicatedStorage:FindFirstChild("CriminalStatusRemote", true)`) и в списке подтверждённых ремоутов.
- `BUGHUNT.md` п.13: «если сервер слушает клиент, можно сбросить криминальный статус».
- `roleOf` уже читает атрибут `Criminal` у игрока — статус виден и другим читателям ESP.
- Анти-ТК-счётчик серверный, но именно поэтому сброс статуса ценен.

**Риск палева: средний.** Если сервер проверяет отправителя — не произойдёт ничего (только лог). Если слушает — статус меняется видимо (иконка/цвет/охота охраны), поэтому не спамь: 1 пакет в 3 с, максимум 4 варианта.

**Сложность: S** (~30–50 строк + зонд).

```lua
local r = ReplicatedStorage:FindFirstChild("CriminalStatusRemote", true)
if r then
    r.OnClientEvent:Connect(function(...)
        print("[PE WANTED] <-", ...) -- учим протокол по ответам сервера
    end)
end
local function wantedSend(clear, target)
    if not r then return end
    local list = clear
        and { {false}, {0}, {LP, false}, {LP, 0} }
        or  { {target, true}, {target and target.Name, true} }
    for _, args in ipairs(list) do
        pcall(function() r:FireServer(table.unpack(args)) end)
        task.wait(0.35)
    end
    print("[PE WANTED] " .. (clear and "CLEAR self" or "MARK " .. tostring(target)))
end
-- в ESP: plr:GetAttribute("Criminal") == true -> метка WANTED
```

Проверка: сначала 1 вариант `false`, смотри `LP:GetAttribute("Criminal")`, `LP.Team`, уведомления; если 0 реакции — сервер не слушает, фичу в топку (не долби).

---

## 6. «ПРИЗРАЧНЫЕ ТРОНЫ» — сеть 97 невидимых сидений

**Что делает.** Индексирует 97 невидимых `Seat` (Tr=1, CanCollide) — это готовые подставки в воздухе. Показывает их ромбиками на ESP/миникарте с высотой, даёт кнопки «сесть на ближайший / следующий / случайный / самый высокий», «встать» и «вернуться». Телепорт на сиденье = стоишь на невидимой платформе в небе: снайперское гнездо, безопасный АФК, побег из драки. 14 невидимых `TextPart`-полок — запасные точки.

**На чём держится.**
- 97 `Seat` с `Transparency=1`, `CanCollide=true` как подставки в воздухе (дамп карты); в скан берём только `Anchored`, иначе сиденье упадёт вместе с тобой.
- 14 невидимых `TextPart`-полок и 14 частей `Tr=0.95` — альтернативные площадки/укрытия.
- Клиентский телепорт `root.CFrame` игра не проверяет (уже используется в waypoints/TP).
- Сиденья анкорнутые и с коллизией: достаточно встать сверху, `Seat:Sit` не обязателен (но можно как якорь от флинга).

**Риск палева: средний.** Сидящий/стоящий в воздухе персонаж виден, если смотреть вверх; на высоте 80+ стадов и за геометрией — почти нет. Другие ESP-юзеры тебя увидят. Стоя на месте, ты уязвим для ауры — добавляй «auto-stand при уроне» (или используй Пепел). Это не замена флаю: флай постоянно палится движением, а трон — статичная невидимая точка, с которой можно стрелять и которую снизу не видно.

**Сложность: M** (~100–150 строк: скан, маркеры, хоткеи, возврат).

```lua
local thrones = {}; local function scanThrones()
    thrones = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Seat") and d.Transparency >= 1 and d.CanCollide and d.Anchored and d.Position.Y > 15 then
            thrones[#thrones + 1] = d
        end
    end
    table.sort(thrones, function(a, b) return a.Position.Y > b.Position.Y end)
    print("[PE THRONE] invisible seats: " .. #thrones)
end
local function throneGo(i)
    local s, root = thrones[i or 1], myRoot(); if not s or not root then return end
    CFG._throneHome = root.CFrame
    root.CFrame = s.CFrame + Vector3.new(0, 3.5, 0) -- встаём сверху
    print("[PE THRONE] Y=" .. math.floor(s.Position.Y) .. " (" .. i .. "/" .. #thrones .. ")")
end
local function throneOff()
    local hum = myHumanoid(); if hum then hum.Sit = false; hum.Jump = true end
    if CFG._throneHome then myRoot().CFrame = CFG._throneHome end
end
```

Фильтруй сиденья внутри стен/под картой (луч вверх-вниз), не показывай ниже Y=15; проверь 3–5 точек, прежде чем делать «random».

---

## 7. «ПЕПЕЛ» — паник-очистка при входе админа

**Что делает.** Следит за `PlayerAdded`; если UserId из вшитого списка админов (86513279, 4008579942, 4865533262, 66120198) или создатель игры — за 0.3–0.5 с: выключает все шумные тумблеры (аура, апокалипсис, c00lkidd, fire paint, авто-гивер, бессмертие), **возвращает оригинальные значения Setting** на всех пушках (снимок делается при `ModGun`), снимает `PE_Marked`, уничтожает рисунки/чамсы/иконки, закрывает Rayfield, при `hard` — телепорт в скрытое Lobby под картой (Y≈-90). Скрипт остаётся загруженным, но спящим (`CFG._panic`), чтобы после ухода админа можно было «RE-ARM».

**На чём держится.**
- 4 админских UserId вшиты в клиентскую админ-панель (`GAME_REPORT.md` §3, `isAdminP` уже есть).
- Скрытое Lobby под картой: пол 30×30, спавн `-347.7, -90.5, -535.1` (`BUGHUNT.md`, «Скрытая комната»).
- `Setting`-модуль мутируется через require-кеш — значит, оригиналы можно сохранить и вернуть.
- Все ESP/аура/метки — клиентские, `VIS.destroy()` + `Rayfield:Destroy()` уже отработаны в `PE_Stop`.

**Риск палева: нет** для других (только свои действия); при `hard` телепорт в Lobby может быть замечен, если админ смотрит именно на тебя. Поэтому по умолчанию `soft` (очистка на месте), `hard` — только по кнопке/если ты «горит».

**Сложность: M** (~150–200 строк: снимок, восстановление, гейт всех циклов, UI).

Не забудь пройтись по `Players:GetPlayers()` на старте: админ мог быть в игре ещё до загрузки скрипта, а `PlayerAdded` для него уже не сработает.

```lua
-- снимок: CFG._gunOrig[tool] = shallowCopy(require(tool.Setting)) при первом ModGun
local function ash(mode, why)
    CFG._panic = true
    for _, k in ipairs({ "KillAura", "Apocalypse", "C00lMode", "FirePaint",
        "AutoGive", "Immortal", "AuraFling", "Retr", "GunFire" }) do CFG[k] = false end
    for tool, o in pairs(CFG._gunOrig or {}) do
        if tool.Parent then
            local S = require(tool.Setting); for k, v in pairs(o) do S[k] = v end
            tool:SetAttribute("PE_Marked", nil)
        end
    end
    VIS.destroy(); clearHighlights()
    if mode == "hard" then
        local r = myRoot(); if r then r.CFrame = CFrame.new(-347.7, -85.5, -535.1) end
    end
    if Rayfield then pcall(function() Rayfield:Destroy() end) end
    print("[PE ASH] " .. why .. " | " .. mode .. " | clean")
end
Players.PlayerAdded:Connect(function(p) if isAdminP(p) then task.delay(0.5, function() ash("soft", p.Name) end) end end)
```

Важно: `CFG._panic` должен гейтить `auraTick`, c00l, apocalypse, fire paint, авто-гивер и рендер; иначе «выключили» только галочки, а циклы продолжат бить. Не вызывай `PE_Stop` — он выгружает скрипт, и «RE-ARM» уже не сделать. И **не меняй команду в панике**: сервер при смене команды респавнит на спавн команды и роняет пушку (v2.47) — это заметнее, чем телепорт в Lobby.

---

## 8. «МСТИТЕЛЬ» — авто-реванш после смерти

**Что делает.** Запоминает последнего, кто снял тебе HP (в `auraTick` уже есть `retTarget`/`findAttacker`), и после респавна: ждёт 1–1.5 с, добирает пушку через `EnsureWeapon`, телепортируется за спину убийцы, выжимает 1.5-секундный залп аурой и возвращается на сохранённую точку/спавн. Тумблер, кулдаун 20 с, игнор админов, отключение при `Immortal`/`Apocalypse`/`_panic`.

**На чём держится.**
- Быстрый респавн и авто-гивер уже есть (`FastRespawn`, `EnsureWeapon`).
- `retTarget`/`findAttacker` уже вычисляют атакующего по падению HP и вооружённости.
- Клиентский телепорт `root.CFrame` работает; серверный тим-чек требует быть врагом → при необходимости `ChooseTeamEvent`.
- v2.56: своя пушка не обязательна — берётся чужой `InflictTarget`-ремоут.

**Риск палева: высокий.** Телепорт + мгновенный урон — самый заметный паттерн; можно ударить не того, если эвристика ошиблась (тогда анти-ТК). Ограничь: только цель, снявшая HP за последние 5 с; не бить, если админ в игре; лог в консоль; максимум один реванш на смерть.

**Сложность: M** (~80–120 строк: запоминание, ожидание респавна, возврат).

Не путать с `Retribution`: тот бьёт атакующего, пока ты жив; «Мститель» — только после смерти, когда ретрибуция уже не сработает.

```lua
local lastHit, lastHitAt = nil, 0
local function revengeTry(ch)
    if not CFG.Revenge or CFG._panic or CFG.Immortal or CFG.Apocalypse then return end
    if not lastHit or os.clock() - lastHitAt > 25 then return end
    task.wait(1.3) -- респавн + выдача пушки
    G.PE.EnsureWeapon("revenge")
    local root = ch:FindFirstChild("HumanoidRootPart")
    local t = lastHit.Character and lastHit.Character:FindFirstChild("HumanoidRootPart")
    if not (root and t) then return end
    local home = CFG._revengeHome or root.CFrame
    root.CFrame = t.CFrame * CFrame.new(0, 0, 3) -- за спину
    for i = 1, 10 do
        local hum = lastHit.Character and lastHit.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then auraHit(lastHit) end
        task.wait(0.1)
    end
    root.CFrame = home
    print("[PE REVENGE] " .. lastHit.Name .. " punished")
end
LP.CharacterAdded:Connect(revengeTry)
```

`lastHit` обновляется в `auraTick` при падении HP: `lastHit = retTarget or findAttacker(root); lastHitAt = os.clock()`. Комбо с «Пеплом»: если админ онлайн — реванш не запускать; если убийца — админ, не запускать никогда.

---

## Что НЕ предлагаю и почему

- **FistEvent / punch-аура.** Она уже была в v1.7–v2.12 и удалена в v2.13 (`git 92690d7`), причём в статическом дампе 46 ремоутов `FistEvent` вообще нет (`studio/pe_remotes.txt`) — сначала надо найти, где он живёт. Это реанимация старого, а не новая фича; к тому же требует подлёта и слабее `InflictTarget`.
- **Наручники, тазер, сайлент-аим, текстур-свап, спинбот** — удалены по твоей просьбе в v2.37 (`b903f8e`), не возвращаю.
- **Крашеры/DoS, фаззинг ремоутов, спам `VisualizeBullet`/`casing`** — запрещено правилом; всё выше либо чтение, либо 1–6 пакетов на действие.
- **Фейковые анонсы, спектейт, админ-команды** — сервер игнорирует (`BUGHUNT.md`).
- **Магазин/геймпассы** — только реальные деньги.
- **Самохил/самоподжог** — сервер отклоняет вызовы по себе и тиммейтам; в v2.55 это обошли вампир-тапом, отдельная фича не нужна.
- **«Посадить другого на сиденье»** — чужим персонажем клиент не управляет; сиденья — только для себя.

## Порядок внедрения

1. **Эхолот** — нулевой риск, сразу даёт информацию для всех остальных.
2. **Гильотина** — 1 слайдер и 2 пакета, моментально «эпик».
3. **Жирные хитбоксы** — если разрешаешь аим-помощь; 30 строк.
4. **Воронка** — комбо с Гильотиной и дверями.
5. **Розыск** — сначала зонд, потом UI.
6. **Троны** — скан + 3 кнопки, без скандального «Sit» (просто встать сверху).
7. **Пепел** — после того как все фичи готовы: он должен выключать их все.
8. **Мститель** — последним: самый палевный.
