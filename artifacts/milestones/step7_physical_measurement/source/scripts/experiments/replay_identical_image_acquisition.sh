#!/usr/bin/env bash
# One controlled main-root replay. Never touches any frozen milestone/archive.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
NAME=EXP-S6-IDENTICAL-IMAGE-STARTUP-ACQUISITION-ATTRIBUTION-20261004
LIVE="experiments/step6/$NAME/raw/20261004T003029Z-live"
RECORD="experiments/step6/$NAME/raw/$(date -u +%Y%m%dT%H%M%SZ)-replay"
test -s "$LIVE/qualified-result.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["verdict"] == "PASS_TIME_VALID_300S"' "$LIVE/qualified-result.json"
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Stop the other JTAG owner first.' >&2; exit 2
fi
mkdir -p "$RECORD/configuration" "$RECORD/build" "$RECORD/program"
exec > >(tee "$RECORD/session.log") 2>&1
printf 'IDENTICAL_REPLAY_BEGIN time=%s source_commit=%s\n' "$(date -Is)" "$(git rev-parse HEAD)"
# Freeze the production input manifest before changing derived build products.
sha256sum -c "$LIVE/reference/SOURCE_SHA256SUMS" > "$RECORD/production-input-check.log"
printf '418bb2546c08cb7b67c09309b58ce1de4c4668e39e3ec84dc94a4add850c6e6a  %s\n' \
  "$LIVE/reference/SOURCE_SHA256SUMS" | sha256sum -c -
bash scripts/tests/run_wrh_time_valid_baseline_c.sh | tee "$RECORD/actual-c-tests.log"
python3 -m unittest scripts.tests.test_step6_acquisition_attribution \
  scripts.tests.test_current_experiment_source scripts.tests.test_step6_time_valid_300s \
  > "$RECORD/offline-tests.log" 2>&1
bash scripts/build/build_current.sh > "$RECORD/build/firmware.log" 2>&1
bash scripts/build/compile_current.sh > "$RECORD/build/compile.log" 2>&1
sha256sum -c "$LIVE/reference/SOURCE_SHA256SUMS" > "$RECORD/postbuild-input-check.log"
for role in master slave; do
  cp "build/build_info_$role.txt" "$RECORD/build/"
  cp "build/quartus_${role}_compile.log" "$RECORD/build/"
  cp "output/DE5a_wr_${role}_jtag.sof" "$RECORD/configuration/new-$role.sof"
done
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
for role in master slave; do
  "$QUARTUS_BIN/quartus_cpf" -c "$LIVE/reference/$role.sof" \
    "$RECORD/configuration/reference-$role.rbf" > "$RECORD/configuration/reference-$role-cpf.log" 2>&1
  "$QUARTUS_BIN/quartus_cpf" -c "$RECORD/configuration/new-$role.sof" \
    "$RECORD/configuration/new-$role.rbf" > "$RECORD/configuration/new-$role-cpf.log" 2>&1
  cmp "$RECORD/configuration/reference-$role.rbf" "$RECORD/configuration/new-$role.rbf"
done
printf '8e5f1ab2c0c44376493f5ff1dedc50c3e6423835e7f96de42ceda96758007f09  %s\n' \
  "$RECORD/configuration/new-master.rbf" | sha256sum -c -
printf '886650e7345968e1739087d3e82fb054caa31950d0eb0f7657e97b148ba908dc  %s\n' \
  "$RECORD/configuration/new-slave.rbf" | sha256sum -c -
sha256sum "$RECORD"/configuration/*.sof "$RECORD"/configuration/*.rbf > "$RECORD/configuration/SHA256SUMS"
echo 'FPGA_CONFIGURATION_EXACT_MATCH=PASS programming_allowed=1'
printf 'PROGRAM_BEGIN time=%s\n' "$(date -Is)"
# Established main-root scripts/order; per-role logs also saved here.
SOF="$ROOT/output/DE5a_wr_slave_jtag.sof" bash scripts/program/program_slave.sh \
  > "$RECORD/program/slave.log" 2>&1
grep -q 'Programmer was successful' "$RECORD/program/slave.log"
printf 'SLAVE_PROGRAM_END time=%s\n' "$(date -Is)"
SOF="$ROOT/output/DE5a_wr_master_jtag.sof" bash scripts/program/program_master.sh \
  > "$RECORD/program/master.log" 2>&1
grep -q 'Programmer was successful' "$RECORD/program/master.log"
printf 'MASTER_PROGRAM_END time=%s\n' "$(date -Is)"
# Existing reader: pre-valid states, then10s health streak and first TRACK or
# deadline. An invalid observer stop is not a firmware acquisition failure.
set +e
timeout --signal=INT --kill-after=5s 950s "$QUARTUS_BIN/quartus_stp" -t \
  scripts/jtag/read_step6_servo_acquisition_context.tcl > "$RECORD/acquisition.log" 2>&1
OBSERVER_RC=$?
set -e
printf 'ACQUISITION_READER_RC=%d\n' "$OBSERVER_RC"
python3 scripts/analysis/step6_acquisition_attribution.py "$RECORD/acquisition.log" \
  > "$RECORD/acquisition.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); assert r["has_reader_done"] and not r["reader_error_lines"] and r["accepted_rows"] >= 10, r; assert any("STOP_REASON=TRACK_PHASE_REACHED" in l or "STOP_REASON=DURATION_LIMIT" in l for l in r["acquisition_stop_lines"]), r' \
  "$RECORD/acquisition.json"
[ "$OBSERVER_RC" -eq 0 ]
ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/dashboard-after-acquisition.log"
# If this replay reached valid time, qualify retention without reprogramming.
if grep -q 'STATUS_TIME_VALID=1' "$RECORD/acquisition.log"; then
  TIME_VALID_ACQUISITION_TIMEOUT_S=60 bash scripts/monitor/verify_time_valid_300s.sh \
    | tee "$RECORD/time-valid-verifier.log"
  capture=$(sed -n 's/^TIME_VALID_CAPTURE_PATH=//p' "$RECORD/time-valid-verifier.log")
  result=$(sed -n 's/^TIME_VALID_RESULT_PATH=//p' "$RECORD/time-valid-verifier.log")
  cp "$capture" "$RECORD/qualified-capture.log"
  cp "$result" "$RECORD/qualified-result.json"
else
  echo 'ACQUISITION_NOT_ESTABLISHED no_automatic_retry=1 no_forced_valid=1'
fi
printf 'IDENTICAL_REPLAY_END time=%s\n' "$(date -Is)"
