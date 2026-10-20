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

# Sikte (fristående demo)

En skjutbana i mappen `sikte/` där telefonen är vapnet. Skärmen (dator eller TV) visar banan och en QR-kod. Spelarna skannar koden, och telefonens gyroskop styr ett sikte på skärmen. Flera telefoner kan spela samtidigt, med var sitt sikte och var sin färg.

- `sikte/index.html` + `skarm.js`: skärmen. Visar banan, QR-koden och poängen.
- `sikte/kontroll.html` + `kontroll.js`: telefonen. Läser rörelsesensorerna och har en stor SKJUT-knapp.
- `sikte/sikte.css`: utseendet för båda sidorna.

## Så spelar man

1. Öppna `sikte/index.html` på datorn eller TV:n.
2. Skanna QR-koden med telefonen, skriv ett namn och tryck **Anslut**. På iPhone måste du tillåta rörelsesensorer.
3. Rikta telefonen mot mitten av skärmen och tryck **Centrera**. Gör om det om siktet glider iväg.
4. Skjut på startmålet. En runda är 60 sekunder:
   - röda tavlor ger 10/25/50 poäng beroende på hur nära mitten du träffar,
   - små blå tavlor ger 75,
   - snabba guldmål ger 150,
   - bomber ger −100.

Du kan välja grepp. **Pekare** betyder att skärmen är uppåt och toppen av telefonen pekar mot TV:n. **Kamera** betyder att telefonens baksida pekar mot TV:n. **Känslighet** styr hur mycket du behöver vrida telefonen. Du kan också testa utan telefon genom att klicka med musen på skärmen.

## Teknik

- Telefonen och skärmen pratar direkt med varandra via WebRTC med [PeerJS](https://peerjs.com). PeerJS gratis molnserver används bara för att koppla ihop dem. Ingen egen server behövs.
- Telefonen räknar ut åt vilket håll den pekar från `deviceorientation` och skickar siktet till skärmen ungefär 60 gånger i sekunden, normaliserat till −1…1 jämfört med centrerat läge.
- **Sidorna måste ligga på https** för att telefonens sensorer ska fungera, till exempel på GitHub Pages: Settings → Pages → välj gren. Då blir adressen `https://<användare>.github.io/<repo>/sikte/`. Det fungerar inte att öppna filen direkt från disken.
