# Soulbound Chronicle

Ett addon till **World of Warcraft: Forever** som ger tråkiga föremål namn värda att minnas.

## Namn

Gråa, vita och gröna föremål (vapen och rustning) får nya namn. Blå och lila behåller sina riktiga namn, men går att döpa om för hand.

- **Genererade namn** bygger på föremålstyp, kvalitet och stats.
  - Gråa blir självironiska: *Rusty Cleaver*, *Lätt Hemsökta Yxan*.
  - Vita: *Trusty Sword*, *Blade of Westfall*, *Torvalds Grisstickare*.
  - Gröna får namn efter sin starkaste stat: *Iron Pants*, *Björnens Benskydd*.

  Namnet slumpas en gång och behålls sedan.
- **Förtjänade namn** ersätter det genererade när föremålet varit med om något:
  | Bedrift | Exempel |
  | --- | --- |
  | Vapnet var med när du dräpte en rare, elit eller boss | *Bane of Mother Fang* / *Mother Fangs Fördärv* |
  | Vapnet har dödat 100 av samma varelsetyp | *Beastslayer's Sword* / *Bestdräparens Svärd* |
  | 10 levels i din utrustning | *Faithful Old Trousers* / *Trogna Gamla Byxorna* |
  | 5 dödsfall i din utrustning | *The Cursed Boots* / *Förbannade Stövlarna* |

  När ett föremål får ett nytt namn står det i chatten och i krönikan.
- **Egna namn:** hovra över ett föremål och skriv `/chronicle name Ondskans Smörkniv`. Du kan också binda en tangent till *Rename hovered item* under Key Bindings → AddOns och trycka på den medan du hovrar. Med `/chronicle name reset` får föremålet tillbaka sitt förtjänade namn.

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
| `/chronicle` (eller `/sbc`, `/kronika`) | Öppna eller stäng krönikan |
| `/chronicle items` | Dina föremål med namn och historia |
| `/chronicle name <namn>` | Döp om föremålet du senast hovrade |
| `/chronicle name` | Samma sak, fast med en ruta att skriva i |
| `/chronicle name reset` | Ta bort ditt eget namn |
| `/chronicle autonames` | Slå på eller av automatiska namn |
| `/chronicle others` | Visa eller dölj andra spelares namn |
| `/chronicle export` | Krönikan som text att kopiera |
| `/chronicle lang sv` / `en` | Byt språk (svenska eller engelska) |
| `/chronicle tooltip` | Slå på eller av historier i tooltips |

## Bra att veta

- `## Interface: 16001` är Forever-betans värde. Det är inte bekräftat för releaseversionen. Kontrollera med `/dump select(4, GetBuildInfo())` i spelet och uppdatera `.toc` vid behov. `11509` (Classic Era) står också med så att addonet kan testas där.
- Namnen visas bara där spelet visar föremålsnamn i text: tooltips och chatt. Väskor och karaktärsfönstret visar inga namn alls.
- Andra spelare får namnen på ditt valda språk.
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
| `Stories.lua` | Gör om sparade fakta till text (ingen text sparas, så språkbyte skriver om allt) |
| `Locales.lua` | Alla texter och namnord på engelska och svenska |
| `Tooltip.lua`, `UI.lua`, `Bindings.xml` | Tooltips, krönikefönster, export och tangentbindning |
