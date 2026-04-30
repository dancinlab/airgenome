# wave-5 SKIP / FAIL Re-validation — 2026-04-30

User Mail.app + Notes set up 후 mail/memo SKIP 4 + calendar_event_shbf FAIL fix 재측정.

## 결과 (5 filter, foreground 직접 실행)

| filter | 직전 상태 | 재측정 결과 | 결정 |
|---|---|---|---|
| calendar_event_shbf | FAIL (BufferError) | **301.8× PASS** (5000 events / 208KB blob / lossless 14025=14025) | datae 추가 ✅ 1800s |
| mail_envelope_shbf | SKIP (V10 inbox 0) | FAIL TypeError schema (V10 subject ROWID 처리 불일치) | 별도 fix cycle |
| mail_body_dedup | SKIP | FAIL 0.8× (V10 39 emlx blocks, dup=1/39 = 2.6% 너무 낮음) | mail body 다양성 높아 dedup ROI 낮음 |
| mail_sender_dict | SKIP | FAIL diff_test mismatches=810 (lossless 위반) + 0.8× wall | encoder bug — 별도 fix |
| memo_attachment_dedup | SKIP | SKIP attachments=0 (Notes 켰지만 첨부 미존재) | 사용자 첨부 추가 시 재측정 |

## 통합 결정

**datae 추가**: calendar_event_shbf @ 1800s (datae w5 11번째 filter)
- airgenome_loop.m + plist 갱신 + production active 검증

**fix-cycle 잔여 (별도)**:
- mail_envelope_shbf — V10 schema (messages.subject ROWID → addresses LEFT JOIN 시 int 처리 분기 누락)
- mail_sender_dict — encoder lossless 위반 (810 mismatch — addresses join 누락 또는 enum overflow 미스)
- mail_body_dedup — 본질적 ROI 한계 (dup<5% 시 negative). 코드 fix 불가 — accept N/A.
- memo_attachment_dedup — 사용자 첨부 추가 시 자동 재측정 가능

## calendar_event_shbf BufferError fix

`MMappedBlob.__init__` 끝에서 `self.mv=mv` 보존 → `mm.close()` 시 BufferError "cannot close exported pointers exist".

수정 (3 lines):
```python
# OLD
self.pool=bytes(mv[pool_off:pool_off+pool_sz])
self.mv=mv

# NEW
self.pool=bytes(mv[pool_off:pool_off+pool_sz])
mv.release()
del mv
```

bg agent (aa0bcd5928fa6b84d) PAYLOAD edit 적용 → auth fail로 검증 실패 → foreground 재측정 PASS.

## production 활성 (PID 77758)

```
[airgenome_loop] datae w5: memo_notes=ok memo_search=ok tel_chat=ok tel_media=ok
                          fi_recent=ok tel_contact=ok cal_recur=ok music=ok
                          books=ok shortcuts=ok cal_event=ok
```

총 **34 timer** active (3 base + 4 safari + 3 blob + 6 procs + 7 K-wave + **11 wave-5**).

## bench_results.jsonl

own9-wave5-fix-calendar_event row appended (5-tuple):
- old_per_call_ns: 227,100 / new_per_call_ns: 800 / speedup 301.8× / saved 99.6%
- diff_test 0/100 lossless / blob 208.4KB / encode 5.4ms

## honest C3

- bg agent 인증 실패 (aa0bcd5928fa6b84d wave-5 FAIL fix + a3702a8365cc49bf1 mail/memo re-validation) → foreground 직접 실행으로 대체
- mail 3 filter는 V10 schema 처리 미스 + encoder bug + 본질적 ROI 한계 → 통합 불가
- memo_attachment는 사용자 액션 (첨부 추가) 의존
- 즉시 흡수 가능한 1건 (cal_event) 만 통합. 나머지 4건은 자연 N/A 또는 별도 fix cycle 처리.
