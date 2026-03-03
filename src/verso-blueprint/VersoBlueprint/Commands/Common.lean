/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

namespace Informal.Commands

def openTargetDetailsJs : String := r##"(function () {
  function openFromHash() {
    if (!window.location.hash) return;
    const id = decodeURIComponent(window.location.hash.slice(1));
    if (!id) return;
    const target = document.getElementById(id);
    if (!target) return;
    const details = target.matches(\"details\") ? target : target.closest(\"details\");
    if (details) details.open = true;
  }

  if (document.readyState === \"loading\") {
    document.addEventListener(\"DOMContentLoaded\", openFromHash);
  } else {
    openFromHash();
  }
  window.addEventListener(\"hashchange\", openFromHash);
})();"##

end Informal.Commands
