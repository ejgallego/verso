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
  <h1 id="Preview-manual">
     Preview manual<span class="permalink-widget inline"><a href="/find/?domain=Verso.Genre.Manual.section&amp;name=Preview-manual" title="Permalink">🔗</a></span></h1>
  <p>
    Manual paragraph with a manual role: successor.</p>
  <div class="paragraph">
    <p>
      First paragraph block in a manual directive.
Second sentence keeps paragraph block context.</p>
    </div>
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

/--
info: <section>
  <h1 id="Preview-refs">
     Preview refs<span class="permalink-widget inline"><a href="/find/?domain=Verso.Genre.Manual.section&amp;name=Preview-refs" title="Permalink">🔗</a></span></h1>
  <p>
    See <a href="/Target/#Preview-refs--Target">target section</a>.</p>
  <section>
    <h2 id="Preview-refs--Target">
      1. Target<span class="permalink-widget inline"><a href="/find/?domain=Verso.Genre.Manual.section&amp;name=Preview-refs--Target" title="Permalink">🔗</a></span></h2>
    <p>
      Target paragraph.</p>
    </section>
  </section>
-/
#guard_msgs in
#docs (Manual) previewRefs "Preview refs" :=
:::::::
See {ref "Preview-refs--Target"}[target section].

# Target
Target paragraph.
:::::::

/--
info: <section>
  <h1 id="Preview-nested">
     Preview nested<span class="permalink-widget inline"><a href="/find/?domain=Verso.Genre.Manual.section&amp;name=Preview-nested" title="Permalink">🔗</a></span></h1>
  <p>
    Intro paragraph.</p>
  <section>
    <h2 id="Preview-nested--First">
      1. First<span class="permalink-widget inline"><a href="/find/?domain=Verso.Genre.Manual.section&amp;name=Preview-nested--First" title="Permalink">🔗</a></span></h2>
    <p>
      First paragraph.</p>
    <section>
      <h3 id="Preview-nested--First--Second">
        1.1. Second<span class="permalink-widget inline"><a href="/find/?domain=Verso.Genre.Manual.section&amp;name=Preview-nested--First--Second" title="Permalink">🔗</a></span></h3>
      <p>
        Second paragraph with <a href="/First/Second/#Preview-nested--First--Second">self ref</a>.</p>
      </section>
    </section>
  </section>
-/
#guard_msgs in
#docs (Manual) previewNested "Preview nested" :=
:::::::
Intro paragraph.

# First
First paragraph.

## Second
Second paragraph with {ref "Preview-nested--First--Second"}[self ref].
:::::::
