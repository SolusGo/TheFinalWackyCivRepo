# Validation

Civilization V was kept closed. These results come from offline checks.

- The project, XML and English key checks passed. An in-memory SQLite copy of the local BNW and v151 database cache accepted both civilizations' SQL and XML actions. Checks covered leader, trait, city order, class overrides, unit stats, Iron, upgrade path, Armory prerequisites and XP, all promotion modifiers, science buildings and game-speed fields.
- Lua 5.1 compilation passed for both add-ins using the installed game DLL as an offline interpreter. The Arachnid regression suite and the Dominion simulation suite passed. The Dominion suite exercises Marathon and Standard costs and cooldowns, capacity, repeated actions, XP and era gates, both branches, Apex, same-owner upgrade, ID reuse, combat death, gifting, capital relocation, over-capacity after losing chambers, repeated loads, memorial persistence and a 34-player fixture with no steady-state foreign roster scans.
- The project package built and extracted successfully. The validator checked all 112 manifest files, MD5 hashes, VFS flags, database actions and both UI entry points. DDS dimensions were checked and the decoded art was visually reviewed.

## In-game checks still required

1. Start Ancient on Marathon and Standard with standalone CP v151. Verify the select-civilization screen, Dawn of Man, Civilopedia, leader scene, colors, map and war dialogue. Check that the War Council appears only for a human Dominion player and that the existing Arachnid console still works when either faction is used in the same mod setup.
2. Open all four tabs, inspect unit details, scroll both large lists, locate a unit, confirm and cancel each action, and check the keyboard dismissal, missing-unit state, displayed tooltips and small-screen layout.
3. On Marathon, attempt an ineligible unit and an unaffordable or over-capacity designation. Designate a Warrior for 120 Gold, double-click the confirmation, wait six turns, and verify current health, movement and XP. Repeat on Standard for 40 Gold and two turns.
4. Verify 30 XP before and after Classical, each exclusive branch, and automatic Apex after reaching Industrial, 100 XP, or choosing Stage II when current XP is already above 100. Check combat previews and damage for real defensive and offensive modifiers. Heal an Apex in friendly, neutral and enemy territory and verify the friendly-only modifier.
5. Train, purchase and upgrade into an Emperor Scorpion with one Iron. Upgrade an Apex Guardian descended from one and verify its promotions, +35 percentage points of additional ranged defence, original designation turn, science, and absence of a false memorial entry.
6. Lose an Ascendant in combat, disband another, and transfer or gift another. Verify slot release, mutations stripped on transfer, separate Imperial Exoskeleton behavior, science reduction, and one Hall entry per identity. Check both immediate and delayed gift paths.
7. Construct, purchase and sell Molting Chambers, then capture or lose a city with one. Verify the limit changes only for the first or last chamber, existing Ascendants survive over-capacity, and the interface explains it. Transfer, raze or capture a capital to check the Science follows the current capital and the recipient gains no dummy yields.
8. Save and load while a designation cooldown is running, while an Apex is due, and after a unit upgrade or removal. Check the roster, bonuses, memorial and notification counts across successive loads.
9. Run a representative 34-civilization Marathon save to profile turn time, UI responsiveness and callback timing under normal play.
