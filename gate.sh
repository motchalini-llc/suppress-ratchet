#!/usr/bin/env bash
# Suppress Ratchet gate (language-agnostic, zero-dependency).
#
# Given a codebase that already lints clean, this ensures the linter
# suppressions do not increase:
#   Python:     # noqa (flake8/ruff), # pylint: disable
#   TypeScript: eslint-disable (line / next-line / block), biome-ignore
#
# It is the sibling of Type Ratchet (which owns the type escape hatches
# `type: ignore` / `as any` / `@ts-ignore`). Those are intentionally NOT
# counted here, so the two gates don't double-count.
#
# It does NOT rerun your linter. It catches what a green lint run can't show
# you: a rule silenced with a disable comment instead of the code fixed.
#
# Inputs come from INPUT_* env vars (set by action.yml). Runs locally with the
# same env.
set -uo pipefail

cd "${INPUT_WORKING_DIRECTORY:-.}"

# GitHub inline annotations (::error) need paths relative to the repo root, so
# prefix offending paths when working-directory is not ".".
ANNOT_PREFIX=""
[ "${INPUT_WORKING_DIRECTORY:-.}" != "." ] && ANNOT_PREFIX="${INPUT_WORKING_DIRECTORY%/}/"

LANGUAGE="${INPUT_LANGUAGE:-auto}"
if [ "$LANGUAGE" = "auto" ]; then
  if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f mypy.ini ] || [ -f setup.py ]; then
    LANGUAGE=python
  elif [ -f tsconfig.json ] || [ -f package.json ]; then
    LANGUAGE=typescript
  else
    echo "Could not auto-detect language. Set 'language' to python or typescript." >&2
    exit 2
  fi
fi

# Vendored / generated trees never count toward a project's own suppressions.
EXCLUDE_DIRS=(--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist
              --exclude-dir=build --exclude-dir=.venv --exclude-dir=venv
              --exclude-dir=vendor --exclude-dir=.next --exclude-dir=coverage)

case "$LANGUAGE" in
  python)
    INCLUDES=(--include="*.py")
    SUP_PAT='#\s*(ruff:\s*)?noqa\b|#\s*pylint:\s*disable\b'
    ;;
  typescript)
    INCLUDES=(--include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx")
    SUP_PAT='eslint-disable|biome-ignore'
    ;;
  *)
    echo "Unknown language: $LANGUAGE" >&2
    exit 2
    ;;
esac

# Baseline: the numeric input is the default; baseline-file overrides it
# (SUP_BASELINE).
SUP_BASELINE="${INPUT_BASELINE_SUPPRESS:-0}"
if [ -n "${INPUT_BASELINE_FILE:-}" ] && [ -f "${INPUT_BASELINE_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${INPUT_BASELINE_FILE}"
fi

read -ra PATHS <<< "${INPUT_PATHS:-.}"

# grep exits 1 on zero matches (fatal under pipefail), so wrap with { ...; || true; }
# and count lines with wc.
count() {
  { grep -rnIE "${INCLUDES[@]}" "${EXCLUDE_DIRS[@]}" "$1" "${PATHS[@]}" || true; } | wc -l | tr -d ' '
}
# List offending locations and emit GitHub Actions inline annotations (::error).
report() {
  local pat="$1" kind="$2" m file line
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    file="${m%%:*}"
    file="${file#./}"   # paths default to "."; drop the leading ./ for clean annotations
    line="$(printf '%s' "$m" | cut -d: -f2)"
    echo "  ${ANNOT_PREFIX}${file}:${line}"
    echo "::error file=${ANNOT_PREFIX}${file},line=${line}::Suppress Ratchet: ${kind}"
  done < <(grep -rnIE "${INCLUDES[@]}" "${EXCLUDE_DIRS[@]}" "$pat" "${PATHS[@]}" 2>/dev/null || true)
}

# Write a results table to the job summary if GITHUB_STEP_SUMMARY is set.
write_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  local s
  [ "$SUP_NOW" -gt "$SUP_BASELINE" ] && s="❌ regression" || s="✅"
  {
    echo "## Suppress Ratchet"
    echo ""
    echo "| metric | now | baseline | status |"
    echo "|---|---|---|---|"
    echo "| linter suppressions | ${SUP_NOW} | ${SUP_BASELINE} | ${s} |"
    echo ""
    echo "language \`${LANGUAGE}\` · paths \`${PATHS[*]}\`"
  } >> "$GITHUB_STEP_SUMMARY"
}

SUP_NOW=$(count "$SUP_PAT")

echo "language=${LANGUAGE}  paths=${PATHS[*]}"
echo "suppressions:   now=${SUP_NOW}  baseline=${SUP_BASELINE}"

status=0
if [ "$SUP_NOW" -gt "$SUP_BASELINE" ]; then
  echo "❌ REGRESSION: linter suppressions increased (${SUP_NOW} > ${SUP_BASELINE})"
  report "$SUP_PAT" "new linter suppression not allowed (exceeds baseline)"
  status=1
elif [ "$SUP_NOW" -lt "$SUP_BASELINE" ]; then
  echo "✅ IMPROVED: below baseline — lower the baseline to tighten the ratchet."
else
  echo "✅ HELD: at baseline."
fi

write_summary

# Optional: also run a linter (e.g. "pnpm exec eslint ." / "uv run ruff check").
if [ -n "${INPUT_LINT_COMMAND:-}" ]; then
  echo "--- lint: ${INPUT_LINT_COMMAND} ---"
  bash -c "${INPUT_LINT_COMMAND}" || status=1
fi

exit "$status"
