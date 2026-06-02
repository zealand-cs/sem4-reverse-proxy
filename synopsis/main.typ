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

#show: word-count.with(counter: string-word-count, exclude: (raw.where(block: true),))
#set text(lang: "da")
#let normalsider = context (str(calc.round(state("wordometer").final().characters / 2400, digits: 1)).replace(".", ","))
#show: synopsis.with(
  author: "William K. G. Jelgren",
  email: "wij001@edu.zealand.dk",
  title: [Plugin-arkitektur i Rust: #linebreak() FFI vs. WASM i modulær software],
  abstract: none,
  date: datetime(year: 2026, month: 06, day: 05),
  character-count: total-characters,
  normalsider: normalsider,
  institution: [Zealand - Sjællands Erhvervsakademi],
  programme: [Datamatiker],
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
// > Det vigtigste er, at I viser, hvad I undersøger, hvordan I undersøger det, og
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
fænomen i softwareverdenen, fra Nginx-moduler til VS Code-udvidelser til Minecraft
servere, og hvordan disse implementeres bagved er ikke nødvendigvis triviel.

En reverse proxy sidder foran én eller flere services og viderestiller indgående
HTTP-kald fra klienten. Det er en meget central byggesten i moderne infrastruktur,
og er et godt udgangspunkt for at undersøge hvordan en applikation kan
udvides @reverse-proxy-wiki.

To udbredte teknologier til dette er `FFI` og `WASM`. `FFI` (Foreign Function Interface)
gør det muligt at kalde funktioner i et eksternt, native library direkte, og på
tværs af programmeringssprog @ffi-wiki. `WASM` (WebAssembly) er et åbent binært format, oprindeligt
designet til brug i browsere, men bliver i dag også brugt server-side som et sandboxet
miljø til eksekvering af eksterne moduler @wasm-wiki.

Begge kan bruges til at loade og køre ekstern kode, men de adskiller sig i
implementering, sikkerhed og ydelse. I dette projekt udvikles der en reverse proxy
i Rust, der understøtter udvidelser via begge teknologier. Udvidelserne skrives ligeledes i Rust, så implementeringsforskellene
ikke defineres af sproglige faktorer. Denne synopse undersøger og sammenligner de
to tilgange i forhold til implementeringskompleksitet, hastighed og hukommelsesforbrug.


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
via `FFI` og `WASM`, og hvordan adskiller de to tilgange sig i forhold til implementering,
udviklingskompleksitet, performance og ressourceforbrug?

Følgende underspørgsmål vil blive undersøgt i forbindelse med problemformuleringen:

1. Hvordan kan en reverse proxy i Rust udvides med plugins via henholdsvis `WASM` og `FFI`?

2. Hvilke forskelle er der mellem `FFI` og `WASM` i forhold til kodekompleksitet,
  læsbarhed og udviklingsoplevelse?

3. Hvordan adskiller `FFI`- og `WASM`-baserede udvidelser sig i forhold til svartid,
  throughput og hukommelsesforbrug?

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

For at finde svar på disse spørgsmål udvikles en simpel reverse proxy der muliggør
en direkte sammenligning af de to tilgange. Den kommer ikke til at have samme omfang
som eksisterende løsninger som Nginx, Caddy og Traefik. Den kommer udelukkende til
at viderestille HTTP-kald til en bagvedliggende service. Udvidelserne kobler sig
på applikationen via hooks som applikationen kalder gennem sin levetid.

For at sikre at de to implementationer ikke påvirker hinanden under tests, bruges
feature flags @rust-lang-docs-features til at slå `FFI` og `WASM`-koden til og fra
ved kompilering. Begge implementeringer vil køre gennem én trait @rust-lang-docs-traits,
så applikationen forholder sig til én ensartet måde at kalde extensions på.

`FFI` extensions bliver indlæst med `libloading`, der giver en sikker
og idiomatisk grænseflade til dynamisk indlæsning af native libraries @docs-libloading.
Det abstraherer diverse platform-specifikke kald som `dlopen`/`LoadLibrary` væk
og minimerer mængden af `unsafe` kode i projektet. `WASM` extensions indlæses, JIT-kompileres
og eksekveres med `wasmtime` @docs-wasm-time, der ligeledes er designet til at minimere `unsafe`
kode for den der implementerer traiten.

For at sammenligningen er fair, vil to test-extensions, `log-ffi` og `log-wasm`
udvikles, med identisk funktionalitet. Begge logger request-detaljer og viderestiller
requesten uændret. Det betyder at eventuelle forskelle i benchmarks vil skyldes
integrationerne af `FFI` og `WASM` i applikationen og ikke selve extension-koden.

Første underspørgsmål besvares i form af at applikationen udvikles og køres. Det
er også en forudsætning for at svare på underspørgsmål to og tre. Underspørgsmål
to besvares ved at analysere koden efter implementeringen er færdig. I denne analyse
vil der blive brugt konkrete indikatorer som antal linjer, antal `unsafe` blokke
og mængden af boilerplate til at vurdere forskellene i kodekompleksitet og
udviklingsoplevelse.

For at besvare underspørgsmål tre vil applikationen blive benchmarket i tre varianter:
uden extensions, med `FFI` og med `WASM`. Benchmarks køres via `cargo make` @cargo-make-github
med værktøjerne `hyperfine` @hyperfine-github til at måle opstartstider og `oha` @oha-github
til svartider, throughput og hukommelsesforbrug.

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
  [Planlægning og research], [3 timer],
  [Opsætning af Rust-projekt, Nix og tooling], [2 timer],
  [Synopsis: Introduktion, motivation og problemformulering], [5 timer],
  [Synopsis: Metodeafsnit], [3 timer],
  [Implementering: Konfigurationsparsing og routing], [5 timer],
  [Implementering: Extension trait og MessagePack-protokol], [4 timer],
  [Implementering: `FFI`-integration med `libloading`], [6 timer],
  [Implementering: `WASM`-integration med `wasmtime`], [8 timer],
  [Implementering: Demo-server], [2 timer],
  [Implementering: Test-extensions (`log-ffi`, `log-wasm`)], [3 timer],
  [Benchmarking-setup og kørsel (`hyperfine`, `oha`)], [5 timer],
  [Synopsis: Reverse proxy-afsnit], [3 timer],
  [Synopsis: `FFI`- og `WASM`-afsnit], [6 timer],
  [Synopsis: Benchmarkanalyse og grafer], [4 timer],
  [Synopsis: Konklusion og perspektivering], [4 timer],
  [Synopsis: Refleksion], [2 timer],
  [Rettelser og forbedringer efter feedback], [3 timer],
  [Forberedelse til mundtlig eksamen], [5 timer],
  table.footer([*I alt*], [*73 timer*]),
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

For at kunne implementere noget som helst med extensions må grundstenene på plads
først. Det omhandler parsing af konfiguration, sætte en async-runtime op og så
reelt route requests til destinationer.

Konfigurationen skrives i KDL @docs-kdl, og definerer hvilke extensions der skal
indlæses og hvilke ruter der proxyes til hvor. `tokio` bruges som async-runtime
og `hyper` kommer til at håndtere HTTP. Feature flags @rust-lang-docs-features sørger
for at `WASM`- og `FFI`-koden kompileres når de skal bruges. Dette sikrer at de
to implementationer ikke påvirker hinanden på nogen måde under tests og benchmarking.

== Simpel reverse proxy

Selve reverse proxyen er implementeret i `src/router.rs` i structen `ProxyRouter`.
Dens ansvar er at tage en indkommende HTTP-request, slå den op i route-tabellen,
viderestille den til den rigtige upstream-service og returnere svaret tilbage til
klienten. Extensions indgår som en del af dette flow og kaldes på bestemte
tidspunkter via hooks som beskrevet i @extension-trait.

#figure(
  ```rust
  let host = req
      .headers()
      .get(HOST)
      .and_then(|v| v.to_str().ok())
      .map(|h| h.split(':').next().unwrap_or(h).to_string());

  let Some(host) = host else {
      return err(StatusCode::BAD_REQUEST);
  };
  let Some(rules) = self.routes.get(&host) else {
      return err(StatusCode::NOT_FOUND);
  };

  let path = req.uri().path().to_string();
  let Some((_, upstream_base)) = rules.iter().find(|(p, _)| path.starts_with(p.as_str()))
  else {
      return err(StatusCode::NOT_FOUND);
  };
  ```,
  caption: [Host-header opslag og longest-prefix route matching (`router.rs`)],
) <rust-routing>

