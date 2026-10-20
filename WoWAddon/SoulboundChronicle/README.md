# Soulbound Chronicle

Ett addon till **World of Warcraft: Forever** som minns.

- **Föremål med historia:** utrustning (som inte staplas) minns var den kom ifrån (byte från en fiende, quest, handlare, tillverkning, byte eller post), när och på vilken level. Burna föremål räknar levels, tid, dödade fiender och dödsfall. De minns också de senaste stora bedrifterna, som rares, elitfiender och bossar.
- **Soul shards med själ:** när du dödar något med Drain Soul (eller Shadowburn) minns shardet vems själ det är, var och när den fångades, och får en replik efter varelsetyp. När shardet offras till en besvärjelse skrivs det in i krönikan.
- **Hjältens krönika:** en dagbok som skriver sig själv. Den tar med level-ups, nya zoner och dungeons, första gången du fäller en rare eller elit, bossar, nära-döden-ögonblick, dödsfall (och vem som dödade dig), fångade själar och nya föremål av rare-kvalitet eller bättre.

Historierna visas i föremålens tooltip och i ett eget fönster.

## Installation

Kopiera mappen `SoulboundChronicle` till
`World of Warcraft/_forever_/Interface/AddOns/`.
Mappnamnet kan skilja sig åt mellan versioner. Använd samma mapp som dina andra Forever-addons ligger i.

## Kommandon

| Kommando | Vad det gör |
| --- | --- |
| `/chronicle` (eller `/sbc`, `/kronika`) | Öppna eller stäng krönikan |
| `/chronicle items` | Historierna för allt du bär och har i väskorna |
| `/chronicle export` | Krönikan som text att kopiera |
| `/chronicle lang sv` / `en` | Byt språk (svenska eller engelska) |
| `/chronicle tooltip` | Slå på eller av historier i tooltips |

## Bra att veta

- `## Interface: 16001` är Forever-betans värde. Det är inte bekräftat för releaseversionen. Kontrollera med `/dump select(4, GetBuildInfo())` i spelet och uppdatera `.toc` vid behov. `11509` (Classic Era) står också med så att addonet kan testas där.
- Allt sparas per karaktär (`SoulboundChronicleCharDB`). Föremål du redan har när du installerar får ursprunget "fanns hos dig innan krönikan började".
- Klienter med föremåls-GUID kan skilja identiska föremål åt. Utan GUID matchas föremål på item-ID, så två soul shards som byter plats med varandra kan byta historier.
- Föremål i banken minns sin historia även när banken är stängd. Sålda föremål minns sin historia om du köper tillbaka dem.

## Utveckling

Logiken testas utan spelet med en mock av WoW-API:et:

```sh
lua5.1 WoWAddon/tests/mock_test.lua
```

| Fil | Innehåll |
| --- | --- |
| `Core.lua` | Händelser, API-kompatibilitet, sparad data, strid (kills, mördare, Drain Soul), slash-kommandon |
| `Tracker.lua` | Följer föremål mellan väskor, bank och utrustning, bestämmer ursprung och räknar statistik |
| `Journal.lua` | Krönikans händelser |
| `Stories.lua` | Gör om sparade fakta till text (inget text sparas, så språkbyte skriver om allt) |
| `Locales.lua` | Alla texter på engelska och svenska, med varianter |
| `Tooltip.lua`, `UI.lua` | Tooltips, krönikefönster och export |
