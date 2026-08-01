local _, ns = ...
local A = ns.AddSeed

-- Coords are 0-1. Sourced from community vendor DBs / in-game map knowledge.
-- Prefer learning for contested/moved NPCs after city redesigns.

---------------------------------------------------------------------------
-- Stormwind City (84)
---------------------------------------------------------------------------
A{ name = "Barber Shop", mapID = 84, x = 0.618, y = 0.652, faction = "Alliance", types = { barber = true }, note = "Trade District" }
A{ name = "Innkeeper Allison", npcID = 6740, mapID = 84, x = 0.606, y = 0.751, faction = "Alliance", types = { innkeeper = true, food = true } }
A{ name = "Thurman Mullby", npcID = 1285, mapID = 84, x = 0.644, y = 0.715, faction = "Alliance", types = { general = true } }
A{ name = "Edna Mullby", npcID = 1286, mapID = 84, x = 0.647, y = 0.712, faction = "Alliance", types = { general = true } }
A{ name = "Gunther Weller", npcID = 1289, mapID = 84, x = 0.642, y = 0.688, faction = "Alliance", types = { repair = true } }
A{ name = "Marda Weller", npcID = 1287, mapID = 84, x = 0.572, y = 0.570, faction = "Alliance", types = { repair = true } }
A{ name = "Keldric Boucher", npcID = 1257, mapID = 84, x = 0.628, y = 0.716, faction = "Alliance", types = { reagents = true } }
A{ name = "Kyra Boucher", npcID = 1275, mapID = 84, x = 0.642, y = 0.732, faction = "Alliance", types = { reagents = true } }
A{ name = "Reese Langston", npcID = 1327, mapID = 84, x = 0.764, y = 0.536, faction = "Alliance", types = { food = true } }
A{ name = "Erika Tate", npcID = 5483, mapID = 84, x = 0.776, y = 0.530, faction = "Alliance", types = { food = true, profession = true }, note = "Cooking supplies" }
A{ name = "Catherine Leland", npcID = 5494, mapID = 84, x = 0.552, y = 0.694, faction = "Alliance", types = { food = true }, note = "Fishing supplies" }
A{ name = "Rachelle Byzanti", mapID = 84, x = 0.642, y = 0.722, faction = "Alliance", types = { poison = true } }
A{ name = "Jenova Stoneshield", npcID = 11069, mapID = 84, x = 0.712, y = 0.622, faction = "Alliance", types = { stable = true } }
A{ name = "Unger Statforth", npcID = 11068, mapID = 84, x = 0.772, y = 0.668, faction = "Alliance", types = { mounts = true } }
A{ name = "Randal Hunter", npcID = 4732, mapID = 84, x = 0.774, y = 0.676, faction = "Alliance", types = { mounts = true } }
A{ name = "Maria Lumere", npcID = 1313, mapID = 84, x = 0.558, y = 0.854, faction = "Alliance", types = { reagents = true, profession = true }, note = "Mage Quarter reagents" }
A{ name = "Charys Yserian", npcID = 1307, mapID = 84, x = 0.324, y = 0.800, faction = "Alliance", types = { reagents = true } }
A{ name = "Adair Gilroy", npcID = 1316, mapID = 84, x = 0.416, y = 0.652, faction = "Alliance", types = { profession = true }, note = "Enchanting supplies" }
A{ name = "Jessara Cordell", npcID = 1318, mapID = 84, x = 0.529, y = 0.743, faction = "Alliance", types = { profession = true } }
A{ name = "Duncan Cullen", npcID = 1314, mapID = 84, x = 0.644, y = 0.684, faction = "Alliance", types = { repair = true } }
A{ name = "Billibub Cogspinner", npcID = 5519, mapID = 84, x = 0.630, y = 0.316, faction = "Alliance", types = { profession = true }, note = "Engineering supplies" }
A{ name = "Auctioneer", mapID = 84, x = 0.612, y = 0.704, faction = "Alliance", types = { general = true }, note = "AH — Trade District" }
A{ name = "Bank of Stormwind", mapID = 84, x = 0.628, y = 0.780, faction = "Alliance", types = { banker = true }, note = "Trade District bank" }

