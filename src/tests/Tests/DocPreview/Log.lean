import Verso
import VersoManual
import Verso.Doc.Concrete.Preview

open Verso Genre Manual

set_option guard_msgs.diff true
set_option verso.doc.preview.logForTest true

/--
info: <section>
  <h1>
    Preview none</h1>
  <p>
    None paragraph.</p>
  </section>
-/
#guard_msgs in
#docs (.none) previewNone "Preview none" :=
:::::::
None paragraph.
:::::::

/--
info: <section>
  <h1>
    Preview manual</h1>
  <p>
    Manual paragraph with a manual role: successor.</p>
  <p>
    First paragraph block in a manual directive.
Second sentence keeps paragraph block context.</p>
  </section>
-/
#guard_msgs in
#docs (Manual) previewManual "Preview manual" :=
:::::::
Manual paragraph with a manual role: {ref "Nat.succ"}[successor].

:::paragraph
First paragraph block in a manual directive.
Second sentence keeps paragraph block context.
:::
:::::::
