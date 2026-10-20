local _, ns = ...

-- Templates use {placeholders}. Lists hold variants; one is picked per
-- item or entry from a stable seed, so a story never changes once written.
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
			"/chronicle items - show the stories of your items",
			"/chronicle export - copy the chronicle as text",
			"/chronicle lang en/sv - change language",
			"/chronicle tooltip - turn item stories in tooltips on or off",
		},
		langSet = "Language set to English.",
		tooltipOn = "Item stories in tooltips: on.",
		tooltipOff = "Item stories in tooltips: off.",
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

	soul = {
		"The soul of {name}{lvl}, torn free {tod} in {place}.",
		"Here lies the soul of {name}{lvl}, taken {tod} in {place}.",
		"Bound within: {name}{lvl}. Captured {tod} in {place}.",
	},
	soulUnknown = "A nameless soul. Whoever it was, they are forgotten.",
	tod = {
		dawn = "at dawn",
		day = "in broad daylight",
		dusk = "at dusk",
		night = "in the dead of night",
	},
	soulFlavor = {
		Humanoid = {
			"It still whispers the names of those it left behind.",
			"It remembers a home it will never see again.",
			"It begs, quietly, when the bag is opened.",
		},
		Beast = {
			"It paces in circles, looking for a way out.",
			"It howls faintly when the moon is full.",
		},
		Undead = {
			"It has died twice now, and resents you for both.",
			"It is almost relieved.",
		},
		Demon = {
			"It is not the first time it has been bound. It will not be the last.",
			"It is laughing at something you cannot hear.",
		},
		Elemental = {
			"It flickers, restless, like a flame without fuel.",
			"It hums with the pull of earth and storm.",
		},
		Dragonkin = {
			"Even caged, it dreams of the sky.",
		},
		Giant = {
			"It is far too big for this little crystal, and it knows it.",
		},
		Mechanical = {
			"There is barely anything in here. A hum, perhaps.",
		},
		Critter = {
			"A very small soul. You feel slightly ashamed.",
		},
		default = {
			"It is cold to the touch.",
			"It pulses faintly, like a heartbeat.",
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
		soul = {
			"Captured the soul of {name}{lvl} in {place}.",
		},
		soulused = {
			"The soul of {name} was spent on {spell}.",
		},
		item = {
			"Acquired {link}. {origin}",
		},
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
			"/chronicle items - visa föremålens historier",
			"/chronicle export - kopiera krönikan som text",
			"/chronicle lang en/sv - byt språk",
			"/chronicle tooltip - slå på eller av historier i tooltips",
		},
		langSet = "Språket är nu svenska.",
		tooltipOn = "Föremålshistorier i tooltips: på.",
		tooltipOff = "Föremålshistorier i tooltips: av.",
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

	soul = {
		"Själen av {name}{lvl}, sliten loss {tod} i {place}.",
		"Här vilar själen av {name}{lvl}, tagen {tod} i {place}.",
		"Bunden här inne: {name}{lvl}. Fångad {tod} i {place}.",
	},
	soulUnknown = "En namnlös själ. Vem den än var, är den glömd.",
	tod = {
		dawn = "i gryningen",
		day = "mitt på ljusa dagen",
		dusk = "i skymningen",
		night = "mitt i natten",
	},
	soulFlavor = {
		Humanoid = {
			"Den viskar fortfarande namnen på dem den lämnade.",
			"Den minns ett hem den aldrig får se igen.",
			"Den ber, tyst, varje gång väskan öppnas.",
		},
		Beast = {
			"Den går i cirklar och letar efter en väg ut.",
			"Den ylar svagt när det är fullmåne.",
		},
		Undead = {
			"Den har dött två gånger nu och hatar dig för båda.",
			"Den verkar nästan lättad.",
		},
		Demon = {
			"Det är inte första gången den binds. Det blir inte den sista.",
			"Den skrattar åt något du inte kan höra.",
		},
		Elemental = {
			"Den fladdrar rastlöst, som en låga utan bränsle.",
			"Den surrar av jordens och stormens dragningskraft.",
		},
		Dragonkin = {
			"Även i fångenskap drömmer den om himlen.",
		},
		Giant = {
			"Den är alldeles för stor för den lilla kristallen, och den vet om det.",
		},
		Mechanical = {
			"Här finns knappt något. Ett surrande, kanske.",
		},
		Critter = {
			"En mycket liten själ. Du skäms lite.",
		},
		default = {
			"Den är kall att röra vid.",
			"Den pulserar svagt, som ett hjärtslag.",
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
		soul = {
			"Fångade själen av {name}{lvl} i {place}.",
		},
		soulused = {
			"Själen av {name} offrades till {spell}.",
		},
		item = {
			"Fick {link}. {origin}",
		},
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
