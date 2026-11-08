local ADDON_NAME, ns = ...

-- Quellen: Wowhead Classic ("Gefischt in"), oatcookies.neocities.org (Zonen-Angelfertigkeit),
-- warcraft.wiki.gg (Abgleich). Werte: min = Angeln möglich, noEscape = kein Fisch entkommt
-- (effektive Fertigkeit inkl. Angel und Köder).
-- Angelgebiete Classic Era (1.12-Daten), Schluessel = uiMapID
-- Fischlisten: Freiwasser-Fang, sortiert nach Fangchance (Wowhead Classic "Fished in",
-- reine Schwarm-Fische wie Sagefish / Greater Sagefish / Stonescale Eel herausgerechnet).
-- note: "coast"/"inland"/"day"/"night"/"winter"/"summer" oder Subzonen-Schluessel.

ns.FISHING_ZONES = {
    ---------------------------------------------------------------- Kalimdor
    [1438] = { -- Teldrassil
        min = 1, noEscape = 25,
        fish = {
            { id = 6303, note = "coast" },  -- Raw Slitherskin Mackerel
            { id = 6291, note = "inland" }, -- Raw Brilliant Smallfish
            { id = 6289, note = "inland" }, -- Raw Longjaw Mud Snapper
        },
    },
    [1439] = { -- Dunkelkueste / Darkshore
        min = 1, noEscape = 75,
        fish = {
            { id = 12238, note = "coast" }, -- Darkshore Grouper
            { id = 6361, note = "coast" },  -- Raw Rainbow Fin Albacore
            { id = 6358, note = "coast" },  -- Oily Blackmouth
            { id = 6303, note = "coast" },  -- Raw Slitherskin Mackerel
            { id = 6289, note = "inland" }, -- Raw Longjaw Mud Snapper
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
            { id = 6291, note = "inland" }, -- Raw Brilliant Smallfish
        },
    },
    [1450] = { -- Mondlichtung / Moonglade
        min = 205, noEscape = 300,
        fish = {
            { id = 13758 },                 -- Raw Redgill
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 8365 },                  -- Raw Mithril Head Trout
            { id = 6358 },                  -- Oily Blackmouth
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
        },
    },
    [1452] = { -- Winterquell / Winterspring
        min = 330, noEscape = 425,
        fish = {
            { id = 13889 },                 -- Raw Whitescale Salmon
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 13890 },                 -- Plated Armorfish
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
            { id = 13757 },                 -- Lightning Eel
            { id = 13758 },                 -- Raw Redgill
        },
    },
    [1448] = { -- Teufelswald / Felwood
        min = 205, noEscape = 300,
        fish = {
            { id = 13758 },                 -- Raw Redgill
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 8365 },                  -- Raw Mithril Head Trout
            { id = 6358 },                  -- Oily Blackmouth
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
        },
    },
    [1447] = { -- Azshara (Bay of Storms / Hetaera's Clutch: 330)
        min = 205, noEscape = 300,
        fish = {
            { id = 13888, note = "coast" },  -- Darkclaw Lobster
            { id = 13755, note = "winter" }, -- Winter Squid
            { id = 4603, note = "coast" },   -- Raw Spotted Yellowtail
            { id = 13893, note = "coast" },  -- Large Raw Mightfish
            { id = 13758, note = "inland" }, -- Raw Redgill
            { id = 6359 },                   -- Firefin Snapper
            { id = 13754, note = "coast" },  -- Raw Glossy Mightfish
            { id = 6362, note = "coast" },   -- Raw Rockscale Cod
            { id = 6358 },                   -- Oily Blackmouth
        },
    },
    [1440] = { -- Eschental / Ashenvale
        min = 55, noEscape = 150,
        fish = {
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
            { id = 6289, note = "inland" }, -- Raw Longjaw Mud Snapper
            { id = 6361, note = "coast" },  -- Raw Rainbow Fin Albacore
            { id = 6358, note = "coast" },  -- Oily Blackmouth
            { id = 6359 },                  -- Firefin Snapper
        },
    },
    [1442] = { -- Steinkrallengebirge / Stonetalon Mountains
        min = 55, noEscape = 150,
        fish = {
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6289 }, -- Raw Longjaw Mud Snapper
            { id = 6359 }, -- Firefin Snapper
        },
    },
    [1411] = { -- Durotar
        min = 1, noEscape = 25,
        fish = {
            { id = 6303, note = "coast" },  -- Raw Slitherskin Mackerel
            { id = 6291, note = "inland" }, -- Raw Brilliant Smallfish
            { id = 6289, note = "inland" }, -- Raw Longjaw Mud Snapper
        },
    },
    [1413] = { -- Brachland / The Barrens
        min = 1, noEscape = 75,
        fish = {
            { id = 6522, note = "oasis" },  -- Deviate Fish
            { id = 6358, note = "coast" },  -- Oily Blackmouth
            { id = 6289, note = "inland" }, -- Raw Longjaw Mud Snapper
            { id = 6361, note = "coast" },  -- Raw Rainbow Fin Albacore
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
            { id = 6303, note = "coast" },  -- Raw Slitherskin Mackerel
            { id = 6291, note = "inland" }, -- Raw Brilliant Smallfish
        },
    },
    [1443] = { -- Desolace
        min = 130, noEscape = 225,
        fish = {
            { id = 8365, note = "inland" }, -- Raw Mithril Head Trout
            { id = 6362, note = "coast" },  -- Raw Rockscale Cod
            { id = 6359 },                  -- Firefin Snapper
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
            { id = 6358 },                  -- Oily Blackmouth
            { id = 4603, note = "coast" },  -- Raw Spotted Yellowtail
        },
    },
    [1412] = { -- Mulgore
        min = 1, noEscape = 25,
        fish = {
            { id = 6291 }, -- Raw Brilliant Smallfish
            { id = 6289 }, -- Raw Longjaw Mud Snapper
        },
    },
    [1445] = { -- Duestermarschen / Dustwallow Marsh
        min = 130, noEscape = 225,
        fish = {
            { id = 6362, note = "coast" },  -- Raw Rockscale Cod
            { id = 8365, note = "inland" }, -- Raw Mithril Head Trout
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
            { id = 6359 },                  -- Firefin Snapper
            { id = 4603, note = "coast" },  -- Raw Spotted Yellowtail
            { id = 6358 },                  -- Oily Blackmouth
        },
    },
    [1444] = { -- Feralas (Jademir Lake: 330)
        min = 205, noEscape = 300,
        fish = {
            { id = 13758, note = "inland" }, -- Raw Redgill
            { id = 13759, note = "night" },  -- Raw Nightfin Snapper
            { id = 6358 },                   -- Oily Blackmouth
            { id = 4603, note = "coast" },   -- Raw Spotted Yellowtail
            { id = 8365, note = "inland" },  -- Raw Mithril Head Trout
            { id = 13760, note = "day" },    -- Raw Sunscale Salmon
            { id = 6359 },                   -- Firefin Snapper
            { id = 13754, note = "coast" },  -- Raw Glossy Mightfish
            { id = 6362, note = "coast" },   -- Raw Rockscale Cod
            { id = 13755, note = "winter" }, -- Winter Squid
            { id = 13889, note = "jademir", minSkill = 330 }, -- Raw Whitescale Salmon
        },
    },
    [1441] = { -- Tausend Nadeln / Thousand Needles
        min = 130, noEscape = 225,
        fish = {
            { id = 8365 }, -- Raw Mithril Head Trout
            { id = 6308 }, -- Raw Bristle Whisker Catfish
        },
    },
    [1451] = { -- Silithus (wenig Wasser, kleine Stichprobe)
        min = 330, noEscape = 425,
        fish = {
            { id = 13889 },                 -- Raw Whitescale Salmon
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
            { id = 13757 },                 -- Lightning Eel
            { id = 13890 },                 -- Plated Armorfish
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 13758 },                 -- Raw Redgill
        },
    },
    [1449] = { -- Krater von Un'Goro / Un'Goro Crater
        min = 205, noEscape = 300,
        fish = {
            { id = 13758 },                 -- Raw Redgill
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 8365 },                  -- Raw Mithril Head Trout
            { id = 6358 },                  -- Oily Blackmouth
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
        },
    },
    [1446] = { -- Tanaris
        min = 205, noEscape = 300,
        fish = {
            { id = 4603 },                   -- Raw Spotted Yellowtail
            { id = 6359 },                   -- Firefin Snapper
            { id = 6358 },                   -- Oily Blackmouth
            { id = 6362 },                   -- Raw Rockscale Cod
            { id = 13754 },                  -- Raw Glossy Mightfish
            { id = 13755, note = "winter" }, -- Winter Squid
            { id = 13756, note = "summer" }, -- Raw Summer Bass
        },
    },

    ---------------------------------------------------------- Oestliche Koenigreiche
    [1420] = { -- Tirisfal
        min = 1, noEscape = 25,
        fish = {
            { id = 6291 }, -- Raw Brilliant Smallfish
            { id = 6289 }, -- Raw Longjaw Mud Snapper
            { id = 6299 }, -- Sickly Looking Fish
        },
    },
    [1421] = { -- Silberwald / Silverpine Forest
        min = 1, noEscape = 75,
        fish = {
            { id = 6358, note = "coast" },  -- Oily Blackmouth
            { id = 6361, note = "coast" },  -- Raw Rainbow Fin Albacore
            { id = 6303, note = "coast" },  -- Raw Slitherskin Mackerel
            { id = 6289, note = "inland" }, -- Raw Longjaw Mud Snapper
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
        },
    },
    [1422] = { -- Westliche Pestlaender / Western Plaguelands
        min = 205, noEscape = 300,
        fish = {
            { id = 13758 },                 -- Raw Redgill
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 8365 },                  -- Raw Mithril Head Trout
            { id = 6358 },                  -- Oily Blackmouth
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
        },
    },
    [1423] = { -- Oestliche Pestlaender / Eastern Plaguelands
        min = 330, noEscape = 425,
        fish = {
            { id = 13889 },                 -- Raw Whitescale Salmon
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 13890 },                 -- Plated Armorfish
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
            { id = 13757 },                 -- Lightning Eel
            { id = 13758 },                 -- Raw Redgill
        },
    },
    [1416] = { -- Alteracgebirge / Alterac Mountains
        min = 130, noEscape = 225,
        fish = {
            { id = 8365 }, -- Raw Mithril Head Trout
            { id = 6308 }, -- Raw Bristle Whisker Catfish
        },
    },
    [1424] = { -- Vorgebirge des Huegellands / Hillsbrad Foothills
        min = 55, noEscape = 150,
        fish = {
            { id = 6358 },                  -- Oily Blackmouth
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
            { id = 6361, note = "coast" },  -- Raw Rainbow Fin Albacore
            { id = 6359 },                  -- Firefin Snapper
            { id = 6289, note = "inland" }, -- Raw Longjaw Mud Snapper
        },
    },
    [1425] = { -- Hinterland / The Hinterlands
        min = 205, noEscape = 300,
        fish = {
            { id = 13758, note = "inland" }, -- Raw Redgill
            { id = 4603, note = "coast" },   -- Raw Spotted Yellowtail
            { id = 13759, note = "night" },  -- Raw Nightfin Snapper
            { id = 13754, note = "coast" },  -- Raw Glossy Mightfish
            { id = 6359 },                   -- Firefin Snapper
            { id = 6362, note = "coast" },   -- Raw Rockscale Cod
            { id = 6358 },                   -- Oily Blackmouth
            { id = 8365, note = "inland" },  -- Raw Mithril Head Trout
            { id = 13760, note = "day" },    -- Raw Sunscale Salmon
            { id = 13755, note = "winter" }, -- Winter Squid
            { id = 13756, note = "summer" }, -- Raw Summer Bass
        },
    },
    [1417] = { -- Arathihochland / Arathi Highlands
        min = 130, noEscape = 225,
        fish = {
            { id = 8365, note = "inland" }, -- Raw Mithril Head Trout
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
            { id = 6362, note = "coast" },  -- Raw Rockscale Cod
            { id = 6359 },                  -- Firefin Snapper
            { id = 6358 },                  -- Oily Blackmouth
            { id = 4603, note = "coast" },  -- Raw Spotted Yellowtail
        },
    },
    [1437] = { -- Sumpfland / Wetlands
        min = 55, noEscape = 150,
        fish = {
            { id = 6361 }, -- Raw Rainbow Fin Albacore
            { id = 6358 }, -- Oily Blackmouth
            { id = 6359 }, -- Firefin Snapper
        },
    },
    [1426] = { -- Dun Morogh
        min = 1, noEscape = 25,
        fish = {
            { id = 6291 }, -- Raw Brilliant Smallfish
            { id = 6289 }, -- Raw Longjaw Mud Snapper
        },
    },
    [1432] = { -- Loch Modan
        min = 1, noEscape = 75,
        fish = {
            { id = 6289 }, -- Raw Longjaw Mud Snapper
            { id = 6317 }, -- Raw Loch Frenzy
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6291 }, -- Raw Brilliant Smallfish
        },
    },
    [1427] = { min = nil }, -- Sengende Schlucht / Searing Gorge: kein Angeln
    [1418] = { min = nil }, -- Oedland / Badlands: kein Angeln
    [1419] = { min = nil }, -- Verwuestete Lande / Blasted Lands: kein Angeln
    [1428] = { -- Brennende Steppe / Burning Steppes (sehr wenig Daten)
        min = 330, noEscape = 425,
        fish = {
            { id = 13889 },                 -- Raw Whitescale Salmon
            { id = 13757 },                 -- Lightning Eel
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 13890 },                 -- Plated Armorfish
            { id = 13758 },                 -- Raw Redgill
        },
    },
    [1429] = { -- Wald von Elwynn / Elwynn Forest
        min = 1, noEscape = 25,
        fish = {
            { id = 6291 }, -- Raw Brilliant Smallfish
            { id = 6289 }, -- Raw Longjaw Mud Snapper
        },
    },
    [1433] = { -- Rotkammgebirge / Redridge Mountains
        min = 55, noEscape = 150,
        fish = {
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6289 }, -- Raw Longjaw Mud Snapper
        },
    },
    [1436] = { -- Westfall
        min = 1, noEscape = 75,
        fish = {
            { id = 6358, note = "coast" },  -- Oily Blackmouth
            { id = 6361, note = "coast" },  -- Raw Rainbow Fin Albacore
            { id = 6303, note = "coast" },  -- Raw Slitherskin Mackerel
            { id = 6289, note = "inland" }, -- Raw Longjaw Mud Snapper
        },
    },
    [1431] = { -- Daemmerwald / Duskwood
        min = 55, noEscape = 150,
        fish = {
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6289 }, -- Raw Longjaw Mud Snapper
        },
    },
    [1430] = { -- Gebirgspass der Totenwinde / Deadwind Pass
        min = 330, noEscape = 425,
        fish = {
            { id = 13889 },                 -- Raw Whitescale Salmon
            { id = 13759, note = "night" }, -- Raw Nightfin Snapper
            { id = 13890 },                 -- Plated Armorfish
            { id = 13760, note = "day" },   -- Raw Sunscale Salmon
            { id = 13757 },                 -- Lightning Eel
            { id = 13758 },                 -- Raw Redgill
        },
    },
    [1435] = { -- Suempfe des Elends / Swamp of Sorrows
        min = 130, noEscape = 225,
        fish = {
            { id = 6362, note = "coast" },  -- Raw Rockscale Cod
            { id = 4603, note = "coast" },  -- Raw Spotted Yellowtail
            { id = 6359 },                  -- Firefin Snapper
            { id = 6358 },                  -- Oily Blackmouth
            { id = 8365, note = "inland" }, -- Raw Mithril Head Trout
            { id = 6308, note = "inland" }, -- Raw Bristle Whisker Catfish
        },
    },
    [1434] = { -- Schlingendorntal / Stranglethorn Vale (Jaguero Isle: 205)
        min = 130, noEscape = 225,
        fish = {
            { id = 6362, note = "coast" },  -- Raw Rockscale Cod
            { id = 6359 },                  -- Firefin Snapper
            { id = 6358 },                  -- Oily Blackmouth
            { id = 4603, note = "coast" },  -- Raw Spotted Yellowtail
            { id = 8365, note = "inland" }, -- Raw Mithril Head Trout
        },
    },

    ---------------------------------------------------------------- Hauptstaedte
    [1453] = { -- Sturmwind / Stormwind City
        min = 1, noEscape = 75,
        fish = {
            { id = 6289 }, -- Raw Longjaw Mud Snapper
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6291 }, -- Raw Brilliant Smallfish
        },
    },
    [1455] = { min = nil }, -- Eisenschmiede / Ironforge: in 1.12 kein Angelwasser (erst 2.3)
    [1457] = { -- Darnassus
        min = 1, noEscape = 75,
        fish = {
            { id = 6289 }, -- Raw Longjaw Mud Snapper
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6291 }, -- Raw Brilliant Smallfish
        },
    },
    [1454] = { -- Orgrimmar
        min = 1, noEscape = 75,
        fish = {
            { id = 6289 }, -- Raw Longjaw Mud Snapper
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6291 }, -- Raw Brilliant Smallfish
        },
    },
    [1456] = { -- Donnerfels / Thunder Bluff
        min = 1, noEscape = 75,
        fish = {
            { id = 6289 }, -- Raw Longjaw Mud Snapper
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6291 }, -- Raw Brilliant Smallfish
        },
    },
    [1458] = { -- Unterstadt / Undercity
        min = 1, noEscape = 75,
        fish = {
            { id = 6289 }, -- Raw Longjaw Mud Snapper
            { id = 6299 }, -- Sickly Looking Fish
            { id = 6308 }, -- Raw Bristle Whisker Catfish
            { id = 6291 }, -- Raw Brilliant Smallfish
        },
    },
}
