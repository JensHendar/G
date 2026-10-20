local _, ns = ...

-- Templates use {placeholders}. Lists hold variants; one is picked per
-- item or entry from a stable seed, so a name or story never changes by
-- itself.
--
-- Swedish names avoid grammatical gender by only using two shapes:
-- weak adjective + definite noun ("Rostiga Svärdet") and
-- genitive + indefinite noun ("Bergets Klinga"). Each Swedish noun is
-- therefore { indefinite, definite }.
local enUS = {
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
			"/chronicle others - show or hide names from other players",
			"/chronicle export - copy the chronicle as text",
			"/chronicle lang en/sv - change language",
			"/chronicle tooltip - turn item stories in tooltips on or off",
		},
		langSet = "Language set to English.",
		tooltipOn = "Item stories in tooltips: on.",
		tooltipOff = "Item stories in tooltips: off.",
		autonamesOn = "Automatic names: on.",
		autonamesOff = "Automatic names: off.",
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
		-- Earned names. {noun} is the item's noun.
		bane = { "{name}'s Bane", "Bane of {name}" },
		slayer = "{title}'s {noun}",
		slayerTitle = {
			Beast = "Beastslayer", Humanoid = "Manslayer", Undead = "Gravebreaker",
			Demon = "Demonbane", Elemental = "Stormbreaker", Dragonkin = "Dragonslayer",
			Giant = "Giantfeller", Mechanical = "Gearbreaker", Critter = "Bunny Menace",
			default = "Slayer",
		},
		faithful = { "Faithful Old {noun}", "Old Reliable" },
		cursed = { "The Cursed {noun}", "The Unlucky {noun}" },

		-- Generated names.
		junk = { "{junk} {noun}" },
		plain = { "{plain} {noun}", "{noun} of {zone}", "{person}'s {noun}" },
		themed = { "{themeAdj} {noun}", "{noun} of the {themeNoun}", "{person}'s {themeAdj} {noun}" },

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

