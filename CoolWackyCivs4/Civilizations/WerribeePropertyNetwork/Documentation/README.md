# Werribee Property Network

Lynne Steinhauer leads a playable, AI-enabled civilization for Brave New World and standalone Community Patch v151. The leader's diplomacy, role in government and accomplishments are fictional game content.

## Economy

- **Prime Real Estate** adds 1 flat Gold per owned, worked, unpillaged improvement adjacent to its city. This Gold and the flat Local Market Appraisal bonus appear in city yields.
- **Construction Commission** pays 20% of full effective city Production cost, rounded down, for the first eligible Production completion of each building class in each city. Free start-era buildings, purchases, wonders, projects, captures and hidden buildings are excluded.
- **Property Sales** roll once at each new population high-water mark. A success pays Gold equal to 10 times the new population, multiplied by the owner's era and by the game-speed reward multiplier, rounded down. It refreshes a +10% city Production modifier. The capital and other cities use the same rules.
- **Connected Suburbs** uses the native capital connection, including harbour links. Connected non-capitals receive +5% Gold and Production, replaced by +10% at population 10.
- **Senior Sales Consultant** replaces the Great Merchant and retains its native Customs House and Trade Mission actions. Local Market Appraisal doubles the qualifying flat adjacent-tile bonus and adds +10% city Gold while at least one Consultant occupies the centre. A successful City-State Trade Mission pays 25 extra Gold per current origin-city population and refreshes +15% Gold and Great Person generation there. The current capital substitutes for a missing or lost origin.
- **Real Estate Office** replaces the Market at Currency. It adds +1 Gold to worked, unpillaged Farms, Pastures and Trading Posts, plus 1 flat Gold per three citizens. Each new population high while the building is present pays 5 Gold times the new population and the speed multiplier, rounded down. Property Boom adds +10% building Production while actively growing with a positive Food surplus.

| Speed | Gold reward multiplier | Property Sale turns | Vendor Network turns |
| --- | ---: | ---: | ---: |
| Quick | 0.67 | 3 | 7 |
| Standard | 1.00 | 5 | 10 |
| Epic | 1.50 | 8 | 15 |
| Marathon | 2.00 | 15 | 30 |

Other speeds use `GameSpeeds.GrowthPercent`. The reward factor is clamped to 0.67–2.00. Durations scale from 5 and 10 Standard turns, round to the nearest whole turn, and are clamped to the respective Quick–Marathon ranges. Era factors from Ancient to Information are 1, 1, 1.5, 2, 2.5, 3, 3.5 and 4. The Trade Mission's extra Gold uses population directly on every speed.

## Engine contracts

The DLL source reviewed was the Community Patch 5.4.6 revision used by the pack's existing v151 audit. [Pinned Community Patch source](https://github.com/LoneGazebo/Community-Patch-DLL/tree/dcb33a654cd9e8efb038a0733b4025e19cbcd8ba).

| Contract | Implementation |
| --- | --- |
| `GameEvents.SetPopulation(x,y,oldPop,newPop)` | Synchronous simulation hook. Only cities already registered under their current owner can earn rewards. `PlayerCityFounded` runs after free start-era buildings and `CityCaptureComplete` runs after acquisition population has been set. `Game.Rand` runs only for new thresholds. |
| `CityConstructed(owner,city,building,gold,faith)` | Fires after Production and purchases. Free start-era buildings also fire it before city registration. `GetBuildingProductionNeeded` returns full effective city cost. The presence of a real copy, unlimited building class and positive cost are checked before the persistent commission record is written. |
| `UnitCreated`, `UnitConverted`, `UnitSetXY`, `UnitPrekill` | Register origins, account for the copied creation turn after conversion, and update appraisal on movement or removal. An externally granted unit starts with the nearest owned city at acquisition. |
| `GreatPersonExpended(owner,unitID,type,x,y)` | In standalone v151, the native Trade Mission applies its normal Gold and Influence before firing the hook and then consumes the unit. The cloned Merchant's other expenditure is Customs House construction. The handler requires a trade-enabled non-teammate City-State plot and a live Consultant with no build mission. Customs Houses require the builder's team territory under the inherited improvement rules. A saved paid marker is consumed once for each unit instance. |
| `IsCapitalConnectedToCity`, `FoodDifferenceTimes100`, `IsForcedAvoidGrowth`, `IsFoodProduction`, `IsResistance` | Read native connection and growth status. Relevant-player turn and end-turn callbacks refresh these values. Tile changes, population, capital changes and construction also refresh affected cities. |
| `Building_YieldChanges`, `Building_YieldModifiers`, `GreatPeopleRateModifier`, `BuildingProductionModifier` | Flat yields scale by the change in real-building count. Percentage modifiers use one copy. Property Boom uses the building-only modifier. |
| `Building_ImprovementYieldChanges` | Native improvement yields use the effective working city and exclude pillaged improvements. Housing Demand uses an exact integer dummy count because the native per-population table uses hundredths. |
| `IsDummy`, `ShowInPedia`, `NeverCapture`, `ConquestProb` | Nine private hidden buildings are free to maintain, unavailable for purchase and construction, and discarded on city transfer. |

Relevant code paths are in [CvCity.cpp](https://github.com/LoneGazebo/Community-Patch-DLL/blob/dcb33a654cd9e8efb038a0733b4025e19cbcd8ba/CvGameCoreDLL_Expansion2/CvCity.cpp), [CvPlayer.cpp](https://github.com/LoneGazebo/Community-Patch-DLL/blob/dcb33a654cd9e8efb038a0733b4025e19cbcd8ba/CvGameCoreDLL_Expansion2/CvPlayer.cpp), [CvPlot.cpp](https://github.com/LoneGazebo/Community-Patch-DLL/blob/dcb33a654cd9e8efb038a0733b4025e19cbcd8ba/CvGameCoreDLL_Expansion2/CvPlot.cpp) and [CvUnit.cpp](https://github.com/LoneGazebo/Community-Patch-DLL/blob/dcb33a654cd9e8efb038a0733b4025e19cbcd8ba/CvGameCoreDLL_Expansion2/CvUnit.cpp).

`Modding.OpenSaveData` stores city records keyed by coordinates, founding turn and original owner. Captures preserve commission and threshold history and clear temporary buffs. Consultant records are scoped to player and unit ID, stamped with the unit's creation turn and replaced at creation, including reuse of an ID. Loading reconciles counters and bonuses without replaying rewards. Units in an older save with no origin record use the capital fallback. Players without cities safely skip origin-dependent awards.

## Limits to verify in game

- Community Patch recalculates native city connections at turn start. Effects follow its reported status at reconciliation. A road break, new harbour or manual citizen reassignment can take until turn reconciliation to affect the hidden yield display. The first city processing tick when the native connection changes can still use the previous modifier.
- Standalone v151 has a primary and a secondary victory pursuit field. Lynne uses Diplomacy and Science, with Culture represented by her standard Culture flavour.
- The Trade Mission confirmation covers the inherited Merchant actions under standalone v151. Mods that add different Consultant expenditure actions on City-State territory would require new confirmation logic.
- Native rendering, AI choice behaviour, practical Marathon balance and a full 34-civilization performance run require the [manual gameplay checks](TESTING.md).