Når en request ankommer, læses `Host`-headeren (@rust-routing) og porten strippes.
Hosten slås op i route-tabellen og stien matches mod præfix-regler sorteret efter
længde, så den mest specifikke regel vinder. Findes ingen match, returneres `404`.

#figure(
  ```rust
  let path_and_query = req
      .uri()
      .path_and_query()
      .map(|p| p.as_str())
      .unwrap_or("/");
  let upstream_url = format!("{}{}", upstream_base, path_and_query);
  ```,
  caption: [Konstruktion af upstream URL (`router.rs`)],
) <rust-upstream-url>

Upstream-URL'en (@rust-upstream-url) bygges ved at sammensætte base-URL'en fra
den matchede regel med `path_and_query` fra den indkommende request.

#figure(
  ```rust
  for ext in self.extensions.iter() {
      if !caps::has(ext.capabilities(), caps::ON_REQUEST) {
          continue;
      }
      let result = tokio::task::block_in_place(|| {
          ext.on_request(&method, &uri, &upstream_url, &req_headers, &working_body)
      });
      match result {
          HookResult::Replace { status, headers, body } => {
              return Ok(build_response(status, headers, body));
          }
          HookResult::Continue { extra_headers: h, body_override } => {
              extra_headers.extend(h);
              if let Some(b) = body_override {
                  working_body = b;
              }
          }
          HookResult::Error(msg) => {
              eprintln!("plugin on_request error: {msg}");
              return err(StatusCode::INTERNAL_SERVER_ERROR);
          }
      }
  }
  ```,
  caption: [`on_request`-hook loop inden viderestilling (`router.rs`)],
) <rust-on-request-loop>

