-- Inherit all main-table BNW and standalone CP attributes, including the native model.
CREATE TEMP TABLE SDOM_Swordsman AS SELECT * FROM Units WHERE Type = 'UNIT_SWORDSMAN';
UPDATE SDOM_Swordsman SET
    ID = NULL, Type = 'UNIT_SDOM_EMPEROR_SCORPION', Combat = 15, Moves = 2, Cost = 75,
    Description = 'TXT_KEY_SDOM_EMPEROR', Civilopedia = 'TXT_KEY_SDOM_EMPEROR_PEDIA',
    Strategy = 'TXT_KEY_SDOM_EMPEROR_STRATEGY', Help = 'TXT_KEY_SDOM_EMPEROR_HELP',
    IconAtlas = 'SDOM_CIV_ATLAS', PortraitIndex = 2,
    UnitFlagAtlas = 'SDOM_FLAG_ATLAS', UnitFlagIconOffset = 0;
INSERT INTO Units SELECT * FROM SDOM_Swordsman;
DROP TABLE SDOM_Swordsman;

INSERT INTO Civilization_UnitClassOverrides (CivilizationType, UnitClassType, UnitType) VALUES
    ('CIVILIZATION_SCORPION_DOMINION', 'UNITCLASS_SWORDSMAN', 'UNIT_SDOM_EMPEROR_SCORPION');
INSERT INTO Unit_ClassUpgrades (UnitType, UnitClassType)
    SELECT 'UNIT_SDOM_EMPEROR_SCORPION', UnitClassType FROM Unit_ClassUpgrades WHERE UnitType = 'UNIT_SWORDSMAN';
INSERT INTO Unit_ResourceQuantityRequirements (UnitType, ResourceType, Cost)
    SELECT 'UNIT_SDOM_EMPEROR_SCORPION', ResourceType, Cost FROM Unit_ResourceQuantityRequirements WHERE UnitType = 'UNIT_SWORDSMAN';
INSERT INTO Unit_FreePromotions (UnitType, PromotionType)
    SELECT 'UNIT_SDOM_EMPEROR_SCORPION', PromotionType FROM Unit_FreePromotions WHERE UnitType = 'UNIT_SWORDSMAN';
INSERT INTO Unit_AITypes (UnitType, UnitAIType)
    SELECT 'UNIT_SDOM_EMPEROR_SCORPION', UnitAIType FROM Unit_AITypes WHERE UnitType = 'UNIT_SWORDSMAN';
INSERT INTO Unit_Flavors (UnitType, FlavorType, Flavor)
    SELECT 'UNIT_SDOM_EMPEROR_SCORPION', FlavorType, Flavor FROM Unit_Flavors WHERE UnitType = 'UNIT_SWORDSMAN';
INSERT INTO UnitGameplay2DScripts (UnitType, SelectionSound, FirstSelectionSound)
    SELECT 'UNIT_SDOM_EMPEROR_SCORPION', SelectionSound, FirstSelectionSound
    FROM UnitGameplay2DScripts WHERE UnitType = 'UNIT_SWORDSMAN';

CREATE TEMP TABLE SDOM_Armory AS SELECT * FROM Buildings WHERE Type = 'BUILDING_ARMORY';
UPDATE SDOM_Armory SET
    ID = NULL, Type = 'BUILDING_SDOM_MOLTING_CHAMBER',
    Description = 'TXT_KEY_SDOM_CHAMBER', Civilopedia = 'TXT_KEY_SDOM_CHAMBER_PEDIA',
    Strategy = 'TXT_KEY_SDOM_CHAMBER_STRATEGY', Help = 'TXT_KEY_SDOM_CHAMBER_HELP',
    IconAtlas = 'SDOM_CIV_ATLAS', PortraitIndex = 3;
INSERT INTO Buildings SELECT * FROM SDOM_Armory;
DROP TABLE SDOM_Armory;

INSERT INTO Civilization_BuildingClassOverrides (CivilizationType, BuildingClassType, BuildingType) VALUES
    ('CIVILIZATION_SCORPION_DOMINION', 'BUILDINGCLASS_ARMORY', 'BUILDING_SDOM_MOLTING_CHAMBER');
