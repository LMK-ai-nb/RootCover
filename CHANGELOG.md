# Changelog

## 0.5.1 — unreleased

- Result JSON: `status`, disjoint `counts` (inside/unknown/pending/excluded), `unresolved_count`, for feasible-set results, plus echoed `options`/`contractors` for both root and feasible-set results.
- Docs: ABLATION (contractors on/off across six scenarios, tolerance ladder) and ENVELOPE (volume ratios, connected components, unresolved reasons).
- Comparison now requires one-to-one matching between Julia cells and enclosures; per-model table added.
- CLI tests 25 → 32.

## 0.5.0 — 2026-11-15 — feasible-set release

- Feasible-set solving over equality, ≤, ≥ and observation bands, with all/any/at_least formulas, per-variable absolute/relative tolerances and DFS/BFS search.
- Interval Newton, preconditioned interval Gauss-Seidel and coordinate Newton joint contraction, forward/backward propagation, and SIVIA inner/outer boxes.
- Verified feasible-set sessions: step, save, verified load and resume with persistent budgets.
- Browser workbench recovers from worker load failures; consumer check runs against the packaged archive.
- Boundaries: binary64, 32 variables / 128 constraints at most, no arbitrary precision, no root-session resume.

## 0.5.0-dev.2 — 2026-11-14 — maintenance

- Recover cleanly from worker-module load failures and allow retry; cancel without starting an unused worker.
- Verify a separate consumer against the actual packaged archive, with 5 public API tests per executed target.
- Include consumer evidence in three-platform CI and session tests in the Pages gate.
- Keep routine browser screenshots in ignored artifacts and record browser results; package publication remains deferred.

## 0.5.0-dev.1 — 2026-11-13 — source build

- Owned feasible-set sessions with chunked advancement and persistent global budgets.
- Covering-trace checkpoints revalidate partitions, contraction and terminal evidence.
- Atomic CLI saves and a browser workbench for save/load/continue/cancel/export.
-65 MoonBit tests per target,25 original CLI and8 session tests;48-model independent regression.
- Root-mode resume and changing original budgets/models remain unsupported.

## 0.4.0-dev.1 — 2026-11-13 — local only

- Positive All/Any/AtLeast constraints, conservative quorum hulls and per-atom evidence.
- DFS/BFS, per-axis absolute/mixed relative precision, normalized/Jacobian-impact branching.
- Pending vs processed-unknown tags; robust observations, design alternatives and mixed-unit examples.
- Refreshed3761-module metadata scan and documented feature/permission boundaries; no push/publication.


## 0.3.0-dev.1 — 2026-11-11 — local only

- Thirteen elementary functions, division/negative powers, domain/smoothness states and interval AD.
- HC4-style dependency propagation, independent interval Newton and fair bounded joint contraction.
- Up to32 variables/128 mixed constraints, nonlinear robotics/parameter scenarios and UI controls.
- Actual Julia IntervalRootFinding0.7.2 reference and independent100-digit validation.
- No push, publication or new remote CI this round.


## 0.2.0 — 2026-11-04

- Bounded-observation feasible sets with non-square polynomial constraints.
- Whole-box inside certificates, conservative unresolved outer coverage and explicit resolution status.
- Tolerance calibration and noisy localization CLI/browser scenarios with export.
- Independent exact-rational inner-box replay, rational-grid coverage and cancellation regressions.

## 0.1.0 — 2026-11-04

- Independent binary64 outward interval arithmetic and polynomial automatic Jacobians.
- Krawczyk exclusion, contraction, strict unique-root certificates and bounded region search.
- Conservative unresolved coverage for budget, singularity, boundary and precision limits.
- Strict JSON, expression grammar, typed API, CLI and offline Worker workbench.
- Exact-rational certificate replay, analytic roots, three application examples and browser validation.
