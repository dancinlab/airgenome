#!/usr/bin/env bash
# runeq_winctl.sh — RUNEQ gate: C reference vs hexa port of winctl_target_rect.
#
# Sweeps a real corpus of (action × screen visibleFrame × current-window) cases
# and asserts the two emit byte-identical "<x> <y> <w> <h>" lines. Covers all
# 7 window actions (incl. 6=top half, 7=bottom half) + the default identity
# path (action 0 = dock reset, a shim action → identity here), real macOS sizes
# (incl. multi-display origins + notch-trimmed visibleFrame heights) and the
# action-5 clamp branch (window larger than visibleFrame on each axis).
#
# Exit 0 = all pairs equal (RUNEQ PASS). Nonzero = first mismatch printed.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cc -O2 -Wall -o /tmp/winctl_ref "$here/winctl_geometry_ref.c"
HEXA="${HEXA:-hexa}"

# Real visibleFrame corpus (AX coords). Each: vfx vfy vfw vfh
#   1080p, 1440p, 4K, MBP14 notch-trimmed (1512x982 of 1512x1117),
#   MBP16, a secondary display at +1920 origin, an ultrawide.
screens=(
  "0 0 1920 1080"
  "0 0 2560 1440"
  "0 0 3840 2160"
  "0 0 1512 982"
  "0 0 1728 1117"
  "1920 0 2560 1440"
  "0 0 3440 1440"
)
# Current-window corpus: cwx cwy cww cwh — incl. oversized (clamp) + tiny.
windows=(
  "100 100 800 600"
  "10 10 400 300"
  "0 0 4000 3000"      # larger than every screen → action-5 clamp both axes
  "500 500 1200 200"   # wide-short → action-5 clamp width only on small screens
  "50 50 100 2500"     # tall-thin → action-5 clamp height
)
actions=(1 2 3 4 5 6 7 0)   # 6=top half, 7=bottom half; 0 exercises the identity/default path

pass=0; fail=0
for a in "${actions[@]}"; do
  for s in "${screens[@]}"; do
    for w in "${windows[@]}"; do
      argline="$a $s $w"
      cref=$(/tmp/winctl_ref $argline)
      hres=$("$HEXA" run "$here/winctl_geometry.hexa" $argline)
      if [ "$cref" == "$hres" ]; then
        pass=$((pass+1))
      else
        fail=$((fail+1))
        echo "MISMATCH args=[$argline]"
        echo "   C   : $cref"
        echo "   hexa: $hres"
      fi
    done
  done
done

total=$((pass+fail))
echo "------------------------------------------------------------"
echo "RUNEQ winctl_target_rect : C-vs-hexa value-exact"
echo "corpus = ${#actions[@]} actions x ${#screens[@]} screens x ${#windows[@]} windows = $total cases"
echo "PASS=$pass  FAIL=$fail"
if [ "$fail" -eq 0 ]; then
  echo "VERDICT: 🟢 RUNEQ PASS — kernel value-exact across full corpus"
  exit 0
else
  echo "VERDICT: 🔴 RUNEQ FAIL — $fail mismatch(es)"
  exit 1
fi
