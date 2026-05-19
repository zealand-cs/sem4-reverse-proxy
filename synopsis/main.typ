#import "./template.typ": synopsis
#import "@preview/wordometer:0.1.5": total-characters, total-words, word-count

#let string-word-count(string) = (
  characters: string
    .replace(regex("^\s+"), "")
    .replace(regex("\s+$"), "")
    .replace(regex("\n+"), "")
    .replace(regex("\r+"), "")
    .replace(regex("\s+"), " ")
    .clusters()
    .len(),
)

#show: word-count.with(counter: string-word-count)

#show: synopsis.with(
  author: "William K. G. Jelgren",
  email: "wij001@edu.zealand.dk",
  title: "Modulær reverse proxy med WASM og FFI i Rust",
  abstract: none,
  total-characters: total-characters,
);

// ## Hvad er en synopsis?
//
// - Kort skriftligt produkt
// - Maks. 10 normalsider
// - 1 normalside = 2400 anslag inkl. mellemrum
// - Evt. programmer tæller ikke med
// - Individuelt arbejde
// - Danner grundlag for mundtlig eksamen
//
// > En synopsis er ikke en fuld rapport. Den skal være kort, fokuseret og undersøgende.
// > Det vigtigste er, at I viser, hvad I undersøger, hvordan I unsersøger det, og
// > hvad I finder ud af.
//
// ## Hvordan foregår eksamen?
//
// - Mundtlig individuel eksamen
// - Maks. 10 min. præsentation af synopsen
// - 20 min. eksamination inkl. votering
// - Alle hjælpemidler er tilladt
// - Samlet karakter efter 7-trinsskalaen
//
// > Start med det vigtigste fra synopsen. I skal ikke læse op. Brug de 10 minutter
// > på at forklare emne, problemformulering, metode, vigtigste resultater og konklusion
// > og gem evt. spørgsmål. Skal ikke bare indeholde det lærer og censor har allerede
// > har læst og set.

= Introduktion

// - Præsentér emnet kort
// - Forklar hvilken teknologi eller hvilket fagligt områden du undersøger
// - Giv kontekst: hvorfor er emnet valgt?
// - Forklar overordnet, hvad du vil undersøge
// - Vent med resultater og konklusion
//
// > Introduktionen skal hjælpe læseren ind i emnet. I skal ikke forklare alle tekniske
// > detaljer her. Gem metode, resultater og konlusion til de senere afsnit.

Udvidelse af software uden at skulle kende kildekoden kan være en stærk motivator
for tredjeparter til at bruge netop dit projekt.

I dette projekt vil der blive udviklet en reverse proxy i Rust, der understøtter
udvidelser i form af WASM og FFI, for at undersøge forskellene på de to nærmere,
i forhold til følgende parametre: implementering, hastighed og brug af hukommelse.

Selve programmet vil blive skrevet i Rust og det vil udvidelserne også, for nemt
at kunne se forskellene på implementeringerne ift. kodemængde og læselighed.

= Motivation

// - Hvorfor har du valgt emnet?
// - Hvorfor er det interessant for dig?
// - Hvorfor er det relevant for it-branchen, virksomheder eller brugere?
// - Hvordan hænger emnet sammen med dit valgfag?
//
// > Motivation er ikke kun "jeg synes emnet er spændendeØ. I skal også forklare,
// > hvorfor emnet er relevant fagligt. Det kan være i forhold til sikkerhed, performance,
// > systemudvikling, Rust, netværk, embedded, web eller andre områder fra valgfaget.

Dette projekt er interessant for mig da jeg synes det er interessant at se hvordan
forskellige programmer/libraries kan snakke sammen lokalt på computeren med så lille
et aftryk som muligt. Det skal gerne være nemt for udvikleren, men det skal i min
mening ikke betyde at den computerkraft vi har til rådighed, skal misbruges så
gralt som det gør i vores verden i dag.

Udover det har jeg også en interesse for at kunne ændre funktionaliteten af programmer
i form af uden at skulle rekompilere base-programmet. Dette kan være til stor fordel
i flere situationer: lang rekompilering af det fulde program, proprietært software
eller bekvemmelighed for brugeren.

= Problemformulering

// - Stil 1 hovedspørgsmål
// - Stil 2-3 underspørgsmål
// - Brug rigtige spørgsmålstegn
// - Spørgsmålene skal kunne undersøges
//   - Et godt spørgsmål kan besvares med teori, praktisk arbejde og analyse
// - Undgå ja/nej-spørgsmål
//
// > Problemformuleringen er styrende for hele synopsen. Metoden, det praktiske
// > arbejde, analysen og konklusionen skal hænge sammen med spørgsmålene. Hvis
// > I ikke kan svare på spørgsmålene i konklusionen, er de enten for brede eller
// > ikke skarpe nok.

Hvordan kan en simpel reverse proxy i Rust designes til at understøtte udvidelser
via `WASM` og `FFI`, og hvordan adskiller de to tilgange sig i forhold til implementering,
udviklingskompleksitet, performance og ressourceforbrug?

Følgende underspørgsmål vil blive undersøgt i forbindelse med problemformuleringen:

1. Hvordan kan en reverse proxy i Rust udvides med plugins via henholdsvis WASM og FFI?

2. Hvilke forskelle er der mellem `WASM` og `FFI` i forhold til kodekompleksitet,
  læsbarhed og udviklingsoplevelse?

