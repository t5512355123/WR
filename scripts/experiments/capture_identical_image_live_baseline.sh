#!/usr/bin/env bash
# Preserve the current boot before any build/programming destroys its history.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
NAME=EXP-S6-IDENTICAL-IMAGE-STARTUP-ACQUISITION-ATTRIBUTION-20261004
RECORD="experiments/step6/$NAME/raw/$(date -u +%Y%m%dT%H%M%SZ)-live"
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG owner first.' >&2; exit 2
fi
mkdir -p "$RECORD/reference" "$RECORD/program-history"
exec > >(tee "$RECORD/session.log") 2>&1
printf 'LIVE_BASELINE_BEGIN time=%s observer_commit=%s no_program=1\n' "$(date -Is)" "$(git rev-parse HEAD)"
sha256sum -c output/SHA256SUMS
sha256sum -c output/SOURCE_SHA256SUMS >/dev/null
cp output/DE5a_wr_master_jtag.sof "$RECORD/reference/master.sof"
cp output/DE5a_wr_slave_jtag.sof "$RECORD/reference/slave.sof"
cp output/SHA256SUMS output/SOURCE_COMMIT output/SOURCE_SHA256SUMS "$RECORD/reference/"
find experiments/step6/EXP-S6-MAIN-ROOT-TIME-VALID-300S-BACKTRACK-20261003/raw/program \
  -name '20261004T001046Z-*' -type f -exec cp -t "$RECORD/program-history" {} +
cp /tmp/wr-current-failure-preflight-20261004-0815.log "$RECORD/initial-preflight.log"
QUARTUS_STP=${QUARTUS_STP:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp}
timeout --signal=INT --kill-after=3s 45s "$QUARTUS_STP" -t \
  scripts/jtag/read_step6_servo_interleaved_offset.tcl 15000 250 1-11.2 2 \
  > "$RECORD/phase-context-smoke.log" 2>&1
python3 scripts/analysis/step6_acquisition_attribution.py "$RECORD/phase-context-smoke.log" \
  > "$RECORD/phase-context-smoke.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); assert r["has_reader_done"] and not r["reader_error_lines"] and r["accepted_rows"] >= 10, r' \
  "$RECORD/phase-context-smoke.json"
TIME_VALID_ACQUISITION_TIMEOUT_S=600 bash scripts/monitor/verify_time_valid_300s.sh \
  | tee "$RECORD/time-valid-verifier.log"
capture=$(sed -n 's/^TIME_VALID_CAPTURE_PATH=//p' "$RECORD/time-valid-verifier.log")
result=$(sed -n 's/^TIME_VALID_RESULT_PATH=//p' "$RECORD/time-valid-verifier.log")
cp "$capture" "$RECORD/qualified-capture.log"
cp "$result" "$RECORD/qualified-result.json"
ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/dashboard-after.log"
printf 'LIVE_BASELINE_END time=%s\n' "$(date -Is)"
