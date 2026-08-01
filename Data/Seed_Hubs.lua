local _, ns = ...
local A = ns.AddSeed

---------------------------------------------------------------------------
-- Shattrath City (111)
---------------------------------------------------------------------------
A{ name = "Innkeeper Haelthol", npcID = 19232, mapID = 111, x = 0.562, y = 0.634, faction = "Neutral", types = { innkeeper = true, food = true } }
A{ name = "Endarin", npcID = 19321, mapID = 111, x = 0.478, y = 0.264, faction = "Neutral", types = { reagents = true } }
A{ name = "Aaron Hollman", npcID = 19662, mapID = 111, x = 0.642, y = 0.712, faction = "Neutral", types = { repair = true } }
A{ name = "Almaador", npcID = 19331, mapID = 111, x = 0.512, y = 0.286, faction = "Neutral", types = { faction = true }, note = "Sha'tari Skyguard / Aldor area" }
A{ name = "Trader Endarno", npcID = 19235, mapID = 111, x = 0.668, y = 0.684, faction = "Neutral", types = { general = true } }
A{ name = "Yurial Soulwater", npcID = 19234, mapID = 111, x = 0.442, y = 0.364, faction = "Neutral", types = { profession = true } }
A{ name = "Barber Shop", mapID = 111, x = 0.582, y = 0.482, faction = "Neutral", types = { barber = true } }
A{ name = "Stable Master", mapID = 111, x = 0.672, y = 0.562, faction = "Neutral", types = { stable = true } }
A{ name = "Bank", mapID = 111, x = 0.582, y = 0.612, faction = "Neutral", types = { general = true } }
A{ name = "Auctioneer", mapID = 111, x = 0.572, y = 0.712, faction = "Neutral", types = { general = true } }

---------------------------------------------------------------------------
-- Dalaran — Northrend (125)
---------------------------------------------------------------------------
A{ name = "Barber Shop", mapID = 125, x = 0.518, y = 0.312, faction = "Neutral", types = { barber = true } }
A{ name = "Amisi Azuregaze", npcID = 28687, mapID = 125, x = 0.506, y = 0.394, faction = "Neutral", types = { innkeeper = true, food = true } }
A{ name = "Aeris", npcID = 29493, mapID = 125, x = 0.388, y = 0.542, faction = "Neutral", types = { reagents = true } }
A{ name = "Harold Winston", npcID = 32172, mapID = 125, x = 0.402, y = 0.342, faction = "Neutral", types = { repair = true } }
A{ name = "Magister Arlan", mapID = 125, x = 0.392, y = 0.562, faction = "Neutral", types = { reagents = true } }
A{ name = "Debbi Moore", npcID = 29528, mapID = 125, x = 0.497, y = 0.555, faction = "Neutral", types = { general = true } }
A{ name = "Bragund Brightlink", npcID = 28994, mapID = 125, x = 0.452, y = 0.286, faction = "Neutral", types = { repair = true } }
A{ name = "Stable Master", mapID = 125, x = 0.586, y = 0.392, faction = "Neutral", types = { stable = true } }
A{ name = "Bank", mapID = 125, x = 0.532, y = 0.152, faction = "Neutral", types = { general = true }, note = "Alliance / Horde banks nearby" }
A{ name = "Auctioneer", mapID = 125, x = 0.382, y = 0.252, faction = "Neutral", types = { general = true } }

---------------------------------------------------------------------------
-- Dalaran — Broken Isles (627)
---------------------------------------------------------------------------
A{ name = "Barber Shop", mapID = 627, x = 0.518, y = 0.312, faction = "Neutral", types = { barber = true } }
A{ name = "Amisi Azuregaze", npcID = 96806, mapID = 627, x = 0.498, y = 0.398, faction = "Neutral", types = { innkeeper = true, food = true } }
A{ name = "Professor Pallin", npcID = 92195, mapID = 627, x = 0.412, y = 0.372, faction = "Neutral", types = { profession = true }, note = "Inscription" }
A{ name = "Lucan Malory", npcID = 112426, mapID = 627, x = 0.452, y = 0.286, faction = "Neutral", types = { transmog = true } }
A{ name = "First Arcanist Thalyssra", mapID = 627, x = 0.362, y = 0.468, faction = "Neutral", types = { faction = true }, note = "Nightfallen embassy area" }
A{ name = "Reagent Vendor", mapID = 627, x = 0.388, y = 0.542, faction = "Neutral", types = { reagents = true } }
A{ name = "Repair Services", mapID = 627, x = 0.402, y = 0.342, faction = "Neutral", types = { repair = true } }
A{ name = "Stable Master", mapID = 627, x = 0.586, y = 0.392, faction = "Neutral", types = { stable = true } }
A{ name = "Bank", mapID = 627, x = 0.532, y = 0.152, faction = "Neutral", types = { general = true } }
A{ name = "Auction House", mapID = 627, x = 0.382, y = 0.252, faction = "Neutral", types = { general = true } }

