# Testing

Run from the repository root with Python 3.9 or later. Use a BNW plus standalone Community Patch v151 cache that has not loaded Cool Wacky Civs 4. The validator replays SQL and XML in a disposable database, parses localization and manifests, and checks packaged bytes, VFS, dependencies, and DDS dimensions.

```powershell
python -B .\CoolWackyCivs4\Tools\BuildStandalone.py .\Build\Werribee
python -B .\CoolWackyCivs4\Tools\Validate.py --database '<Civ5DebugDatabase.db>' --build '.\Build\Werribee\Cool Wacky Civs 4 (v 1)'
.\CoolWackyCivs4\Tools\TestLua.ps1 -Civ5Path '<Civilization V installation directory>'
```

The Lua harness uses simulated callbacks, tests exact amounts and effect counts, and reloads the script against the same save records. The installed v151 database replay and the standalone manifest audit passed. The game executable was not run for these checks.

## In-game checklist

Use a fresh BNW game with standalone Community Patch v151 and the unpacked mod. Enable logging and watch `Database.log`, `xml.log` and `Lua.log`. Start a Marathon game as Lynne with a nearby City-State, a coastal site, and Farms, Pastures and Trading Posts within reach. Use a separate turn save for each independent scenario. FireTuner can inspect each city's real dummy-building counts and the treasury before and after the action.

| Scenario | Procedure and expected result |
| --- | --- |
| Setup | Select Lynne, confirm the leader art, crest, map, Dawn of Man, matching player colours and both uniques. Found the first city, verify its name is Werribee and its treasury and notifications show no founding reward. A later-era founding also gives no construction commission on its free buildings. |
| Adjacent tiles | Improve and work an adjacent owned tile for +1 city Gold. Unwork it, pillage it, repair it, and try a road on an unimproved tile. Assign an overlapping improved tile to one of two nearby cities and confirm only its working city receives the bonus. |
| Construction | Read the full effective cost and complete an ordinary building. Confirm a one-time commission of floor(cost / 5). Try Gold/Faith purchase, free grants, national/world wonders, a project and a dummy-building refresh. Sell and reconstruct the building, then construct the same class in another city. Only the first ordinary construction in each eligible city pays. |
| Population | Grow through a fresh threshold and check the synchronized roll and Gold delta after the event. Test a multi-citizen gain, then reload, starve and regrow to the old high. Confirm each new threshold is processed once and the old thresholds remain spent. |
| Suburbs | Connect a non-capital by road, then test a harbour link. Bring it to population 10 and back to nine. Break the link and confirm the connection bonus is gone after reconciliation. Confirm the current capital never has either connection effect. |
| Merchant pathways | Generate Merchants from specialists, a free Great Person choice and a Faith purchase where enabled. Confirm the Consultant appears and can build a Customs House. Station one or two Consultants in a city centre, then move, gift or remove them. Confirm a single appraisal and removal after the last Consultant leaves. |
| Successful mission | Generate a Consultant in a population-12 city and conduct a City-State Trade Mission. Confirm normal Gold and Influence plus 300 Gold, +15% Gold and Great Person generation in the origin city. Test a Consultant granted outside a city and a Consultant whose origin was transferred away. Confirm the acquisition-time nearest city and capital fallback respectively. |
| Failed mission | Preview and attempt a blocked mission. Test deletion, death and Customs House construction. None should grant mission Gold or Vendor Network. On successful repeated missions, verify one payment per Consultant and a refreshed, single Vendor Network modifier. |
| Expiration | Start a Marathon Property Sale and Vendor Network, then save and reload mid-effect. Confirm their expiration at the 15- and 30-turn boundaries. Also verify that repeated sales refresh the single Production modifier. Try Quick, Standard and Epic against the duration table. |
| Real Estate Office | Check population 5, 9, 14 and 30 for 1, 3, 4 and 10 flat Gold. Work appropriate improvements outside the first ring, then pillage or unwork them. Grow with and without the Office. The settlement commission must apply only to new thresholds while the Office exists. Check that Property Boom adds +10% building Production only, and stops for Avoid Growth, resistance, non-positive Food or Food-to-Production conversion. |
| Lifecycle | Capture, liberate, recapture and raze a Werribee city. Check for clean yields under foreign ownership, no expired boosts on recapture, changed city IDs, no repeated Gold, and sensible behaviour after losing the capital. |
| AI and scale | Run a map with at least 34 major slots and an AI Werribee. Verify its treasury, Office, connection bonuses and Trade Missions, compare turn times with a matching baseline, and inspect the other pack civilizations for unchanged uniques and behaviour. |
