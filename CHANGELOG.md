# Changelog

Chronological log of notable changes. One section per ship batch, date-keyed.

For the full audit trail, see `git log`.

---

## 2026-05-22

- **scope-reduce — mac-local-only** (PR #89) — the cross-host layer removed; airgenome runs mac-local only.
- **project.tape SSOT** — project identity + governance consolidated into `project.tape`; interim Spec Kit scaffolding removed, `AGENTS.tape` archived.
- **DESIGN doc split** — `design.md` → `DESIGN.log.md` (decision audit trail) + `DESIGN.md` live pointer.

## 2026-05-21

- **org rename** — owning org `need-singularity` → `dancinlab`.
- **constitution v1.0.0** — OS Genome Scanner · 6-axis · hexa-native.

## 2026-05-20

- **launcher — snippet auto-input** — direct `CGEventKeyboardSetUnicodeString` typing so snippet content never lands on the system clipboard.

## 2026-05-15

- **native menubar** — DisplayLink lifecycle + supervisor async cadence; fixed a supervisor process leak (944 stale procs). Spotlight toggle added then reverted.

## 2026-05-14

- **AGENTS.tape** — `TAPE-AUDIT.md` adoption; `@I id001` enhanced with project-tree fields; README aligned to the atlas 18-block format.

## 2026-05-10

- **overload watch** — load > 80 → Claude Code CLI prioritized: competing PIDs demoted to `taskpolicy_bg`, Claude pinned foreground.
