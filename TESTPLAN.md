# ТЕСТ-ПЛАН PrisonESP v2.50 — вживую, по порядку (от безопасного к заметному)

Запуск:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/PrisonESP/main/PrisonESP.lua",true))()
```
Старт: `[PE] v2.50 started | Drawing=true | Rayfield=true | ...`; через 3 с сам печатает `[PE DIAG] START ... END`. Выше должна быть строка `[PE VIS] Drawing objects (3 slots): lines=3 squares=3 circles=3 text=3` (нули = рисовалки не работают). Все логи (F9) после теста скинуть агенту. Пустой сервер лучше. Тесты 6–7 самые видимые — последними.

## 1. АДМИН-ДЕТЕКТОР (пассивный; ESP → Roles → "Admins highlight + alert", вкл. по умолч.)
- Что: просто играть. При входе одного из 4 известных админов/создателя — плашка магента + тег [ADMIN].
- Успех: warn `[PE] ADMIN ON SERVER: <ник> (userId N) - be careful!` + всплывашка Rayfield.
- Провал: админ подсвечен обычным цветом без [ADMIN] → прислать ник+userId. Админов нет — «не проверено», не блокирует остальные.

## 2. КОМАНДА (Combat → Team & status)
- а) Кнопка "Team: ESCAPED (criminal)" (быть заключённым): `[PE TEAM] ChooseTeamEvent('Escaped'). WATCH YOUR TEAM!`; в Tab команда сменилась, ESP-тег красный [CRIM].
- б) Дропдаун "Switch team" → Prisoner: `[PE] team switch: Prisoner` + та же строка [PE TEAM], респавн в зеке.
- Провал: print есть, команда не сменилась → сервер режет ChooseTeamEvent → агенту переделать/убрать.

## 3. ПРОКАЧКА ПУШКИ (Combat → Gun upgrade). Пушка в РУКАХ: Combat → Weapon giver → "Give: M9"
- Гивер: `[PE GIVE] M9: fireclickdetector -> true`; "Auto-give after death" + дропдаун M9 → после смерти `[PE GIVE] auto-gave M9 after respawn`.
- а) "UPGRADE gun in hands": `[PE MOD] M9 upgraded: damage 250, headshot x500, shotgun 8 pellets, explosive r25, burning, knockback 0, auto, no spread` (строка зависит от включённых тумблеров); ваншот в голову, очереди, взрывы.
- б) "Auto-upgrade (equip/respawn)": новая пушка/респавн → та же строка [PE MOD] сама за ~1 с.
- в) "Ammo hack: 1e9 clip via real reload": перезарядка → магазин не кончается. Пушка зависла пустой = сервер сверяет свой Setting (так задумано, не баг теста).
- г) "Sniper scope on any gun (E key)": E на любой пушке зумит.
- Провал: урон как был → сервер не берёт клиентский Setting → слить консоль целиком. `take a gun in HANDS (Setting not found)` = пушки не было в руках.

## 4. КИЛЛ-АУРА (Combat → Kill aura (InflictTarget); пушка в руках/рюкзаке)
- а) Toggle "Kill aura", "Damage per shot" ~200: враги в радиусе "Aura radius" теряют HP без прицела. Без пушки warn раз в 10 с `[PE] kill aura: no gun with InflictTarget - take a weapon` (не баг).
- б) "Lifesteal (heal self per hit)": свой HP полный. в) "Burn targets (fire DOT)": жертвы горят после отхода.
- г) "Fling targets (mega knockback up)" + "Fling direction" (Up/Away from me/Random): жертв швыряет.
- д) "Infinite aura range (whole map)": бьёт по всей карте. е) "Max targets per tick" 20 = мясорубка.
- ж) "Who to hit" → выбрать ник: `[PE] kill aura target: <ник>`, бьёт только его.
- з) "Immortality (self-heal loop, 0 dmg)": HP сам восстанавливается. и) "Kill sound (death beep)": бип при смерти цели (только у тебя).
- к) "Auto-burn attacker (retribution)": получили урон → `[PE RET] attacker: <ник> -> BURN`, атакующий горит ~1.5 с.
- Провал: HP целей не падает → сервер валидирует пакеты → агенту переработать.

## 5. ДВИЖЕНИЕ (Combat → Movement)
- а) "Speed hack (WalkSpeed)" + слайдер "Speed (studs/s)". б) "Noclip (walk through walls)". в) "Fly (WASD + Space/Ctrl)" + "Fly speed".
- г) "Infinite jump (jump in air)". д) "Jump boost (higher jumps)" + "Jump power".
- е) "TP to crosshair (blink)": прицел на стену → `[PE TP] teleported to crosshair`; в небо → `[PE TP] aim at a surface first (sky has no target)`.
- ж) Waypoints: имя + "SAVE waypoint (my position)" → `[PE WP] saved 'armory' (total 1)`; дропдаун + "TELEPORT to waypoint" → `[PE WP] teleported to 'armory'`.
- з) "Anti-AFK (no idle kick)": 20+ мин бездействия — нет кика. и) "Anti-stun (taser/cuffs/ragdoll)": тазер/наручники охраны не валят. к) "FPS boost": `[PE FPS] boost ON (quality 1, shadows off)`.
- Провал: физика не меняется → сервер/исполнитель режет клиентскую физику → слить консоль.

## 6. C00LKIDD MODE (Combat → C00LKIDD MODE (2014); нужна пушка)
- "Slow burn EVERYONE (server-wide fire)" + "C00l fling (throw everyone)": весь сервер горит и медленно умирает ("Burn damage per tick"), флинг швыряет горящих. Дропдаун "Who burns" → ник: `[PE] burn target: <ник>`.
- Без пушки: warn `[PE] c00lkidd: no gun with InflictTarget` (раз в 10 с).
- "Fire paint (draw with fire at cursor)": курсор рисует огонь по стенам (сервер может отвергнуть части карты — тогда огонь только на врагах). Нет живого врага-носителя: warn `[PE PAINT] no enemy alive to carry the fire`.
- Провал: никто не горит → сервер стал проверять пакеты → переработать.

## 7. АПОКАЛИПСИС (Combat → APOCALYPSE (auto killer)) — самый заметный, держать 30–60 с
- Тоггл "APOCALYPSE (auto killer machine)" сам делает всё: `[PE APOC] perch point saved (+400 studs)` (тп вверх + якорь), сам берёт M9, если пушки нет, сам мигает Prisoner↔Escaped раз в 1 с (обход командных проверок), всем игрокам 100 урона + огонь ("Apocalypse damage") раз в 0.5 с.
- Выкл: `[PE APOC] perch released`, возврат на землю.
- Провал: нет вышки/урона → слить консоль; пушка не берётся → проверить `[PE GIVE] model 'M9' not found on the ground`.

## 8. ESP-ДОПОЛНЕНИЯ (вкладка ESP)
- а) "Chams (role highlight, through walls)": игроки подсвечены цветом роли сквозь стены.
- б) "Invisible walls ESP (perimeter)": голубой периметр невидимых стен (флай не бьётся в пустоту).
- в) "Danger/escape zones ESP": красные Death Part, зелёный EscapePart.
- г) "AUTO-ESCAPE (tp to zone and back)" (быть заключённым): `[PE ESCAPE] on the zone (N studs), waiting for escape...` → 0.6 с → `[PE ESCAPE] returned home`, побег засчитан. Нет зоны: `[PE ESCAPE] no EscapePart on the map`.
- д) "Guns/keycards/ammo on ground": подсветка предметов сквозь стены. е) "Minimap": точки игроков в углу экрана.
- Провал: подсветки нет при Drawing=true → прислать строку `[PE VIS]` + скрин.

## 9. НАСТРОЙКИ (Settings) + СБРОС
- а) Дропдаун "Menu language / Язык меню" → Русский: `[PE] language = Русский - press RESTART SCRIPT to apply`.
- б) "RESTART SCRIPT (apply language)": `[PE] restarting with new language...` → новое окно на русском.
- в) Конфиг: включённые тогглы восстанавливаются после перезапуска скрипта/реjoin (Rayfield config, папка PrisonESP).
- г) "UNLOAD script (full cleanup)": `[PE] unloading...` → `[PE] v2.50 stopped`, окно и ESP исчезли, повторный запуск работает.
- Провал: язык/конфиг не применились → слить консоль.

После теста: всю консоль (F9) сохранить. Перед выходом с сервера выключить боевые тогглы.
