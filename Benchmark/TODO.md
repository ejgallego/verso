# Benchmark TODO

- Prototype a more aggressive hidden-setup mode behind a separate option, with explicit tradeoff review for editor/info-tree behavior.
- Broaden the page sample and profile more manual chapters before attempting another semantic optimization pass.

## Findings

- Broadened sample: `Terms.lean`, `BasicTypes/Range.lean`, `Tactics/Reference.lean`, and `BuildTools/Lake/Config.lean`.
- The remaining inline-Lean hotspot is not hidden setup. On both `Terms.lean` and `BasicTypes/Range.lean`, shown `#eval` commands dominate the residual `InlineLean` cost.
- Hidden setup commands are small after the existing cuts, so a more aggressive hidden-setup mode is currently deprioritized unless a future profile shows hidden output-heavy blocks dominating a specific page.
