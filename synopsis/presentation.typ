#import "@preview/polylux:0.4.0": *
#set page(
  paper: "presentation-16-9",
  margin: 2cm,
  footer: align(bottom, toolbox.full-width-block(fill: rgb("#ffffff"))[
    #toolbox.progress-ratio(ratio => {
      stack(
        dir: ltr,
        rect(stroke: none, fill: rgb("#fff387"), width: ratio * 100%),
        rect(stroke: none, fill: rgb("#ffffff"), width: (1 - ratio) * 100%),
      )
    })
  ]),
)
#set text(size: 25pt)

// ── Del 1: Præsentation af projektet (~5 min) ──

#slide[
  #set align(horizon)

  #title[Plugin-arkitektur i Rust: #linebreak() FFI vs. WASM i modulær software]
]

#slide[
  #show outline.entry: it => link(
    it.element.location(),
    // Keep just the body, dropping
    // the fill and the page.
    it.indented(none, it.body()),
  )

  #title[Agenda]

  #set text(size: 18pt)
  #outline(title: none)
]

#slide[
  == Problemformulering

  Hvordan kan en simpel reverse proxy i Rust designes til at understøtte udvidelser
  via `FFI` og `WASM`, og hvordan adskiller de to tilgange sig?

  - Implementering og kodekompleksitet
  - Svartid, throughput og hukommelsesforbrug
]

#slide[
  #set align(horizon)

  == Reverse proxy
]

#slide[
  == FFI vs. WASM

  #toolbox.side-by-side[
    *FFI*
    - Kald direkte til native kode
    - Samme adresserum som host
    - \~200 linjer, \~8 `unsafe` blokke
    - Ingen isolation
  ][
    *WASM*
    - Sandboxet eksekvering
    - Isoleret hukommelse
    - \~300 linjer, 0 `unsafe` blokke
    - Kun eksplicit eksponerede funktioner
  ]
]

#slide[
  == Fælles Extension trait

  - Ét trait begge implementerer
  - Proxyen kender ikke forskel på FFI/WASM
  - Bitmask for capabilities: undgå unødvendige kald
  - `HookResult`: `Continue`, `Replace` eller `Error`
  - MessagePack til serialisering af kontekst
]

#slide[
  == Resultater

  #table(
    columns: (auto, 1fr, 1fr, 1fr),
    inset: 8pt,
    align: horizon,
    table.header([], [*no-plugins*], [*FFI*], [*WASM*]),
    [*Opstartstid*], [baseline], [\~samme], [\~4,4x langsommere],
    [*Throughput*], [baseline], [-28,8%], [-37,9%],
    [*Hukommelse*], [baseline], [+564 kB], [+34,5 MB],
  )
]

#slide[
  == Konklusion

  - FFI vinder i alle benchmarks
  - WASM er ikke _dårligere_
  - Tillid vs. isolation: betroede extensions → FFI, \
    tredjeparts kode → WASM
  - Fælles trait gør begge udskiftelige
]

// ── Del 2: Nye tanker og refleksioner (~5 min) ──

#slide[
  == Serialisering

  - _Nødvendigt_ for WASM (separat hukommelse)
  - _Unødvendigt_ for FFI
  - Begge bruger MessagePack til serialisering
  - FFI bærer et overhead den ikke behøver
  - Den reelle forskel i throughput er nok _mindre_ end målt
]

#slide[
  == Hvad ville jeg gøre anderledes?

  - Benchmark _med_ og _uden_ serialisering for FFI
  - Teste på flere platforme (macOS, andre CPU-arkitekturer)
  - Prøve ahead-of-time kompilering for WASM \
    (`wasmtime` understøtter det)
]

#slide[
  == Nye indsigter

  - `wasm32` ABI-begrænsningen med multi-value returns \
    var overraskende - endte med i64-packing
  - `Library` i FFI-structen _skal_ leve så længe symbolerne bruges \
    (`Drop` kalder `dlclose`)
  - Bitmask-capabilities: simpelt men effektivt \
    til at undgå unødvendige boundary-crossings
]

#slide[
  == Brug i verden

  - Nginx: native C-moduler (FFI-tilgangen)
  - Envoy Proxy: WASM som officiel plugin-mekanisme
  - Cloudflare Workers, Fastly Compute: WASM server-side
  - WASI og Wasm Component Model: fremtiden?

  Valget FFI vs. WASM er ikke unikt for proxies - \
  det gælder _alle_ applikationer med ekstern kode.
]

#slide[
  #set align(horizon + center)
  #text(size: 35pt)[Spørgsmål?]
]