---------------------------------------------------------------------------
-- Shrine of Two Moons / Seven Stars (approximates — Vale hubs)
---------------------------------------------------------------------------
A{ name = "Innkeeper", mapID = 392, x = 0.612, y = 0.372, faction = "Horde", types = { innkeeper = true, food = true }, note = "Shrine of Two Moons" }
A{ name = "Repair", mapID = 392, x = 0.582, y = 0.412, faction = "Horde", types = { repair = true } }
A{ name = "Reagents", mapID = 392, x = 0.598, y = 0.398, faction = "Horde", types = { reagents = true } }
A{ name = "Innkeeper", mapID = 393, x = 0.862, y = 0.628, faction = "Alliance", types = { innkeeper = true, food = true }, note = "Shrine of Seven Stars" }
A{ name = "Repair", mapID = 393, x = 0.842, y = 0.642, faction = "Alliance", types = { repair = true } }

---------------------------------------------------------------------------
-- Ashran / Stormshield / Warspear (622 / 624)
---------------------------------------------------------------------------
A{ name = "Innkeeper", mapID = 622, x = 0.402, y = 0.652, faction = "Alliance", types = { innkeeper = true, food = true }, note = "Stormshield" }
A{ name = "Repair", mapID = 622, x = 0.438, y = 0.682, faction = "Alliance", types = { repair = true } }
A{ name = "Reagents", mapID = 622, x = 0.452, y = 0.664, faction = "Alliance", types = { reagents = true } }
A{ name = "Barber Shop", mapID = 622, x = 0.428, y = 0.612, faction = "Alliance", types = { barber = true } }
A{ name = "Innkeeper", mapID = 624, x = 0.448, y = 0.452, faction = "Horde", types = { innkeeper = true, food = true }, note = "Warspear" }
A{ name = "Repair", mapID = 624, x = 0.482, y = 0.428, faction = "Horde", types = { repair = true } }
A{ name = "Reagents", mapID = 624, x = 0.468, y = 0.442, faction = "Horde", types = { reagents = true } }
A{ name = "Barber Shop", mapID = 624, x = 0.512, y = 0.412, faction = "Horde", types = { barber = true } }

---------------------------------------------------------------------------
-- Lunastre Estate / Suramar city services are sparse; skip.

---------------------------------------------------------------------------
-- Boralus (1161) / Dazar'alor (1165)
---------------------------------------------------------------------------
A{ name = "Innkeeper", mapID = 1161, x = 0.742, y = 0.162, faction = "Alliance", types = { innkeeper = true, food = true }, note = "Boralus Harbor" }
A{ name = "Repair", mapID = 1161, x = 0.712, y = 0.186, faction = "Alliance", types = { repair = true } }
A{ name = "Reagents", mapID = 1161, x = 0.728, y = 0.174, faction = "Alliance", types = { reagents = true } }
A{ name = "Barber Shop", mapID = 1161, x = 0.684, y = 0.212, faction = "Alliance", types = { barber = true } }
A{ name = "Stable Master", mapID = 1161, x = 0.692, y = 0.152, faction = "Alliance", types = { stable = true } }
A{ name = "Auction House", mapID = 1161, x = 0.768, y = 0.138, faction = "Alliance", types = { general = true } }

A{ name = "Innkeeper", mapID = 1165, x = 0.524, y = 0.848, faction = "Horde", types = { innkeeper = true, food = true }, note = "The Great Seal area" }
A{ name = "Repair", mapID = 1165, x = 0.512, y = 0.862, faction = "Horde", types = { repair = true } }
A{ name = "Reagents", mapID = 1165, x = 0.498, y = 0.854, faction = "Horde", types = { reagents = true } }
A{ name = "Barber Shop", mapID = 1165, x = 0.562, y = 0.882, faction = "Horde", types = { barber = true } }
A{ name = "Stable Master", mapID = 1165, x = 0.482, y = 0.878, faction = "Horde", types = { stable = true } }

