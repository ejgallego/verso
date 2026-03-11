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
  Informal.PreviewManifest.manualMainWithSharedPreviewManifest
    (%doc SpherePackingBlueprint.Contents)
    args
    (extensionImpls := by exact extension_impls%)
    (config := renderConfig)
