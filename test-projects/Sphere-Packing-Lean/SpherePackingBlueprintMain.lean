import Std.Data.HashMap
import VersoManual
import VersoBlueprint.PreviewManifest
import SpherePackingBlueprint.Contents

open Verso Doc
open Verso.Genre Manual
open Std (HashMap)

def htmlAssets : HtmlAssets where
  features := .all
  extraCss := {}
  extraJs := {}
  extraJsFiles := {}
  extraCssFiles := {}

def htmlConfig : HtmlConfig where
  toHtmlAssets := htmlAssets
  htmlDepth := 1
  extraHead : Array Output.Html := #[]

def outputConfig : OutputConfig where
  emitTeX := false
  emitHtmlSingle := .no
  emitHtmlMulti := .immediately

def config : Config where
  toHtmlConfig := htmlConfig
  toOutputConfig := outputConfig

def renderConfig : RenderConfig where
  toConfig := config

def main (args : List String) : IO UInt32 :=
  do
    let (dumped?, args) ← Informal.PreviewManifest.handleDumpSchemaFlag args
    if let some code := dumped? then
      return code
    manualMain (%doc SpherePackingBlueprint.Contents)
      (options := args)
      (extensionImpls := by exact extension_impls%)
      (config := renderConfig)
