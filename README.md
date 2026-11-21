# Kingdom Clicker

A 2D incremental game in the spirit of Cookie Clicker. Hire 18 medieval professions and grow a hamlet into an empire.
Plain HTML, CSS and JavaScript with no build step. Open `index.html` in a browser to play.

## Files

- `kingdom.js`: all content (professions, ranks, seasons, synergies, edicts, perks, chronicle lines). Tune the game here.
- `game.js`: rules, rendering (canvas), shop UI and saving.
- `style.css`, `index.html`: layout.

## Mechanics

- **Collect taxes**: click the money bag.
- **18 professions**, from Peasant (15 gold) to Grail Seeker (79 T). Each costs 15% more per copy. Buy ×1, ×10, ×100 or Max. Hired workers walk around the realm.
- **Upgrades**
  - 5 tiers per profession (at 1/10/25/50/100 owned), each doubles that profession.
  - 5 click upgrades.
  - 12 **synergies** such as *Granary* (Bakers +2% per Peasant) and *Dragonfire Forge* (Blacksmiths +5% per Dragon Tamer).
  - 7 **Royal Edicts**: kingdom-wide boosts that unlock as the settlement grows.
- **Settlement ranks**: Hamlet → Village (25 workers) → Town (75) → City (150) → Kingdom (300) → Empire (600). Each rank changes the skyline and adds +5% to +50% income.
- **Seasons** change every 2 minutes. Each one boosts or hurts certain trades (Autumn doubles Peasants, Bakers and Monks; Winter freezes the fields but fires up the forges). The sky, ground and trees change too, and petals, leaves or snow fall.
- **Four-leaf clovers** appear now and then: a windfall, a ×7 income frenzy, or a ×25 tax storm.
- **Bandit raids** (once you have 15 workers): click the bandits before they cross the screen. Each one you catch pays out; each one that escapes steals some gold. Knights reduce what they steal.
- **Royal Charters** (prestige): found a new dynasty to turn lifetime gold into charters. Each gives +2% income forever, and you can spend them on 12 permanent perks.
- **79 achievements**, each +1% income.
- **Chronicle**: a running stream of village news that reacts to your progress.
- Name your realm, sound effects with a mute toggle, offline earnings (50%, up to 8 hours), autosave to `localStorage`.

Saves from the earlier multi-theme version's Medieval Kingdom are migrated automatically.

## Pärlverkstaden

`parlplatta/index.html` är en fristående sida som gör pärlplattemönster. Du kan beskriva ett motiv eller ladda upp en bild. Bilden skalas ner till plattans storlek och färgerna byts mot närmaste pärlfärger. Sidan visar också en inköpslista och låter dig måla om pärlor för hand. Utanför Claude blir beskrivningar en snabbskiss från en emoji.
