import VersoManual.Bibliography
import VersoBlueprint.Cite

open Verso.Genre.Manual.Bibliography

@[bib "Via2017"]
def Via2017 : Citable := .article
  {
    title := inlines!"The sphere packing problem in dimension 8"
    authors := #[inlines!"Maryna S. Viazovska"]
    journal := inlines!"Annals of Mathematics"
    year := 2017
    month := none
    volume := inlines!"185"
    number := inlines!"3"
    pages := some (991, 1015)
    url := none
  }

@[bib "ElkiesCohn"]
def ElkiesCohn : Citable := .article
  {
    title := inlines!"New upper bounds on sphere packings I"
    authors := #[inlines!"Henry Cohn", inlines!"Noam Elkies"]
    journal := inlines!"Annals of Mathematics"
    year := 2003
    month := none
    volume := inlines!"157"
    number := inlines!"2"
    pages := some (689, 714)
    url := none
  }

@[bib "first.course"]
def first_course : Citable := .inProceedings
  {
    title := inlines!"A First Course in Modular Forms"
    authors := #[inlines!"Fred Diamond", inlines!"Jerry Shurman"]
    year := 2005
    booktitle := inlines!"Graduate Texts in Mathematics"
    editors := none
    series := none
    url := none
  }

@[bib "Lee"]
def Lee : Citable := .arXiv
  {
    title := inlines!"Algebraic proof of modular form inequalities for optimal sphere packings"
    authors := #[inlines!"Seewoo Lee"]
    year := 2024
    id := "2406.14659"
  }
