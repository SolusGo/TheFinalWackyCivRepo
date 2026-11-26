# Testing

## Offline validation

From the repository root, run the following commands with the SDK and a BNW + Community Patch v151 debug cache available. Use the appropriate paths for the installation. The Lua runner loads the game's Lua 5.1 library into a separate 32-bit PowerShell process. It does not start the game. The database validator opens the baseline read-only and applies updates to an in-memory copy.

```powershell
.\CoolWackyCivs4\Tools\TestLua.ps1 -Civ5Path '<Civ V installation folder>'
python .\CoolWackyCivs4\Tools\Validate.py --database '<Civ5DebugDatabase.db>' --build '.\Build\Cool Wacky Civs 4'
```

| Check | Coverage |
| --- | --- |
| Lua 5.1 compile and simulated hooks | All runtime Lua files compile. The rule harness exercises starting resources, payout and reload guards, military kill validation, barbarian caps, all purchases, all era prices, spawn restrictions, storage, upgrades, gifts, Queen's Lair capture and recovery, Science updates and pending poison. |
| BNW + Community Patch v151 database | Apply all four actions to an in-memory database and compare the Archer and Barracks replacements to the active originals. Verify the ranged upgrade chain, promotion modifiers, prerequisites, human-only flag, city names and patch options. |
| Assets and registration | Parse project, UI and game XML, cross-check text keys, VFS entries and asset references, and check every DDS atlas dimension. The leader, Dawn, map and icon artwork were visually reviewed outside the game. |
| SDK packaging | The ModBuddy MSBuild targets ran in both Package Only and Default. Default deployed to a workspace test profile. The validator matched all built file hashes to source and verified the generated manifest. |

## In-game checklist

Gameplay, native visuals, and 34-civilization performance require an in-game run. Use a fresh save of BNW with standalone Community Patch v151 and Cool Wacky Civs 4, and enable logging. Inspect `Database.log`, `xml.log`, and `Lua.log` after each scenario.

1. Select the Spider Queen in a single-player Marathon game. Check the crest, color, city list, opening narrative, Civilopedia, and unit and building tooltips. Verify the launcher, its Additional Information entry, all three tabs, tooltip legibility and unit location. Check with a non-Arachnid human and the Arachnids excluded from AI random selection.
2. Found the Queen's Lair and build three Brood Chambers. Verify +2/3/4/4 passive SP across the sequence. Save and reload during a turn. Verify the payout only occurs once. Verify all Chambers receive exactly +1 Science after Intelligence II and lose it immediately when the building is sold or city is captured.
3. Gain XP and kill enemy military units with ordinary and spawned units in melee and at range. Repeat with a city-state, barbarian, naval unit, and aircraft. Verify five barbarian rewards per player era and no payouts for civilians, capture, disbanding, gifts, upgrades or trades. Compare normal and quick combat.
4. Buy each evolution at its first eligible era. Try a missing prerequisite, a repeat purchase, insufficient EP and a purchase during occupation. Check that existing units and units spawned later gain the applicable promotions.
5. Spawn all variants, at the capital and at adjacent tiles. Block the usable tiles and try again. Check cooldown across variants, Quick/Standard/Epic/Marathon timing, CP over-capacity handling, and costs in different eras. Exhaust Iron and check that the spawn selects an eligible fallback without changing strategic resources. Train an ordinary Black Widow and verify no occupied CP or poison.
6. Attack a living military target twice with Venom Spiders. Verify it receives a single 5 HP tick at the start of its turn, then upgrade Neurotoxin and repeat for 10 HP. Reapply at 1 HP, on a civilian, and against a city. Save before the tick and reload. Upgrade, gift, capture, disband and kill different poisoned targets before their turn.
7. Test native healing for Armoured Spiders at home, neutral territory and hostile territory. Compare the normal heal before and after Regeneration, including movement, attacks, damage while defending, and near-full HP. Upgrade the unit normally, verify specialization and CP transfer exactly once, then test a gift, death, and reacquisition.
8. Lose the Queen's Lair, retain at least one city, and verify that Palace relocation restores none of the suspended mechanics. Check that existing units and yields remain, and that kill rewards still accrue. Save and reload, then recapture the original city. Test capital elimination cleanup separately.
9. Repeat with the other Cool Wacky Civs packs enabled. Run a long 34-civilization Marathon game and review logs, turn times, and save/reload behavior.
