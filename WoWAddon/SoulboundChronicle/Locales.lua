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
	},

	cls = {
		elite = "an elite",
		rare = "a rare",
		rareelite = "a rare elite",
		worldboss = "a world boss",
	},
	env = {
		Falling = "a long fall",
		Drowning = "the deep water",
		Fatigue = "exhaustion",
		Fire = "fire",
		Lava = "lava",
		Slime = "slime",
	},
	level = " (level {lvl})",
	time = { h = "{h}h {m}m", m = "{m}m" },
}

function ns.L()
	return L
end
