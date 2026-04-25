# airgenome

**Minimal scope — gates + filters only.**

Mac process gates (`modules/filters/process/*`) + byte-reinterpret filters (`modules/filters/data/*`).

Cross-host execution, supervisor, harvest/label/probe/throttle, drill helpers, governance scanners — all migrated to [hive](https://github.com/need-singularity/hive) (`~/core/hive`, `/resource` menu).

## Layout

```
modules/filters/process/   # mac process gates — ps census → recall recommendation
  safari.hexa  claude.hexa  finder.hexa  memo.hexa  mail.hexa  calendar.hexa
modules/filters/data/      # byte-reinterpret filters — raw → reencoded
  claude_bytes.hexa        — session-constant extraction (JSONL → reduced JSONL)
  claude_quantum.hexa      — entanglement drop (JSONL → qjsonl.gz)
  claude_compress.hexa     — claude data compress
  claude_runtime.hexa      — entanglement-collapsed msgpack (JSONL → binary)
  safari_mmap.hexa         — mmap binary bisect (History.db → SHBF)
  safari_bench.hexa        — safari filter bench
  sqlite_vacuum.hexa       — VACUUM page repack (sqlite → compacted)
  vacuum_watcher.hexa      — vacuum watcher
  quantum_bench.hexa       — quantum filter bench
rules/                     # governance SSOT (active: AG5/AG10/AG11)
archive/v1/                # frozen — v1 시점 전체 (read-only)
```

## Run

```bash
hexa run modules/filters/process/safari.hexa
hexa run modules/filters/data/claude_bytes.hexa
```

## History

- 2026-04-25 미니멀 reduction — gates+filters 만 잔존. supervisor/probe/harvest/label/predictive_throttle/scanners/tool/launchd/bin 전체 제거.
- 2026-04-25 scope-reduce — cross-host (ubu1/ubu2/hetzner) 책임 hive 이관.
- AG6/AG7/AG2/AG3/AG4/AG8/AG9/AG1/AG12 — superseded (cross-host enforcement 책임 hive 이관).

## Cross-host

See `~/core/hive` → `/resource list|score|route|ping`.
