#!/usr/bin/env bash
# apply_canonical_term_raw_to_hive.sh
#
# Manual-apply tool for raw 258 canonical-tool-term-disambiguation-mandate.
#
# DEFAULT MODE: dry-run (READ-ONLY, prints planned actions, mutates nothing).
# MUTATING MODE: requires --apply flag AND explicit user approval echo.
#
# This script does NOT auto-commit. It optionally appends raw entry, runs raw
# lint selftest, restores chflags lock, and PRINTS the suggested git add /
# commit / push commands for manual user execution.
#
# read-only constraints (per raw 47 / raw 1 r25):
#   * /Users/ghost/core/hive          — locked uchg by default; this script does
#                                       NOT bypass without explicit unlock + --apply
#   * /Users/ghost/core/anima         — read-only here (registry row written to
#                                       airgenome/docs/ as artifact)
#   * /Users/ghost/core/hexa-lang     — read-only here

set -euo pipefail

readonly AIRGENOME_REPO="${AIRGENOME:-$HOME/core/airgenome}"
readonly HIVE_REPO="${HIVE:-$HOME/core/hive}"
readonly HIVE_RAW="${HIVE_REPO}/.raw"
readonly RAW_ENTRY_SRC="${AIRGENOME_REPO}/docs/hive_pr_ready_canonical_term_disambiguation_2026-05-01.raw_entry.txt"
readonly EXPECTED_RAW_NUMBER=258
readonly RAW_LINT_TOOL="${HIVE_REPO}/tool/raw_lint.hexa"

MODE="dry-run"
for arg in "$@"; do
    case "$arg" in
        --apply) MODE="apply" ;;
        --dry-run) MODE="dry-run" ;;
        -h|--help)
            cat <<'HELP'
apply_canonical_term_raw_to_hive.sh — append raw 258 canonical-tool-term-disambiguation
to hive/.raw with explicit user approval gate.

Usage:
    apply_canonical_term_raw_to_hive.sh [--dry-run|--apply]

  --dry-run  (default) print planned actions, mutate nothing
  --apply    perform mutations (requires hive/.raw chflags unlock + EXPLICIT
             USER APPROVAL echoed before any write)

Workflow when --apply:
  1. verify chflags status of hive/.raw
  2. if uchg set => ABORT with clear error message; user must:
         sudo chflags nouchg /Users/ghost/core/hive/.raw
     (chflags lock is raw 1 r25 SSOT immutability protection — explicit unlock
     required to acknowledge the modification window)
  3. verify last raw number in hive/.raw matches expected predecessor (raw 257)
  4. append raw entry from airgenome/docs/hive_pr_ready_canonical_term_disambiguation_2026-05-01.raw_entry.txt
  5. (optional) run hive tool/raw_lint.hexa selftest if available
  6. restore chflags uchg lock
  7. PRINT suggested git add / commit / push commands — does NOT execute them

NEVER amends existing commits. NEVER force-pushes. NEVER skips hooks.
HELP
            exit 0
            ;;
        *) echo "[error] unknown arg: $arg (try --help)" >&2; exit 64 ;;
    esac
done

echo "[apply_canonical_term_raw_to_hive] mode=${MODE}"
echo "[apply_canonical_term_raw_to_hive] AIRGENOME=${AIRGENOME_REPO}"
echo "[apply_canonical_term_raw_to_hive] HIVE=${HIVE_REPO}"
echo "[apply_canonical_term_raw_to_hive] HIVE_RAW=${HIVE_RAW}"
echo "[apply_canonical_term_raw_to_hive] RAW_ENTRY_SRC=${RAW_ENTRY_SRC}"
echo "[apply_canonical_term_raw_to_hive] EXPECTED_RAW_NUMBER=${EXPECTED_RAW_NUMBER}"

# --- Step 1: source artifact existence -------------------------------------------------
if [[ ! -f "${RAW_ENTRY_SRC}" ]]; then
    echo "[error] raw entry source not found: ${RAW_ENTRY_SRC}" >&2
    exit 65
fi
RAW_ENTRY_BYTES=$(wc -c < "${RAW_ENTRY_SRC}" | tr -d ' ')
echo "[step 1] raw entry source OK (${RAW_ENTRY_BYTES} bytes)"

# --- Step 2: hive/.raw existence + chflags status ---------------------------------------
if [[ ! -f "${HIVE_RAW}" ]]; then
    echo "[error] hive/.raw not found: ${HIVE_RAW}" >&2
    exit 66
fi
CHFLAGS_LINE=$(ls -lO "${HIVE_RAW}" 2>/dev/null | head -1)
echo "[step 2] hive/.raw chflags status:"
echo "         ${CHFLAGS_LINE}"

UCHG_SET="no"
if echo "${CHFLAGS_LINE}" | grep -qw "uchg"; then
    UCHG_SET="yes"
fi

# --- Step 3: predecessor raw-number sanity ----------------------------------------------
LAST_RAW=$(grep -E "^raw [0-9]+ " "${HIVE_RAW}" 2>/dev/null | tail -1 | sed -E 's/^raw ([0-9]+) .*/\1/')
echo "[step 3] last hive/.raw raw number: ${LAST_RAW}"
if [[ "${LAST_RAW}" != "$((EXPECTED_RAW_NUMBER - 1))" ]]; then
    echo "[warn] expected predecessor raw $((EXPECTED_RAW_NUMBER - 1)), found raw ${LAST_RAW}"
    echo "       raw entry may need renumbering before apply"
fi

# --- Dry-run termination point ---------------------------------------------------------
if [[ "${MODE}" == "dry-run" ]]; then
    cat <<'DRYRUN_REPORT'

