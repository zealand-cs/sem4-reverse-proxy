#import "./template.typ": synopsis
#import "@preview/wordometer:0.1.5": total-characters, total-words, word-count
#import "@preview/lilaq:0.6.0" as lq

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

#show: word-count.with(counter: string-word-count, exclude: (raw,))
#set text(lang: "da")
#show: synopsis.with(
  author: "William K. G. Jelgren",
  email: "wij001@edu.zealand.dk",
  title: "Modulær reverse proxy med WASM og FFI i Rust",
  abstract: none,
  total-characters: total-characters,
)


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
for tredjeparter til at bruge netop dit projekt. Plugin-systemer er et meget velkendt
fænomen i softwareverdene, fra Nginx-moduler til VS Code-udvidelser til Minecraft
Servere, og hvordan disse implementeres bagved er ikke nødvendighvis triviel.

En reverse proxy sidder foran én eller flere services og viderestiller indgående
HTTP-kald fra klienten. Det er en meget central byggesten i moderne infrastruktur,
og er et godt udgangspunkt for at undersøge hvordan et eksisterende system kan
udvides @reverse-proxy-wiki.

To udbredte teknologier til dette er `FFI` og `WASM`. `FFI` (Foreign Function Interface)
gør det muligt at kalde funktioner i et eksternt, native library direkte, og på
tværs af programmeringssprog @ffi-wiki. `WASM` (WebAssembly) er et åbent binært format, oprindeligt
designet til brug i browsere, men bliver i dag også brugt server-side som et sandboxet
miljø til eksekvering af eksterne moduler @wasm-wiki. Begge kan bruges til at loade
og køre ekstern kode, men de adskiller sig i implementering, sikkerhed og ydelse.

I dette projekt udvikles der en reverse proxy i Rust, der understøtter udvidelser
via begge teknologier. Udvidelserne skrives ligeledes i Rust, så implementeringsforskellene
ikke defineres af sproglige faktorer. Denne synopse unsersøegr og sammenligner de
to tilgange i forhold til implemnenteringskompleksitet, hastighed og hukommelsesforbrug.


= Motivation

// - Hvorfor har du valgt emnet?
// - Hvorfor er det interessant for dig?
// - Hvorfor er det relevant for it-branchen, virksomheder eller brugere?
// - Hvordan hænger emnet sammen med dit valgfag?
//
// > Motivation er ikke kun "jeg synes emnet er spændende". I skal også forklare,
// > hvorfor emnet er relevant fagligt. Det kan være i forhold til sikkerhed, performance,
// > systemudvikling, Rust, netværk, embedded, web eller andre områder fra valgfaget.

Jeg har længe interesseret mig for hvordan programmer og libraries kan kommunikere
lokalt sammen med så lille et ressourceaftryk som muligt. Det skal også gerne være
nemt for udvikleren at integrere med andet software, men dette skal ikke være
på bekostning af den computerkraft vi har til rådighed.

En måde at udvide et programs funktionalitet på, uden at rekompilere selve programmet,
er ved brug af et plugin-system. Det kan have store fordele i flere forskellige situationer:
når et program har lange kompileringstider, når kildekoden er proprietær eller for
bekvemmeligheden af slutbrugeren.

Proprietære programmer kan ved brug af et sådant plugin-system udvides med brugerskabt
kode og fx danne "marketplaces", uden at hovedapplikationens kildekode er åbent tilgængelig.
Dette kan åbne forretningsmuligheder og offloade udvikling fra virksomheden til
brugerbasen. Derfor er det også vigtigt at kunne integrere plugins sikkert, med en
acceptabel balance mellem udviklernes bekvemmelighed og effektivt software.

Rust er i denne sammenhæng et oplagt valg til at bygge en plugin-host, da sproget
giver memory safety uden en garbage collector, hvilket gør det muligt at skrive
præcis og forudsigelig kode, også når man arbejder tæt på operativsystemet som
ved dynamisk indlæsning af ekstern kode.

`FFI` og `WASM` ligger i to forskellige ender af et spektrum der består af tillid
og sikkerhed. `FFI` giver direkte adgang til native kode med minimalt overhead,
hvorimod `WASM` isolerer extensions i et sandboxet miljø på bekostning af ekstra
kompleksitet. Dette gør dem interessante at sammenligne med hinanden med henblik
på udvidelse af software.

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
  througput og hukommelsesforbrug?

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