3. Hvordan adskiller WASM- og FFI-baserede udvidelser sig i forhold til svartid,
  CPU-forbrug og hukommelsesforbrug?

= Metode

// Hvordan vil du finde svar?
// Teori og kilder
// Praktisk arbejde: eksperimenter, kodning eller test
// Målinger eller observationer
// Ikke det samme som Scrum eller XP
//
// > Metoden skal forklar, hvordan I vil gå fra spørgsmål til svar. Det er ikke
// > nok at skrive "jeg laver et program". I skal forklare, hvad programmet skal
// > bruges til at undersøge, hvad I måler eller observerer, og hvordan I bruger
// > resultaterne til at svare på problemformuleringen.

For finde svar på disse spørgsmål vil jeg først og fremmest udvikle en simpel reverse
proxy. Den kommer ikke til at have samme omfang som eksisterende løsninger som Nginx,
Caddy, Traefik osv. Reverse proxyen vil kun sørge for at viderstille et kald til
en anden service. Det kan enten være lokalt eller på en anden server, så længe at
enheden reverse proxyen kører på, har HTTP adgang til destinationen. Udvidelserne
vil kunne forbinde på forskellige hooks applikationen kalder igennem applikationens
levetid. Reverse proxyen bliver udviklet så `WASM` og `FFI` kan slås til og fra via
feature flags @rust-lang-docs-features, så selve koden for hver af måderne at loade
udvidelser på, slet ikke bliver kompileret. Det sikrer at den ene implementation ikke
påvirker den anden under tests. Begge implementationer kører dog over samme
trait @rust-lang-docs-traits hvilket gør at applikationen stadig forholder sig
til én måde at kalde extensionsne på.

FFI extensions bliver loadet med `libloading` @docs-libloading, der hjælper med at
loade eksterne libraries dynamisk med mindre unsafe kode. `libloading` hjælper abstraherer
nogle ting væk der gør det lettere at arbejde med.

WASM extensions bliver loadet og kørt med `wasmtime`, der er et api
til at interagere med WASM moduler. `wasmtime` er designet til at
den der implementerer craten skal bruge minimalt `unsafe` kode @docs-wasm-time.

= Planlægning

// - Liste aktiviteter i rækkefølge
// - Angiv hvor lang tid hver aktivitet tager
// - Planlæg både undersøgelse og skrivning
// - Sæt tid af til test, analyse og reflektion
// - Lav evt. en kalender med datoer
//
// > Planen skal vise, at I kan nå hele processen. Det er ikke nok at skrive,
// > hvornår I vil kode. I skal også planlægge teori, praktisk arbejde, test,
// > analyse, konklusion, reflektion og forberedelse til den mundtlige eksamen.

Her er en tabel med estimeret tid per opgave. Opgaverne er skrevet i en estimeret
rækkefølge, altså bliver der måske rykket rundt imens det hele bliver udført.

#table(
  columns: (1fr, auto),
  inset: 8pt,
  align: horizon,
  table.header([*Aktivitet*], [*Estimeret tid*]),
  [Basic Reverse Proxy], [2 timer],
  [Config parsing for reverse proxyen], [2 timer],
  [WASM og FFI protocol og integration], [6 timer],
  [Test server reverse proxy kan forwarde til], [3 timer],
  [Test om applikation lever op til målene], [2 timer],
)

= Arbejdet

// - Beskriv hvad du har gjort for at besvare dine spørgsmål
// - Vis både teori og praktisk arbejde
// - Dokumentér tests, målinger eller observationer
// - Forklar hvad resultaterne betyder
// - Kobl resultaterne til problemformuleringen
//
// > Her skal I ikke bare vise kode, screenshots eller tabeller. I skal forklare,
// > hvad arbejdet viser, og hvordan det hjælper jer med at svare på problemformuleringen.

Det første der blev udviklet var selve config parsing og reverse proxyen. Det er
i bund og grund rigtig simpelt, da den kun forwarder enhver request til en anden
destination.

= Konklusion

// - Svar på underspøgsmålene
// - Svar på hovedspørgsmålet
// - Byg på dine resultater og din analyse
// - Kort perspektivering: kan din viden bruges andre steder?
// - Åbn ikke nye emner her
//
// > Konklusionen skal samle trådene. I skal ikke skrive noget helt nyt her. I skal
// > bruge de resultater og observationer, I allerede har præsenteret, til at svare
// > på problemformuleringen.

= Reflektion

// - Var problemformuleringen skarp nok?
// - Var metoden god nok?
// - Var planen realistisk?
// - Var tests og målinger præcise nok?
// - Hvad ville du gøre anderledes næste gang?
//
// > Reflektion er ikke det samme som konklusion. I konklusionen svarer i på problemformuleringen.
// > I reflektionen vurderer I jeres egen proces, metode og afgrænsning. Det er
// > helt fint at skrive, hvad der ikke virkede, hvis I også forklarer, hvad I har
// > lært af det.

= Referencer

// - Liste alle kilder korrekt
// - Brug kilder aktivt i teksten
// - Bøger: forfatter, titel, forlag, årstal, hvordan brugt
// - Web: titel, evt. forfatter/organisation, URL, besøgsdato, hvordan brugt
// - En URL alene er ikke nok
//
// > Referencer skal vise, hvor jeres teori og faglige viden kommer fra. Det er
// > ikke nok at samle links til sidst. IO skal også genvise til kilderne i teskten,
// > når I bruger teori, definitioner eller dokumentation.

#bibliography("bib.yaml", title: none, style: "ieee", full: true)
