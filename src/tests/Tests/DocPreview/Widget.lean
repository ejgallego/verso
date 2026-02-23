import Verso
import VersoBlog
import VersoManual
import Lean.Widget.Commands
import Verso.Doc.Concrete.Preview
import Verso.Doc.Concrete.PreviewWidget

open Verso Genre Manual InlineLean
open Verso.Doc.Concrete.PreviewWidget

set_option verso.doc.preview.widget true

show_panel_widgets [local htmlPreviewWidget with Lean.Json.mkObj [("html", "<p>Preview widget module is enabled.</p>")]]

#docs (Manual) widgetPreviewManual "Widget preview: manual" :=
:::::::
Manual paragraph with a reference to {ref "Nat.succ"}[Nat.succ].

:::paragraph
Paragraph directive content.
:::

# Nested section
Nested paragraph with inline Lean: {lean}`Nat.succ 0`.
:::::::

#docs (Verso.Genre.Blog.Post) widgetPreviewPost "Widget preview: blog post" :=
:::::::
Blog paragraph with _emphasis_ and *bold* text.

# Follow-up
Blog follow-up section with `inline code`.
:::::::

#doc (Manual) "Widget preview command: manual" =>
Incremental command paragraph for manual preview.