Første underspørgsmål til problemformuleringen bliver besvaret i form at at selve
applikationen bliver udviklet og køres. Det er også første krav for at kunne besvare
underspørgsmål to og tre. Underspørgsmål 2 besvares efter applikationen er udviklet,
ved at kigge på koden. Bl.a. kan antallet af linjer kode, keywords og andre indikatorer
bruges til at tjekke hvad foreskellene på `WASM` og `FFI` for en udvikler er.

For at besvare underspørgsmål 3, bliver vi nødt til at benchmarke applikationen
i forskellige stadier. Benchmarks der tester de forskellige parametre vil blive
kørt ved en blanding af manuelt Bash scripts og programmer som hyperfine @hyperfine-github
og oha @oha-github.

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
  columns: (1fr, auto, auto),
  inset: 8pt,
  align: horizon,
  table.header([*Aktivitet*], [*Estimeret tid*], [*Note*]),
  [Planlægning], [0,5 dag], [],
  [Introduktion og motivation], [0,5 dag], [],
  [Problemformulering], [1 dag], [Inkl. bekræftelse],
  [Basic Reverse Proxy], [1 dag], [],
  [Config parsing for reverse proxyen], [0,5 dag], [],
  [WASM og FFI protocol og integration], [2 dage], [],
  [Test server reverse proxy kan forwarde til], [0,5 dag], [],
  [Benchmarking], [1 dag], [],
  [Undersøgelse af om spørgsmålene er besvaret], [2 dage], [],
  [Reflektion], [1 dag], [],
  [Præsentation til mundtlig eksamination], [1 dag], [],
  [Forberedelse til mundtlig eksamen], [3 dage], [],
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

For at kunne implementerer noget som helst med ekstensions må grundstenene på plads
først. Det omhandler parsing af konfiguration, sætte en async-runtime op og så
reelt route requests til destinationer.

Konfigurationen skrives i KDL @docs-kdl, og definerer hvilke extensions der skal
indlæses og hvilke ruter der proxyes til hvor. `tokio` bruges som async-runtime
og `hyper` kommer til at håndtere HTTP. Feature flags @rust-lang-docs-features sørger
for at `WASM`- og `FFI`-koden kompileres når de skal bruges. Dette sikrer at de
to implementationer ikke påvirker hinanden på nogen måde under tests og benchmarking.

== Extension interface <extension-trait>

For at både `FFI` og `WASM` bliver brugt på akkurat samme måde i proxyens kode,
implementeres begge gennem et `Extension` trait @rust-lang-docs-traits. Traiten
definerer nogle forskellige hooks: `on_load`, `on_unload`, `on_request`, `on_response`,
og `on_error`. Extensions definerer så med en bitmask hvilke hooks de vil reagere
på. Ved at bruge en bitmask kan man undgå unødvendige kald til extensions der ikke
har nogen intensioner om at blive kaldt på specifikke hooks, og derved undgå at
krydse mellem `WASM` eller andet eksternt sprog når det ikke er nødvendigt. En hook
returnerer så en `HookResult` der enten er `Continue`, `Replace` eller `Error`.
`Continue` bruges når alt forløb successfuldt og kan ændre headers og/eller body,
`Replace` er et helt nyt svar og `Error` er når der sker en fejl.

For at kommunikere mellem proxy og extensions bruges der MessagePack @docs-rmp-serde,
der serialiserer request og response-kontekster til binære buffere. Ved at bruge
MessagePack simplificerede vi dette projekts implementation, men kan i fremtiden
også betyde at man kan skrive ekstensions i andre sprog der har MessagePack implementeret.

Runtime-performance ville evt. kunne forbedres ved at bruge en custom protokol istedet.
Dette er dog ikke målet for projektet, så længe `WASM` og `FFI` er på lige fod.

== FFI implementering

Filen `src/extensions/ffi.rs` indeholder ca. 200 linjer kode og er alt kode specifik
til implementering af FFI. Filen beskriver primært structen `FfiExtension` der
implementerer `Extension` trait.

