# airgenome

**Minimal — data filters only (byte-reinterpret, 상시, no kill).**

`modules/filters/data/*` — raw bytes → reencoded bytes. No process kill, no recall, no orchestration. 상시 동작 데이터 재해석 계층만.

## Layout

```
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
rules/                     # governance SSOT (active: AG5, AG10)
archive/v1/                # frozen — v1 시점 전체 (read-only)
```

## Run

```bash
hexa run modules/filters/data/claude_bytes.hexa
```

## Out of scope

- Process kill / recall (process gates 제거됨 — 'no kill' directive)
- Cross-host execution → see `~/core/hive` (`/resource list|score|route|ping`)
- Supervisor / probe / harvest / label / drill — hive 이관

## History

- 2026-04-25 데이터 필터 only — process/* 제거 ('no kill' directive). AG11 superseded.
- 2026-04-25 미니멀 reduction — gates+filters 만 잔존.
- 2026-04-25 scope-reduce — cross-host 책임 hive 이관.

active rules: AG5 (filter taxonomy), AG10 (no hooks/skills)
superseded: AG1/AG2/AG3/AG4/AG6/AG7/AG8/AG9/AG11/AG12 (cross-host + inbox 책임 외부 이관)
