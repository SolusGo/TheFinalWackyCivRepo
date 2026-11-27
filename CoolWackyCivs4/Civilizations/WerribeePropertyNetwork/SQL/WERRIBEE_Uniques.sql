-- Keep the native Great Merchant and Market attributes of the active BNW + CP database.
CREATE TEMP TABLE WerribeeMerchant AS SELECT * FROM Units WHERE Type = 'UNIT_MERCHANT';
UPDATE WerribeeMerchant SET
    ID = NULL, Type = 'UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT',
    Description = 'TXT_KEY_WERRIBEE_CONSULTANT', Civilopedia = 'TXT_KEY_WERRIBEE_CONSULTANT_PEDIA',
    Strategy = 'TXT_KEY_WERRIBEE_CONSULTANT_STRATEGY', Help = 'TXT_KEY_WERRIBEE_CONSULTANT_HELP',
    IconAtlas = 'WERRIBEE_ATLAS', PortraitIndex = 2,
    UnitFlagAtlas = 'WERRIBEE_FLAG_ATLAS', UnitFlagIconOffset = 0;
INSERT INTO Units SELECT * FROM WerribeeMerchant;
DROP TABLE WerribeeMerchant;

INSERT INTO Civilization_UnitClassOverrides (CivilizationType, UnitClassType, UnitType) VALUES
    ('CIVILIZATION_WERRIBEE_PROPERTY_NETWORK', 'UNITCLASS_MERCHANT', 'UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT');

CREATE TEMP TABLE WerribeeMarket AS SELECT * FROM Buildings WHERE Type = 'BUILDING_MARKET';
UPDATE WerribeeMarket SET
    ID = NULL, Type = 'BUILDING_WERRIBEE_REAL_ESTATE_OFFICE',
    Description = 'TXT_KEY_WERRIBEE_OFFICE', Civilopedia = 'TXT_KEY_WERRIBEE_OFFICE_PEDIA',
    Strategy = 'TXT_KEY_WERRIBEE_OFFICE_STRATEGY', Help = 'TXT_KEY_WERRIBEE_OFFICE_HELP',
    IconAtlas = 'WERRIBEE_ATLAS', PortraitIndex = 3;
INSERT INTO Buildings SELECT * FROM WerribeeMarket;
DROP TABLE WerribeeMarket;

INSERT INTO Civilization_BuildingClassOverrides (CivilizationType, BuildingClassType, BuildingType) VALUES
    ('CIVILIZATION_WERRIBEE_PROPERTY_NETWORK', 'BUILDINGCLASS_MARKET', 'BUILDING_WERRIBEE_REAL_ESTATE_OFFICE');

INSERT INTO Unit_AITypes (UnitType, UnitAIType)
    SELECT 'UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT', UnitAIType
    FROM Unit_AITypes WHERE UnitType = 'UNIT_MERCHANT';

INSERT INTO Unit_Builds (UnitType, BuildType)
    SELECT 'UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT', BuildType
    FROM Unit_Builds WHERE UnitType = 'UNIT_MERCHANT';

INSERT INTO Unit_Flavors (UnitType, FlavorType, Flavor)
    SELECT 'UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT', FlavorType, Flavor
    FROM Unit_Flavors WHERE UnitType = 'UNIT_MERCHANT';

INSERT INTO Unit_UniqueNames (UnitType, UniqueName, GreatWorkType, EraType)
    SELECT 'UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT', UniqueName, GreatWorkType, EraType
    FROM Unit_UniqueNames WHERE UnitType = 'UNIT_MERCHANT';

INSERT INTO UnitGameplay2DScripts (UnitType, SelectionSound, FirstSelectionSound)
    SELECT 'UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT', SelectionSound, FirstSelectionSound
    FROM UnitGameplay2DScripts WHERE UnitType = 'UNIT_MERCHANT';

INSERT INTO Building_Flavors (BuildingType, FlavorType, Flavor)
    SELECT 'BUILDING_WERRIBEE_REAL_ESTATE_OFFICE', FlavorType, Flavor
    FROM Building_Flavors WHERE BuildingType = 'BUILDING_MARKET';

INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield)
    SELECT 'BUILDING_WERRIBEE_REAL_ESTATE_OFFICE', YieldType, Yield
    FROM Building_YieldChanges WHERE BuildingType = 'BUILDING_MARKET';

INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield)
    SELECT 'BUILDING_WERRIBEE_REAL_ESTATE_OFFICE', YieldType, Yield
    FROM Building_YieldModifiers WHERE BuildingType = 'BUILDING_MARKET';

INSERT INTO Building_ClassesNeededInCity (BuildingType, BuildingClassType)
    SELECT 'BUILDING_WERRIBEE_REAL_ESTATE_OFFICE', BuildingClassType
    FROM Building_ClassesNeededInCity WHERE BuildingType = 'BUILDING_MARKET';

INSERT INTO Building_PrereqBuildingClasses (BuildingType, BuildingClassType, NumBuildingNeeded)
    SELECT 'BUILDING_WERRIBEE_REAL_ESTATE_OFFICE', BuildingClassType, NumBuildingNeeded
    FROM Building_PrereqBuildingClasses WHERE BuildingType = 'BUILDING_MARKET';

INSERT INTO Building_ImprovementYieldChanges (BuildingType, ImprovementType, YieldType, Yield) VALUES
    ('BUILDING_WERRIBEE_REAL_ESTATE_OFFICE', 'IMPROVEMENT_FARM', 'YIELD_GOLD', 1),
    ('BUILDING_WERRIBEE_REAL_ESTATE_OFFICE', 'IMPROVEMENT_PASTURE', 'YIELD_GOLD', 1),
    ('BUILDING_WERRIBEE_REAL_ESTATE_OFFICE', 'IMPROVEMENT_TRADING_POST', 'YIELD_GOLD', 1);

CREATE TEMP TABLE WerribeeEffects (
    Suffix TEXT PRIMARY KEY, FlatGold INTEGER, GoldPercent INTEGER, ProductionPercent INTEGER,
    GreatPeoplePercent INTEGER, BuildingProductionPercent INTEGER
);
INSERT INTO WerribeeEffects VALUES
    ('PRIME_REAL_ESTATE',     1,  0,  0,  0,  0),
    ('PROPERTY_SALE',         0,  0, 10,  0,  0),
    ('CONNECTED_SUBURB',     0,  5,  5,  0,  0),
    ('CONNECTED_METROPOLIS',  0, 10, 10,  0,  0),
    ('APPRAISAL_YIELD',       1,  0,  0,  0,  0),
    ('APPRAISAL_MODIFIER',    0, 10,  0,  0,  0),
    ('VENDOR_NETWORK',       0, 15,  0, 15,  0),
    ('HOUSING_DEMAND',       1,  0,  0,  0,  0),
    ('PROPERTY_BOOM',        0,  0,  0,  0, 10);

INSERT INTO BuildingClasses (Type, Description, DefaultBuilding)
    SELECT 'BUILDINGCLASS_WERRIBEE_DUMMY_' || Suffix, 'TXT_KEY_WERRIBEE_INTERNAL',
        'BUILDING_WERRIBEE_DUMMY_' || Suffix FROM WerribeeEffects;
INSERT INTO Buildings (
    Type, BuildingClass, Description, Cost, FaithCost, GoldMaintenance, NeverCapture, ConquestProb,
    ShowInPedia, IsDummy, GreatWorkCount, GreatPeopleRateModifier, BuildingProductionModifier,
    IconAtlas, PortraitIndex
)
    SELECT 'BUILDING_WERRIBEE_DUMMY_' || Suffix, 'BUILDINGCLASS_WERRIBEE_DUMMY_' || Suffix,
        'TXT_KEY_WERRIBEE_INTERNAL', -1, -1, 0, 1, 0, 0, 1, -1, GreatPeoplePercent,
        BuildingProductionPercent, 'WERRIBEE_ATLAS', 0 FROM WerribeeEffects;
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield)
    SELECT 'BUILDING_WERRIBEE_DUMMY_' || Suffix, 'YIELD_GOLD', FlatGold FROM WerribeeEffects WHERE FlatGold > 0;
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield)
    SELECT 'BUILDING_WERRIBEE_DUMMY_' || Suffix, 'YIELD_GOLD', GoldPercent FROM WerribeeEffects WHERE GoldPercent > 0
    UNION ALL
    SELECT 'BUILDING_WERRIBEE_DUMMY_' || Suffix, 'YIELD_PRODUCTION', ProductionPercent FROM WerribeeEffects
    WHERE ProductionPercent > 0;
DROP TABLE WerribeeEffects;
