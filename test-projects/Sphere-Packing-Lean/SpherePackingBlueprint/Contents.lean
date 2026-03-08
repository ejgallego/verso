import Verso
import VersoManual
import VersoBlueprint

import SpherePackingBlueprint.Bibliography
import SpherePackingBlueprint.Chapters.SpherePackings
import SpherePackingBlueprint.Chapters.PackingsDensity
import SpherePackingBlueprint.Chapters.E8
import SpherePackingBlueprint.Chapters.FourierAnalysis
import SpherePackingBlueprint.Chapters.CohnElkies
import SpherePackingBlueprint.Chapters.ModularForms
import SpherePackingBlueprint.Chapters.MagicFunctions
import SpherePackingBlueprint.Chapters.ModularInequalities

open Verso.Genre
open Verso.Genre.Manual hiding citep citet citehere
open Informal

set_option doc.verso true
set_option pp.rawOnError true


#doc (Manual) "Contents" =>

%%%
shortTitle := "Sphere Packing in R^8"
authors := ["Maryna Viazovska", "Sphere Packing in Lean collaborators"]
%%%

# Introduction

This document ports the original TeX blueprint from
`test-projects/Sphere-Packing-Lean/tmp/Sphere-Packing-Lean/blueprint/src` to Verso Blueprints.

The project formalizes the dimension-8 optimality theorem from {citet Via2017}[].
The Cohn-Elkies linear programming strategy follows {citet ElkiesCohn}[].

{include 0 SpherePackingBlueprint.Chapters.SpherePackings}
{include 0 SpherePackingBlueprint.Chapters.PackingsDensity}
{include 0 SpherePackingBlueprint.Chapters.E8}
{include 0 SpherePackingBlueprint.Chapters.FourierAnalysis}
{include 0 SpherePackingBlueprint.Chapters.CohnElkies}
{include 0 SpherePackingBlueprint.Chapters.ModularForms}
{include 0 SpherePackingBlueprint.Chapters.MagicFunctions}
{include 0 SpherePackingBlueprint.Chapters.ModularInequalities}

{blueprint_graph}

{bp_summary}

{bp_bibliography}