---------------------------------------------------------------------------
-- Orgrimmar (85)
---------------------------------------------------------------------------
A{ name = "Barber Shop", mapID = 85, x = 0.402, y = 0.606, faction = "Horde", types = { barber = true }, note = "The Drag" }
A{ name = "Innkeeper Gryshka", npcID = 6929, mapID = 85, x = 0.536, y = 0.787, faction = "Horde", types = { innkeeper = true, food = true } }
A{ name = "Koma", npcID = 3362, mapID = 85, x = 0.468, y = 0.732, faction = "Horde", types = { general = true } }
A{ name = "Soran", npcID = 3320, mapID = 85, x = 0.462, y = 0.746, faction = "Horde", types = { repair = true } }
A{ name = "Horthus", npcID = 3323, mapID = 85, x = 0.458, y = 0.456, faction = "Horde", types = { reagents = true } }
A{ name = "Hagrus", npcID = 3335, mapID = 85, x = 0.460, y = 0.459, faction = "Horde", types = { reagents = true } }
A{ name = "Asoran", npcID = 3350, mapID = 85, x = 0.464, y = 0.458, faction = "Horde", types = { reagents = true } }
A{ name = "Xon'cha", npcID = 9988, mapID = 85, x = 0.612, y = 0.348, faction = "Horde", types = { mounts = true, stable = true } }
A{ name = "Kuris", mapID = 85, x = 0.622, y = 0.352, faction = "Horde", types = { stable = true } }
A{ name = "Shankys", npcID = 3333, mapID = 85, x = 0.667, y = 0.419, faction = "Horde", types = { food = true }, note = "Fishing supplies" }
A{ name = "Xen'to", npcID = 3400, mapID = 85, x = 0.326, y = 0.686, faction = "Horde", types = { food = true, profession = true }, note = "Cooking supplies" }
A{ name = "Kor'geld", npcID = 3348, mapID = 85, x = 0.552, y = 0.458, faction = "Horde", types = { profession = true }, note = "Alchemy supplies" }
A{ name = "Kithas", npcID = 3346, mapID = 85, x = 0.537, y = 0.380, faction = "Horde", types = { profession = true }, note = "Enchanting supplies" }
A{ name = "Borya", npcID = 3364, mapID = 85, x = 0.630, y = 0.512, faction = "Horde", types = { profession = true }, note = "Tailoring supplies" }
A{ name = "Tamar", npcID = 3366, mapID = 85, x = 0.603, y = 0.543, faction = "Horde", types = { profession = true }, note = "Leatherworking supplies" }
A{ name = "Felika", npcID = 3367, mapID = 85, x = 0.605, y = 0.507, faction = "Horde", types = { general = true } }
A{ name = "Sovik", npcID = 3413, mapID = 85, x = 0.756, y = 0.252, faction = "Horde", types = { profession = true }, note = "Engineering supplies" }
A{ name = "Sumi", npcID = 3356, mapID = 85, x = 0.758, y = 0.352, faction = "Horde", types = { repair = true, profession = true }, note = "Blacksmithing supplies" }
A{ name = "Tor'phan", npcID = 3315, mapID = 85, x = 0.626, y = 0.506, faction = "Horde", types = { repair = true } }
A{ name = "Handor", npcID = 3316, mapID = 85, x = 0.628, y = 0.448, faction = "Horde", types = { repair = true } }
A{ name = "Jin'Sora", npcID = 3410, mapID = 85, x = 0.778, y = 0.386, faction = "Horde", types = { repair = true } }
A{ name = "Rekkul", npcID = 3334, mapID = 85, x = 0.462, y = 0.502, faction = "Horde", types = { poison = true } }
A{ name = "Auctioneer", mapID = 85, x = 0.540, y = 0.735, faction = "Horde", types = { general = true }, note = "AH — Valley of Strength" }
A{ name = "Bank of Orgrimmar", mapID = 85, x = 0.488, y = 0.842, faction = "Horde", types = { banker = true } }