```rust
#[allow(dead_code)]
pub struct FfiExtension {
    _lib: Library,
    name: String,
    version: String,
    capability_mask: u32,
    fn_on_load: unsafe extern "C" fn(),
    fn_on_unload: unsafe extern "C" fn(),
    fn_on_request: Option<unsafe extern "C" fn(*const u8, u32) -> FfiPluginBuffer>,
    fn_on_response: Option<unsafe extern "C" fn(*const u8, u32) -> FfiPluginBuffer>,
    fn_on_error: Option<unsafe extern "C" fn(*const u8, u32) -> FfiPluginBuffer>,
    fn_free: unsafe extern "C" fn(*mut u8, u32),
}
```

`FfiExtension` indeholder bl.a. vores `Library` fra
`libloading` som er, ifølge dokumentationen, "et loaded dynamisk library". Selvom
denne property ikke bliver brugt i koden er det nødvendigt at opbevare den, da `Library`
implementerer `Drop`-traiten der kalder `dlclose` på Linux systemet, hvilket er
en funktion implementeret i styresystemet, der unloader et dynamic library @dlclose-linux-man.
Fra Linux man pages, omkring `dlclose`:

"Once a symbol table handle has been closed [with `dlclose`], an application should
assume that any symbols (function identifiers and data object
identifiers) made visible using handle, are no longer available to
the process."

For os betyder dette at selvom vi har fået referencerne til vores symboler i extensionen,
og at Rust's compiler ikke brokker sig, kan vi altså ikke antage at symbolerne stadig
eksisterer, efter at `Drop`-traiten bliver kaldt, hvilket den gør når `Library` ryger
ud af gyldigt scope @rust-drop-trait.

Data fra hooks der bliver kaldt i en extension, bliver returneret i form af `FfiPluginBuffer`.
I `C` er variable længder af data (fx `string`) beskrevet med en pointer og en længde.
Det samme gør vi her for at læse bytes fra en specifik lokation i hukommelsen. Det
bytes der ligger på denne lokation i hukommelsen bliver læst og derefter decoded,
som defineret i `protocol`. Dette bliver offloadet til `rmp_serde` og er derfor
ikke i dette projekts scope at implementere.

```rust
#[repr(C)]
pub struct FfiPluginBuffer {
    pub ptr: *mut u8,
    pub len: u32,
}
```

Efter af denne buffer er blevet læst og decoded til en Rust struct der er nemmere
at arbejde med, skal denne buffer frigøres i hukommelsen så vi ikke får et memory
leak. Det gør vi med `fn_free` (defineret i `FfiExtension`), hvilket er en funktion der skal
implementeres i alle ffi extensions. `fn_free` sørger så for at frigøre hukommelsen der
er blevet allokeret for `FfiPluginBuffer`. Vi arbejder altså med to forskellige
grader af tillid, at applikationen anmoder om at frigøre hukommelsen korrekt og
at extensionen så faktisk frigører hukommelsen korrekt.

Implementeringen af `Extension` for `FfiExtension` sørger for at kalde de rigtige
symboler i vores extension for specifikt FFI implementationen og sørger også for at
applikationen har Rust-typer at arbejde med, i stedet for rå `C` typer @extension-trait.
Den sørger også for at kalde `fn_free` på det rigtige tidspunkt.

== WASM implementering

Filen `src/extensions/wasm.rs` indeholder ca. 300 linjer kode og er alt kode specifikt
til implementering af WASM.

// TODO

== Test-extensions

For at kunne sammenligne parametrene på `FFI` og `WASM`, er to extensions med
identisk funktionalitet blevet skrevet: `log-ffi` og `log-wasm` hhv. `FFI` og `WASM`
som target. Begge extensions registrerer `ON_REQUEST`, deserialiserer konteksten
og printer diverse detaljer om requesten i terminalen, og returnerer en `Continue`.

Målet med disse to plugins er ikke at teste performance af WASM kode og FFI kode selv,
men i stedet forbindelserne mellem hovedapplikationen og extensionsne og se hvor meget
overhead dette bringer. Derfor er selve extensionsne meget simple uden nogen brugbar
funktionalitet for en slutbruger, da loggingen ikke kan customizes, skrives til filer
osv.

== Benchmarks

