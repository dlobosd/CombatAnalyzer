# Combat Analyzer

A World of Warcraft combat performance analyzer written in Lua, sharing a
single codebase between **Retail** and **Classic**.

## Architecture

```
Core.lua                     <- shared: client detection, data model, combat lifecycle
   |
   +-- CombatLog.lua          <- shared: normalization + dispatch (no Retail/Classic branching)
          |
          +-- CombatLog_Retail.lua    <- acquisition layer, loads ONLY on Retail
          +-- CombatLog_Classic.lua   <- acquisition layer, loads ONLY on Classic

Damage.lua / Buffs.lua / Interrupts.lua / Deaths.lua / Timeline.lua / UI.lua
   -> read only the normalized `combat` table built by CombatLog.lua.
   -> never check the client version.
```

Only one of `CombatLog_Retail.lua` / `CombatLog_Classic.lua` is ever loaded
by the game client — selection happens at the `.toc` level (see below), so
the "wrong" file for a given client is never even parsed, and no
Retail-only/Classic-only event or API is ever registered/called on the
client that doesn't have it.

## Client detection

`Core.lua` uses the official Blizzard globals `WOW_PROJECT_ID` /
`WOW_PROJECT_MAINLINE` (set by the client itself before any addon code
runs) to set `CA.IsRetail` / `CA.IsClassic`. Every Classic expansion
(Vanilla/Classic Era, TBC, Wrath, Cataclysm, Mists Classic, and future
Classic progression clients) is treated uniformly as "Classic," because the
combat log surface this addon depends on is identical across all of them.

## The `.toc` file

A single `.toc` is used, made possible by two features Blizzard added
specifically for cross-flavor addons:

- **Comma-delimited `Interface` versions**, so one file declares
  compatibility with every client flavor at once instead of triggering an
  "out of date" flag on all but one:
  ```
  ## Interface: 120100, 50504, 40402, 30405, 20506, 11509
  ```
- **Per-file conditional loading** (`[AllowLoadGameType ...]`), used to pick
  the acquisition file:
  ```
  CombatLog_Retail.lua [AllowLoadGameType mainline]
  CombatLog_Classic.lua [AllowLoadGameType classic]
  ```

Blizzard's own documentation recommends this over shipping multiple
client-specific `.toc` files where possible, so that's what's used here.
Update the `Interface` numbers as new patches ship — a stale number is only
a cosmetic "out of date" warning, it doesn't block loading (as long as the
user has "Load out of date AddOns" enabled, which is common practice for
this kind of situation while a new patch is very fresh).

## Verified API differences (Retail vs Classic)

| Area | Retail | Classic | Impact on V0.1 |
|---|---|---|---|
| `COMBAT_LOG_EVENT_UNFILTERED` + `CombatLogGetCurrentEventInfo()` | present | present, same base argument layout | None — genuinely shared, used identically in both acquisition files |
| `SPELL_DAMAGE`, `SWING_DAMAGE`, `SPELL_HEAL`, `SPELL_CAST_SUCCESS`, `SPELL_INTERRUPT`, `UNIT_DIED` subevents | present | present | None — Classic uses the same unified combat log taxonomy as Retail |
| `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`, `UnitGUID`, `UnitAffectingCombat`, `C_Timer.After` | present | present | None |
| Spell name/icon lookup | `C_Spell.GetSpellInfo(spellID)` returns a table | `GetSpellInfo(spellID)` returns multiple values (legacy signature) | Isolated behind `CL.GetSpellName` / `CL.GetSpellIcon`, implemented separately per client in the acquisition layer |
| Aura inspection (buffs/debuffs) | `C_UnitAuras` / `AuraUtil.ForEachAura` | `UnitAura(unit, index, filter)` | Not implemented yet (out of scope for V0.1); `Buffs.lua` documents where this split belongs when it's built |

No incompatible API is forced on either client to fake compatibility: where
the two clients genuinely agree (which is most of the combat-log surface
this version needs), the code says so; where they don't, the divergence
lives in the acquisition layer.

## Features in V0.1

- Client detection (Retail vs Classic) with confirmation via `/ca version`
- Combat start/end detection
- Combat log parsing, normalized to a shared data structure
- Damage and DPS
- Healing and HPS
- Damage by ability
- Cast count
- Interrupt count
- Death count
- Combat timeline
- Session history (up to 20 combats)
- `/ca`, `/ca reset`, `/ca debug`, `/ca version`

Advanced analysis (aura uptime, cooldown efficiency, etc.) is intentionally
**not** implemented yet — this milestone is about a solid, genuinely
compatible foundation for both clients first.

## Install

Copy the `CombatAnalyzer` folder as-is into:

```
World of Warcraft/_retail_/Interface/AddOns/CombatAnalyzer/
```

and/or

```
World of Warcraft/_classic_/Interface/AddOns/CombatAnalyzer/
```

The same folder works for both — no separate build or file removal needed.
The addon detects the client at load time and activates the matching
acquisition layer automatically.

## Important

This is an early prototype. WoW's API can change between patches on both
Retail and Classic; the `Interface` numbers in the `.toc` and the acquired
combat log fields should be re-verified against current patch notes
periodically.
