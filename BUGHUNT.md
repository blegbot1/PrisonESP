# Разбор багов игры (по клиентскому дампу от 2026-10-24)

Дамп: 1306 строк, 471 скрипт. Выводы — по структуре (клиент не видит
исходники, но видит ЧТО и ГДЕ лежит). Гарантия — только после зонда
или студийного дампа (см. внизу).

## Как устроена игра

- Пушки — старый бесплатный кит (подпись `qPerfectionWeld`): урон
  идёт через `RemoteEvent InflictTarget` ВНУТРИ каждого Tool,
  серверная часть (`GunScript_Server`) тоже внутри Tool.
- Серверная логика вообще раскидана по тулзам и моделям:
  `Cuff server`, `Taser.Main`, `Item Give script`, `Doorscript`,
  `Health` в персонаже. `ServerScriptService` из клиента пустой —
  там прячется только центральный код.
- Анти-тимкилл («3 убийства невинных → в зеки») — **LocalScript**,
  т.е. наказание считает КЛИЕНТ.
- Пустой `Teams` в дампе → команды, похоже, создаются рантайм;
  роль для ESP определяем по тулзам в рюкзаке (Handcuffs/Taser =
  охрана и т.п.).

## P0 — почти наверняка работает (ядро v0.2)

1. **Гивер оружия.** Модели на земле (`AK-74`, `M9`, `SVD`,
   `PPSH-41`, `MP5 Short`, `M16a4 MOD`, `MG42`, `Kord`, `Hammer`,
   `KeyCard`) с `Item Give script` — почти наверняка ClickDetector.
   `fireclickdetector()` игнорирует дистанцию: любое оружие любой
   команде из любой точки. KeyCard = свободный выход через ворота.
2. **Килл-аура / урон по всем.** В этом ките клиент сам делает
   рейкаст и стреляет `InflictTarget`-ом на сервер; серверы таких
   китов обычно не проверяют ни расстояние, ни владельца пушки, ни
   команду. Зонд: `PE.Probe("InflictTarget", workspace["НИК"].Humanoid)`.
3. **Вечный магазин.** `ChangeAmmoAndClip` клиентский:
   `PE.Probe("ChangeAmmoAndClip", 30, 30)`; даже если не примет —
   патроны обычно считает клиент, можно просто не декрементить.
4. **Скорострельность/разброс/отдача — всё в `GunScript_Local`**,
   т.е. на клиенте: авто-режим любой пушки, без разброса, без
   отдачи, мгновенная перезарядка.

## P1 — проверить одним зондом

5. **Двери.** `Workspace.Doors` — 20+ дверей с `Doorscript`
   (клик/тач). Открыть ВСЕ камеры удалённо (`Prison Jail Door`,
   `Prison Large Door`) через клик-детекторы = массовый побег.
6. **Наручники.** `Handcuffs.CuffEvent:FireServer(цель)` — сковать
   кого угодно откуда угодно, если нет проверки команды/дистанции.
7. **Тазер.** `Taser.RemoteEvent:FireServer(цель)` — тазер по всем
   (в жертву клонируется `GetTasedBro` + RagdollModule).
8. **Вечный спринт.** `SprintRemote:FireServer(true)` один раз и
   никогда `false`; стамина (если есть) — клиентская.

## P2

9. **Смена команды.** `ChooseTeamEvent:FireServer("Guard")` —
   мгновенный переход за охрану, включая обход наказания за ТК.
10. **Выход из наручников.** `ResetToMenuEvent:FireServer()` —
    сброс в меню: снять арест без смерти.
11. **Тимкилл без наказания** — анти-ТК клиентский, просто не
    считает (или сервер дублирует — проверить).
12. **Маскировка.** Outfit-модели «Click for cloths / accessories» —
    надеть форму охраны, будучи зеком (обман чужого ESP и игроков).
13. **Снять розыск.** `CriminalStatusRemote` — если сервер слушает
    клиент, можно сбросить криминальный статус.

## P3 — троллинг / видно всем (аккуратно)

14. **Админ-панель.** `AdminCommandBarEvent` + LocalScript «to enter
    TRIAL MOD/Admin PANEL» — если сервер не проверяет отправителя,
    это произвольные админ-команды. Пробовать только пустой строкой.
15. **Фейк-объявления.** `GlobalAnnouncement`, `PowerMessageEvent`,
    `PrivateWarning`, `PrisonAnnouncementEvent` — фейковые
    объявления/варны, если нет проверки отправителя.
16. **Спектейт.** `SpectateEvent` — смотреть любым игроком.
17. **Инфо-лик.** `GetBannedPlayers` (RemoteFunction) — InvokeServer()
    отдаёт список банов.

## Что из клиента НЕ видно и что делать

`ServerScriptService` и `ServerStorage` в дампе пустые — там
центральный серверный код с проверками. Раз игра скопирована «по
фулу», запусти в Studio (режим Edit, не Play):

1. Открой **Command Bar** (View → Command Bar).
2. Вставь целиком содержимое `PRISON_DUMP_STUDIO.lua` и нажми Enter.
3. Сохрани файл `prison_dump_full.txt` (появится диалог) и скинь его мне.

По нему я прочитаю серверные проверки каждого ремоута и скажу
точно, что из P0–P2 валидно, а что сервер режет — и сразу соберу
v0.2 (гивер, килл-аура, патроны, двери, анти-наручники/тазер).

