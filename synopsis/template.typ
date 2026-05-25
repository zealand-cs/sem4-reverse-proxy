#import "@preview/fontawesome:0.5.0": *

#set text(lang: "da")

// Frontpage design made with AI

#let frontpage(
  title: none,
  author: none,
  email: none,
  date: none,
  total-characters: none,
  institution: none,
  programme: none,
) = {
  set page(paper: "a4", margin: 30mm)

  if title != none {
    align(center + top, text(size: 28pt, weight: 700, title))
  }

  if author != none {
    align(center + horizon, {
      line(length: 30mm, stroke: 0.5pt)
      v(4mm)
      text(size: 13pt, weight: 400, [Af #author])
      v(4mm)
      line(length: 30mm, stroke: 0.5pt)
    })
  }

  let meta = ()
  if email != none { meta.push((label: "E-mail", value: email)) }
  if institution != none { meta.push((label: "Institution", value: institution)) }
  if programme != none { meta.push((label: "Uddannelse", value: programme)) }
  if date != none { meta.push((label: "Dato", value: date.display("[day]. [month repr:short] [year]"))) }
  if total-characters != none { meta.push((label: "Tegn inkl. mellemrum", value: total-characters)) }

  if meta.len() > 0 {
    align(center + bottom, grid(
      columns: (auto, auto),
      column-gutter: 8mm,
      row-gutter: 4mm,
      align: (right, left),
      ..meta
        .map(m => (
          text(size: 9pt, style: "italic", m.label + ":"),
          text(size: 9pt, m.value),
        ))
        .flatten(),
    ))
  }
}

#let synopsis(
  title: none,
  date: datetime.today(),
  author: none,
  email: none,
  abstract: none,
  total-characters: none,
  institution: none,
  programme: none,
  body,
) = {
  set document(
    title: title,
    author: author,
    description: abstract,
    date: date,
  )

  set page(paper: "a4", margin: 30mm)
  set heading(numbering: "1.")
  set text(weight: 300, font: "Source Sans Pro")
  set par(leading: 1.4em, spacing: 2.4em, justify: true)
  show heading: set block(above: 1.8em, below: 0.8em)

  if title != none {
    frontpage(
      title: title,
      author: author,
      email: email,
      date: date,
      total-characters: total-characters,
      institution: institution,
      programme: programme,
    )
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
