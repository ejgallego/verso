import Verso
import VersoManual

open Verso.Genre Manual InlineLean

#doc (Manual) "Embedded semantic tokens" =>

Inline term: {lean}`let x := 1; x`

```lean
def blockVal := let y := 1; y
theorem blockThm : True := by
  trivial
```
--^ sync
--^ textDocument/semanticTokens/range: {"range":{"start":{"line":7,"character":20},"end":{"line":7,"character":33}}}
--^ textDocument/semanticTokens/range: {"range":{"start":{"line":10,"character":0},"end":{"line":12,"character":9}}}