INSERT INTO Building_ClassesNeededInCity (BuildingType, BuildingClassType)
    SELECT 'BUILDING_SDOM_MOLTING_CHAMBER', BuildingClassType FROM Building_ClassesNeededInCity WHERE BuildingType = 'BUILDING_ARMORY';
INSERT INTO Building_DomainFreeExperiences (BuildingType, DomainType, Experience)
    SELECT 'BUILDING_SDOM_MOLTING_CHAMBER', DomainType, Experience FROM Building_DomainFreeExperiences WHERE BuildingType = 'BUILDING_ARMORY';
INSERT INTO Building_Flavors (BuildingType, FlavorType, Flavor)
    SELECT 'BUILDING_SDOM_MOLTING_CHAMBER', FlavorType, Flavor FROM Building_Flavors WHERE BuildingType = 'BUILDING_ARMORY';
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES
    ('BUILDING_SDOM_MOLTING_CHAMBER', 'YIELD_SCIENCE', 2),
    ('BUILDING_SDOM_MOLTING_CHAMBER', 'YIELD_PRODUCTION', 1);

-- One instance per occupied Apex slot. Native capture rules also exclude these buildings.
CREATE TEMP TABLE SDOM_ScienceSlots (Slot INTEGER);
INSERT INTO SDOM_ScienceSlots VALUES (1), (2), (3), (4), (5), (6);
INSERT INTO BuildingClasses (Type, Description, DefaultBuilding)
    SELECT 'BUILDINGCLASS_SDOM_APEX_' || Slot, 'TXT_KEY_SDOM_APEX_SCIENCE', 'BUILDING_SDOM_APEX_' || Slot
    FROM SDOM_ScienceSlots;
INSERT INTO Buildings (
    Type, BuildingClass, Description, Cost, FaithCost, NeverCapture, ConquestProb, NukeImmune,
    ShowInPedia, IsDummy, GreatWorkCount, IconAtlas, PortraitIndex
)
    SELECT 'BUILDING_SDOM_APEX_' || Slot, 'BUILDINGCLASS_SDOM_APEX_' || Slot, 'TXT_KEY_SDOM_APEX_SCIENCE',
        -1, -1, 1, 0, 1, 0, 1, -1, 'SDOM_MUTATION_ATLAS', 3
    FROM SDOM_ScienceSlots;
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield)
    SELECT 'BUILDING_SDOM_APEX_' || Slot, 'YIELD_SCIENCE', 2 FROM SDOM_ScienceSlots;
DROP TABLE SDOM_ScienceSlots;

INSERT INTO UnitPromotions (
    Type, Description, Help, CannotBeChosen, LostWithUpgrade, LostOnGifting, IconAtlas, PortraitIndex,
    Sound, DefenseMod, AttackMod, RangedDefenseMod, CombatPercent, FriendlyHealChange
) VALUES
    ('PROMOTION_SDOM_ASCENDANT','TXT_KEY_SDOM_ASCENDANT','TXT_KEY_SDOM_ASCENDANT_HELP',1,0,1,'SDOM_MUTATION_ATLAS',0,'',10,0,0,0,0),
    ('PROMOTION_SDOM_PINCERS','TXT_KEY_SDOM_PINCERS','TXT_KEY_SDOM_PINCERS_HELP',1,0,1,'SDOM_MUTATION_ATLAS',1,'',0,15,0,0,0),
    ('PROMOTION_SDOM_CARAPACE','TXT_KEY_SDOM_CARAPACE','TXT_KEY_SDOM_CARAPACE_HELP',1,0,1,'SDOM_MUTATION_ATLAS',2,'',0,0,20,0,0),
    ('PROMOTION_SDOM_APEX','TXT_KEY_SDOM_APEX','TXT_KEY_SDOM_APEX_HELP',1,0,1,'SDOM_MUTATION_ATLAS',3,'',0,0,0,10,5),
    ('PROMOTION_SDOM_EXOSKELETON','TXT_KEY_SDOM_EXOSKELETON','TXT_KEY_SDOM_EXOSKELETON_HELP',1,0,0,'SDOM_MUTATION_ATLAS',4,'',0,0,15,0,0);
INSERT INTO Unit_FreePromotions (UnitType, PromotionType) VALUES
    ('UNIT_SDOM_EMPEROR_SCORPION', 'PROMOTION_SDOM_EXOSKELETON');
