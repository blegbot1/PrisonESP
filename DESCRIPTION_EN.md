# PrisonESP — English Description

A client-side script for a Roblox prison roleplay game (teams: Guard,
Prisoner, Escaped). Runs through a Lua executor via HttpGet loadstring.
UI: Rayfield (English / Russian), settings persist between sessions.

## ESP tab
- **Player visuals**: 3D boxes (frame / corners / full box) that follow
  each player's model, skeletons (R6/R15), HP bars with gradient and
  damage flash, head frames, snaplines, off-screen arrows, movement
  vector, ground ring, minimap. Roles detected from team / attributes /
  tools: guards blue, prisoners orange, escaped (criminals) red,
  others gray, **admins magenta with [ADMIN] tag + on-screen alert**
  (admin UserIds are hardcoded in the game's own panel script).
- **Chams**: Highlight fill per character, role-colored, visible
  through walls.
- **Server intel**: Death Part kill-zones (red), EscapePart zones
  (green), **invisible perimeter walls** highlighted light blue
  (the prison fence is 132 fully transparent collidable parts).
- **AUTO-ESCAPE toggle**: teleports you onto the nearest escape zone,
  waits for it to register, returns you home.
- Ground item highlights (weapons, keycards, ammo), lite mode,
  distance limit, hide-dead.

## Combat tab
- **Kill aura** — the game's gun kit (qPerfection) computes damage on
  the client; the script sends the exact `InflictTarget(Humanoid, Part,
  damage, direction, knockback, lifesteal, flaming)` call the gun
  itself uses: damage up to 5000, head-aiming, **vampirism** (each hit
  heals the shooter), **fling** (up / away / random pinball), **burn**
  (server-side fire, visible to everyone), **infinite range** (the
  server does not validate distance), up to 20 targets per tick,
  target = everyone or a picked player.
- **Retribution** — when you take damage the script identifies the
  attacker (nearest player, armed players prioritized) and burns them.
- **Immortality** — reactive self-heal loop: HP snaps back the frame
  it drops.
- **C00LKIDD MODE** — slow-burns the whole server (tiny damage ticks +
  server fire), optional fling variant, and a fire-paint experiment
  that draws fire at your cursor.
- **APOCALYPSE** — a fully automatic killer machine: teleports you 400
  studs up and anchors you out of reach, auto-fetches an M9 pistol,
  flips your team every second (so every player becomes a valid target
  in turn — the server's team check is bypassed by schedule), and
  deals 100 damage + fire to everyone every 0.5 s. Toggle off and you
  are unanchored and lowered back.
- **Gun upgrade** — mutates the gun's Setting module (shared require
  cache): damage, headshot multiplier x200, shotgun pellets, burst,
  explosive bullets, burning bullets, knockback, body piercing, full
  auto, no spread, instant reload; re-applies automatically on equip /
  respawn; ammo hack carries a 1e9 clip through a legitimate reload;
  sniper scope on any gun (E key).
- **Team switch** (dropdown, instant), fast respawn (instant rejoin
  into your last team), auto-give M9 after death.

## Movement section
- Speed hack (WalkSpeed slider), **noclip** (re-applied every physics
  step, collisions restored on toggle-off), **fly** (camera-relative
  WASD + Space/Ctrl), infinite jump, jump boost, **TP to crosshair**,
  **waypoints** (saved between sessions), anti-stun (ragdoll / taser /
  cuffs never hold you), anti-AFK, FPS boost (low graphics mode).

## Settings tab
- Menu language English / Russian, restart-to-apply, full unload with
  cleanup (restores collisions, speed, textures of FPS mode), version
  and console API info.

## Technical notes
- Rayfield UI is vendored and patched to render in PlayerGui (some
  executors' protected containers draw but drop input).
- Every menu element is wrapped in a pcall proxy; the script kills its
  previous instance on re-execution (full connection / highlight /
  state cleanup).
- Combat features clamp their values at the call site and throttle
  per-player effects (burn / fling / stun) to stay below "impossible"
  rates. Apocalypse and kill aura are mutually exclusive (network
  packet ceiling).
- Console tools: `PE.Guns()`, `PE.Remotes()`, `PE.GunSource()`,
  `PE.Diag()`, `PE.TeamOf(name)`, `PE.Probe(...)`, `PE.Hit(name)`,
  `PE.Team(name)`, `PE.FakeShot()`, `PE.EscapeTrip()`,
  `PE.WearOutfit()`, `PE.ShopInfo()`.
