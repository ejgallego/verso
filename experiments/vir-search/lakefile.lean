import Lake
open Lake DSL

package verso_search_vir

require verso from "../.."
require lean_vir from git
  "https://github.com/ejgallego/lean-vir" @ "025e1bdd753b9077bced07be3cb36536f501ee40"

lean_lib VersoSearchVir where
  roots := #[
    `VersoSearchVir.FullLean,
    `VersoSearchVir.Runtime
  ]
