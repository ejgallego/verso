import Lake
open Lake DSL

package verso_search_vir

require verso from "../.."
require lean_vir from git
  "https://github.com/ejgallego/lean-vir" @ "40f2e3d02b6f7b5ca8026bd44e65bd99283c6c57"

lean_lib VersoSearchVir where
  roots := #[`VersoSearchVir.Runtime]
