# ТЕСТ-ПЛАН PrisonESP v2.23 — вживую, по порядку (от безопасного к заметному)

Запуск:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/blegbot1/PrisonESP/main/PrisonESP.lua",true))()
```
После старта в консоли ждать `[PE] v2.23 started ...`, через 3 сек — [PE DIAG].
Все логи/скрины консоли после теста скинуть агенту. Пустой сервер лучше.

## 1. АДМИН-ДЕТЕКТОР (безопасный, пассивный)
- Где: ESP → Roles → "Admins highlight + alert" (вкл. по умолчанию).
- Что: просто играть; если заходит один из 4 известных админов/создатель — смотреть консоль.
- Успех: warn `[PE] ADMIN ON SERVER: <ник> (userId N) - be careful!`; плашка магента + тег [ADMIN].
- Провал: известный админ подсвечен обычным цветом без [ADMIN] → прислать ник+userId.
- Если админов нет — отметить «не проверено», не блокировать остальные тесты.

## 2. КНОПКА "Team: ESCAPED"
- Где: Combat → Team & status → "Team: ESCAPED (criminal)". Быть заключённым.
- Успех: консоль `[PE TEAM] ChooseTeamEvent('Escaped')...`; в Tab команда сменилась, ESP-тег красный [CRIM].
- Провал: команда не сменилась → сервер режет → агенту убрать/переделать кнопку.

## 3. ПРОКАЧКА ПУШКИ v2 (Combat → Gun upgrade; пушка в РУКАХ — дать через Weapon giver)
- а) "UPGRADE gun in hands": успех = `[PE MOD] ... upgraded: damage ..., headshot x..., shotgun ... pellets, explosive r...`; один выстрел в голову валит, вокруг взрыв (AoE).
- б) "Burning bullets (ignite)" ON + UPGRADE: у цели урон продолжается после выстрела (DOT).
- в) "Knockback (fling victims)" ~3000 + UPGRADE: жертву подбрасывает.
- г) Слайдеры "Headshot multiplier"/"Shotgun pellets"/"Burst bullets per click"/"Piercing": сдвинуть → UPGRADE → в строке [PE MOD] перечислено и ощущается.
- д) "Auto-upgrade (equip/respawn)": респавн/новая пушка → сам печатает [PE MOD] в течение ~1 сек.
- Провал: урон как был → сервер не берёт Setting → слить консоль целиком.

## 4. КИЛЛ-АУРА (Combat → Kill aura; пушка в руках)
- а) Toggle "Kill aura" (или клавиша K — `[PE] kill aura ON (keybind)`): враги в радиусе теряют HP без прицела. Warn "no gun with InflictTarget" = пушки нет, не баг.
- б) "Lifesteal": при ударах свой HP полный.
- в) "Burn targets": жертвы горят (HP тает после отхода).
- г) "Fling targets": жертв подбрасывает вверх.
- д) "Who to hit" → "Selected player" (или кнопка "Aura: ONLY selected player"; цель задать в Combat → Cuffs & teleport → "Victim (pick a player)" — `[PE] target = <ник>`): бьёт ТОЛЬКО его с любой дистанции.
- Провал: HP целей не падает → сервер валидирует дистанцию → агенту переработать.

## 5. ТАЗЕР (нужен GUARD: "Team: GUARD" → респавн → Taser в рюкзаке)
- а) "TASE selected player (x3)" (или Y): успех = `[PE TASE] <ник> tased x3 (position shots)`, цель падает/замирает.
- б) "Taser aura" (или T): враги в радиусе станятся сами; без тулзы warn "no Taser tool (switch to GUARD)".
- Провал: print есть, цель НЕ станится (и стоит вплотную) → сервер валидирует позицию → переработать/убрать.

## 6. ФЕЙК-ВЫСТРЕЛЫ (Combat → Fake shots; пушка в руках)
- а) "FAKE SHOT at selected player": `[PE FAKE] tracer sent -> <координаты>`.
- б) Клавиша G с курсором на враге: трассер в точку курсора.
- Успех: второй аккаунт ВИДИТ трассер; урона нет.
- Провал: print есть, никто не видит → сервер игнорит VisualizeBullet → удалить фичу.

## 7. ПОБЕГ + ОПАСНЫЕ ЗОНЫ (World → Escape & danger zones)
- а) "Danger/escape zones ESP": красная подсветка Death Part (9 шт), зелёная — EscapePart.
- б) Быть заключённым, "TELEPORT to escape zone": `[PE ESCAPE] teleported to escape zone (N studs)`; статус уходит в escaped.
- Провал: телепорт сработал, побег НЕ засчитан → сервер требует заход пешком → агенту ставить точку ПЕРЕД зоной.

## 8. МАСКИРОВКА (World → "WEAR nearest outfit (disguise)")
- Успех: `[PE OUTFIT] clicked N detectors ...` (N>0); внешний вид сменился (видео/второй аккаунт).
- Провал: вид прежний при N>0 → сервер проверяет дистанцию/команду → убрать кнопку.

## 9. МАГАЗИН (World → "Shop catalog -> console")
- Успех: `[PE SHOP] catalog: <таблица товаров>`.
- Провал: "not found"/"invoke failed" → каталог недоступен → удалить.

После теста: всю консоль (F9) сохранить. Тесты 4–5 делать последними — самые видимые.
