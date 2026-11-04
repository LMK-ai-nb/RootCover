# Sources and dependencies

Copyright for the independent RootCover implementation: 2026 李明坤 / LMK-ai-nb.
Original source is MIT. AI assisted implementation, research, tests and documentation;
the maintainer remains responsible for understanding and reviewing the work.

The only imported MoonBit modules are the standard-library double, debug and JSON
packages and this project's own packages. MoonBit core is Apache-2.0 with LLVM
exceptions and contains additional notices. Unmodified notices from the validated
toolchain are under `third_party/MoonBit-core-LICENSE.txt` and
`third_party/MoonBit-core-NOTICE.txt`. The build copies them beside distributed
JavaScript and into the hosted demo. No external font, map, API, numerical service,
npm runtime dependency or Python runtime dependency is needed for the solver.
Playwright/Chromium is an optional test tool, not a runtime dependency.

Interval arithmetic, forward-mode automatic differentiation, the Krawczyk operator
and branch-and-bound region search are established methods. RootCover does not
claim their invention and is not a source-code port of the projects below.

- [IntervalRootFinding.jl documentation](https://juliaintervals.github.io/IntervalRootFinding.jl/latest/): conceptual reference for root-region statuses and interval root solving. GitHub reports multiple/unclassified licensing; no code or fixtures copied.
- [IBEX documentation](https://ibex-lib.readthedocs.io/en/latest/): conceptual reference for interval contractors and system solving; upstream repository LGPL-3.0. No code or fixtures copied.
- [Luna-Flow/floating](https://github.com/Luna-Flow/floating), Apache-2.0: related arbitrary-precision and interval arithmetic. No import or source-code reuse.
- [CAIMEOX/mbmath](https://github.com/CAIMEOX/mbmath), Apache-2.0: related arbitrary-precision numerical methods. No import or source-code reuse.

The Python oracle is independently written using the Python standard library's
Fraction and AST modules. Its inputs use a recorded seed and synthetic data. All
three application examples are synthetic; no operator, laboratory, customer or
production adoption is claimed. Native HTML/CSS/SVG assets are created in this
repository. Generic engineering conventions do not import old project business
implementations; see `docs/ORIGIN.md` for the relationship to earlier work.

Version 0.2 adds independently implemented interval set inversion (SIVIA), following established concepts documented in IBEX and the 2016 paper linked in docs/PAVING.md. No source code or data from either is copied; neither algorithmic novelty nor full IBEX compatibility is claimed.
