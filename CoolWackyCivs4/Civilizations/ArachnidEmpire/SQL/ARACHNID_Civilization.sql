-- CP hooks are opt-in, including with the standalone Community Patch.
UPDATE CustomModOptions SET Value = 1 WHERE Name IN (
    'EVENTS_BATTLES', 'EVENTS_UNIT_PREKILL', 'EVENTS_UNIT_CONVERTS',
    'EVENTS_CITY', 'EVENTS_NEW_ERA', 'EVENTS_RED_COMBAT',
    'EVENTS_RED_COMBAT_RESULT', 'EVENTS_RED_COMBAT_ENDED'
);

INSERT INTO Colors (Type, Red, Green, Blue, Alpha) VALUES
    ('COLOR_ARACHNID_OBSIDIAN', 0.075, 0.062, 0.085, 1),
    ('COLOR_ARACHNID_VENOM_CRIMSON', 0.78, 0.13, 0.23, 1);
INSERT INTO PlayerColors (Type, PrimaryColor, SecondaryColor, TextColor) VALUES
    ('PLAYERCOLOR_ARACHNID_EMPIRE', 'COLOR_ARACHNID_OBSIDIAN', 'COLOR_ARACHNID_VENOM_CRIMSON', 'COLOR_PLAYER_WHITE_TEXT');

INSERT INTO Civilizations (
    Type, Description, ShortDescription, Adjective, Civilopedia, CivilopediaTag, Strategy,
    Playable, AIPlayable, DefaultPlayerColor, ArtDefineTag, ArtStyleType, ArtStyleSuffix,
    ArtStylePrefix, PortraitIndex, IconAtlas, AlphaIconAtlas, MapImage, DawnOfManQuote,
    DawnOfManImage, DawnOfManAudio, SoundtrackTag
) VALUES (
    'CIVILIZATION_ARACHNID_EMPIRE', 'TXT_KEY_ARACHNID_CIV', 'TXT_KEY_ARACHNID_SHORT',
    'TXT_KEY_ARACHNID_ADJECTIVE', 'TXT_KEY_ARACHNID_CIV_PEDIA', 'TXT_KEY_ARACHNID_HISTORY',
    'TXT_KEY_ARACHNID_STRATEGY', 1, 0, 'PLAYERCOLOR_ARACHNID_EMPIRE', 'ART_DEF_CIVILIZATION_AMERICA',
    'ARTSTYLE_EUROPEAN', '_EURO', 'EUROPEAN ', 0, 'ARACHNID_CIV_ATLAS', 'ARACHNID_ALPHA_ATLAS',
    'ARACHNID_Map.dds', 'TXT_KEY_ARACHNID_DAWN', 'ARACHNID_Dawn.dds', '', 'America'
);

INSERT INTO Leaders (
    Type, Description, Civilopedia, CivilopediaTag, ArtDefineTag, PrimaryVictoryPursuit,
    SecondaryVictoryPursuit, VictoryCompetitiveness, Boldness, WarmongerHate, Meanness,
    PortraitIndex, IconAtlas
) VALUES (
    'LEADER_ARACHNID_SPIDER_QUEEN', 'TXT_KEY_ARACHNID_QUEEN', 'TXT_KEY_ARACHNID_QUEEN_PEDIA',
    'TXT_KEY_ARACHNID_QUEEN_HISTORY', 'ARACHNID_LeaderScene.xml', 'VICTORY_PURSUIT_DOMINATION',
    'VICTORY_PURSUIT_SCIENCE', 8, 8, 2, 7, 0, 'ARACHNID_QUEEN_ATLAS'
);
INSERT INTO Traits (Type, Description, ShortDescription) VALUES
    ('TRAIT_ARACHNID_EVOLUTION', 'TXT_KEY_ARACHNID_TRAIT_HELP', 'TXT_KEY_ARACHNID_TRAIT');
INSERT INTO Civilization_Leaders (CivilizationType, LeaderheadType) VALUES
    ('CIVILIZATION_ARACHNID_EMPIRE', 'LEADER_ARACHNID_SPIDER_QUEEN');
INSERT INTO Leader_Traits (LeaderType, TraitType) VALUES
    ('LEADER_ARACHNID_SPIDER_QUEEN', 'TRAIT_ARACHNID_EVOLUTION');

INSERT INTO Civilization_FreeBuildingClasses (CivilizationType, BuildingClassType)
    SELECT 'CIVILIZATION_ARACHNID_EMPIRE', BuildingClassType
    FROM Civilization_FreeBuildingClasses WHERE CivilizationType = 'CIVILIZATION_AMERICA';
INSERT INTO Civilization_FreeTechs (CivilizationType, TechType)
    SELECT 'CIVILIZATION_ARACHNID_EMPIRE', TechType
    FROM Civilization_FreeTechs WHERE CivilizationType = 'CIVILIZATION_AMERICA';
INSERT INTO Civilization_FreeUnits (CivilizationType, UnitClassType, UnitAIType, Count)
    SELECT 'CIVILIZATION_ARACHNID_EMPIRE', UnitClassType, UnitAIType, Count
    FROM Civilization_FreeUnits WHERE CivilizationType = 'CIVILIZATION_AMERICA';

INSERT INTO Leader_Flavors (LeaderType, FlavorType, Flavor)
    SELECT 'LEADER_ARACHNID_SPIDER_QUEEN', Type,
        CASE Type WHEN 'FLAVOR_OFFENSE' THEN 9 WHEN 'FLAVOR_SCIENCE' THEN 8 ELSE 5 END
    FROM Flavors;