---------------------------------------------------------------------------
-- Ironforge (87)
---------------------------------------------------------------------------
A{ name = "Barber Shop", mapID = 87, x = 0.236, y = 0.592, faction = "Alliance", types = { barber = true } }
A{ name = "Innkeeper Firebrew", npcID = 5111, mapID = 87, x = 0.181, y = 0.515, faction = "Alliance", types = { innkeeper = true, food = true } }
A{ name = "Bryllia Ironbrand", npcID = 5102, mapID = 87, x = 0.224, y = 0.164, faction = "Alliance", types = { general = true } }
A{ name = "Dolman Steelfury", npcID = 5103, mapID = 87, x = 0.366, y = 0.842, faction = "Alliance", types = { repair = true } }
A{ name = "Barim Jurgenstaad", npcID = 5110, mapID = 87, x = 0.192, y = 0.561, faction = "Alliance", types = { reagents = true } }
A{ name = "Ginny Longberry", npcID = 5151, mapID = 87, x = 0.312, y = 0.276, faction = "Alliance", types = { reagents = true } }
A{ name = "Gearcutter Cogspinner", npcID = 5175, mapID = 87, x = 0.678, y = 0.434, faction = "Alliance", types = { profession = true }, note = "Engineering" }
A{ name = "Tilli Thistlefuzz", npcID = 5158, mapID = 87, x = 0.606, y = 0.442, faction = "Alliance", types = { profession = true }, note = "Enchanting" }
A{ name = "Bombus Finespindle", npcID = 5128, mapID = 87, x = 0.394, y = 0.324, faction = "Alliance", types = { profession = true }, note = "Leatherworking" }
A{ name = "Poranna Snowbraid", npcID = 5154, mapID = 87, x = 0.432, y = 0.288, faction = "Alliance", types = { profession = true }, note = "Tailoring" }
A{ name = "Ulthaan", npcID = 5122, mapID = 87, x = 0.702, y = 0.482, faction = "Alliance", types = { mounts = true, stable = true } }
A{ name = "Auctioneer", mapID = 87, x = 0.252, y = 0.742, faction = "Alliance", types = { general = true } }
A{ name = "Ironforge Bank", mapID = 87, x = 0.354, y = 0.604, faction = "Alliance", types = { banker = true } }

---------------------------------------------------------------------------
-- Thunder Bluff (88)
---------------------------------------------------------------------------
A{ name = "Barber Shop", mapID = 88, x = 0.408, y = 0.552, faction = "Horde", types = { barber = true } }
A{ name = "Innkeeper Pala", npcID = 6746, mapID = 88, x = 0.458, y = 0.644, faction = "Horde", types = { innkeeper = true, food = true } }
A{ name = "Kul Inkspiller", npcID = 8361, mapID = 88, x = 0.412, y = 0.532, faction = "Horde", types = { reagents = true } }
A{ name = "Tagain", npcID = 3019, mapID = 88, x = 0.452, y = 0.556, faction = "Horde", types = { repair = true } }
A{ name = "Kuruk", npcID = 3015, mapID = 88, x = 0.472, y = 0.546, faction = "Horde", types = { general = true } }
A{ name = "Hewa", npcID = 3010, mapID = 88, x = 0.454, y = 0.422, faction = "Horde", types = { reagents = true } }
A{ name = "Karm Ironquill", npcID = 3021, mapID = 88, x = 0.408, y = 0.624, faction = "Horde", types = { profession = true } }
A{ name = "Seikwa", npcID = 10054, mapID = 88, x = 0.452, y = 0.604, faction = "Horde", types = { stable = true, mounts = true } }
A{ name = "Auctioneer", mapID = 88, x = 0.402, y = 0.628, faction = "Horde", types = { general = true } }

---------------------------------------------------------------------------
-- Undercity (90)
---------------------------------------------------------------------------
A{ name = "Innkeeper Norman", npcID = 6741, mapID = 90, x = 0.677, y = 0.379, faction = "Horde", types = { innkeeper = true, food = true } }
A{ name = "Daniel Bartlett", npcID = 4561, mapID = 90, x = 0.642, y = 0.372, faction = "Horde", types = { general = true } }
A{ name = "Salazar Bloch", npcID = 4562, mapID = 90, x = 0.698, y = 0.392, faction = "Horde", types = { reagents = true } }
A{ name = "Eleanor Rusk", npcID = 4555, mapID = 90, x = 0.688, y = 0.384, faction = "Horde", types = { food = true } }
A{ name = "Gordon Wendham", npcID = 4556, mapID = 90, x = 0.614, y = 0.414, faction = "Horde", types = { repair = true } }
A{ name = "Louis Warren", npcID = 4557, mapID = 90, x = 0.622, y = 0.412, faction = "Horde", types = { repair = true } }
A{ name = "Anya Maulray", npcID = 10053, mapID = 90, x = 0.672, y = 0.378, faction = "Horde", types = { stable = true } }
A{ name = "Barber Shop", mapID = 90, x = 0.704, y = 0.462, faction = "Horde", types = { barber = true } }

