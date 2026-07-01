# Roadmap

Guiding principle: **ship the light, free version first; build the heavy version only once there's demand.** The gate (counting linter suppressions and failing the PR) is the core value — everything else is demand-driven.

## Shipped

- v1 gate: Python (`# noqa`, `# ruff: noqa`, `# pylint: disable`) and TypeScript (`eslint-disable`, `biome-ignore`), auto-detected
- Baseline ratchet (count can only go down), `baseline-file` support
- Vendored/generated dirs excluded (`node_modules`, `dist`, `.venv`, …)
- Inline PR annotations + job summary table
- Optional `lint-command` (run `eslint` / `ruff` alongside the gate)
- Self-test on fixtures; published to GitHub Marketplace

## Next (when there's a clear signal)

- **Demo GIF in the README** — show a PR going red on a new `eslint-disable`, then green after a fix. (Cheap, lifts conversion. Do this early.)
- **More suppression kinds (opt-in)** — security (`# nosec`, `// eslint-disable ... security`), coverage (`# pragma: no cover`, `/* c8 ignore */`, `/* istanbul ignore */`), formatter (`# fmt: off`). Add per demand to avoid noisy defaults.
- **Require a justification (opt-in)** — fail a suppression that has no trailing reason/rule code, nudging teams to document why.

## Ideas backlog

- Per-path / per-package baselines (monorepos).
- A config file (`.suppress-ratchet.yml`) as an alternative to action inputs.
- More languages (Go `//nolint`, Rust `#[allow(...)]`, C# `#pragma warning disable`) if requested.
- `warn-only` mode (annotate without failing) for gradual adoption.

## Later / business

- Marketplace verified publisher (requires the org) once monetizing.
- Decide free vs. paid tiers based on usage and requests.

## Non-goals

- Re-running the linter for you (that's your existing CI's job; this catches what a green lint run can't: silencing vs. fixing).
- Owning the type-checker escape hatches (`type: ignore` / `as any`) — that's Type Ratchet's job.
- Becoming a general linter.

## How to validate / what to watch

Marketplace views, stars, issues, and "I tried it" mentions. Issues are the best signal for what to build next.