Benchmarks er blevet implementeret ved hjælp af `hyperfine` og `oha`. Benchmarks
kan blive kørt ved at køre `cargo make bench-all`. Alle resultater vil
blive skrevet til `results/` mappen i roden af repositoriet. Disse resultater vil
hjælpe med at besvare underspørgsmål 3. Herunder vil resultaterne vises i form af
grafer. Graferne er genereret med `lilaq` @lilaq-homepage, et library til `Typst`
@typst-app. #footnote[
  Alle benchmarks er kørt på en bærbar
  laptop (ASUS ZenBook model UM431D fra 2020) med Linux (NixOS). MacOS og Windows
  (og dermed WSL) er ikke testet og jeg kan derfor ikke garantere at resultaterne
  kan repoduceres på disse styresystemer. På trods af dette er resultaterne så
  klare på dette system at jeg antager der vil være samme tendens på andre systemer.
]

#let _s_noplugins = json("results/startup_no-plugins.json").results.at(0)
#let _s_ffi = json("results/startup_ffi.json").results.at(0)
#let _s_wasm = json("results/startup_wasm.json").results.at(0)

#let s_means = (_s_noplugins.mean * 1000, _s_ffi.mean * 1000, _s_wasm.mean * 1000)
#let s_stddevs = (_s_noplugins.stddev * 1000, _s_ffi.stddev * 1000, _s_wasm.stddev * 1000)

#figure(
  lq.diagram(
    width: 10cm,
    height: 6cm,
    yaxis: (label: [Opstartstid (ms)]),
    xaxis: (
      ticks: ((0, [no-plugins]), (1, [ffi]), (2, [wasm])),
      subticks: none,
    ),
    legend: (position: right + top),
    lq.bar((0,), (s_means.at(0),), width: 0.6, fill: blue.lighten(20%), label: [no-plugins]),
    lq.bar((1,), (s_means.at(1),), width: 0.6, fill: green.lighten(20%), label: [ffi]),
    lq.bar((2,), (s_means.at(2),), width: 0.6, fill: red.lighten(20%), label: [wasm]),
    lq.plot((0,), (s_means.at(0),), yerr: (s_stddevs.at(0),), stroke: none, mark: none, color: black),
    lq.plot((1,), (s_means.at(1),), yerr: (s_stddevs.at(1),), stroke: none, mark: none, color: black),
    lq.plot((2,), (s_means.at(2),), yerr: (s_stddevs.at(2),), stroke: none, mark: none, color: black),
  ),
  caption: [Opstartstid for de tre varianter (gennemsnit ± stddev, n=10) (lavere er bedre)],
) <fig-startup>

På <fig-startup> ser vi at FFI næsten ikke tilføjer overhead til opstartstiden,
mens WASM er 4,4 gange langsommere at starte. Dette er primært fordi `wasmtime`
JIT-kompilerer modulet ved load.

#let _l_noplugins = json("results/load_no-plugins.json")
#let _l_ffi = json("results/load_ffi.json")
#let _l_wasm = json("results/load_wasm.json")

#let _lp(d, p) = d.latencyPercentiles.at(p) * 1000
#let _bar_w = 0.25

#figure(
  lq.diagram(
    width: 11cm,
    height: 6cm,
    yaxis: (label: [Svartid (ms)]),
    xaxis: (
      ticks: ((0, [p50]), (1, [p90]), (2, [p99])),
      subticks: none,
    ),
    legend: (position: left + top),
    lq.bar(
      (0, 1, 2),
      (_lp(_l_noplugins, "p50"), _lp(_l_noplugins, "p90"), _lp(_l_noplugins, "p99")),
      offset: -_bar_w,
      width: _bar_w,
      fill: blue.lighten(20%),
      label: [no-plugins],
    ),
    lq.bar(
      (0, 1, 2),
      (_lp(_l_ffi, "p50"), _lp(_l_ffi, "p90"), _lp(_l_ffi, "p99")),
      offset: 0,
      width: _bar_w,
      fill: green.lighten(20%),
      label: [ffi],
    ),
    lq.bar(
      (0, 1, 2),
      (_lp(_l_wasm, "p50"), _lp(_l_wasm, "p90"), _lp(_l_wasm, "p99")),
      offset: _bar_w,
      width: _bar_w,
      fill: red.lighten(20%),
      label: [wasm],
    ),
  ),
  caption: [Svartidspercentiler (p50, p90, p99) under load (10 000 requests) (lavere er bedre)],
) <fig-load-latency>