local svSE = {
	ui = {
		title = "Soulbound Chronicle",
		chronicle = "Krönika",
		items = "Föremål",
		export = "Exportera",
		exportHint = "Ctrl+A, Ctrl+C för att kopiera.",
		noEntries = "Din krönika är fortfarande tom. Ut och skriv historia.",
		noItems = "Inga ihågkomna föremål i väskorna eller på kroppen.",
		equipped = "Utrustat",
		bags = "Väskor",
		bank = "Bank",
		help = {
			"/chronicle - öppna eller stäng krönikan",
			"/chronicle items - visa dina föremål och deras historier",
			"/chronicle name <nytt namn> - döp om föremålet du senast hovrade",
			"/chronicle name reset - ge det tillbaka sitt förtjänade namn",
			"/chronicle autonames - slå på eller av automatiska namn",
			"/chronicle others - visa eller dölj andra spelares namn",
			"/chronicle export - kopiera krönikan som text",
			"/chronicle lang en/sv - byt språk",
			"/chronicle tooltip - slå på eller av historier i tooltips",
		},
		langSet = "Språket är nu svenska.",
		tooltipOn = "Föremålshistorier i tooltips: på.",
		tooltipOff = "Föremålshistorier i tooltips: av.",
		autonamesOn = "Automatiska namn: på.",
		autonamesOff = "Automatiska namn: av.",
		othersOn = "Andra spelares namn: visas.",
		othersOff = "Andra spelares namn: dolda.",
		noHovered = "Hovra över ett av dina föremål först och försök igen.",
		renamePrompt = "Nytt namn för %s:",
		renamed = "%s ska hädanefter kallas %s.",
		renameReset = "%s har fått tillbaka sitt gamla namn.",
		bindingRename = "Döp om hovrat föremål",
	},

	origin = {
		loot = {
			"Taget från kvarlevorna av {src}{lvl} i {place}.",
			"Bänt ur de kalla händerna på {src}{lvl} i {place}.",
			"Byte från striden mot {src}{lvl} i {place}.",
		},
		fish = {
			"Fiskat ur vattnen i {place}.",
			"Draget ur djupet i {place} på en fiskelina.",
		},
		container = {
			"Hittat i {place}.",
			"Upptäckt bland bortglömda ting i {place}.",
		},
		quest = {
			"Belöning för \"{src}\".",
			"Givet som tack för \"{src}\".",
		},
		vendor = {
			"Köpt av {src} i {place}.",
			"Betalt med ärliga mynt till {src} i {place}.",
		},
		craft = {
			"Tillverkat med egna händer i {place}.",
			"Smitt och sytt i {place}.",
		},
		trade = {
			"Fått i ett byte med {src}.",
			"Bytte ägare med {src} i {place}.",
		},
		mail = {
			"Kom med posten i {place}.",
		},
		before = {
			"Ursprunget är glömt. Det fanns hos dig innan krönikan började.",
		},
		found = {
			"Dök upp i väskan i {place}.",
		},
	},
	when = "{date}, på level {plvl}.",
	wornSince = "Buret sedan level {lvl}.",
	wornStats = "Levels: {levels} · Buret: {time} · Dödade: {kills} · Dödsfall: {deaths}",
	deed = "Var med när du besegrade {name}.",

	names = {
		originally = "Egentligen: {name}",
		why = {
			custom = "Namngiven av dig.",
			remote = "Namngiven av {owner}.",
			bane = "Förtjänat genom att dräpa {name}.",
			slayer = "Förtjänat efter {count} dödade ({ctype}).",
			faithful = "Förtjänat genom {levels} levels vid din sida.",
			cursed = "Förtjänat genom {deaths} dödsfall i dess sällskap.",
		},
		bane = { "{nameGen} Fördärv", "{nameGen} Död" },
		slayer = "{title} {noun}",
		slayerTitle = {
			Beast = "Bestdräparens", Humanoid = "Mandråparens", Undead = "Gravbrytarens",
			Demon = "Demonjägarens", Elemental = "Stormbrytarens", Dragonkin = "Drakdräparens",
			Giant = "Jättefällarens", Mechanical = "Kugghjulskrossarens", Critter = "Kaninskräckens",
			default = "Dräparens",
		},
		faithful = { "Trogna Gamla {nounDef}", "Gamla Pålitliga" },
		cursed = { "Förbannade {nounDef}", "Olycksaliga {nounDef}" },

		junk = { "{junk} {nounDef}" },
		plain = { "{plain} {nounDef}", "{nounDef} från {zone}", "{personGen} {noun}" },
		themed = { "{themeAdj} {nounDef}", "{themeNoun} {noun}", "{personGen} {themeAdj} {noun}" },

		junkAdj = {
			"Rostiga", "Vingliga", "Tvivelaktiga", "Begagnade", "Illaluktande", "Lätt Hemsökta",
			"Lånade", "Ledsna", "Skorpiga", "Fuktiga", "Glömda", "Sorgliga",
		},
		plainAdj = {
			"Pålitliga", "Ödmjuka", "Ärliga", "Stadiga", "Trofasta", "Enkla",
			"Envisa", "Hemtrevliga", "Tålmodiga", "Lyckosamma",
		},
		persons = { "Grimtusk", "Gamla Bessie", "Barnabus", "Ozzle", "Mirelle", "Torvald", "Fenwick", "Hilda", "Gus", "Pip" },
		themes = {
			strength = { adj = { "Mäktiga", "Järnhårda", "Dånande" }, noun = { "Bergets", "Björnens", "Oxens" } },
			agility = { adj = { "Snabba", "Skuggiga", "Viskande" }, noun = { "Rävens", "Skuggans", "Vindens" } },
			stamina = { adj = { "Ståndaktiga", "Stenhårda", "Uthålliga" }, noun = { "Ekens", "Stenblockets", "Sköldpaddans" } },
			intellect = { adj = { "Arkana", "Stjärnklara", "Lärda" }, noun = { "Stjärnornas", "Lärlingens", "Ugglans" } },
			spirit = { adj = { "Stilla", "Drömmande", "Månbelysta" }, noun = { "Månens", "Drömmarens", "Källans" } },
		},
		nouns = {
			sword = { { "Klinga", "Klingan" }, { "Egg", "Eggen" }, { "Svärd", "Svärdet" }, { "Grisstickare", "Grisstickaren" } },
			axe = { { "Yxa", "Yxan" }, { "Klyvare", "Klyvaren" }, { "Huggare", "Huggaren" } },
			mace = { { "Klubba", "Klubban" }, { "Stridsklubba", "Stridsklubban" }, { "Knackare", "Knackaren" } },
			dagger = { { "Dolk", "Dolken" }, { "Kniv", "Kniven" }, { "Stilett", "Stiletten" } },
			fist = { { "Knogjärn", "Knogjärnet" }, { "Näve", "Näven" } },
			polearm = { { "Spjut", "Spjutet" }, { "Pik", "Piken" }, { "Hillebard", "Hillebarden" } },
			staff = { { "Stav", "Staven" }, { "Käpp", "Käppen" }, { "Påk", "Påken" } },
			bow = { { "Båge", "Bågen" }, { "Långbåge", "Långbågen" } },
			gun = { { "Bössa", "Bössan" }, { "Gevär", "Geväret" }, { "Smällare", "Smällaren" } },
			crossbow = { { "Armborst", "Armborstet" }, { "Bultkastare", "Bultkastaren" } },
			wand = { { "Trollstav", "Trollstaven" }, { "Kvist", "Kvisten" }, { "Gnista", "Gnistan" } },
			thrown = { { "Kastkniv", "Kastkniven" } },
			fishing = { { "Metspö", "Metspöet" } },
			head = { { "Hjälm", "Hjälmen" }, { "Hatt", "Hatten" }, { "Mössa", "Mössan" } },
			neck = { { "Hänge", "Hänget" }, { "Halsband", "Halsbandet" }, { "Amulett", "Amuletten" } },
			shoulder = { { "Axelskydd", "Axelskydden" }, { "Mantel", "Manteln" } },
			chest = { { "Tunika", "Tunikan" }, { "Väst", "Västen" }, { "Rock", "Rocken" } },
			waist = { { "Bälte", "Bältet" }, { "Gördel", "Gördeln" }, { "Skärp", "Skärpet" } },
			legs = { { "Byxor", "Byxorna" }, { "Benskydd", "Benskydden" } },
			feet = { { "Stövlar", "Stövlarna" }, { "Skor", "Skorna" }, { "Sandaler", "Sandalerna" } },
			wrist = { { "Armskydd", "Armskydden" }, { "Manschetter", "Manschetterna" } },
			hands = { { "Handskar", "Handskarna" }, { "Vantar", "Vantarna" } },
			finger = { { "Ring", "Ringen" }, { "Signetring", "Signetringen" } },
			trinket = { { "Berlock", "Berlocken" }, { "Talisman", "Talismanen" }, { "Lyckosak", "Lyckosaken" } },
			back = { { "Mantel", "Manteln" }, { "Kappa", "Kappan" }, { "Sjal", "Sjalen" } },
			shield = { { "Sköld", "Skölden" }, { "Bucklare", "Bucklaren" }, { "Dörr", "Dörren" } },
			holdable = { { "Klot", "Klotet" }, { "Bok", "Boken" }, { "Lykta", "Lyktan" } },
			shirt = { { "Skjorta", "Skjortan" } },
			tabard = { { "Vapenrock", "Vapenrocken" } },
			generic = { { "Grej", "Grejen" }, { "Pryl", "Prylen" } },
		},
	},

	journal = {
		begin = "Krönikan om {player} börjar. Level {l}, i {place}.",
		level = {
			"Nådde level {l}.",
			"Blev starkare: level {l}.",
			"Level {l}. Vägen fortsätter.",
		},
		zone = {
			"Satte för första gången sin fot i {zone}.",
			"Anlände till {zone}.",
		},
		instance = {
			"Gick in i {zone}.",
			"Vågade sig in i {zone}.",
		},
		kill = {
			"Dräpte {name}{lvl}, {cls}, i {place}.",
			"Fällde {name}{lvl}, {cls}, i {place}.",
		},
		boss = {
			"Besegrade {name} i {zone}.",
			"{name} har fallit. {zone} kommer att minnas det.",
		},
		death = {
			"Föll för {killer} i {place}.",
			"Dräptes av {killer} i {place}.",
		},
		deathUnknown = "Dog i {place}.",
		neardeath = {
			"Undkom döden med nöd och näppe i {place}, med {pct}% hälsa kvar.",
			"Var nära att dö i {place}. {pct}% hälsa. För nära.",
		},
		item = {
			"Fick {link}. {origin}",
		},
		renamed = "{old} ska hädanefter kallas {new}.",
	},

	cls = {
		elite = "en elit",
		rare = "en sällsynt",
		rareelite = "en sällsynt elit",
		worldboss = "en världsboss",
	},
	env = {
		Falling = "ett långt fall",
		Drowning = "det djupa vattnet",
		Fatigue = "utmattning",
		Fire = "eld",
		Lava = "lava",
		Slime = "slem",
	},
	level = " (level {lvl})",
	time = { h = "{h} h {m} min", m = "{m} min" },
}

-- Missing Swedish keys fall back to English.
local function inherit(t, base)
	for k, v in pairs(t) do
		if type(v) == "table" and type(base[k]) == "table" and #v == 0 then
			inherit(v, base[k])
		end
	end
	setmetatable(t, { __index = base })
end
inherit(svSE, enUS)

ns.Locales = { en = enUS, sv = svSE }

function ns.L()
	return ns.Locales[ns.db and ns.db.lang or "en"] or enUS
end
