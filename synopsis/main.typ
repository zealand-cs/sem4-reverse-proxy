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

= Introduktion

Udvidelse af software uden at skulle kende kildekoden kan være en stærk motivator
for tredjeparter til at bruge netop dit projekt.

I dette projekt vil der blive udviklet en reverse proxy i Rust, der understøtter
udvidelser i form af WASM og FFI, for at undersøge forskellene på de to nærmere,
i forhold til følgende parametre: implementering, hastighed og brug af hukommelse.

Selve programmet vil blive skrevet i Rust og det vil udvidelserne også, for nemt
at kunne se forskellene på implementeringerne ift. kodemængde og læselighed.

= Motivation

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

Hvordan kan en reverse proxy implementeret i Rust designes til at understøtte
udvidelser via WASM og FFI, og hvilke forskelle er der mellem disse to tilgange
i forhold til implementering, udvikling af udvidelserne og ressourceforbrug?

Følgende underspørgsmål vil blive undersøgt i forbindelse med problemformuleringen:

1. Hvordan adskiller implementering af udvidelser i WASM og FFI sig i praksis,
   herunder kompleksitet, kodemængde og læselighed?

2. Hvilke forskelle er der i ydeevne og ressourcebrug mellem WASM- og FFI-baserede
   udvidelser?

3. Hvordan adskiller udviklingen af udvidelserne i WASM og FFI fra hinanden?

= Metode

= Planlægning

= Arbejdet

= Konklusion

= Reflektion

= Referencer

#bibliography("bib.yaml", title: none, style: "ieee",full: true)
