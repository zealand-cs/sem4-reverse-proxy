#let synopsis(
  title: none,
  date: datetime.today(),
  author: none,
  email: none,
  abstract: none,
  body,
) = {
  set document(
    title: title,
    author: author,
  )

  set page(paper: "a4", margin: 15mm)
  set document(
    title: title,
    author: author,
    description: abstract,
    date: date,
  )

  set heading(numbering: "1.")
  set text(weight: 300, font: "Source Sans Pro")
  set par(justify: true)

  {
    if title != none {
      std.title()
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