## Зонды в живой игре (если Studio-дамп лень)

```lua
getgenv().PE.Probe("InflictTarget", workspace["НИК"].Humanoid)
getgenv().PE.Probe("ChangeAmmoAndClip", 30, 30)
getgenv().PE.Probe("CuffEvent", game.Players["НИК"])
getgenv().PE.Probe("ChooseTeamEvent", "Guard")
getgenv().PE.Probe("SprintRemote", true)
getgenv().PE.Remotes()
```

Результат (консоль) → мне, дальше строим боевые функции.

---

# Обновление 2026-10-25: полный разбор через Studio MCP

Через официальный Studio MCP (`StudioMCP.exe`, stdio JSON-RPC) подключились
к Studio с открытым save.rbxlx (18.8 МБ, 13765 инстансов, 177 скриптов)
и прочитали всё, что читается. Главный факт: **серверные скрипты в копии
вычищены (Source = 0 байт)** — Item Give script, Doorscript, Health,
Taser.Main, GunScript_Server, Cuff server. Клиентские — целые.

## Подтверждено исходниками (включено в v2.13–v2.17)

- **Весь урон считается в GunScript_Local (клиент)**: InflictTarget:FireServer(
  Humanoid, Part, `Headshot and BaseDamage*HeadshotDamageMultiplier or BaseDamage`,
  lookVector, Knockback, Lifesteal, FlamingBullet) — ВСЕ аргументы из
  Setting-модуля, который мутается через require-кеш. Хедшот = попадание
  в парт с именем «Head».
- **Полный Setting-модуль** (M16a4 MOD): BaseDamage 6, HeadshotMultiplier 3,
  ShotgunEnabled/BulletPerShot 8, BurstFire/BulletPerBurst 3/BurstRate,
  ExplosiveEnabled/Radius (Explosion.Hit → InflictTarget ПО ВСЕМ в радиусе!),
  Piercing, Knockback 3, Lifesteal 0, FlamingBullet, LimitedClipEnabled,
  DelayBefore/AfterFiring, Spread, FireRate, ReloadTime.
- **Тимфейндли-чек в ките мёртв**: `v1.Parent.TEAM.Value == TEAM.Value`,
  но глобальный TEAM у игрока nil → проверка всегда пропускает.
- **Тазер**: Taser.RemoteEvent:FireServer(ПОЗИЦИЯ) — один аргумент-вектор;
  кулдаун 5 секунд только в LocalScript тулзы (флаг u20) → спам напрямую.
- **Регдолл** (RagdollModule): Motor6D заменяются на BallSocketConstraint
  (+ подмена RagdollAssets, CanCollide=false). Анти-стан правильный:
  disable BallSocketConstraint + запрет состояний.

## Мир (Workspace, 13765 инстансов)

- **EscapePart** × 4+ — зоны побега заключённых (→ телепорт-кнопка).
- **Death Part** × 9 (позиции сняты) — убивают на касание (Front Gate,
  стены) → красная подсветка.
- ServerStorage ПОЛНОСТЬЮ пуст. Машин нет (97 столовых стульев).
- Villain-эффекты в ReplicatedStorage (Laser Eyes, Jet Flame, Speed Run,
  Eye beam, Flame Parts, Speed Kick) — косметика SuperVillain-геймпасса,
  клонируется на себя только клиентски (другие не видят) — отсеяно.

## Отсеяное (проверено, не работает / бессмысленно)

- **Админ-панель**: открывается клавишей `;` (Semicolon), команды текстом
  в AdminCommandBarEvent («/unspectate», баны и т.д.), но сервер проверяет
  права отправителя — молчание на все пробы.
- **Магазин**: только MarketplaceService.PromptProductPurchase/
  PromptGamePassPurchase — реальные деньги, халявы нет. GetShopInfo —
  RemoteFunction, только читает каталог.
- **Спринт**: SprintRemote:FireServer("StartRun"/"StopRun") — протокол
  подтверждён, сервер режет скорость (вживую не работает).
- **Объявления/спектейт/варны** (GlobalAnnouncement, PowerMessageEvent,
  PrivateWarning, SpectateEvent, PrisonAnnouncementEvent): клиентские
  слушатели OnClientEvent; FireServer с клиента — сервер игнорирует.
- **GetBannedPlayers** (RemoteFunction): InvokeServer отдаёт список банов —
  только информация.
- **CuffUiClient**: при «HideHotbar» прячет рюкзак и разэкипирует тулзы —
  чистый UI, на сервер не влияет.
- **Анти-ТК «3 innocent kills»**: оказался просто слушателем уведомлений
  (GameMessageRemote → SendNotification). Счётчик где-то на сервере.

## Дебри GunScript_Local (на память)

- При перезарядке клиент сам шлёт ChangeAmmoAndClip:FireServer(clip, total)
  и при каждом выстреле тоже — это бухгалтерия магазина, «бесконечные
  патроны» через прямой FireServer сервер не принял (проверено вживую).
- VisualizeBullet:FireServer(...) — визуал трассеров для остальных; в ките
  есть баг: передаётся Setting.BlastRadius, которого нет в модуле (nil).
- Mouse Sensitivity / SniperEnabled — снайперский зум M16 (FOV 18).
