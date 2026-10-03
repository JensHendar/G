// All Medieval Kingdom content. game.js holds the rules; this file holds the world.
window.KINGDOM = {
  currency: { name: "gold", icon: "🪙" },
  clicker: { icon: "💰", label: "Collect taxes" },
  colors: { panel: "#f3ead6", panel2: "#e6d8b8", ink: "#3b2a17", muted: "#7a6448", accent: "#a8441c", accentInk: "#fff6e8", good: "#3d7a2a", bad: "#a3261c" },

  // Ordered by price. `cost` and `rate` are the price of the first hire and gold per second each.
  professions: [
    { id: "peasant", name: "Peasant", icon: "🧑‍🌾", cost: 15, rate: 0.17, desc: "Tills the fields. Complains about it." },
    { id: "woodcutter", name: "Woodcutter", icon: "🪓", cost: 84, rate: 0.71, desc: "Turns forests into firewood and lumber." },
    { id: "fisher", name: "Fisher", icon: "🎣", cost: 470, rate: 3, desc: "Hauls carp and eels from the mill pond." },
    { id: "miner", name: "Miner", icon: "⛏️", cost: 2600, rate: 13, desc: "Digs ore out of the mountain's ribs." },
    { id: "hunter", name: "Hunter", icon: "🏹", cost: 15e3, rate: 55, desc: "Sells venison and furs, poaches the king's deer." },
    { id: "blacksmith", name: "Blacksmith", icon: "⚒️", cost: 83e3, rate: 230, desc: "Hammers ore into horseshoes and swords." },
    { id: "baker", name: "Baker", icon: "🥖", cost: 46e4, rate: 970, desc: "Bread at dawn, gossip by noon." },
    { id: "monk", name: "Monk", icon: "📜", cost: 2.6e6, rate: 4100, desc: "Copies manuscripts. Brews remarkable ale." },
    { id: "merchant", name: "Merchant", icon: "🐪", cost: 1.5e7, rate: 18e3, desc: "Runs caravans across the desert roads." },
    { id: "bard", name: "Bard", icon: "🪕", cost: 8.1e7, rate: 74e3, desc: "Sings for coins. Is paid to stop." },
    { id: "mason", name: "Mason", icon: "🧱", cost: 4.5e8, rate: 31e4, desc: "Raises walls, towers and invoices." },
    { id: "alchemist", name: "Alchemist", icon: "⚗️", cost: 2.5e9, rate: 1.3e6, desc: "Almost turns lead into gold. Almost." },
    { id: "knight", name: "Knight", icon: "🛡️", cost: 1.4e10, rate: 5.6e6, desc: "Collects tribute from the next valley over. Scares off bandits." },
    { id: "spymaster", name: "Spymaster", icon: "🗝️", cost: 8e10, rate: 2.4e7, desc: "Knows where every noble hides their silver." },
    { id: "wizard", name: "Wizard", icon: "🧙", cost: 4.5e11, rate: 1e8, desc: "Conjures gold, mostly on purpose." },
    { id: "dragontamer", name: "Dragon Tamer", icon: "🐉", cost: 2.5e12, rate: 4.3e8, desc: "Dragons sit on hoards. Tamers borrow them." },
    { id: "monarch", name: "Monarch", icon: "👑", cost: 1.4e13, rate: 1.8e9, desc: "Everything belongs to the crown anyway." },
    { id: "grail", name: "Grail Seeker", icon: "🏆", cost: 7.9e13, rate: 7.8e9, desc: "Found the Grail. It fills with gold at every sunrise." }
  ],

  // Index map from the 12-profession save of the first version.
  legacyIndex: [0, 1, 3, 5, 6, 8, 9, 11, 12, 14, 15, 16],

  tiers: ["Apprentices", "Guild Charter", "Masterwork Tools", "Royal Patronage", "Ancient Secrets"],

  clickUpgrades: [
    { name: "Leather Purse", cost: 100, desc: "Taxes collected by hand are doubled." },
    { name: "Iron Strongbox", cost: 1e4, desc: "Taxes collected by hand are doubled again." },
    { name: "Tax Collector's Ledger", cost: 1e6, desc: "Each click also collects 1% of your gold per second." },
    { name: "Royal Treasury", cost: 1e8, desc: "Each click also collects 2% of your gold per second." },
    { name: "Midas Touch", cost: 1e10, desc: "Each click also collects 5% of your gold per second." }
  ],

  // Settlement ranks, reached by total workers. Each changes the skyline and adds income.
  ranks: [
    { name: "Hamlet", workers: 0, bonus: 0, skyline: ["🌳", "🛖", "🌲", "🌳", "🛖", "🌲"] },
    { name: "Village", workers: 25, bonus: 0.05, skyline: ["🌳", "🛖", "🏠", "🌾", "🏡", "🌲", "🛖"] },
    { name: "Town", workers: 75, bonus: 0.1, skyline: ["🌲", "🏠", "⛪", "🏡", "🏘️", "🌳", "🏠", "🌾"] },
    { name: "City", workers: 150, bonus: 0.2, skyline: ["🏘️", "🏠", "⛪", "🏰", "🏡", "🏘️", "🌳", "🏠"] },
    { name: "Kingdom", workers: 300, bonus: 0.3, skyline: ["🏘️", "⛪", "🏰", "🏘️", "🏯", "🏡", "🏰", "🏘️"] },
    { name: "Empire", workers: 600, bonus: 0.5, skyline: ["🏯", "🏰", "⛪", "🏘️", "🏰", "🏯", "🏘️", "🏰", "⛪"] }
  ],

  // Seasons cycle every 2 minutes of play. `boost` maps profession id to an income multiplier.
  seasonLength: 120,
  seasons: [
    { name: "Spring", icon: "🌸", tree: "🌸", sky: ["#8cc4e8", "#e4f3d8"], ground: ["#6aa84f", "#4f8a38"], weather: "petals",
      boost: { peasant: 1.5, fisher: 1.5, hunter: 1.5 }, blurb: "Planting season. Peasants, Fishers and Hunters +50%." },
    { name: "Summer", icon: "☀️", tree: "🌳", sky: ["#5aa8de", "#f4e9b8"], ground: ["#5d8a3c", "#46702b"], weather: null,
      boost: { merchant: 1.5, bard: 1.5, mason: 1.5 }, blurb: "Fair weather for roads and festivals. Merchants, Bards and Masons +50%." },
    { name: "Autumn", icon: "🍂", tree: "🍂", sky: ["#e0a46c", "#f6dfb8"], ground: ["#8f7a35", "#6e5b24"], weather: "leaves",
      boost: { peasant: 2, baker: 2, monk: 2 }, blurb: "Harvest time. Peasants, Bakers and Monks x2." },
    { name: "Winter", icon: "❄️", tree: "🌲", sky: ["#8a9bb4", "#dce6ee"], ground: ["#e8eef2", "#c9d4dc"], weather: "snow",
      boost: { peasant: 0.5, fisher: 0.5, blacksmith: 1.5, alchemist: 1.5, wizard: 1.5 }, blurb: "Fields freeze, forges roar. Peasants and Fishers -50%; Blacksmiths, Alchemists and Wizards +50%." }
  ],

  // Profession synergies: `to` earns `pct` more per `from` owned.
  synergies: [
    { name: "Granary", to: "baker", from: "peasant", pct: 0.02, need: 10, cost: 5e6, desc: "Bakers +2% for each Peasant." },
    { name: "Salted Catch", to: "merchant", from: "fisher", pct: 0.01, need: 15, cost: 1e8, desc: "Merchants +1% for each Fisher." },
    { name: "Ore Carts", to: "blacksmith", from: "miner", pct: 0.02, need: 10, cost: 1e6, desc: "Blacksmiths +2% for each Miner." },
    { name: "Fur Trade", to: "merchant", from: "hunter", pct: 0.02, need: 15, cost: 2e8, desc: "Merchants +2% for each Hunter." },
    { name: "Timber Scaffolds", to: "mason", from: "woodcutter", pct: 0.01, need: 25, cost: 5e9, desc: "Masons +1% for each Woodcutter." },
    { name: "Illuminated Ledgers", to: "merchant", from: "monk", pct: 0.02, need: 10, cost: 1e9, desc: "Merchants +2% for each Monk." },
    { name: "Ballads of Valor", to: "knight", from: "bard", pct: 0.02, need: 10, cost: 1e11, desc: "Knights +2% for each Bard." },
    { name: "Forged Plate", to: "knight", from: "blacksmith", pct: 0.01, need: 25, cost: 2e11, desc: "Knights +1% for each Blacksmith." },
    { name: "Monastery Library", to: "alchemist", from: "monk", pct: 0.02, need: 15, cost: 3e10, desc: "Alchemists +2% for each Monk." },
    { name: "Arcane Tutors", to: "wizard", from: "alchemist", pct: 0.02, need: 15, cost: 4e12, desc: "Wizards +2% for each Alchemist." },
    { name: "Court Whispers", to: "monarch", from: "spymaster", pct: 0.03, need: 10, cost: 1e15, desc: "Monarchs +3% for each Spymaster." },
    { name: "Dragonfire Forge", to: "blacksmith", from: "dragontamer", pct: 0.05, need: 5, cost: 5e13, desc: "Blacksmiths +5% for each Dragon Tamer." }
  ],

  // Kingdom-wide upgrades, unlocked by settlement rank.
  edicts: [
    { name: "Cobbled Roads", rank: 1, cost: 5e4, mult: 1.1, desc: "All income +10%." },
    { name: "Lucky Horseshoes", rank: 1, cost: 2e5, clover: 1.25, desc: "Four-leaf clovers appear 25% more often." },
    { name: "Market Charter", rank: 2, cost: 5e7, mult: 1.15, desc: "All income +15%." },
    { name: "Town Watch", rank: 2, cost: 2e8, watch: true, desc: "Bandits move 30% slower." },
    { name: "Royal Mint", rank: 3, cost: 5e10, mult: 1.2, desc: "All income +20%." },
    { name: "Great Library", rank: 4, cost: 5e13, mult: 1.25, desc: "All income +25%." },
    { name: "Imperial Highway", rank: 5, cost: 5e16, mult: 1.3, desc: "All income +30%." }
  ],

  golden: { icon: "🍀", name: "Four-Leaf Clover" },
  bandit: { icon: "🥷", name: "Bandit" },

  prestige: { name: "Royal Charters", one: "Royal Charter", verb: "Found a new dynasty" },

  // Bought with Royal Charters; kept forever.
  perks: [
    { id: "purse", name: "Heirloom Purse", icon: "👛", cost: 1, desc: "Start each dynasty with 1,000 gold." },
    { id: "bloodline", name: "Lucky Bloodline", icon: "🍀", cost: 2, desc: "Four-leaf clovers appear 25% more often." },
    { id: "recruits", name: "Trained Recruits", icon: "📯", cost: 3, desc: "Hiring costs 5% less." },
    { id: "memory", name: "Long Memory", icon: "🕯️", cost: 5, desc: "Workers earn at full speed while you're away, instead of half." },
    { id: "tutor", name: "Royal Tutor", icon: "🎓", cost: 5, desc: "Clicks are three times as strong." },
    { id: "almanac", name: "Farmer's Almanac", icon: "📅", cost: 8, desc: "Season bonuses are twice as strong. Season penalties are gone." },
    { id: "gates", name: "Iron Gates", icon: "🚪", cost: 8, desc: "Bandits that escape steal nothing." },
    { id: "legacy", name: "Guild Legacy", icon: "🏛️", cost: 12, desc: "Keep every Apprentices (tier I) upgrade when founding a new dynasty." },
    { id: "meadow", name: "Clover Meadow", icon: "☘️", cost: 15, desc: "Clover frenzies and click storms last twice as long." },
    { id: "founders", name: "Founding Families", icon: "🏘️", cost: 20, desc: "Start each dynasty with 10 Peasants, Woodcutters and Fishers." },
    { id: "dynasty", name: "Golden Dynasty", icon: "🦁", cost: 30, desc: "All income +50%." },
    { id: "hoard", name: "Dragon's Hoard", icon: "🐲", cost: 50, desc: "Clover windfalls are three times larger." }
  ],

  // News for the chronicle ticker. `when` (optional) gets the game API and decides if a line can show.
  chronicle: [
    { text: "A traveling friar swears the taxes here are the fairest in the land. He is lying." },
    { text: "The village goat has been elected reeve. Nobody can remember voting." },
    { text: "Local man claims he saw a dragon. It was a large chicken." },
    { text: "Peasants petition for a fourth meal. Petition used as kindling.", when: (g) => g.owned("peasant") >= 5 },
    { text: "Woodcutters report the forest is getting smaller. Experts baffled.", when: (g) => g.owned("woodcutter") >= 10 },
    { text: "Fishers catch a pike the size of a cart. It is now a tavern sign.", when: (g) => g.owned("fisher") >= 5 },
    { text: "Miners strike silver, then strike for better wages.", when: (g) => g.owned("miner") >= 10 },
    { text: "Hunters return with forty pheasants and one very cross badger.", when: (g) => g.owned("hunter") >= 5 },
    { text: "Blacksmith forges a sword so sharp it cut its own scabbard.", when: (g) => g.owned("blacksmith") >= 5 },
    { text: "Baker's guild bans the phrase \"half a dozen\". Thirteen is the law.", when: (g) => g.owned("baker") >= 5 },
    { text: "Monks finish copying the Great Book. Begin the sequel.", when: (g) => g.owned("monk") >= 3 },
    { text: "Abbey ale wins the regional fair for the ninth year running.", when: (g) => g.owned("monk") >= 15 },
    { text: "A camel caravan arrives with silk, spices and a lot of opinions.", when: (g) => g.owned("merchant") >= 1 },
    { text: "Bard releases a ballad about taxes. It is a hit with everyone except the tax collector.", when: (g) => g.owned("bard") >= 1 },
    { text: "Masons finish the new wall. Masons propose a second, taller wall.", when: (g) => g.owned("mason") >= 5 },
    { text: "Alchemist's lab explodes again. Nearby goats now glow faintly.", when: (g) => g.owned("alchemist") >= 1 },
    { text: "Knights hold a tournament. The winner gets a ribbon and a concussion.", when: (g) => g.owned("knight") >= 5 },
    { text: "A spy reports that the neighbouring duke keeps his gold under his bed. Under it now: nothing.", when: (g) => g.owned("spymaster") >= 1 },
    { text: "Wizard accidentally turns the tax office into a pumpkin. Productivity unchanged.", when: (g) => g.owned("wizard") >= 1 },
    { text: "Dragon refuses to give back the gold. Dragon Tamer gives it a stern talking-to.", when: (g) => g.owned("dragontamer") >= 1 },
    { text: "The Monarch declares a holiday. The Monarch also declares a holiday tax.", when: (g) => g.owned("monarch") >= 1 },
    { text: "The Grail glows. Pilgrims arrive. Pilgrims pay admission.", when: (g) => g.owned("grail") >= 1 },
    { text: "Travelers now call this place a village. Residents demand a sign.", when: (g) => g.rank() >= 1 },
    { text: "A cathedral is planned. Completion expected in roughly two hundred years.", when: (g) => g.rank() >= 2 },
    { text: "The city gates now have a queue. Nobody is sure what for.", when: (g) => g.rank() >= 3 },
    { text: "Foreign envoys bring gifts. One of them is a very confused elephant.", when: (g) => g.rank() >= 4 },
    { text: "Maps are redrawn. The whole map is now your realm.", when: (g) => g.rank() >= 5 },
    { text: "First frost. The well froze; the ale did not.", when: (g) => g.season() === 3 },
    { text: "Snowball fight at the castle. The Knights lost.", when: (g) => g.season() === 3 },
    { text: "Harvest moon rises. Every barn is full to the rafters.", when: (g) => g.season() === 2 },
    { text: "Spring fair opens. A pig wins the beauty contest, again.", when: (g) => g.season() === 0 },
    { text: "Midsummer feast lasts three days. The fourth is for headaches.", when: (g) => g.season() === 1 },
    { text: "Bandits spotted near the old mill. Lock up your purses.", when: (g) => g.bandits() >= 1 },
    { text: "Captured bandits sentenced to community service: peeling potatoes.", when: (g) => g.bandits() >= 10 },
    { text: "A clover patch was found behind the stables. The stablehand is suddenly rich.", when: (g) => g.clovers() >= 3 },
    { text: "Chroniclers note that the old dynasty is remembered fondly. Mostly for the gold.", when: (g) => g.charters() >= 1 }
  ]
};