---------------------------------------------------------------------------
-- Darnassus (89) — may be limited post-BFA; kept for older content
---------------------------------------------------------------------------
A{ name = "Innkeeper Saelienne", npcID = 6735, mapID = 89, x = 0.626, y = 0.326, faction = "Alliance", types = { innkeeper = true, food = true } }
A{ name = "Ellandrieth", npcID = 4164, mapID = 89, x = 0.604, y = 0.372, faction = "Alliance", types = { general = true } }
A{ name = "Fyldan", npcID = 4230, mapID = 89, x = 0.482, y = 0.220, faction = "Alliance", types = { repair = true } }
A{ name = "Cyroen", npcID = 4167, mapID = 89, x = 0.478, y = 0.336, faction = "Alliance", types = { reagents = true } }
A{ name = "Jartsam", npcID = 4753, mapID = 89, x = 0.384, y = 0.156, faction = "Alliance", types = { mounts = true, stable = true } }

---------------------------------------------------------------------------
-- The Exodar (103)
---------------------------------------------------------------------------
A{ name = "Innkeeper Edul", npcID = 16739, mapID = 103, x = 0.595, y = 0.184, faction = "Alliance", types = { innkeeper = true, food = true } }
A{ name = "Onnis", npcID = 16732, mapID = 103, x = 0.608, y = 0.284, faction = "Alliance", types = { general = true } }
A{ name = "Nurgazz", npcID = 16718, mapID = 103, x = 0.532, y = 0.412, faction = "Alliance", types = { repair = true } }
A{ name = "Musal", npcID = 16705, mapID = 103, x = 0.452, y = 0.248, faction = "Alliance", types = { reagents = true } }
A{ name = "Aalun", npcID = 20914, mapID = 103, x = 0.812, y = 0.524, faction = "Alliance", types = { mounts = true, stable = true } }
A{ name = "Barber Shop", mapID = 103, x = 0.412, y = 0.392, faction = "Alliance", types = { barber = true } }

---------------------------------------------------------------------------
-- Silvermoon City (110)
---------------------------------------------------------------------------
A{ name = "Innkeeper Jovia", npcID = 17630, mapID = 110, x = 0.794, y = 0.582, faction = "Horde", types = { innkeeper = true, food = true } }
A{ name = "Quelis", npcID = 16664, mapID = 110, x = 0.694, y = 0.668, faction = "Horde", types = { reagents = true } }
A{ name = "Celana", npcID = 16646, mapID = 110, x = 0.898, y = 0.378, faction = "Horde", types = { repair = true } }
A{ name = "Stable Master", mapID = 110, x = 0.838, y = 0.282, faction = "Horde", types = { stable = true, mounts = true }, note = "Farstriders' Square" }
A{ name = "Barber Shop", mapID = 110, x = 0.582, y = 0.642, faction = "Horde", types = { barber = true } }
A{ name = "Gelanthis", npcID = 16624, mapID = 110, x = 0.908, y = 0.734, faction = "Horde", types = { profession = true } }
A{ name = "Lyna", npcID = 16635, mapID = 110, x = 0.694, y = 0.244, faction = "Horde", types = { profession = true }, note = "Enchanting" }
A{ name = "Zaralda", npcID = 16689, mapID = 110, x = 0.844, y = 0.802, faction = "Horde", types = { profession = true }, note = "Leatherworking" }
A{ name = "Deynna", npcID = 16638, mapID = 110, x = 0.556, y = 0.510, faction = "Horde", types = { profession = true }, note = "Tailoring" }
A{ name = "Auctioneer", mapID = 110, x = 0.924, y = 0.582, faction = "Horde", types = { general = true } }
A{ name = "Bank", mapID = 110, x = 0.900, y = 0.432, faction = "Horde", types = { banker = true } }