Inden requesten sendes videre, køres `on_request`-hooks (@rust-on-request-loop)
for alle extensions med `ON_REQUEST` i deres bitmask. `Replace` stopper behandlingen
og sender svaret direkte, `Continue` akkumulerer ekstra headers og body-overrides,
og `Error` afbryder med en fejl. Selve viderestillingen sker med `hyper`'s `Client`,
og `on_error`- og `on_response`-hooks køres tilsvarende efter upstream-kaldet.

== Extension interface <extension-trait>

For at både `FFI` og `WASM` bliver brugt på akkurat samme måde i proxyens kode,
implementeres begge gennem et `Extension` trait @rust-lang-docs-traits. Traiten
definerer nogle forskellige hooks: `on_load`, `on_unload`, `on_request`, `on_response`,
og `on_error`. Extensions definerer så med en bitmask hvilke hooks de vil reagere
på. Ved at bruge en bitmask kan man undgå unødvendige kald til extensions der ikke
har nogen intentioner om at blive kaldt på specifikke hooks, og derved undgå at
krydse mellem `WASM` eller andet eksternt sprog når det ikke er nødvendigt. En hook
returnerer så en `HookResult` der enten er `Continue`, `Replace` eller `Error`.
`Continue` bruges når alt forløb succesfuldt og kan ændre headers og/eller body,
`Replace` er et helt nyt svar og `Error` er når der sker en fejl.

For at kommunikere mellem proxy og extensions bruges der MessagePack @docs-rmp-serde,
der serialiserer request og response-kontekster til binære buffere. Ved at bruge
MessagePack simplificeres dette projekts implementation, men kan i fremtiden
også betyde at man kan skrive extensions i andre sprog der har MessagePack implementeret.

