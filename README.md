# Plattifiera.se

Gör pärlplattemönster från en beskrivning eller en uppladdad bild. Bilden krymps till plattans storlek och varje färg byts mot närmaste pärlfärg. Sidan visar en inköpslista per färg, låter dig måla om pärlor för hand och sparar mönstret som bild med koder.

Ren HTML, CSS och JavaScript utan byggsteg. Öppna `index.html` i en webbläsare.

- `index.html` – själva sidan
- `logo.svg` – loggan, används även som flikikon
- `exempel/` – exempelmönster (isometrisk fotbollsarena, 58 × 58)

AI-ritningen under "Beskriv" fungerar när sidan öppnas i Claude. På en vanlig webbsida görs i stället en snabbskiss från en emoji som matchar ordet.

## Publicera med GitHub Pages

Settings → Pages → Deploy from a branch → välj gren och `/ (root)`. För egen domän: skriv `plattifiera.se` under Custom domain och lägg A-poster mot 185.199.108.153–185.199.111.153 hos domänleverantören.
