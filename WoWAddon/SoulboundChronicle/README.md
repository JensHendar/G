# Soulbound Chronicle

Ett addon till **World of Warcraft: Forever** som ger tråkiga föremål namn värda att minnas. All text i spelet är på engelska.

## Namn

Vapen och rustning av alla kvaliteter upp till lila (epic) får nya namn. Blå och lila namn går att stänga av med `/chronicle rares`.

- **Genererade namn** bygger på föremålstyp, kvalitet och stats.
  - Gråa blir självironiska: *Rusty Cleaver*, *Smelly Axe*.
  - Vita: *Trusty Sword*, *Blade of Westfall*, *Torvald's Pigsticker*.
  - Gröna får namn efter sin starkaste stat: *Iron Pants*, *Leggings of the Bear*.
  - Blå: *Thunderward*, *Mighty Helm*.
  - Lila: *Stormfang*, *Thundersong, the Whispering Dark*.

  Namnet slumpas en gång och behålls sedan.
- **Förtjänade namn** ersätter det genererade när föremålet varit med om något:
  | Bedrift | Gäller | Del av namnet |
  | --- | --- | --- |
  | Var med när du dräpte en rare, elit eller boss | vapen | *…, Bane of Mother Fang* |
  | 100 dödade av samma varelsetyp | vapen | *Beastslayer's …* |
  | 10 levels i din utrustning | allt | *Old Faithful …* |
  | 5 dödsfall i din utrustning | allt | *Cursed …* |

  Bedrifterna kombineras, till exempel *Old Faithful Beastslayer's Sword, Bane of Mother Fang*. En svagare fiende tar inte över Bane-delen, men en starkare gör det (elit < rare < rare elit < boss < världsboss). När ett föremål får ett nytt namn står det i chatten och i krönikan.

  Räknarna nollställs aldrig. Tar du av ett föremål pausas de och fortsätter när du tar på det igen. De 10 levelsen behöver alltså inte vara i följd.
- **Egna namn** går på alla föremål: hovra över ett föremål och skriv `/chronicle name Ondskans Smörkniv`. Du kan också binda en tangent till *Rename hovered item* under Key Bindings → AddOns och trycka på den medan du hovrar. Med `/chronicle name reset` får föremålet tillbaka sitt förtjänade namn.

Namnen visas i tooltipen (med originalnamnet under), i chattlänkar och på föremålssidan i addonets fönster.

### Ser andra mina namn?

Ja, om de också har addonet. Addonen skickar dolda meddelanden till varandra:
- När du loggar in skickas namnen på det du bär till gillet. När någon går med i din grupp skickas de till gruppen.
- Om någon länkar ett föremål vars namn ditt addon inte känner till, frågar det ägaren med en dold viskning.
- Namnen syns då i chattlänkar, i tooltips för länkar och när du inspekterar spelaren. Tooltipen visar vem som döpte föremålet.

Spelare utan addonet ser bara originalnamnen. Servern ändrar aldrig något. Med `/chronicle others` döljer du andras namn.

## Föremålens historia och krönikan

- Varje föremål minns var det kom ifrån (byte från en fiende, quest, handlare, tillverkning, byte eller post), när och på vilken level. Burna föremål räknar levels, tid, dödade fiender och dödsfall, och minns sina senaste stora bedrifter.
- Krönikan skriver sig själv. Den tar med level-ups, nya zoner och dungeons, första gången du fäller en rare eller elit, bossar, nära-döden-ögonblick, dödsfall (och vem som dödade dig), nya föremål av rare-kvalitet eller bättre, och namnbyten.

## Installation

Kopiera mappen `SoulboundChronicle` till
`World of Warcraft/_forever_/Interface/AddOns/`.
Mappnamnet kan skilja sig åt mellan versioner. Använd samma mapp som dina andra Forever-addons ligger i.

## Kommandon

| Kommando | Vad det gör |
| --- | --- |
| `/chronicle` (eller `/sbc`) | Öppna eller stäng krönikan |
| `/chronicle items` | Dina föremål med namn och historia |
| `/chronicle name <namn>` | Döp om föremålet du senast hovrade |
| `/chronicle name` | Samma sak, fast med en ruta att skriva i |
| `/chronicle name reset` | Ta bort ditt eget namn |
| `/chronicle autonames` | Slå på eller av automatiska namn |
| `/chronicle rares` | Slå på eller av automatiska namn för blå och lila föremål |
| `/chronicle others` | Visa eller dölj andra spelares namn |
| `/chronicle export` | Krönikan som text att kopiera |
| `/chronicle tooltip` | Slå på eller av historier i tooltips |

## Bra att veta

- `## Interface: 16001` är Forever-betans värde. Det är inte bekräftat för releaseversionen. Kontrollera med `/dump select(4, GetBuildInfo())` i spelet och uppdatera `.toc` vid behov. `11509` (Classic Era) står också med så att addonet kan testas där.
- Namnen visas bara där spelet visar föremålsnamn i text: tooltips och chatt. Väskor och karaktärsfönstret visar inga namn alls.
- Allt sparas per karaktär (`SoulboundChronicleCharDB`). Föremål du redan har när du installerar får ursprunget "fanns hos dig innan krönikan började".

## Utveckling

Logiken testas utan spelet med en mock av WoW-API:et:

```sh
lua5.1 WoWAddon/tests/mock_test.lua
```

| Fil | Innehåll |
| --- | --- |
| `Core.lua` | Händelser, API-kompatibilitet, sparad data, strid (kills och mördare), slash-kommandon |
| `Tracker.lua` | Följer föremål mellan väskor, bank och utrustning, bestämmer ursprung och räknar statistik |
| `Journal.lua` | Krönikans händelser |
| `Names.lua` | Genererade, förtjänade och egna namn |
| `Comm.lua` | Delar namn med andra spelare och byter namn i chattlänkar |
| `Stories.lua` | Gör om sparade fakta till text |
| `Locales.lua` | Alla texter och namnord |
| `Tooltip.lua`, `UI.lua`, `Bindings.xml` | Tooltips, krönikefönster, export och tangentbindning |
