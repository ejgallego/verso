# Verso Blueprint

This folder contains the extracted blueprint-specific package while the split
from the parent Verso checkout is in progress.

The package lives here:

- `src/verso-blueprint`
- `test-projects/Noperthedron`
- `test-projects/Sphere-Packing-Lean`
- `src/tests`

During this transition, the local dependency on `verso` points at the parent
repository root:

```bash
require verso from ".."
```

Useful commands:

```bash
lake build
lake test
./generate-example-blueprints.sh
```
