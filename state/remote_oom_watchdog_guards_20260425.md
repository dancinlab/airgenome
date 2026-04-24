# Remote OOM + Watchdog Hardening — 2026-04-25

물리 전원 재시작 필요 케이스를 근본 차단하기 위한 4-layer 방어선.

## 배경
- ubu2 가 세션 중 OOM-killed sshd → banner timeout → 원격 복구 불가 → 물리 전원 재시작 필요
- 이전 세션의 docker 는 Claude CLI 샌드박스 전용, drill 실행 경로 아님
- drill = `systemd-run --user --scope` host systemd scope (cgroup O, 하지만 host OOM-killer 가 sshd 고를 권리는 여전히 있음)
- cgroup 은 프로세스 그룹별 한계, OOM-killer 는 전역 선택자 — 다른 레이어

## Layer 구성

### Layer 1 — sshd OOM-unkillable
`/etc/systemd/system/{ssh,sshd}.service.d/oom.conf`:
```
[Service]
OOMScoreAdjust=-1000
```
OOM-killer 우선순위 최하 → 마지막까지 보호.

### Layer 2 — drill scope OOMScoreAdjust=500 (nexus@8105fb80 Wave 13)
`hexa_remote` 의 `_SD_WRAP` 에 `-p OOMScoreAdjust=500` 추가.
drill 이 메모리 압력 시 가장 먼저 kill 대상이 됨 (sshd 대비 1500점 차).

### Layer 3 — user.slice MemoryMin=2G
`/etc/systemd/system/user-.slice.d/mem-reserve.conf`:
```
[Slice]
MemoryMin=2G
```
user session (sshd+shell) 에 2GB reserved floor 보장.

### Layer 4 — hardware watchdog
`/dev/watchdog` 디바이스 + `watchdog` 데몬.
- hetzner + ubu1: 디바이스 부재 (VM) → skip
- 물리 하드웨어 환경 추가 시 자동 적용 가능

## 적용 결과

| Host | L1 sshd OOM | L2 drill scope | L3 user.slice | L4 watchdog |
|---|---|---|---|---|
| hetzner | drop-in 설치 완료 (재시작 대기, daemon-reload 됨) | nexus@8105fb80 | 설치 (root systemd-run, 실효 제한적) | 디바이스 없음 skip |
| ubu1 | **즉시 효력 `-1000` 확인** | nexus@8105fb80 | 설치 완료 | 디바이스 없음 skip |
| ubu2 | **unreachable (물리 리부트 필요)** | 리부트 후 자동 적용 | 리부트 후 | 리부트 후 |

## ubu2 리부트 후 재-설치 지시
사용자가 192.168.50.60 물리 전원 재시작 후, 셸에서 1회 실행:
```
ssh ubu2 'sudo mkdir -p /etc/systemd/system/ssh.service.d /etc/systemd/system/user-.slice.d && \
  sudo tee /etc/systemd/system/ssh.service.d/oom.conf <<<"[Service]
OOMScoreAdjust=-1000" && \
  sudo tee /etc/systemd/system/user-.slice.d/mem-reserve.conf <<<"[Slice]
MemoryMin=2G" && \
  sudo systemctl daemon-reload'
```

## 한계
- L4 watchdog 없이 kernel soft-lock 시에는 여전히 물리 접근 필요 (이번 ubu2 사례는 soft-lock, 아니라 sshd OOM — L1 으로 차단 가능)
- MemoryMin 은 _soft_ guarantee — 시스템 전역 메모리 초과 시 모든 reservation 이 깨질 수 있음

## Wave 1-13 커밋 체인 최종
- nexus: 109a1270 / 7dad025d / 66635696 / 638cff3d / 185c4816 / 99c35eb0 / 1503b253 / a5a3562a / bad4ed52 / c3393ee8 / bf8b7e10 / 01e38b2c / **8105fb80**
- airgenome: fix/roadmap-2-note 40+ commits (safety-committed 단계별)
