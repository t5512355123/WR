#!/usr/bin/env bash
# One same-control root replay with passive Main progress and actual GPS query.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT"
test "$ROOT" = /home/b10504072/04_WR
MODE=${1:?use smoke or replay}
case "$MODE" in smoke|replay) ;; *) exit 2;; esac
NAME=EXP-S6-SAME-IMAGE-MAIN-PHASE-READBACK-STARTUP-20261004
BASE="experiments/step6/$NAME"
REFERENCE=experiments/step6/EXP-S6-IDENTICAL-IMAGE-STARTUP-ACQUISITION-ATTRIBUTION-20261004/raw/20261004T003029Z-live/reference
if pgrep -x quartus_stp >/dev/null || pgrep -x quartus_pgm >/dev/null; then
  echo 'Other JTAG owner exists; stop without altering it.' >&2; exit 2
fi
if [ "$MODE" = replay ]; then
  test -s "$BASE/SMOKE_QUALIFIED.json"
  python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); assert r["has_reader_done"] and not r["reader_error_lines"]; m=r["main_phase_readback"]; assert m["valid_frames"] >= 3 and any(d>0 and d<0x80000000 for d in m["update_progress_deltas_same_identity"]), r' "$BASE/SMOKE_QUALIFIED.json"
fi
RECORD="$BASE/raw/$(date -u +%Y%m%dT%H%M%SZ)-$MODE"
mkdir -p "$RECORD"
exec > >(tee "$RECORD/session.log") 2>&1
printf 'MAIN_READBACK_BEGIN time=%s source=%s mode=%s\n' "$(date -Is)" "$(git rev-parse HEAD)" "$MODE"
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
"$QUARTUS_BIN/quartus_sh" -t scripts/tests/test_step6_main_phase_readback.tcl > "$RECORD/native-tcl-tests.log" 2>&1
grep -q 'NATIVE_TCL_MAIN_PHASE_READBACK_TESTS=12 PASS' "$RECORD/native-tcl-tests.log"
if [ "$MODE" = replay ]; then
  mkdir -p "$RECORD/build" "$RECORD/configuration" "$RECORD/program"
  sha256sum -c "$REFERENCE/SOURCE_SHA256SUMS" > "$RECORD/production-input-check.log"
  bash scripts/tests/run_wrh_time_valid_baseline_c.sh > "$RECORD/native-tests.log" 2>&1
  python3 -m unittest scripts.tests.test_step6_main_phase_readback scripts.tests.test_step6_acquisition_attribution scripts.tests.test_current_experiment_source scripts.tests.test_step6_time_valid_300s > "$RECORD/offline-tests.log" 2>&1
  bash scripts/build/build_current.sh > "$RECORD/build/firmware.log" 2>&1
  bash scripts/build/compile_current.sh > "$RECORD/build/compile.log" 2>&1
  sha256sum -c "$REFERENCE/SOURCE_SHA256SUMS" > "$RECORD/postbuild-input-check.log"
  for role in master slave; do
    cp "output/DE5a_wr_${role}_jtag.sof" "$RECORD/configuration/$role.sof"
    cp "build/build_info_$role.txt" "$RECORD/build/"
    cp "build/quartus_${role}_compile.log" "$RECORD/build/"
    "$QUARTUS_BIN/quartus_cpf" -c "$RECORD/configuration/$role.sof" "$RECORD/configuration/$role.rbf" > "$RECORD/configuration/$role-cpf.log" 2>&1
  done
  printf '8e5f1ab2c0c44376493f5ff1dedc50c3e6423835e7f96de42ceda96758007f09  %s\n' "$RECORD/configuration/master.rbf" | sha256sum -c -
  printf '886650e7345968e1739087d3e82fb054caa31950d0eb0f7657e97b148ba908dc  %s\n' "$RECORD/configuration/slave.rbf" | sha256sum -c -
  sha256sum "$RECORD"/configuration/*.sof "$RECORD"/configuration/*.rbf > "$RECORD/configuration/SHA256SUMS"
  printf 'PROGRAM_BEGIN time=%s\n' "$(date -Is)"
  SOF="$ROOT/output/DE5a_wr_slave_jtag.sof" bash scripts/program/program_slave.sh > "$RECORD/program/slave.log" 2>&1
  grep -q 'Programmer was successful' "$RECORD/program/slave.log"
  printf 'SLAVE_PROGRAM_END time=%s\n' "$(date -Is)"
  SOF="$ROOT/output/DE5a_wr_master_jtag.sof" bash scripts/program/program_master.sh > "$RECORD/program/master.log" 2>&1
  grep -q 'Programmer was successful' "$RECORD/program/master.log"
  printf 'MASTER_PROGRAM_END time=%s\n' "$(date -Is)"
fi
set +e
if [ "$MODE" = smoke ]; then
  S6_ACQ_MAIN_READBACK=1 S6_ACQ_SMOKE_ONLY=1 timeout --signal=INT --kill-after=5s 45s "$QUARTUS_BIN/quartus_stp" -t scripts/jtag/read_step6_servo_acquisition_context.tcl > "$RECORD/acquisition.log" 2>&1
else
  S6_ACQ_MAIN_READBACK=1 timeout --signal=INT --kill-after=5s 950s "$QUARTUS_BIN/quartus_stp" -t scripts/jtag/read_step6_servo_acquisition_context.tcl > "$RECORD/acquisition.log" 2>&1
fi
OBSERVER_RC=$?
set -e
printf 'OBSERVER_RC=%s\n' "$OBSERVER_RC"
python3 scripts/analysis/step6_acquisition_attribution.py "$RECORD/acquisition.log" > "$RECORD/acquisition.json"
if [ "$MODE" = smoke ]; then
  [ "$OBSERVER_RC" -eq 0 ]
  python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); assert r["has_reader_done"] and not r["reader_error_lines"] and any("STOP_REASON=SMOKE_DONE" in s for s in r["acquisition_stop_lines"]); m=r["main_phase_readback"]; assert m["valid_frames"] >= 3 and any(d>0 and d<0x80000000 for d in m["update_progress_deltas_same_identity"]), r' "$RECORD/acquisition.json"
  cp "$RECORD/acquisition.json" "$BASE/SMOKE_QUALIFIED.json"
else
  # Existing readonly fixed queries, after the acquisition reader releases
  # JTAG. Always preserve the unfavorable boot; never reprogram/retry it.
  printf 'TERMINAL_READBACK_BEGIN time=%s\n' "$(date -Is)"
  set +e
  timeout --signal=INT --kill-after=5s 100s "$QUARTUS_BIN/quartus_stp" -t scripts/jtag/read_step6_ip_vuart.tcl 1500 15000 pll_read_both > "$RECORD/pll-current-target-calibration.log" 2>&1
  READBACK_RC=$?
  ONCE=1 CLEAR_SCREEN=0 bash scripts/monitor/step1_6_dashboard.sh > "$RECORD/dashboard-terminal.log" 2>&1
  DASHBOARD_RC=$?
  set -e
  printf 'TERMINAL_READBACK_END time=%s readback_rc=%d dashboard_rc=%d\n' "$(date -Is)" "$READBACK_RC" "$DASHBOARD_RC"
  if [ "$OBSERVER_RC" -eq 0 ] && grep -q 'STOP_REASON=TRACK_PHASE_REACHED' "$RECORD/acquisition.log" && grep -q 'STATUS_TIME_VALID=1' "$RECORD/acquisition.log"; then
    TIME_VALID_ACQUISITION_TIMEOUT_S=60 bash scripts/monitor/verify_time_valid_300s.sh | tee "$RECORD/time-valid-verifier.log"
    capture=$(sed -n 's/^TIME_VALID_CAPTURE_PATH=//p' "$RECORD/time-valid-verifier.log")
    result=$(sed -n 's/^TIME_VALID_RESULT_PATH=//p' "$RECORD/time-valid-verifier.log")
    cp "$capture" "$RECORD/qualified-capture.log"
    cp "$result" "$RECORD/qualified-result.json"
  else
    echo 'BOOT_PRESERVED no_automatic_retry=1 no_forced_valid=1'
  fi
fi
printf 'MAIN_READBACK_END time=%s mode=%s\n' "$(date -Is)" "$MODE"