[dry-run] no mutations performed. Planned actions on --apply:
  (a) verify chflags lock status (above)
  (b) IF uchg set => ABORT with explicit unlock instructions
  (c) append raw entry to hive/.raw
  (d) run tool/raw_lint.hexa selftest if available
  (e) restore chflags uchg lock
  (f) PRINT git commands for manual user execution (NO auto-commit)

To apply, re-run with --apply (and ensure hive/.raw is chflags-unlocked).
EXPLICIT USER APPROVAL REQUIRED for the mutating path.
DRYRUN_REPORT
    exit 0
fi

# --- APPLY MODE BELOW: mutating path with explicit approval gate ------------------------
echo
echo "EXPLICIT USER APPROVAL REQUIRED"
echo "================================"
echo "About to MUTATE ${HIVE_RAW} (append raw ${EXPECTED_RAW_NUMBER} entry, ${RAW_ENTRY_BYTES} bytes)."
echo "This violates the read-only mandate UNLESS the user has explicitly granted hive transfer."
echo

if [[ "${UCHG_SET}" == "yes" ]]; then
    cat <<'UCHG_ABORT' >&2

[abort] hive/.raw is chflags uchg-locked (raw 1 r25 SSOT immutability protection).

To explicitly authorize this mutation, run:

    sudo chflags nouchg /Users/ghost/core/hive/.raw

Then re-run this script with --apply.

Alternatively, abort and have the main agent (with explicit user approval)
perform the apply.
UCHG_ABORT
    exit 67
fi

if [[ "${HIVE_PR_APPLY_CONFIRMED:-}" != "yes" ]]; then
    cat <<'CONFIRM_ABORT' >&2

[abort] HIVE_PR_APPLY_CONFIRMED=yes env var not set.

The user must set this env var explicitly to acknowledge that the PR transfer
is authorized for this run:

    HIVE_PR_APPLY_CONFIRMED=yes ./apply_canonical_term_raw_to_hive.sh --apply

Without this env var, the script refuses to mutate even when chflags is unlocked.
CONFIRM_ABORT
    exit 68
fi

echo "[apply] HIVE_PR_APPLY_CONFIRMED=yes received — proceeding with mutation."

# --- Step 4: append raw entry -----------------------------------------------------------
PRE_BYTES=$(wc -c < "${HIVE_RAW}" | tr -d ' ')
echo "[step 4] hive/.raw size before: ${PRE_BYTES} bytes"

# Ensure trailing newline before append (idempotent).
if [[ -n "$(tail -c 1 "${HIVE_RAW}")" ]]; then
    printf '\n' >> "${HIVE_RAW}"
fi
cat "${RAW_ENTRY_SRC}" >> "${HIVE_RAW}"
# Ensure trailing newline after append.
if [[ -n "$(tail -c 1 "${HIVE_RAW}")" ]]; then
    printf '\n' >> "${HIVE_RAW}"
fi

POST_BYTES=$(wc -c < "${HIVE_RAW}" | tr -d ' ')
echo "[step 4] hive/.raw size after:  ${POST_BYTES} bytes (delta +$((POST_BYTES - PRE_BYTES)))"

# --- Step 5: raw_lint selftest ----------------------------------------------------------
if [[ -x "${RAW_LINT_TOOL}" ]] || [[ -f "${RAW_LINT_TOOL}" ]]; then
    echo "[step 5] running ${RAW_LINT_TOOL} --selftest (best-effort)"
    if command -v hexa >/dev/null 2>&1; then
        hexa "${RAW_LINT_TOOL}" --selftest || echo "[warn] raw_lint selftest non-zero exit (review output above)"
    else
        echo "[warn] hexa runtime not on PATH — skipping raw_lint selftest"
    fi
else
    echo "[step 5] ${RAW_LINT_TOOL} not present — skipping selftest"
fi

# --- Step 6: restore chflags uchg --------------------------------------------------------
echo "[step 6] re-locking hive/.raw with chflags uchg"
if sudo -n chflags uchg "${HIVE_RAW}" 2>/dev/null; then
    echo "[step 6] chflags uchg restored (sudo non-interactive)"
else
    echo "[step 6] sudo non-interactive failed — run manually:"
    echo "         sudo chflags uchg ${HIVE_RAW}"
fi

# --- Step 7: PRINT git commands (NEVER auto-execute) ------------------------------------
cat <<COMMIT_PROMPT

================================
Manual git commit/push commands (review and execute manually if desired):
================================

  cd ${HIVE_REPO}
  git status
  git add .raw
  git diff --cached .raw | head -50
  git commit -m "raw ${EXPECTED_RAW_NUMBER}: canonical-tool-term-disambiguation-mandate

  Adds raw ${EXPECTED_RAW_NUMBER} codifying canonical mapping for 15 reserved tool terms
  (kick / harvest / label / forecast / drill / blowup / revive / ingest /
  absorb / kick-tree / omega-ingest / smash / free / meta-closure / absolute).

  Source: airgenome/docs/raw_canonical_tool_term_disambiguation_proposal.md
  Score:  raw 240 V2.6 800/800 (V2.7+ exhaustion at B33).
  Baseline: 30d ~/.claude/projects/ walk (5662 files, 4744 mentions, 97.34% fail_rate).
  Phase A -> B -> C executed.

  Co-Authored-By: airgenome canonical-tool-term-disambiguation Phase C artifact"

  git push origin main          # NEVER --force
  # OR
  git push origin HEAD:work-branch && gh pr create ...

This script does NOT execute these commands automatically. Manual confirmation required.
COMMIT_PROMPT

echo
echo "[done] raw ${EXPECTED_RAW_NUMBER} appended. Manual git commands above."
