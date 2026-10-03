"""Supplemental descriptive audit; does not replace or relax strict verdicts."""
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts" / "analysis"))
from step6_strict_offset_300s import fields

BASE = Path(__file__).resolve().parent


def audit_strict(path):
    rows = [fields(line) for line in path.read_text().splitlines()
            if line.startswith("S6_STRICT_SAMPLE ")]
    reasons = Counter()
    previous = None
    fine = []
    for row in rows:
        t, u = int(row["row_end_ms"]), int(row["UCNT"], 16)
        k, state = int(row["CKO_PS"]), int(row["SERVO_STATE"])
        for flag in ("READS_VALID", "FRAME_VALID", "TRUSTWORTHY",
                     "STEP1_GATE", "LOCK_GATE"):
            if row[flag] != "1":
                reasons[flag + "!=1"] += 1
        if int(row["MASTER_AGE_MS"]) > 1500:
            reasons["master_age_over_1500ms"] += 1
        if previous:
            dt, du = t - previous[0], (u - previous[1]) & 0xffffffff
            if not 0 < dt <= 1000:
                reasons["sample_gap_over_1000ms_or_nonpositive"] += 1
            if du not in (0, 1):
                reasons["skipped_or_backwards_update"] += 1
        # A separate descriptive subset, never substituted into dwell analysis.
        # Retain all original rows. SYNC_PHASE/coarse low32 values are not
        # interpreted as fine, full64 phase evidence.
        if (all(row[f] == "1" for f in ("READS_VALID", "FRAME_VALID",
                                        "STEP1_GATE", "LOCK_GATE"))
                and state in (4, 5) and u > 0):
            fine.append(k)
        previous = (t, u)
    return {"rows": len(rows), "overlapping_guard_reasons": dict(reasons),
            "coherent_track_wait_descriptive_rows": len(fine),
            "coherent_track_wait_cko_range_ps": [min(fine), max(fine)] if fine else [],
            "coherent_track_wait_outside_120_rows": sum(abs(k) > 120 for k in fine)}


def main():
    dco = json.loads((BASE / "analysis/20261003T071703Z-main-dco.json").read_text())
    if dco["errors"] or len(dco["rows"]) != 60:
        raise ValueError("No complete diagnostic; do not silently filter failed rows")
    rows = dco["rows"]
    out = {"strict": {p.name: audit_strict(p) for p in
                         sorted((BASE / "raw/observe").glob("*strict-offset-validity.log"))},
           "dco": {"rows": len(rows), "success_first": rows[0]["success"],
                   "success_last": rows[-1]["success"],
                   "success_delta": (rows[-1]["success"] - rows[0]["success"]) & 0xffffffff,
                   "ucnt_range": [rows[0]["ucnt"], rows[-1]["ucnt"]],
                   "strict60_rows": sum(abs(r["cko_ps"]) < 60 for r in rows),
                   "inclusive120_rows": sum(abs(r["cko_ps"]) <= 120 for r in rows),
                   "states": dict(Counter(str(r["servo_state"]) for r in rows)),
                   "residual_abs_over8": [r for r in rows if abs(r["residual"]) > 8]},
           "scope": "Descriptive secondary audit only. Guard counts overlap. No rejected row removed, freshness/gap relaxed, or 300s verdict changed. Not a randomized paired comparison or physical chip readback."}
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
