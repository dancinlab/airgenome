# Remote Emergency Stabilize — 2026-04-25

## 트리거
- ubu2 sshd 다시 OOM-killed → banner timeout
- hetzner: hexa_real 좀비 + 메모리 800Mi free (124GB 중)
- ubu1: hexa_stage0 / hexa_real runaway 의심

## 액션 (UTC 2026-04-24T23:50Z 기준)

### 1. drill-kill --all
```
=== killing Mac-side nexus drill ===   (none)
=== killing hetzner drill processes ===  killed: 8
=== killing ubu1 drill processes ===   killed: 0
=== killing ubu2 drill processes ===   killed: 0   (SSH unreachable)
=== Mac state cleanup ===              locks/blacklists cleared
```

### 2. hetzner — 후속 정리
- drill-kill 직후: hexa_real PID 1420870 (defunct, RSS=0)
- pkill -9 -f hexa_stage0/hexa_real 적용
- 추가 발견 PID 1461674 (56s old, 93MB) → kill -9
- **결과: free 808Mi → 123Gi, swap 3.2Gi → 74Mi, hexa procs 0**

### 3. ubu1 — runaway 정리
- drill-kill 시점 hexa procs 0 (필터 미스 — drill-kill 은 nexus drill / drill-live 패턴만 매치)
- 후속 ps 발견: hexa_stage0 PID 3772472 (1GB), hexa_real PID 625545 (256MB)
- pkill -9 적용 후 일부 ssh 세션 exit 255 발생 → 재연결로 verify
- 최종 kill -9 625545 (마지막 hexa_real 248MB)
- **결과: load 0.52, free 27Gi, hexa procs 0**

### 4. ubu2 — banner timeout 처리
- 첫 probe: 의외로 응답 (load 37.92, hexa_stage0 PID 1067032 RSS 2.4GB, hexa_real PID 503234)
- pkill 시도 → SSH 즉시 banner timeout 으로 전환 (sshd OOM 재발 추정)
- 두 번째 probe (45s ConnectTimeout): banner timeout 확정
- **Mac 측 차단:** `touch /tmp/hexa_remote.blacklist.ubu2` (Wave 11 TTL 300s 한계 — 사용자가 물리 리부트 필요)

## 호스트별 최종 상태

| Host | SSH | RAM free | swap | hexa procs | load |
|---|---|---|---|---|---|
| hetzner | OK | 123Gi/124Gi | 74Mi/63Gi | 0 | n/a |
| ubu1 | OK | 27Gi/30Gi | 2.1Gi/8Gi | 0 | 0.52 |
| ubu2 | banner timeout | unknown (이전 ps: hexa_stage0 2.4GB) | unknown | unknown | 37.92 (이전 probe) |

## 정리한 좀비 PID 합계
- hetzner: 8 (drill-kill) + 1420870 + 1461674 = ~10
- ubu1: 3772472 (hexa_stage0), 625545 (hexa_real) = 2
- ubu2: 0 (실패 — pkill 도달 전 sshd 사망)

## 사용자 액션 (필수)
1. **ubu2 192.168.50.60 물리 전원 재시작**
2. 부팅 후 SSH 가능해지면 1회 실행:
   ```
   ssh ubu2 'sudo mkdir -p /etc/systemd/system/ssh.service.d /etc/systemd/system/user-.slice.d && \
     sudo tee /etc/systemd/system/ssh.service.d/oom.conf <<<"[Service]
   OOMScoreAdjust=-1000" && \
     sudo tee /etc/systemd/system/user-.slice.d/mem-reserve.conf <<<"[Slice]
   MemoryMin=2G" && \
     sudo systemctl daemon-reload'
   ```
3. Wave 13/14 OOM hardening drop-in 영구화 후 blacklist 해제:
   `rm /tmp/hexa_remote.blacklist.ubu2`

## 제약 준수
- sudo -n 미사용 (kill/pkill 만 사용자 권한)
- claude container / docker images / runaway_guard 미접촉
- Mac drill 자체는 0건 (drill-kill 보고)

## 알려진 한계
- drill-kill helper 의 패턴 (nexus drill / drill-live / hexa_remote.*run.hexa) 가
  hexa_stage0 / 단독 hexa_real binary 를 잡지 못함
  → helper 보강 필요 (별도 PR — `pkill -9 -f hexa_stage0` / `pkill -9 -f '^hexa_real'` 추가)
