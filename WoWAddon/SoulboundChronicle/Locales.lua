local _, ns = ...

-- All player-facing text. Templates use {placeholders}. Lists hold
-- variants; one is picked per item or entry from a stable seed, so a name
-- or story never changes by itself.
local L = {
	ui = {
		title = "Soulbound Chronicle",
		chronicle = "Chronicle",
		items = "Items",
		export = "Export",
		exportHint = "Ctrl+A, Ctrl+C to copy.",
		noEntries = "Your chronicle is still empty. Go and make some history.",
		noItems = "No remembered items in your bags or on your body.",
		equipped = "Equipped",
		bags = "Bags",
		bank = "Bank",
		help = {
			"/chronicle - open or close the chronicle",
			"/chronicle items - show your items and their stories",
			"/chronicle name <new name> - rename the item you last hovered",
			"/chronicle name reset - give it back its earned name",
			"/chronicle autonames - turn automatic names on or off",
			"/chronicle rares - turn automatic names for blue and purple items on or off",
			"/chronicle others - show or hide names from other players",
			"/chronicle export - copy the chronicle as text",
			"/chronicle tooltip - turn item stories in tooltips on or off",
		},
		tooltipOn = "Item stories in tooltips: on.",
		tooltipOff = "Item stories in tooltips: off.",
		autonamesOn = "Automatic names: on.",
		autonamesOff = "Automatic names: off.",
		raresOn = "Automatic names for blue and purple items: on.",
		raresOff = "Automatic names for blue and purple items: off.",
		othersOn = "Names from other players: shown.",
		othersOff = "Names from other players: hidden.",
		noHovered = "Hover over one of your items first, then try again.",
		renamePrompt = "New name for %s:",
		renamed = "%s shall henceforth be known as %s.",
		renameReset = "%s has its old name back.",
		bindingHeader = "Soulbound Chronicle",
		bindingRename = "Rename hovered item",
		settings = "Settings",
		search = "Search",
		subtitle = "{player} · Level {level}",
		entries = "{count} entries",
		entriesOne = "1 entry",
		showing = "Showing {shown} of {count}",
		itemCount = "{count} remembered items",
		itemCountOne = "1 remembered item",
		renameHint = "Right-click an item to rename it.",
		noMatches = "Nothing matches your search.",
		options = {
			{ key = "autonames", label = "Automatic names", text = "Give your gear new names based on its type, quality and deeds." },
			{ key = "rares", label = "Names for blue and purple items", text = "Also rename rare and epic gear. Turn off to keep their real names." },
			{ key = "others", label = "Names from other players", text = "Show the names other players with the addon gave their items." },
			{ key = "tooltip", label = "Stories in tooltips", text = "Show where an item came from and what it has been through." },
			{ key = "identify", label = "Unidentified items", text = "Some looted green, blue and purple items arrive unidentified. Take them to any innkeeper to learn their name and legend." },
		},
		unknownYet = "You don't know what it is yet. Take it to an innkeeper first.",
		identifiedBy = "Identified by %s",
		thanks = "Thank you",
		andMore = "...and {count} more. Your chronicle has them all.",
	},

	origin = {
		loot = {
			"Taken from the remains of {src}{lvl} in {place}.",
			"Pried from the cold hands of {src}{lvl} in {place}.",
			"Spoils of the fight with {src}{lvl} in {place}.",
		},
		fish = {
			"Fished out of the waters of {place}.",
			"Pulled from the depths of {place} on a fishing line.",
		},
		container = {
			"Found in {place}.",
			"Discovered among forgotten things in {place}.",
		},
		quest = {
			"Reward for \"{src}\".",
			"Given in thanks for \"{src}\".",
		},
		vendor = {
			"Bought from {src} in {place}.",
			"Paid for in honest coin to {src} in {place}.",
		},
		craft = {
			"Made by your own hands in {place}.",
			"Crafted in {place}.",
		},
		trade = {
			"Received in a trade with {src}.",
			"Changed hands with {src} in {place}.",
		},
		mail = {
			"Arrived by mail in {place}.",
		},
		before = {
			"Its origin is lost. It was with you before the chronicle began.",
		},
		found = {
			"Turned up in your bags in {place}.",
		},
	},
	when = "{date}, at level {plvl}.",
	wornSince = "Worn since level {lvl}.",
	wornStats = "Levels: {levels} · Worn: {time} · Kills: {kills} · Deaths: {deaths}",
	deed = "Was there when you defeated {name}.",

	names = {
		originally = "Originally: {name}",
		why = {
			custom = "Named by you.",
			remote = "Named by {owner}.",
			bane = "Earned by slaying {name}.",
			slayer = "Earned after {count} kills ({ctype}).",
			faithful = "Earned by {levels} levels at your side.",
			cursed = "Earned by {deaths} deaths in its company.",
		},

		-- Earned names combine: [prefixes] [Title's] noun[, Bane of X]
		-- e.g. "Old Faithful Beastslayer's Sword, Bane of Mother Fang".
		prefix = { cursed = "Cursed", faithful = "Old Faithful" },
		slayerTitle = {
			Beast = "Beastslayer", Humanoid = "Manslayer", Undead = "Gravebreaker",
			Demon = "Demonbane", Elemental = "Stormbreaker", Dragonkin = "Dragonslayer",
			Giant = "Giantfeller", Mechanical = "Gearbreaker", Critter = "Bunny Menace",
			default = "Slayer",
		},
		baneSuffix = "Bane of {name}",
		baneAlone = { "{name}'s Bane", "Bane of {name}" },

		-- Generated names, by quality.
		junk = { "{junk} {noun}" },
		plain = { "{plain} {noun}", "{noun} of {zone}", "{person}'s {noun}" },
		themed = { "{themeAdj} {noun}", "{noun} of the {themeNoun}", "{person}'s {themeAdj} {noun}" },
		rare = { "{compound}", "{themeAdj} {noun}", "{noun} of the {themeNoun}" },
		rarePlain = { "{compound}", "{plain} {noun}", "{noun} of {zone}" },
		epic = { "{compound}", "{compound}, {epithet}" },

		junkAdj = {
			"Rusty", "Wobbly", "Disappointing", "Questionable", "Second-Hand", "Smelly",
			"Slightly Haunted", "Borrowed", "Sad", "Crusty", "Damp", "Forgettable",
		},
		plainAdj = {
			"Trusty", "Humble", "Honest", "Sturdy", "Faithful", "Plain",
			"Stubborn", "Homely", "Patient", "Lucky",
		},
		persons = { "Grimtusk", "Old Bessie", "Barnabus", "Ozzle", "Mirelle", "Torvald", "Fenwick", "Hilda", "Gus", "Pip" },
		themes = {
			strength = { adj = { "Mighty", "Iron", "Thundering" }, noun = { "Mountain", "Bear", "Ox" } },
			agility = { adj = { "Swift", "Shadow", "Whispering" }, noun = { "Fox", "Shadow", "Wind" } },
			stamina = { adj = { "Stalwart", "Stone", "Enduring" }, noun = { "Oak", "Boulder", "Tortoise" } },
			intellect = { adj = { "Arcane", "Starlit", "Learned" }, noun = { "Stars", "Scholar", "Owl" } },
			spirit = { adj = { "Serene", "Dreaming", "Moonlit" }, noun = { "Moon", "Dreamer", "Stillwater" } },
		},
		-- Compound names like "Stormfang" or "Dawnward".
		compoundStart = {
			"Dawn", "Doom", "Storm", "Grim", "Soul", "Night", "Frost",
			"Blood", "Star", "Thunder", "Shadow", "Ember", "Wraith", "Sun",
		},
		compoundEnd = {
			weapon = { "fang", "reaver", "bringer", "song", "cleaver", "bite", "fall", "edge" },
			armor = { "guard", "ward", "mantle", "hide", "shroud", "heart", "veil", "bulwark" },
		},
		epithets = {
			"the Unbroken", "Last Light of the Vale", "Herald of Storms", "the Patient",
			"Breaker of Oaths", "the Whispering Dark", "Song of the Deep", "the Final Word",
		},
		nouns = {
			sword = { "Blade", "Edge", "Sword", "Pigsticker" },
			axe = { "Axe", "Cleaver", "Chopper" },
			mace = { "Mace", "Club", "Knocker" },
			dagger = { "Dagger", "Knife", "Shiv" },
			fist = { "Knuckles", "Fist" },
			polearm = { "Spear", "Pike", "Halberd" },
			staff = { "Staff", "Stick", "Rod" },
			bow = { "Bow", "Longbow", "Twanger" },
			gun = { "Boomstick", "Rifle", "Blunderbuss" },
			crossbow = { "Crossbow", "Bolt-Thrower" },
			wand = { "Wand", "Twig", "Spark" },
			thrown = { "Throwing Knives", "Chuckers" },
			fishing = { "Fishing Pole", "Rod" },
			head = { "Helm", "Hat", "Cap" },
			neck = { "Pendant", "Choker", "Amulet" },
			shoulder = { "Pauldrons", "Shoulderpads", "Mantle" },
			chest = { "Tunic", "Vest", "Robe", "Jerkin" },
			waist = { "Belt", "Girdle", "Sash" },
			legs = { "Leggings", "Trousers", "Pants" },
			feet = { "Boots", "Shoes", "Sandals" },
			wrist = { "Bracers", "Cuffs", "Wristguards" },
			hands = { "Gloves", "Gauntlets", "Mitts" },
			finger = { "Ring", "Band", "Loop" },
			trinket = { "Charm", "Trinket", "Lucky Thing" },
			back = { "Cloak", "Cape", "Shawl" },
			shield = { "Shield", "Buckler", "Door" },
			holdable = { "Orb", "Tome", "Lantern" },
			shirt = { "Shirt", "Tunic" },
			tabard = { "Tabard", "Banner" },
			generic = { "Thing", "Gear" },
		},
	},

	journal = {
		begin = "The chronicle of {player} begins. Level {l}, in {place}.",
		level = {
			"Reached level {l}.",
			"Grew stronger: level {l}.",
			"Level {l}. The road goes on.",
		},
		zone = {
			"Set foot in {zone} for the first time.",
			"Arrived in {zone}.",
		},
		instance = {
			"Entered {zone}.",
			"Ventured into {zone}.",
		},
		kill = {
			"Slew {name}{lvl}, {cls}, in {place}.",
			"Brought down {name}{lvl}, {cls}, in {place}.",
		},
		boss = {
			"Defeated {name} in {zone}.",
			"{name} has fallen. {zone} will remember it.",
		},
		death = {
			"Fell to {killer} in {place}.",
			"Was slain by {killer} in {place}.",
		},
		deathUnknown = "Died in {place}.",
		neardeath = {
			"Escaped death by a hair in {place}, with {pct}% health left.",
			"Nearly died in {place}. {pct}% health. Too close.",
		},
		item = {
			"Acquired {link}. {origin}",
		},
		renamed = "{old} shall henceforth be known as {new}.",
		found = {
			"Found an unidentified {noun} in {place}. Nobody knows what it is yet.",
			"Found an unidentified {noun} in {place}.",
		},
		identified = {
			"{npc} identified {new} in {place}.",
			"{npc} recognized {new} at once.",
		},
	},

	identify = {
		name = "Unidentified {noun}",
		hint = "An innkeeper might know what it is.",
		identifiedBy = "Identified by {npc}, {date}.",
		mystery = {
			weapon = {
				"Strange runes run along it. Someone learned might read them.",
				"Its balance is odd, as if it was made for someone else.",
				"Old notches cover it. It has seen more fights than you.",
			},
			armor = {
				"Faded markings cover it, half worn away.",
				"It smells of old smoke and older battles.",
				"A crest has been scratched off it, on purpose.",
			},
			jewelry = {
				"It is warm to the touch, though it should not be.",
				"Something is engraved on the inside, too small to read.",
			},
		},
		-- What the innkeeper says when they recognise it.
		quote = {
			"{npc} squints at it for a long moment. \"Well, I'll be. That's {name}.\"",
			"{npc} wipes it clean with a bar towel. \"{name}. My grandfather told stories about this one.\"",
			"{npc} sets down a mug and leans closer. \"Ah. {name}. Keep it close.\"",
			"{npc} lowers their voice. \"{name}. Where did you find that?\"",
		},
		-- Legends are built from three parts: origin, history and fate.
		origin = {
			"Forged in {forge} for {owner}.",
			"Made in {forge} for {owner}.",
			"Crafted long ago in {forge}, by hands no one remembers.",
		},
		history = {
			"Its owner fell at {fall}, and it was lost for years.",
			"It changed hands {count} times before it found you.",
			"It was once lost in a card game in Booty Bay.",
			"It spent a decade at the bottom of a lake.",
			"It was carried to {fall} and back again.",
			"It was stolen twice, and returned once.",
		},
		fate = {
			"Now it is yours.",
			"Some say it brings luck. Others say the opposite.",
			"It seems glad to be carried again.",
			"It hums faintly when danger is near.",
			"Its last owner wanted it buried with them. Clearly, that did not happen.",
		},
		forges = {
			"the foothills of Dun Morogh", "the fires of Blackrock Mountain", "a forgotten workshop in Stormwind",
			"the elven halls of Darnassus", "a troll village in Stranglethorn", "the ruins of Lordaeron",
			"a smithy in Lakeshire", "the depths of Gnomeregan", "the high mesas of Thunder Bluff",
			"the deserts of Tanaris", "the shadow of Ironforge", "a camp in the Barrens",
		},
		owners = {
			"a captain of the Ironforge guard", "a Defias smuggler", "a priestess of Elune",
			"a wandering tauren hunter", "a goblin merchant prince", "a Scarlet Crusader",
			"a dwarven explorer", "an orcish grunt", "a forgotten king's bodyguard",
			"a gnomish inventor", "a Forsaken apothecary", "a night elf sentinel",
		},
		falls = {
			"Thelsamar", "the Dark Portal", "Hillsbrad", "Darkshore", "Stratholme",
			"Southshore", "the Crossroads", "Sentinel Hill", "Tarren Mill", "Astranaar",
		},
		nouns = {
			sword = "Sword", axe = "Axe", mace = "Mace", dagger = "Dagger", fist = "Fist Weapon",
			polearm = "Polearm", staff = "Staff", bow = "Bow", gun = "Gun", crossbow = "Crossbow",
			wand = "Wand", thrown = "Throwing Weapon", fishing = "Fishing Pole", head = "Helm",
			neck = "Necklace", shoulder = "Shoulderguards", chest = "Chestpiece", waist = "Belt",
			legs = "Leggings", feet = "Boots", wrist = "Bracers", hands = "Gloves", finger = "Ring",
			trinket = "Trinket", back = "Cloak", shield = "Shield", holdable = "Off-hand",
			shirt = "Shirt", tabard = "Tabard", generic = "Item",
		},
	},

	cls = {
		elite = "an elite",
		rare = "a rare",
		rareelite = "a rare elite",
		worldboss = "a world boss",
	},
	level = " (level {lvl})",
	time = { h = "{h}h {m}m", m = "{m}m" },
}

function ns.L()
	return L
end
