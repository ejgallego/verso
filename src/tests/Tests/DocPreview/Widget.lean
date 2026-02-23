import Verso
import VersoBlog
import VersoManual
import Verso.Doc.Concrete.Preview
import Verso.Doc.Concrete.PreviewWidget

open Verso Genre Manual InlineLean

set_option verso.doc.preview.widget true

#docs (Manual) widgetPreviewManual "Widget preview: manual" :=
:::::::
This extended manual example is intended to stress preview rendering with several block kinds.
It links to a declaration using a manual role: {ref "Nat.succ"}[`Nat.succ`], and it includes
inline Lean syntax for hover metadata: {lean}`Nat.succ 0`.

:::paragraph
Paragraph directive content can include _emphasis_, *bold text*, and `inline code`
while remaining in a block-directive context.
:::

# Feature tour
This section mixes lists and prose to make sure numbering and paragraph breaks look stable.

* First bullet with a short sentence.
* Second bullet that references {ref "Nat.zero"}[`Nat.zero`] for role expansion.
* Third bullet with inline Lean: {lean}`Nat.succ (Nat.succ 0)`.

1. Ordered item one.
2. Ordered item two with `code`.
3. Ordered item three with a longer explanation that wraps.

> Block quote paragraphs should preserve spacing and line wrapping while rendering
> inside the preview widget.

## Deep subsection
Final subsection paragraph to exercise nested heading sizing and permalink rendering.
:::::::

#docs (Verso.Genre.Blog.Post) widgetPreviewPost "Widget preview: blog post" :=
:::::::
This blog post preview is intentionally richer, with multiple paragraphs and diverse syntax.
It contains _emphasis_, *bold text*, and a short `inline code` span.

The second paragraph is longer so we can observe line wrapping and spacing inside the widget
container, especially in conjunction with heading blocks and list elements below.

# Follow-up
In the follow-up section we include mixed content:

* blog bullet one
* blog bullet two
* blog bullet three

1. first ordered point
2. second ordered point
3. third ordered point

> Quoted blog text to test blockquote rendering in post previews.

## Closing notes
Closing paragraph with punctuation, symbols, and another `inline code` sample.
:::::::

#doc (Manual) "Widget preview command: manual" =>
Incremental command paragraph one for manual preview.

Incremental command paragraph two with _emphasis_ and {lean}`Nat.succ 1`.

Incremental command paragraph three to confirm multi-paragraph command previews.
