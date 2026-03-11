import VersoBlueprint.PreviewManifest

namespace Verso.Tests.BlueprintPreviewSchema

open Lean
open Informal.PreviewManifest

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let schema := schemaJson
    let defs? := Json.getObjVal? schema "$defs"
    let rootRef? := Json.getObjVal? schema "$ref"
    pure <| Id.run do
      let Except.ok defsJson := defs? | return false
      let Except.ok defs := defsJson.getObj? | return false
      let Except.ok rootRefJson := rootRef? | return false
      let Except.ok rootRef := fromJson? (α := String) rootRefJson | return false
      let some fileSchema := defs.get? "Informal.PreviewManifest.File" | return false
      let some entrySchema := defs.get? "Informal.PreviewManifest.Entry" | return false
      let some facetSchema := defs.get? "Informal.PreviewCache.Facet" | return false
      let Except.ok filePropsJson := Json.getObjVal? fileSchema "properties" | return false
      let Except.ok fileProps := filePropsJson.getObj? | return false
      let Except.ok entryPropsJson := Json.getObjVal? entrySchema "properties" | return false
      let Except.ok entryProps := entryPropsJson.getObj? | return false
      rootRef == "#/$defs/Informal.PreviewManifest.File" &&
        defs.size == 3 &&
        fileProps.contains "previews" &&
        entryProps.contains "key" &&
        entryProps.contains "facet" &&
        (Json.getObjVal? facetSchema "enum").isOk

end Verso.Tests.BlueprintPreviewSchema
