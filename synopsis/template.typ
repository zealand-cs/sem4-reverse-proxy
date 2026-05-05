#import "@preview/fontawesome:0.5.0": *

#let synopsis(
  title: none,
  date: datetime.today(),
  author: none,
  email: none,
  abstract: none,
  total-characters: none,
  body,
) = {
  set document(
    title: title,
    author: author,
  )

  set page(paper: "a4", margin: 30mm)
  set document(
    title: title,
    author: author,
    description: abstract,
    date: date,
  )

  set heading(numbering: "1.")
  set text(weight: 300, font: "Source Sans Pro")
  set par(leading: 1.4em, spacing: 2.4em, justify: true)
  show heading: set block(above: 1.8em, below: 0.8em)

  {
    if title != none {
      std.title()

      total-characters
    }
    pagebreak()
  }

  if abstract != none {
    set page(margin: (x: 60mm))
    set par(justify: true)

    align(center + horizon, std.title[Resumé])
    align(left + horizon, abstract)

    pagebreak()
  }

  outline(title: "Indholdsfortegnelse")

  pagebreak()

  body
}
