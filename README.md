# FinalWackyFolder

Each mod has its own folder and ModBuddy project file. Cool Wacky Civs 4 runs on Brave New World with standalone Community Patch v151. [The Arachnid Empire](CoolWackyCivs4/Civilizations/ArachnidEmpire/Documentation/README.md), [The Scorpion Dominion](CoolWackyCivs4/Civilizations/ScorpionDominion/Documentation/README.md), [Werribee Property Network](CoolWackyCivs4/Civilizations/WerribeePropertyNetwork/Documentation/README.md).

## Install the package

Copy the built `Cool Wacky Civs 4 (v 1).civ5mod` into Civilization V's `MODS` folder and enable it alongside standalone Community Patch v151.

## Build an unpacked mod

Run the following from the repository root with Python 3.9 or later.

```powershell
python -B .\CoolWackyCivs4\Tools\BuildStandalone.py .\Build\Standalone
```

Copy the resulting `Build/Standalone/Cool Wacky Civs 4 (v 1)` folder into Civilization V's `MODS` folder. Enable Cool Wacky Civs 4 and Community Patch v151 in the Mods menu.

## Build with ModBuddy

Open [FinalWackyFolder.civ5sln](FinalWackyFolder.civ5sln) in ModBuddy from the Civilization V SDK. Set the game and user paths in ModBuddy, then choose **Build → Build Solution**. Choose **Default** to package and deploy, or **Package Only** to build a package without installing it. The package goes to `Packages/Cool Wacky Civs 4 (v 1).civ5mod`.

For future mods, create a folder at the repository root with its own `.civ5proj`, then add that project to the solution.
