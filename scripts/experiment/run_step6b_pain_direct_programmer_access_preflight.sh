#!/usr/bin/env bash
# Read-only Pain programmer-access preflight for
# EXP-S6B-PAIN-DIRECT-PROGRAMMER-ACCESS-PREFLIGHT-20260922.
# This script must never invoke sudo or a Quartus programming operation.
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
QUARTUS_BIN=${QUARTUS_BIN:-/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin}
QUARTUS_PGM="$QUARTUS_BIN/quartus_pgm"
EXP_ID=${1:-EXP-S6B-PAIN-DIRECT-PROGRAMMER-ACCESS-PREFLIGHT-20260922}
EXP_DIR="$ROOT/experiments/step6/$EXP_ID"
RAW_DIR="$EXP_DIR/raw"
ANALYSIS_DIR="$EXP_DIR/analysis"
PREV_BUILD_DIR="$ROOT/experiments/legacy/exp-step6-global-time/EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-20260922/raw/build"
POSTFIT_TIMING_SUMMARY="$ROOT/experiments/legacy/exp-step6-global-time/EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922/analysis/summary.json"
DESIGN_SOURCE_COMMIT="c24568e383be3355ac8684b7d13f293115931586"
MASTER_SOF="$ROOT/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof"
SLAVE_SOF="$ROOT/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof"
MASTER_MIF="$ROOT/build/firmware/master/wrc.mif"
SLAVE_MIF="$ROOT/build/firmware/slave/wrc.mif"

mkdir -p "$RAW_DIR" "$ANALYSIS_DIR"

cat > "$RAW_DIR/protocol.txt" <<EOF
EXP_ID=$EXP_ID
COMPILE=NO
FIRMWARE_BUILD=NO
MASTER_PROGRAM=NO
SLAVE_PROGRAM=NO
FPGA_PROGRAM_COUNT=0
RESET=NO
PTP_RESTART=NO
POWER_CYCLE=NO
TARGET_ARM_WRITE=NO
SUDO=FORBIDDEN
QUARTUS_PGM_OPERATION=list_only
EOF

actual_hash() {
  if [ -s "$1" ]; then
    sha256sum "$1" | awk '{print $1}'
  else
    printf 'MISSING'
  fi
}