#figure(
  lq.diagram(
    width: 10cm,
    height: 6cm,
    yaxis: (label: [Requests/sek]),
    xaxis: (
      ticks: ((0, [no-plugins]), (1, [ffi]), (2, [wasm])),
      subticks: none,
    ),
    lq.bar((0,), (_l_noplugins.rps.mean,), width: 0.6, fill: blue.lighten(20%)),
    lq.bar((1,), (_l_ffi.rps.mean,), width: 0.6, fill: green.lighten(20%)),
    lq.bar((2,), (_l_wasm.rps.mean,), width: 0.6, fill: red.lighten(20%)),
    lq.plot((0,), (_l_noplugins.rps.mean,), yerr: (_l_noplugins.rps.stddev,), stroke: none, mark: none, color: black),
    lq.plot((1,), (_l_ffi.rps.mean,), yerr: (_l_ffi.rps.stddev,), stroke: none, mark: none, color: black),
    lq.plot((2,), (_l_wasm.rps.mean,), yerr: (_l_wasm.rps.stddev,), stroke: none, mark: none, color: black),
  ),
  caption: [Gennemsnitlig requests/sek under load (gennemsnit ± stddev) (højere er bedre)],
) <fig-load-rps>

På @fig-load-rps ses det at throughput falder med 28,8 % for `FFI` og 37,9 % for
`WASM` sammenlignet med baseline. Der er ~#calc.round(37.9 - 28.8)%-point forskel
på `FFI` og `WASM`.

#let _mem_raw = read("results/memory_peak.txt")
#let _mem_lines = _mem_raw.trim().split("\n")
#let _mem_val(line) = float(
  line.split(regex("\s+")).filter(p => p != "").at(-2),
)
#let mem_noplugins_mb = _mem_val(_mem_lines.at(0)) / 1024
#let mem_ffi_mb = _mem_val(_mem_lines.at(1)) / 1024
#let mem_wasm_mb = _mem_val(_mem_lines.at(2)) / 1024

#figure(
  lq.diagram(
    width: 10cm,
    height: 6cm,
    yaxis: (label: [Hukommelsesforbrug (MB)]),
    xaxis: (
      ticks: ((0, [no-plugins]), (1, [ffi]), (2, [wasm])),
      subticks: none,
    ),
    lq.bar((0,), (mem_noplugins_mb,), width: 0.6, fill: blue.lighten(20%)),
    lq.bar((1,), (mem_ffi_mb,), width: 0.6, fill: green.lighten(20%)),
    lq.bar((2,), (mem_wasm_mb,), width: 0.6, fill: red.lighten(20%)),
  ),
  caption: [Peak RSS-hukommelsesforbrug for de tre varianter (lavere er bedre)],
) <fig-memory>

Hukommelsesforbruget er marginalt for FFI (+564 kB), men markant større for
WASM (+34,5 MB), da `wasmtime`-runtimen og den JIT-kompilerede kode fylder meget.

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

Vi kan konkludere at selve reverse proxyen i sig selv, ikke er specielt advanceret
at designe, men til gengæld opstår der udfordringer når eksisterende systemer skal
udvides.

1. Hvordan kan en reverse proxy i Rust udvides med plugins via henholdsvis WASM og FFI?

En reverse proxy kan udvides relativt hurtigt ved brug af eksisterende crates i
Rust økosystemet. De essentielle crates der sørger for at selve reverse proxyen
fungerer er: `tokio`, `hyper`, `http-body-util`, `hyper-util` og `bytes`.

`libloading` hjælper med at læse FFI extensions og `wasmtime` læser, compilerer og
eksekverer WASM moduler. Disse to crates bliver implementeret relativt minimalistisk
i separate moduler, der er wired sammen med et fælles trait som reverse proxyen
anvender. Noget af det første reverse proxyen gør når den starter, er at parse
konfigurationen og derefter loade extensions der er defineret i samme konfiguration.

Extensionsne kan "subscribe" på forskellige hooks som reverse proxyen kalder.
Extensionsne kan gøre som de vil med de detaljer som reverse proxyen giver igennem
hooken.

2. Hvilke forskelle er der mellem `WASM` og `FFI` i forhold til kodekompleksitet,
  læsbarhed og udviklingsoplevelse?