---------------------------------------------------------------------------
-- Oribos (1670)
---------------------------------------------------------------------------
A{ name = "Innkeeper", mapID = 1670, x = 0.672, y = 0.502, faction = "Neutral", types = { innkeeper = true, food = true } }
A{ name = "Repair", mapID = 1670, x = 0.642, y = 0.328, faction = "Neutral", types = { repair = true } }
A{ name = "Reagents", mapID = 1670, x = 0.648, y = 0.312, faction = "Neutral", types = { reagents = true } }
A{ name = "Barber Shop", mapID = 1670, x = 0.612, y = 0.482, faction = "Neutral", types = { barber = true } }
A{ name = "Stable Master", mapID = 1670, x = 0.598, y = 0.524, faction = "Neutral", types = { stable = true } }
A{ name = "Auction House", mapID = 1670, x = 0.672, y = 0.722, faction = "Neutral", types = { general = true } }
A{ name = "Bank", mapID = 1670, x = 0.652, y = 0.268, faction = "Neutral", types = { general = true } }
A{ name = "Transmogrifier", mapID = 1670, x = 0.638, y = 0.684, faction = "Neutral", types = { transmog = true } }

---------------------------------------------------------------------------
-- Valdrakken (2112)
---------------------------------------------------------------------------
A{ name = "Barber Shop", mapID = 2112, x = 0.286, y = 0.562, faction = "Neutral", types = { barber = true } }
A{ name = "Innkeeper", mapID = 2112, x = 0.472, y = 0.462, faction = "Neutral", types = { innkeeper = true, food = true } }
A{ name = "Repair Services", mapID = 2112, x = 0.368, y = 0.502, faction = "Neutral", types = { repair = true } }
A{ name = "Reagent Vendor", mapID = 2112, x = 0.372, y = 0.528, faction = "Neutral", types = { reagents = true } }
A{ name = "Dragonriding / Mount Vendor", mapID = 2112, x = 0.262, y = 0.508, faction = "Neutral", types = { mounts = true } }
A{ name = "Stable Master", mapID = 2112, x = 0.278, y = 0.492, faction = "Neutral", types = { stable = true } }
A{ name = "Auction House", mapID = 2112, x = 0.442, y = 0.598, faction = "Neutral", types = { general = true } }
A{ name = "Bank", mapID = 2112, x = 0.308, y = 0.548, faction = "Neutral", types = { general = true } }
A{ name = "Transmogrifier", mapID = 2112, x = 0.452, y = 0.512, faction = "Neutral", types = { transmog = true } }
A{ name = "Crafting Order / Profession Hub", mapID = 2112, x = 0.368, y = 0.612, faction = "Neutral", types = { profession = true } }

---------------------------------------------------------------------------
-- Dornogal (2339) — The War Within
---------------------------------------------------------------------------
A{ name = "Barber Shop", mapID = 2339, x = 0.522, y = 0.468, faction = "Neutral", types = { barber = true } }
A{ name = "Innkeeper", mapID = 2339, x = 0.448, y = 0.512, faction = "Neutral", types = { innkeeper = true, food = true } }
A{ name = "Repair Services", mapID = 2339, x = 0.482, y = 0.492, faction = "Neutral", types = { repair = true } }
A{ name = "Reagent Vendor", mapID = 2339, x = 0.496, y = 0.504, faction = "Neutral", types = { reagents = true } }
A{ name = "General Goods", mapID = 2339, x = 0.508, y = 0.486, faction = "Neutral", types = { general = true } }
A{ name = "Stable Master", mapID = 2339, x = 0.534, y = 0.452, faction = "Neutral", types = { stable = true } }
A{ name = "Auction House", mapID = 2339, x = 0.562, y = 0.502, faction = "Neutral", types = { general = true } }
A{ name = "Bank", mapID = 2339, x = 0.528, y = 0.528, faction = "Neutral", types = { general = true } }
A{ name = "Transmogrifier", mapID = 2339, x = 0.548, y = 0.478, faction = "Neutral", types = { transmog = true } }
A{ name = "Profession Hub", mapID = 2339, x = 0.472, y = 0.538, faction = "Neutral", types = { profession = true } }

---------------------------------------------------------------------------
-- Faction examples (Eastern Plaguelands / classic hubs)
---------------------------------------------------------------------------
A{ name = "Quartermaster Miranda Breechlock", npcID = 11536, mapID = 23, x = 0.756, y = 0.542, faction = "Neutral", types = { faction = true }, note = "Argent Dawn — Eastern Plaguelands" }
