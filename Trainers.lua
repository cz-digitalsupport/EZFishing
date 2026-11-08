local ADDON_NAME, ns = ...

-- Angel-Ränge in Classic Era (1.12-Regeln): Lehrling und Geselle bei jedem
-- Angellehrer, Experte per Buch (Beutebucht), Fachmann per Quest (Nat Pagle).
-- Quellen: Wowhead Classic (skill=356, item=16083, quest=6607),
-- wow-professions.com (Stufenanforderungen), warcraft.wiki.gg (Abgleich).
-- WoW Forever: Lehrling hat dort keine Stufenanforderung.
ns.FISHING_RANKS = {
    { key = "APPRENTICE", from = 1, to = 75, level = 5, skill = 0, source = "trainer" },
    { key = "JOURNEYMAN", from = 75, to = 150, level = 10, skill = 50, source = "trainer" },
    { key = "EXPERT", from = 150, to = 225, level = 20, skill = 125, source = "book" },
    { key = "ARTISAN", from = 225, to = 300, level = 35, skill = 225, source = "quest" },
}

-- Schluessel = uiMapID, Koordinaten aus wow-professions.com/forever (WoW-Forever-Karten,
-- mit Wowhead Classic abgeglichen).
-- faction: "Alliance" / "Horde", nil = neutral (für beide sichtbar).
-- kind: "trainer" (Lehrling + Geselle), "book" (Expertenbuch), "quest" (Fachmann).
-- offset: Pixelversatz, wenn zwei Pins fast auf derselben Stelle liegen.
ns.FISHING_TRAINERS = {
    ---------------------------------------------------------------- Allianz
    [1438] = { -- Teldrassil (Rut'theran)
        { id = 3607, name = "Androl Oakhand", x = 55.9, y = 93.5, faction = "Alliance", kind = "trainer" },
    },
    [1453] = { -- Sturmwind (Kanäle)
        { id = 5493, name = "Arnold Leland", x = 55.0, y = 69.6, faction = "Alliance", kind = "trainer" },
    },
    [1457] = { -- Darnassus
        { id = 4156, name = "Astaia", x = 47.8, y = 56.7, faction = "Alliance", kind = "trainer" },
    },
    [1444] = { -- Feralas (Mondfederfeste)
        { id = 7946, name = "Brannock", x = 32.2, y = 41.6, faction = "Alliance", kind = "trainer" },
    },
    [1424] = { -- Vorgebirge des Hügellands (Süderstade)
        { id = 2367, name = "Donald Rabonne", x = 50.4, y = 64.1, faction = "Alliance", kind = "trainer" },
    },
    [1455] = { -- Eisenschmiede (Die Verlassene Höhle)
        { id = 5161, name = "Grimnur Stonebrand", x = 48.1, y = 6.5, faction = "Alliance", kind = "trainer",
          note = "BREADCRUMB" },
    },
    [1437] = { -- Sumpfland (Menethil)
        { id = 3179, name = "Harold Riggs", x = 8.1, y = 58.5, faction = "Alliance", kind = "trainer" },
    },
    [1429] = { -- Wald von Elwynn (Goldhain)
        { id = 1651, name = "Lee Brown", x = 47.6, y = 62.3, faction = "Alliance", kind = "trainer" },
    },
    [1433] = { -- Rotkammgebirge (Seenhain)
        { id = 1680, name = "Matthew Hooper", x = 21.4, y = 51.1, faction = "Alliance", kind = "trainer" },
    },
    [1426] = { -- Dun Morogh
        { id = 1700, name = "Paxton Ganter", x = 35.5, y = 40.2, faction = "Alliance", kind = "trainer" },
    },
    [1432] = { -- Loch Modan (Thelsamar)
        { id = 1683, name = "Warg Deepwater", x = 40.6, y = 39.6, faction = "Alliance", kind = "trainer" },
    },

    ---------------------------------------------------------------- Horde
    [1458] = { -- Unterstadt
        { id = 4573, name = "Armand Cromwell", x = 80.9, y = 31.1, faction = "Horde", kind = "trainer" },
    },
    [1420] = { -- Tirisfal
        { id = 5690, name = "Clyde Kellen", x = 67.2, y = 51.0, faction = "Horde", kind = "trainer" },
    },
    [1456] = { -- Donnerfels
        { id = 3028, name = "Kah Mistrunner", x = 56.1, y = 46.7, faction = "Horde", kind = "trainer" },
    },
    [1425] = { -- Hinterland (Revantusk)
        { id = 14740, name = "Katoom the Angler", x = 80.3, y = 81.4, faction = "Horde", kind = "trainer" },
    },
    [1440] = { -- Eschental (Zoram'gar)
        { id = 12961, name = "Kil'Hiwana", x = 10.8, y = 33.6, faction = "Horde", kind = "trainer" },
    },
    [1411] = { -- Durotar (Sen'jin)
        { id = 5941, name = "Lau'Tiki", x = 53.3, y = 81.6, faction = "Horde", kind = "trainer" },
    },
    [1443] = { -- Desolace (Schattenflucht)
        { id = 12032, name = "Lui'Mala", x = 22.7, y = 72.5, faction = "Horde", kind = "trainer" },
    },
    [1454] = { -- Orgrimmar (Tal der Ehre)
        { id = 3332, name = "Lumak", x = 69.8, y = 29.2, faction = "Horde", kind = "trainer",
          note = "BREADCRUMB" },
    },
    [1412] = { -- Mulgore
        { id = 5938, name = "Uthan Stillwater", x = 44.2, y = 63.7, faction = "Horde", kind = "trainer" },
    },

    ---------------------------------------------------------------- Neutral
    [1434] = { -- Schlingendorntal (Beutebucht)
        { id = 2834, name = "Myizz Luckycatch", x = 27.5, y = 77.1, kind = "trainer", offset = { 12, 0 } },
        { id = 2626, name = "Old Man Heming", x = 27.5, y = 77.1, kind = "book", offset = { -12, 0 },
          item = 16083, price = 10000 },
    },
    [1445] = { -- Düstermarschen (Insel südwestlich von Theramore)
        { id = 12919, name = "Nat Pagle", x = 58.5, y = 59.9, kind = "quest", quest = 6607,
          fish = { 16967, 16970, 16968, 16969 } }, -- Feralas Ahi, Misty Reed Mahi Mahi, Sar'theris Striker, Savage Coast Blue Sailfin
    },

    ---------------------------------------------------------------- WoW-Forever-Zonen (neutral)
    -- Ohne NPC-ID (nicht in Wowhead Classic); der Name bleibt daher englisch.
    [2548] = { -- Riverglades (Powderfuse Port)
        { name = "Krix", x = 79.3, y = 54.8, kind = "trainer" },
    },
    [2521] = { -- Zephras Isle
        { name = "Baelann Swiftcurrent", x = 63.2, y = 75.7, kind = "trainer" }, -- Valanaar
        { name = "Fenn Fairweather", x = 45.0, y = 48.4, kind = "trainer" },     -- Shen'dar Village
    },
}