Runtime-performance ville evt. kunne forbedres ved at bruge en custom protokol istedet.
Dette er dog ikke målet for projektet, så længe `WASM` og `FFI` er på lige fod.

#figure(
  ```rust
  pub trait Extension: Send + Sync {
      fn name(&self) -> &str;
      fn version(&self) -> &str;

      fn capabilities(&self) -> u32;

      fn has_capability(&self, cap: u32) -> bool {
          caps::has(self.capabilities(), cap)
      }

      fn on_load(&self);
      fn on_unload(&self);
      fn on_request(
          &self,
          method: &str,
          uri: &str,
          upstream_url: &str,
          headers: &[(String, String)],
          body: &[u8],
      ) -> HookResult;
      fn on_response(&self, status: u16, headers: &[(String, String)], body: &[u8]) -> HookResult;
      fn on_error(&self, status: u16, upstream_url: &str) -> HookResult;
  }
  ```,
  caption: [`Extension` trait (kommentarer fjernet)],
) <rust-extension-trait>

@rust-extension-trait viser trait-definitionen. `name` og `version` returnerer
metadata, `capabilities` returnerer en bitmask der angiver hvilke hooks extensionen
abonnerer på, og `has_capability` (automatisk implementeret af traiten) hjælper
proxyen med at undgå unødvendige kald.

#figure(
  ```rust
  pub enum HookResult {
      Continue {
          extra_headers: Vec<(String, String)>,
          body_override: Option<Vec<u8>>,
      },
      Replace {
          status: u16,
          headers: Vec<(String, String)>,
          body: Vec<u8>,
      },
      Error(String),
  }
  ```,
  caption: [`HookResult` enum (kommentarer fjernet)],
) <rust-hook-result-enum>

HookResult-enumen (@rust-hook-result-enum) bruges som returværdi fra alle hook-metoder.
`Continue` signalerer at requesten skal fortsætte, evt. med ændrede headers eller
body. `Replace` returnerer et helt nyt svar, og `Error` indikerer en fejl.

#figure(
  ```rust
  pub mod caps {
      pub const ON_REQUEST: u32 = 0b001;
      pub const ON_RESPONSE: u32 = 0b010;
      pub const ON_ERROR: u32 = 0b100;

      pub fn has(mask: u32, cap: u32) -> bool {
          mask & cap != 0
      }
  }
  ```,
  caption: [`caps` modul med bitmasks der beskriver capabilities en extension understøtter],
) <rust-caps-module>

Capabilities komponeres med bitmask-konstanter i `caps`-modulet (@rust-caps-module),
fx `ON_REQUEST | ON_RESPONSE` for en extension der vil reagere på begge.

== `FFI` implementering

Filen `src/extensions/ffi.rs` indeholder ca. 200 linjer kode og er alt kode specifik
til implementering af `FFI`. Filen beskriver primært structen `FfiExtension` der
implementerer `Extension` trait.