provenance_ok=1
expected_build_source_commit=$(sed -n 's/^GIT_HEAD=//p' \
  "$PREV_BUILD_DIR/source_identity.txt" 2>/dev/null | head -1)
{
  echo "=== STEP6B DIRECT PROGRAMMER PREFLIGHT ==="
  date -Is
  echo "HOST=$(hostname)"
  echo "ROOT=$ROOT"
  echo "GIT_HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "GIT_BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo unknown)"
  echo "DESIGN_SOURCE_COMMIT=$DESIGN_SOURCE_COMMIT"
  echo "EXPECTED_FITTED_BUILD_SOURCE_COMMIT=$expected_build_source_commit"
  if [ "$expected_build_source_commit" = "$DESIGN_SOURCE_COMMIT" ]; then
    echo "FITTED_BUILD_SOURCE_COMMIT_MATCH=YES"
  else
    echo "FITTED_BUILD_SOURCE_COMMIT_MATCH=NO"
    provenance_ok=0
  fi
  echo "QUARTUS_VERSION_BEGIN"
  "$QUARTUS_BIN/quartus_sh" --version 2>&1 || true
  echo "QUARTUS_VERSION_END"
  echo "ARTIFACT_HASHES_BEGIN"
  for pair in \
    "MASTER_SOF_SHA256|$MASTER_SOF|1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5" \
    "SLAVE_SOF_SHA256|$SLAVE_SOF|66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151" \
    "MASTER_MIF_SHA256|$MASTER_MIF|8b569afe29d93cfedca84eed484c9c683f1fc58cf10e89943574b7de8d31df7e" \
    "SLAVE_MIF_SHA256|$SLAVE_MIF|eab60d5ceb4af234284f6f241a4595ee850cf3a0184a939d70a30c3d8a5ad26b"; do
    label=${pair%%|*}
    rest=${pair#*|}
    file=${rest%%|*}
    expected=${rest#*|}
    actual=$(actual_hash "$file")
    match=NO
    if [ "$actual" = "$expected" ]; then match=YES; else provenance_ok=0; fi
    printf '%s EXPECTED=%s ACTUAL=%s MATCH=%s FILE=%s\n' \
      "$label" "$expected" "$actual" "$match" "$file"
  done
  echo "ARTIFACT_HASHES_END"
  if grep -q '"classification": "PASS_STEP6B_POSTFIT_TIMING_PROVEN"' \
      "$POSTFIT_TIMING_SUMMARY" 2>/dev/null; then
    echo "POSTFIT_TIMING_PROOF=PASS_STEP6B_POSTFIT_TIMING_PROVEN"
  else
    echo "POSTFIT_TIMING_PROOF=MISSING_OR_MISMATCH"
    provenance_ok=0
  fi
  echo "PROVENANCE_CHECK=$provenance_ok"
} > "$RAW_DIR/provenance.txt" 2>&1

if [ "$provenance_ok" -ne 1 ]; then
  cat > "$RAW_DIR/stop.txt" <<EOF
RESULT=NOT_RUN_FITTED_ARTIFACT_PROVENANCE_MISMATCH
FPGA_PROGRAM_COUNT=0
MASTER_PROGRAM_COUNT=0
SLAVE_PROGRAM_COUNT=0
EOF
  printf '{\n  "classification": "NOT_RUN_FITTED_ARTIFACT_PROVENANCE_MISMATCH",\n  "verdict": "NOT_RUN",\n  "fpga_program_count": 0\n}\n' > "$ANALYSIS_DIR/summary.json"
  exit 0
fi

command_line="$QUARTUS_PGM -l"
printf 'COMMAND=%s\n' "$command_line" > "$RAW_DIR/quartus_pgm_list.log"
set +e
"$QUARTUS_PGM" -l >> "$RAW_DIR/quartus_pgm_list.log" 2>&1
quartus_pgm_rc=$?
set -e

master_visible=NO
slave_visible=NO
grep -Fq 'DE5 [1-11.1]' "$RAW_DIR/quartus_pgm_list.log" && master_visible=YES
grep -Fq 'DE5 [1-11.2]' "$RAW_DIR/quartus_pgm_list.log" && slave_visible=YES
forbidden=NO
if grep -Eiq 'sudo|password|configuration succeeded|programming successful|[[:space:]]-o([[:space:]]|$)' \
    "$RAW_DIR/quartus_pgm_list.log"; then
  forbidden=YES
fi

result=FAIL_DIRECT_NONSUDO_PROGRAMMER_ACCESS
failure_class=PAIN_PROGRAMMER_ACCESS_INFRASTRUCTURE
if [ "$forbidden" = YES ]; then
  result=INCONCLUSIVE_UNEXPECTED_CONFIGURATION_ACTION
  failure_class=UNEXPECTED_CONFIGURATION_ACTION
elif [ "$quartus_pgm_rc" -eq 0 ] && [ "$master_visible" = YES ] && [ "$slave_visible" = YES ]; then
  result=PASS_DIRECT_NONSUDO_PROGRAMMER_ACCESS
  failure_class=NONE
elif [ "$quartus_pgm_rc" -eq 0 ] && { [ "$master_visible" = YES ] || [ "$slave_visible" = YES ]; }; then
  result=FAIL_REQUIRED_PROGRAMMING_CABLE_NOT_VISIBLE
  failure_class=INCOMPLETE_CABLE_ENUMERATION
fi

cat > "$RAW_DIR/stop.txt" <<EOF
RESULT=$result
FAILURE_CLASS=$failure_class
QUARTUS_PGM_LIST_RC=$quartus_pgm_rc
MASTER_CABLE_VISIBLE=$master_visible
SLAVE_CABLE_VISIBLE=$slave_visible
FPGA_PROGRAM_COUNT=0
MASTER_PROGRAM_COUNT=0
SLAVE_PROGRAM_COUNT=0
SUDO_USED=NO
PROGRAM_OPERATION=NO
EOF
printf '{\n  "classification": "%s",\n  "failure_class": "%s",\n  "verdict": "%s",\n  "quartus_pgm_list_rc": %d,\n  "master_cable_visible": "%s",\n  "slave_cable_visible": "%s",\n  "fpga_program_count": 0,\n  "sudo_used": false\n}\n' \
  "$result" "$failure_class" "$([ "$result" = PASS_DIRECT_NONSUDO_PROGRAMMER_ACCESS ] && printf PASS || printf STOP)" \
  "$quartus_pgm_rc" "$master_visible" "$slave_visible" > "$ANALYSIS_DIR/summary.json"
exit 0
