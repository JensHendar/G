# Profession Clicker

A 2D incremental game in the spirit of Cookie Clicker, built around hiring professions.
Plain HTML, CSS and JavaScript with no build step. Open `index.html` in a browser to play.

## Themes

Pick a world when you start, and switch any time from **🎨 Themes**. Each world keeps its own save.

| Theme | Currency | Click to… | Professions (12 each) |
|---|---|---|---|
| Medieval Kingdom | gold | Collect taxes | Peasant → Monarch (Blacksmith, Alchemist, Wizard, Dragon Tamer…) |
| Space Colony | credits | Scan the planet | Maintenance Bot → Time Weaver (Terraformer, Dyson Architect…) |
| Hustle City | dollars | Take a gig | Dog Walker → Tech Mogul (Programmer, Surgeon, Movie Star…) |
| Pirate Harbor | doubloons | Dig for treasure | Deckhand → Kraken Whisperer (Navigator, Smuggler, Ghost Crew…) |

## Mechanics

- **Click** the big icon in the world to earn currency.
- **Hire professions.** Each produces currency per second and costs 15% more per copy. You can buy ×1, ×10, ×100 or Max at once. Hired workers walk around the world.
- **Upgrades**: five tiers per profession, unlocked at 1/10/25/50/100 owned. Each tier doubles that profession's output. Five click upgrades double clicks or add a share of your income per second to each click.
- **Lucky events**: a golden item drifts into the world now and then. Catch it for a windfall, a 7× income frenzy, or a 25× click storm.
- **Achievements**: 50 per theme, each worth +1% income.
- **Prestige**: reset a run for Royal Charters / Star Seeds / Startup Exits / Legends. Each one gives +2% income permanently.
- **Offline progress**: workers earn 50% of their normal rate while you're away, for up to 8 hours.
- Saves to `localStorage` every 10 seconds and when you leave the page.

## Adding a theme

Add an entry to `themes.js` with 12 professions, colors, decor and names. The economy in `game.js` is shared, so the new theme is balanced automatically.
