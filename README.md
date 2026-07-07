# Suppress Ratchet

[![Marketplace](https://img.shields.io/badge/Marketplace-Suppress%20Ratchet-2ea44f?logo=github)](https://github.com/marketplace/actions/suppress-ratchet)
[![Release](https://img.shields.io/github/v/release/motchalini-llc/suppress-ratchet?sort=semver)](https://github.com/motchalini-llc/suppress-ratchet/releases)
[![self-test](https://github.com/motchalini-llc/suppress-ratchet/actions/workflows/self-test.yml/badge.svg)](https://github.com/motchalini-llc/suppress-ratchet/actions/workflows/self-test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A zero-dependency GitHub Action that **stops new linter suppressions from creeping into a linted codebase**.

Your linter (`eslint`, `biome`, `ruff`, `pylint`) can pass while `eslint-disable`, `biome-ignore`, `# noqa`, and `# pylint: disable` comments quietly pile up. Suppress Ratchet counts those suppressions and **fails the PR if the count goes up** — so a clean codebase stays clean, and a messy one only gets better (a ratchet).

It does **not** just rerun your linter. It catches the thing a green lint run can't: someone silencing a rule with a disable comment instead of fixing the code.

**Why now:** AI coding agents are very good at making CI green — and the fastest route to green is `eslint-disable`, not a fix. A reviewer can miss one suppression in a 400-line diff; a counter can't. No AI, no SaaS, no config: the whole gate is [one bash script](gate.sh) you can read.

> 📖 Launch article: [Your AI makes CI green by cheating. I built three GitHub Actions to stop it.](https://dev.to/motchalini/your-ai-makes-ci-green-by-cheating-i-built-three-github-actions-to-stop-it-4pal) · [日本語版 (Zenn)](https://zenn.dev/motchalini/articles/99f743d923fb54)

[![Demo: one 'quick fix' PR trips all three ratchet gates](https://raw.githubusercontent.com/motchalini-llc/ratchet-demo/main/docs/ratchet-demo.gif)](https://github.com/motchalini-llc/ratchet-demo/pull/1)

> 🔴 **Live demo:** [ratchet-demo#1](https://github.com/motchalini-llc/ratchet-demo/pull/1) — one "quick fix" PR that silences the type checker, skips a test and mutes the linter. All three gates go red with inline annotations.

## The Ratchet family

Three zero-dependency PR gates, each blocking a different way a green check gets faked:

| Action | Blocks the cheat |
|---|---|
| [Type Ratchet](https://github.com/marketplace/actions/type-ratchet) | type escape hatches — `any` / `as any` / `# type: ignore` |
| [Test Ratchet](https://github.com/marketplace/actions/test-ratchet) | disabled tests — `it.skip` / `.only` / `@pytest.mark.skip` |
| [Suppress Ratchet](https://github.com/marketplace/actions/suppress-ratchet) **← this repo** | linter suppressions — `eslint-disable` / `biome-ignore` / `# noqa` |

## Usage

Add one step to a PR workflow:

```yaml
# .github/workflows/suppress-ratchet.yml
name: Suppress Ratchet Gate
on:
  pull_request:
    branches: [main]
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: motchalini-llc/suppress-ratchet@v1
        with:
          language: typescript   # python | typescript | auto
          baseline-suppress: '12'   # suppressions already in the codebase
```

### TypeScript (also run the linter)

```yaml
      - uses: actions/checkout@v4
      - run: corepack enable
      - run: pnpm install --frozen-lockfile
      - uses: motchalini-llc/suppress-ratchet@v1
        with:
          language: typescript
          baseline-suppress: '12'
          lint-command: pnpm exec eslint .
```

### Python (also run ruff)

```yaml
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - run: uv sync --frozen
      - uses: motchalini-llc/suppress-ratchet@v1
        with:
          language: python
          baseline-suppress: '4'
          lint-command: uv run ruff check
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `language` | `auto` | `python` \| `typescript` \| `auto` (detects from `pyproject.toml` / `tsconfig.json`) |
| `paths` | `.` | Space-separated directories to scan |
| `baseline-suppress` | `0` | Max allowed linter-suppression count |
| `baseline-file` | `''` | Optional file defining `SUP_BASELINE` (overrides the numeric input) |
| `lint-command` | `''` | Optional command also run as part of the gate (e.g. `pnpm exec eslint .`) |
| `working-directory` | `.` | Directory to run in |

## What counts

| | linter suppression |
|---|---|
| **Python** | `# noqa` (flake8 / ruff), `# ruff: noqa`, `# pylint: disable` |
| **TypeScript** | `eslint-disable` (line / next-line / block), `biome-ignore` |

Vendored / generated trees (`node_modules`, `dist`, `build`, `.venv`, `vendor`, `.next`, `coverage`, …) are skipped.

**Not counted here:** the type-checker escape hatches `# type: ignore`, `as any`, `@ts-ignore` — those belong to [Type Ratchet](https://github.com/marketplace/actions/type-ratchet), so the two gates don't double-count.

## Output

On failure the action:

- Emits **inline annotations** (`::error`) on the exact offending lines, so violations show up right on the PR's *Files changed* tab.
- Writes a **job summary** table (count vs. baseline) to the run summary.

## Tightening the ratchet

When you remove a suppression and the count drops below the baseline, the gate prints `IMPROVED` — lower the baseline and commit it. The count can only go down.

## License

MIT