#figure(
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
  ```,
  caption: "FfiExtension struct",
) <rust-ffi-extension>

`FfiExtension` (@rust-ffi-extension) indeholder bl.a. `Library` fra `libloading`.
Selvom denne property ikke bruges direkte, er det nødvendigt at opbevare den, da
`Library` implementerer `Drop`-traiten der kalder `dlclose` @dlclose-linux-man og
dermed unloader det dynamiske library. Uden `Library` i structen ville symbolreferencerne
blive ugyldige når det underliggende library unloades @rust-drop-trait.

Hook-returværdier sendes som en `FfiPluginBuffer` (@rust-ffi-plugin-buffer),
der ligesom i `C` beskriver data med en pointer og en længde. Bytes læses fra
hukommelsen og decodes via `rmp_serde`.

#figure(
  ```rust
  #[repr(C)]
  pub struct FfiPluginBuffer {
      pub ptr: *mut u8,
      pub len: u32,
      pub cap: u32,
  }
  ```,
  caption: [`FfiPluginBuffer` struct],
) <rust-ffi-plugin-buffer>

`FfiPluginBuffer` indeholder `ptr`, `len` og `cap`. `cap` er nødvendig fordi
Rust's allokator kan reservere en større blok end `len`, og `fn_free` skal frigøre
præcis hvad der blev allokeret. Implementeringen af `Extension` for `FfiExtension`
konverterer de rå `C`-typer til Rust-typer @extension-trait og sørger for at kalde
`fn_free` på det rigtige tidspunkt.

== `WASM` implementering

Filen `src/extensions/wasm.rs` indeholder ca. 300 linjer kode og indeholder alt
kode specifikt til implementering af `WASM`.

`WASM`-implementeringen består af to structs. Da `wasmtime`'s `Store` er `!Sync`
@rust-lang-send-and-sync og derfor ikke kan deles mellem threads, wrappes den i en
`Mutex` i `WasmPlugin` (@rust-wasm-plugin-struct), mens selve instansen med
hook-funktioner og hukommelse ligger i `WasmExtensionInstance`
(@rust-wasm-extension-instance-struct).

#figure(
  ```rust
  #[allow(dead_code)]
  struct WasmExtensionInstance {
      store: Store<HostData>,
      memory: Memory,
      capability_mask: u32,
      fn_alloc: TypedFunc<i32, i32>,
      fn_free: TypedFunc<(i32, i32), ()>,
      fn_on_load: TypedFunc<(), ()>,
      fn_on_unload: TypedFunc<(), ()>,
      fn_on_request: Option<TypedFunc<(i32, i32), i64>>,
      fn_on_response: Option<TypedFunc<(i32, i32), i64>>,
      fn_on_error: Option<TypedFunc<(i32, i32), i64>>,
  }
  ```,
  caption: [`WasmExtensionInstance` implementering #footnote([
      Hook-funktionerne i `WASM`-modulet returnerer en `i64` frem for to separate `i32`
      værdier. Dette skyldes at multi-value returns fra Rust kompileret til `wasm32`
      ikke eksporteres korrekt, så pointer og længde pakkes i stedet ind i ét 64-bit
      heltal med lidt bit-magic: de 32 laveste bits er pointeren, de 32 højeste er længden.
      Dette er en begrænsning i `wasm32` ABI'en og dette var den simpleste løsning
      uden for meget overhead.
    ]) <wasm-i64-return>],
) <rust-wasm-extension-instance-struct>

#figure(
  ```rust
  pub struct WasmPlugin {
      name: String,
      version: String,
      capability_mask: u32,
      inner: Mutex<WasmExtensionInstance>,
  }
  ```,
  caption: [`WasmPlugin` implementering (kommentarer fjernet)],
) <rust-wasm-plugin-struct>

WASM-moduler kører i et isoleret sandboxet miljø og kan derfor ikke kalde vilkårlige
OS-funktioner. Det er host-applikationens ansvar eksplicit at eksponere de funktioner
et modul må kalde, via `wasmtime`'s `Linker`. Her eksponeres kun én enkelt host-funktion:
`env::log`, der giver extensions mulighed for at printe til værtens `stdout` ved
at sende en pointer og en længde. For `FFI` gælder det modsatte da modulet kører
i samme adresserum som applikationen og kan i princippet kalde hvad som helst.
`WASM`'s model er dermed mere strikt, men giver kontrol over hvad extensions har
adgang til.

Den mest centrale del af `WASM`-implementeringen er `call_hook` på `WasmExtensionInstance`.
Fordi modulet kører i sin egen hukommelse, kræver et hook-kald flere trin: allokér
en buffer i modulet med `plugin_alloc`, kopiér den serialiserede kontekst ind, kald
hook-funktionen med `(ptr, len)`, læs resultatet ud og frigør med `plugin_free`.
Resultatet returneres som én `i64` @wasm-i64-return. Til sammenligning kalder `FFI`
hook-funktionen direkte og modtager en `FfiPluginBuffer` tilbage.

En stor forskel er mængden af `unsafe`-kode. `WASM`-implementeringen indeholder ingen
runtime `unsafe`-blokke da `wasmtime` eksponerer et fuldstændigt sikkert API. `FFI`-
implementeringen indeholder ca. otte `unsafe`-blokke, hvilket er uundgåeligt ved
direkte arbejde med native kode. `WASM`'s sandboxing afspejles altså i selve koden.

== Test-extensions

To extensions med identisk funktionalitet er skrevet: `log-ffi` og `log-wasm`. Begge
registrerer `ON_REQUEST`, deserialiserer konteksten, printer request-detaljer og
returnerer `Continue`. Målet er ikke at teste selve extension-kodens performance,
men overheadet fra integrationen mellem hovedapplikationen og extensions.

== Benchmarks

Benchmarks er blevet implementeret ved hjælp af `hyperfine` og `oha` og kan køres
med `cargo make bench-all`. Alle resultater skrives til `results/`-mappen i roden
af repositoriet. En simpel demo-server kørte lokalt under alle tests, så
netværkslatency ikke påvirker resultaterne. Herunder præsenteres resultaterne som
grafer genereret med `lilaq` @lilaq-homepage, et library til `Typst` @typst-app. #footnote[
  Alle benchmarks er kørt på en bærbar laptop (ASUS ZenBook model UM431D fra 2020)
  med Linux (NixOS). MacOS og Windows (og dermed WSL) er ikke testet og jeg kan
  derfor ikke garantere at resultaterne kan reproduceres på disse styresystemer.
  På trods af dette er resultaterne så klare på dette system at jeg antager der
  vil være samme tendens på andre systemer.
]

#let _s_noplugins = json("benchmarks/startup_no-plugins.json").results.at(0)
#let _s_ffi = json("benchmarks/startup_ffi.json").results.at(0)
#let _s_wasm = json("benchmarks/startup_wasm.json").results.at(0)

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
  caption: [Opstartstid for de tre varianter, `hyperfine --warmup 2 --runs 10`, lokal demo-server, gennemsnit ± stddev (lavere er bedre)],
) <fig-startup>

@fig-startup viser tiden fra proxyen startes til den returnerer sit første HTTP-svar. Benchmarket starter proxyen, poller med `curl` indtil
det første succesfulde svar ankommer og måler den samlede tid med `hyperfine`. `FFI`
tilføjer næsten ikke overhead, mens `WASM` er 4,4 gange langsommere at starte. Dette
er primært fordi `wasmtime` JIT-kompilerer modulet ved load.

#let _l_noplugins = json("benchmarks/load_no-plugins.json")
#let _l_ffi = json("benchmarks/load_ffi.json")
#let _l_wasm = json("benchmarks/load_wasm.json")

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
  caption: [Svartidspercentiler (p50, p90, p99), `oha -n 10000 -c 50`, lokal demo-server, ingen warm-up (lavere er bedre)],
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
  caption: [Gennemsnitlig requests/sek under load, `oha -n 10000 -c 50`, lokal demo-server, ingen warm-up, gennemsnit ± stddev (højere er bedre)],
) <fig-load-rps>

På @fig-load-rps ses det at throughput falder med 28,8 % for `FFI` og 37,9 % for
`WASM` sammenlignet med baseline. Der er ~#calc.round(37.9 - 28.8)%-point forskel
på `FFI` og `WASM`.

#let _mem_raw = read("benchmarks/memory_peak.txt")
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
  caption: [
    Peak VmRSS #footnote[Resident Set Size, den fysisk tilgængelige hukommelse en
      applikation bruger, hvor Swap-space og lign. ikke er inkluderet @linux-proc-pid-statm @linux-proc-pid-status.
    ] under `oha`-kørslen, samplet fra `/proc/$PID/status` @linux-proc-pid-status
    hvert 0,5 sek., lokal demo-server (lavere er bedre)
  ],
) <fig-memory>

Hukommelsesforbruget er marginalt for `FFI` (+564 kB), men markant større for
`WASM` (+34,5 MB), da `wasmtime`-runtimen og den JIT-kompilerede kode fylder meget.

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

Det kan konkluderes at det er muligt at designe en udvidelig reverse proxy i Rust,
der understøtter både `FFI` og `WASM` som plugin-mekanismer, og at de to tilgange
adskiller sig markant i implementeringskompleksitet, performance og ressourceforbrug.

`FFI`-implementeringen er kortere (~200 vs ~300 linjer) og mere direkte, men kræver
ca. otte `unsafe`-blokke, hvorimod `WASM` er mere verbose men indeholder ingen
runtime-`unsafe` kode. Fra en udviklers perspektiv er `FFI` tættere på hvad
Rust-udviklere allerede kender, mens `WASM` kræver forståelse for `wasmtime`'s
koncepter som `Store`, `Linker` og `Engine`, men resulterer i et sikrere API hvor
fejl primært fanges ved kompilering.

Baseret på resultaterne vinder `FFI` i alle kategorier. Opstartstiden er næsten
identisk med baselinjen, mens `WASM` er omkring 4,4 gange langsommere at starte,
primært fordi `WASM` JIT-kompilerer modulet ved load. Throughput falder med 28,8%
for `FFI` og 37,9% for `WASM` sammenlignet med baselinjen og hukommelsesforbruget
er småt for `FFI` (+564 kB) og markant større for `WASM` (+34,5 MB) grundet
`wasmtime`-runtimen og den JIT-kompilerede kode.

Det er værd at bemærke at begge implementeringer bruger MessagePack til serialisering
hvilket er nødvendigt for `WASM` da modulet lever i sin egen hukommelse, men teknisk
unødvendigt for `FFI` hvor man kan sende rå pointere direkte. Dette betyder at
`FFI`-implementeringen bærer et serialiserings-overhead den ikke behøver,
og at den reelle forskel mellem `FFI` og en native extension sandsynligvis ville
være endnu mindre. Det ændrer dog ikke konklusionen, da `FFI` slår `WASM` i alle
benchmarks, men forklarer den større, uforudsete forskel på throughput mellem `FFI`
og `no-plugins` som set på @fig-load-rps.

Designmæssigt er svaret det fælles `Extension`-trait. Ved at lade begge tilgange
implementere ét fælles interface kan reverse proxyen understøtte begge dele, uden
at kende til implementeringsdetaljerne bag dem. Valget mellem `FFI` og `WASM` handler
derefter ikke om design, men om krav: `FFI` er det oplagte valg når performance
og lavt ressourceforbrug er kritisk og extensions kommer fra en betroet kilde.
`WASM` er det rigtige valg når extensions kommer fra tredjeparter eller et åbent
økosystem, og sandboxing er vigtigere end rå hastighed. Begge kan sameksistere i
samme applikation via det fælles interface.

Det er dog værd at bemærke at `FFI` og `WASM` i bund og grund er to vidt forskellige
teknologier, og sammenligningen har sine grænser. `FFI` er en mekanisme der gør at
forskellige programmeringssprog kan tale direkte sammen @ffi-wiki, hvorimod `WASM`
er en åben standard for et portabelt binært format, oprindeligt designet til browsere
@wasm-wiki. At de begge kan bruges til extensions er en anvendelse de deler, men
ikke hvad de er designet til. Resultaterne sammenligner altså ikke to ligeværdige
løsninger på samme problem, men to teknologier med forskelligt ophav, brugt til
samme formål.

`WASM` er derfor ikke dårligere end `FFI`, men et bevidst tradeoff. Forskellen er
fundamental: `FFI`-plugins kører i samme adresserum som host-applikationen og har
dermed i princippet ubegrænset adgang til hukommelse og OS-funktioner uden nogen
begrænsning fra runtimen. `WASM`-moduler kører derimod i et isoleret sandbox adskilt
fra hostens adresserum, og kan kun kalde de host-funktioner der eksplicit er eksponeret
via `wasmtime`'s `Linker`, hvilket i dette projekt udelukkende er `env::log`. Alt andet er
utilgængeligt for modulet. Man betaler altså en runtime-pris for denne garanti.
Valget afhænger ikke af hvilken teknologi der er "bedst", men af tillidsmodellen:
en latency-kritisk service med betroede extensions peger mod `FFI`, mens en platform
der kører vilkårlig tredjeparts kode sagtens kan bære `WASM`'s overhead til gengæld
for sandboxing.

== Perspektivering

`FFI` og `WASM` er to fundamentalt forskellige filosofier: tillid vs isolation, og
dette valg er ikke unikt for reverse proxies, men for alle situationer hvor en
applikation skal køre ekstern kode. Da extension-økosystemer vokser og tredjeparts-
udvidelser bliver mere udbredte, bliver denne beslutning mere relevant. Valget
afspejles allerede i industrien: Nginx bruger native C-moduler der loades direkte
i processen (`FFI`-tilgangen), mens Envoy Proxy har valgt `WASM` som sin officielle
plugin-mekanisme netop for at isolere tredjeparts-kode fra hostens adresserum.

`WASM` bevæger sig desuden i stigende grad ud af browseren. Platforme som Cloudflare
Workers og Fastly Compute kører `WASM`-moduler server-side på edge-niveau, og WASI
(WebAssembly System Interface) arbejder på at standardisere OS-adgang for `WASM`
uden for browseren. Dette tyder på at `WASM`'s rolle som sandboxet eksekverings-
miljø kun vil vokse, hvilket gør sammenligningen med `FFI` mere relevant over tid.

Designet med et fælles `Extension`-trait gør at reverse proxyen er agnostisk over
for hvilken plugin-mekanisme der bruges. Det betyder at den underliggende implementering
kan udskiftes uden at ændre host-applikationen, så længe den nye implementering
opfylder samme trait. Standarder som `Wasm Component Model` @wasm-component-model
arbejder på at reducere `WASM`'s boilerplate og overhead, og kunne på sigt erstatte
den nuværende `wasmtime`-implementering bag det samme interface. Den grundlæggende
filosofiske forskel på `FFI` og `WASM` vil dog altid forblive.

= Refleksion

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

Metoden byggede på at de to test-extensions, `log-ffi` og `log-wasm`, var funktionelt
identiske, så eventuelle forskelle i benchmarks udelukkende skyldtes integrationen
i applikationen. Dette holder i store træk, men som nævnt i konklusionen bærer
`FFI`-implementeringen et serialiseringsoverhead den ikke behøver. En mere præcis
sammenligning ville have inkluderet en variant hvor `FFI` bruger rå pointere direkte,
hvilket ville have isoleret serialiseringsoverheadet og givet et klarere billede af
`FFI`'s reelle ydelse.

Benchmarks er kun kørt på én maskine, og resultaterne kan ikke nødvendigvis
reproduceres på andre styresystemer. Det har dog størst betydning for de absolutte
tal, da alle tre varianter er kørt under identiske forhold, og de relative forskelle
mellem `no-plugins`, `FFI` og `WASM` bør derfor være omtrent de samme uanset platform.

Analysen af kodekompleksitet afspejler heller ikke den virkelige verden fuldt ud. I
praksis stiller mange projekter libraries til rådighed der reducerer boilerplate for
understøttede sprog. For dette projekt kunne det fx inkludere protokol-typer og
serialisering heraf, samt en macro der implementerer `plugin_name` og `plugin_version`
ud fra projektets `Cargo.toml`. Det ville mindske mængden af kode, sikre korrekt
implementering og gøre det nemmere for slutudvikleren, da implementeringsspecifikke
detaljer skjules bag en abstraktion.


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