Baseret på antallet af linjer kode (`WASM`: ca. 300, `FFI`: ca. 200), og komplexiteten
som `wasmtime` dækker over, er `WASM` væsentligt mere kompliceret at implementere
i nogen som helst applikationer end `FFI`. `WASM` har mere boilerplate end `FFI`,
for at få en basal extension til at køre. Men dette er ikke uhørt, da `WASM` dækker
over meget mere end `FFI`. `FFI` er et (relativt) simpelt kald til et ekstern library
hvorimod bare at køre `WASM`-kode kræver en JIT-kompilering og en runtime, hvilket
`wasmtime` sørger for.

// TODO expand wasm after wasm section has been written

3. Hvordan adskiller WASM- og FFI-baserede udvidelser sig i forhold til svartid,
  CPU-forbrug og hukommelsesforbrug?

Baseret på analysen og benchmarksne vinde `FFI` i alle tilfælde over `WASM`.
`FFI` implementeringen start hurtigere, svarer hurtigere, større throughput og
væsentligt mindre hukommelsesforbrug. `FFI` lægger side om side med barebones
reverse proxyen der ikke indeholder nogen form for extensions.

// TODO more explanation?

Da `FFI` og `WASM` er implementeret gennem ét interface opstår der potentielt flere
bottlenecks, da man skal finde "lowest common denominator", altså kan den ene implementation
stadig godt være begrænset af den anden ved dybere analyse. Et eksempel på dette
er bl.a. brugen af MessagePack (`rmp_serde`) som er nødvendigt for denne `WASM` implementation,
men ikke nødvendig for `FFI` integrationer hvor man simpelt kan læse rå pointers
i stedet. Der er altså et unødvendigt sterilizerings-step i `FFI` integrationen
der måske gør `FFI` langsommere. Dette kan også forklare den relativt store forskel
på throughput mellem `FFI` og `no-plugins` som set på @fig-load-rps. Det ændrer
dog ikke udfaldet for sammenligningen mellem `WASM` og `FFI` brugt som extensions
da `FFI` stadig vinder alle benchmarks imod `WASM`.

---


Disse delkonklusioner hjælper os til at besvare den overordnede problemformulering:

Hvordan kan en simpel reverse proxy i Rust designes til at understøtte udvidelser
via `WASM` og `FFI`, og hvordan adskiller de to tilgange sig i forhold til implementering,
udviklingskompleksitet, performance og ressourceforbrug?

// TODO

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

Problemformuleringen dækkede godt over projektet, men det er et rigtig stort emne.
`WASM` og `FFI` integrationer er en stor verden hver for sig, så at samle dem i
ét projekt kunne godt være udfordrende. På trods af at scopet var større end projektets
tid tillod, var problemformuleringen bred nok til at undersøge relevante emner inden
for faget. Min motivation for dette projekt blev også dækket og de tanker jeg fremhævede
dér blev undersøgt tilstrækkeligt. Dette inkluderer bl.a. grøn omstilling ved at
udnytte vores enheder til det fulde, at udvide programmer uden for dets egne rammer.

En anden note er at `WASM` og `FFI` er to vidt forskellige tilgange og i dybden,
næsten ikke sammenlignelige. Selvfølgelig kan begge to bruges til at lave udvidelser
til diverse applikationer, men de er to vidt forskellige teknologier. `FFI` er
en mekanisme der gør at forskellige programmeringssprog kan tale sammen @ffi-wiki,
hvorimod `WASM` er en åben standard der beskriver et "portable binary code" format
og et tilsvarende tekst format for eksekverbare programmer, der er designet til
at køre i en browser, med mulighed for at køre det i andre miljøer @wasm-wiki.


// - Liste alle kilder korrekt
// - Brug kilder aktivt i teksten
// - Bøger: forfatter, titel, forlag, årstal, hvordan brugt
// - Web: titel, evt. forfatter/organisation, URL, besøgsdato, hvordan brugt
// - En URL alene er ikke nok
//
// > Referencer skal vise, hvor jeres teori og faglige viden kommer fra. Det er
// > ikke nok at samle links til sidst. I skal også henvise til kilderne i teskten,
// > når I bruger teori, definitioner eller dokumentation.

#bibliography("bib.yaml", style: "ieee", full: true)
