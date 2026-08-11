import Lake
open Lake DSL

package verso_search_vir

require verso from "../.."
require lean_vir from git
  "https://github.com/ejgallego/lean-vir" @ "2ddbfad021eddce634a9ea74ba315492d7b96708"

lean_lib VersoSearchVir where
  roots := #[`VersoSearchVir.Runtime]
