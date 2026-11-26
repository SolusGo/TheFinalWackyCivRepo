# The Arachnid Empire

The Spider Queen leads the Arachnid Empire in Cool Wacky Civs 4. Its original capital is the Queen's Lair. The pack requires Civilization V with Brave New World and standalone Community Patch v151. It supports single-player Windows games. Select the empire for the human player during setup. The civilization is excluded from normal AI selection.

## Install and build

Copy the built `Cool Wacky Civs 4 (v 1).civ5mod` into the game's `Documents/My Games/Sid Meier's Civilization 5/MODS` directory. Open the in-game Mods menu and let Civ V unpack it, then enable **(1) Community Patch** and **Cool Wacky Civs 4**. A build's unpacked mod folder can also be copied directly into `MODS`.

Open `FinalWackyFolder.civ5sln` in ModBuddy to build with **Default** (package and deploy) or **Package Only**. Configure ModBuddy with the installed Civ V directory and the Civ V user-data directory. The package is written to the repository's `Packages` directory and the unpacked build to `Build`.

From the repository root, use the SDK's registered ModBuddy targets without opening the IDE. The default configuration below produces the installable package. Add `-Configuration Default` for deployment and `-Civ5UserPath <folder>` to point deployment at a staging profile. The script takes a game installation path and invokes 32-bit MSBuild against the existing project.

```powershell
.\CoolWackyCivs4\Tools\Build.ps1 -Civ5Path 'G:\SteamLibrary\steamapps\common\Sid Meier''s Civilization V'
```

## Evolution Through Warfare

Start at 0 Spawn Points (SP), 0 Evolution Points (EP), 0 occupied Control Points (CP), and 3 CP maximum. Points are not strategic resources and cannot be traded. Open **Arachnid Empire** at the right side of the map or from **Additional Information**.

| Source | SP | EP |
| --- | ---: | ---: |
| Original capital each turn | 2 | 0 |
| Each of up to two owned Brood Chambers each turn | 1 | 0 |
| Hostile major or city-state military unit defeated in damage-driven combat | 4 | 1 |
| Each of the first five eligible barbarian military kills in each civilization era | 1 | 0 |

Occupation of the original capital suspends all passive SP and both purchasing actions. Combat still pays. Existing evolutions, units, balances, capacity and Intelligence II Science are retained. Recover the original city to resume the suspended effects.

### Spawning

| Variant | Ancient SP | CP | Unlock | Specialization |
| --- | ---: | ---: | --- | --- |
| Broodling | 45 | 1 | Found the original capital | Melee reinforcement |
| Venom Spider | 65 | 2 | Venom Glands | Damaging a hostile military unit in direct combat inflicts one tick of poison |
| Armoured Spider | 80 | 2 | Chitin Armour | +15% defensive strength, with optional regeneration |

Add 15 SP for each era after Ancient, using the player's current era. Shared cooldown in Quick/Standard/Epic/Marathon is 1/1/2/3 turns. A spawn tries the original capital and then the six adjacent plots in native direction order. A plot must be owned, passable, and on land, with no foreign unit or competing military unit. Capacity is the sum of specialization costs on living units. It is released on death or transfer, retained on upgrade, and stops new spawning if full or over capacity.

| Lineage | Eligible BNW classes in strength order |
| --- | --- |
| Melee | Mechanized Infantry, Infantry, Great War Infantry, Rifleman, Musketman, Longswordsman, Pikeman, Swordsman, Spearman, Warrior |
| Ranged | Bazooka, Machine Gun, Gatling Gun, Crossbowman, Composite Bowman, Archer (Black Widow) |

The selection uses the best eligible entry by the active database's combat or ranged strength, including the civilization's class replacement. It checks primary and additional techs and available strategic resources, including existing usage. An older eligible entry may spawn when a stronger class lacks technology or resources. These explicit lists govern spawn selection. Subsequent paid upgrades use the base game's routes. The ranged chain stays ranged through Bazooka, with the normal one-tile reach beginning at Gatling Gun. The melee list includes spears and pikes as alternatives, with their normal mounted upgrade path and an unchanged specialization after upgrade.

A pending poison effect uses the strongest damage applied before the target owner's next turn. It expires after one nonlethal tick, never affects a city or civilian, and is cleared if its target dies or is replaced by conversion. Neurotoxin increases new applications. Normal upgrades retain specialization and can occur with the Queen's Lair under occupation. Ownership transfers permanently remove the specialization and its combat bonuses.

### Evolution

| Node | EP | Earliest era | Prerequisite | Effect |
| --- | ---: | --- | --- | --- |
| Intelligence I | 3 | Ancient | — | +2 CP, raising the cap to 5 |
| Venom Glands | 4 | Ancient | — | Unlock Venom Spider |
| Chitin Armour | 5 | Ancient | — | Unlock Armoured Spider |
| Intelligence II | 6 | Medieval | Intelligence I | +3 CP, raising the cap to 8, and +1 Science from every owned Brood Chamber |
| Neurotoxin | 6 | Medieval | Venom Glands | Newly inflicted poison rises from 5 to 10 HP |
| Regeneration | 6 | Medieval | Chitin Armour | +5 HP whenever the engine awards normal resting healing |
| Apex Evolution | 10 | Industrial | All three Medieval nodes | +10% general Combat Strength for all spawned units |

**Black Widow** replaces the Archer and retains its normal production, movement, range, combat strength, tech and upgrade path. Ranged Strength increases from 7 to 8. An ordinary Black Widow occupies no CP and has no poison.

**Brood Chamber** replaces the Barracks and retains the normal production cost, prerequisite, maintenance and training experience. Every owned Chamber can receive Intelligence II's Science independently of the two-Chamber passive SP limit.

## Architecture

- `SQL` defines the civilization, options, unique replacements and promotions. `XML` defines the atlases and `Text` supplies localization, dialogue, Civilopedia entries and 25 city names. The project schedules four `UpdateDatabase` actions after Community Patch.
- `UI/ARACHNID_Console.xml` is the sole `InGameUIAddin`. It loads the state module and registers simulation hooks once in the same private Lua context. The package imports only runtime UI, Lua and art into the VFS. The launcher and Additional Information callback coexist with the stock UI. The panel reads simulation state and calls validation functions that check eligibility and the current turn again. No stock UI overrides are bundled.
- `Modding.OpenSaveData()` stores a namespaced schema marker, one record per participating player for balances, progression, passive payout, cooldown, barbarian counters, original capital and notifications, and a bounded pending poison record per affected owner. A missing schema initializes revision 1. An unknown revision disables the add-in and preserves its data. The capital identity uses map coordinates, the founding turn, and the engine's original capital and original owner checks.
- The reservation lives in native, serialized specialization promotions. The swarm is reconciled from the owner's living units whenever the game needs to validate capacity. Upgrade conversions post their events after the promotion copy. The handler ensures the new unit retains the correct traits and clears them from the previous unit before its removal. Other conversions remove the inherited promotions. Poison validates owner, unit ID, creation turn and its native marker before applying damage. Prekill and conversion clear obsolete poison entries, and turn processing touches only the affected owner's indexed entries.
- Science uses a nonbuildable, nonpurchasable, noncapturable, zero-maintenance dummy. The event handlers and the owner's turn reconcile it with real Brood Chambers and Intelligence II. Unit promotion data implements passive combat and healing modifiers through the engine.
- Balance and source data were checked against the installed Community Patch v151 cache. Lua callbacks and APIs were checked against the SDK and the Community Patch v151 source in [CustomMods.h](https://github.com/LoneGazebo/Community-Patch-DLL/blob/master/CvGameCoreDLL_Expansion2/CustomMods.h), [CvUnitCombat.cpp](https://github.com/LoneGazebo/Community-Patch-DLL/blob/master/CvGameCoreDLL_Expansion2/CvUnitCombat.cpp), [CvUnit.cpp](https://github.com/LoneGazebo/Community-Patch-DLL/blob/master/CvGameCoreDLL_Expansion2/CvUnit.cpp) and [CvPlayer.cpp](https://github.com/LoneGazebo/Community-Patch-DLL/blob/master/CvGameCoreDLL_Expansion2/CvPlayer.cpp).

### Hook contracts

| Hook | Use |
| --- | --- |
| `BattleStarted(kind, x, y)`, `BattleJoined(owner, id, role, isCity)` | Capture the actual direct combatants and pre-combat damage |
| `CombatResult(attackerOwner, attackerID, attackerDamage, attackerFinalDamage, attackerMaxHP, defenderOwner, defenderID, defenderDamage, defenderFinalDamage, defenderMaxHP, interceptorOwner, interceptorID, interceptorDamage, x, y, …)` | Establish that the combat passed the mission veto and identify its possible damage sources |
| `UnitPrekill(owner, id, unitType, x, y, delayed, killer)`, `UnitKilledInCombat(killer, victim, type, killingUnitID)` | Pair a damage-driven delayed death with the engine's confirmation; consume that match once |
| `BattleFinished()`, `CombatEnded(…)`, `GameCoreUpdateEnd()` | Process verified direct damage and discard transient combat state |
| `UnitConverted(oldOwner, newOwner, oldID, newID, isUpgrade)` | Preserve upgrade specialization, or strip inherited traits and invalidate pending poison |
| `PlayerDoTurn(player)`, `TeamSetEra(team, era, first)` | Process owner-turn effects, and announce evolution availability |
| `PlayerCityFounded(owner, x, y)`, `CityCaptureComplete(oldOwner, wasCapital, x, y, newOwner, …)`, `CityConstructed(owner, cityID, building, …)`, `CitySoldBuilding(owner, cityID, building)` | Reconcile the original capital and Science |

## Artwork and known limits

The project includes original portrait, map, Dawn of Man, variant, resource and evolution art. Black Widow uses the Archer's stock 3D model and sound, and the spawned variants use their contemporary base unit models. Unit names, specialization promotions, the Black Widow's flag and the dedicated console distinguish the variants. The Queen has a static diplomacy scene. No GR2 assets or new DLL are required.

Combat eligibility is limited to hostile military deaths supported by the paired engine events. This supports damage-driven melee, ranged, naval and air combat through the shared resolver. Overruns, captures, and special paths such as nuclear events without the paired damage attribution do not pay. Venom uses the two principal unit combatants in direct melee and ranged combat, so collateral city garrison damage does not add a poison status. Native healing and late-game ranges are inherited from the engine.

The code avoids map-wide scans and only reconciles the Arachnid owner's cities and units. The requested 34-civilization, long Marathon compatibility still needs a real-game stress run. Other packs' database and UI integrations were reviewed for namespacing, with combined in-game testing pending.

See [Testing](TESTING.md) and [Artwork](ARTWORK.md).
