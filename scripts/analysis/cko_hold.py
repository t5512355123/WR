#!/usr/bin/env python3
"""Strict CKO hold analysis for read_step6_servo_interleaved_offset.tcl logs.

PASS when, after a fresh unique update with |CKO| < entry_ps (TRACK entry),
every following unique coherent update stays |CKO| <= retain_ps and in
TRACK_PHASE (state 4) for at least hold_s seconds.  Read-only analysis.
"""
import argparse, json, re, sys

ap = argparse.ArgumentParser()
ap.add_argument("log")
ap.add_argument("--entry-ps", type=int, default=60)
ap.add_argument("--retain-ps", type=int, default=120)
ap.add_argument("--hold-s", type=float, default=120.0)
ap.add_argument("--max-gap-s", type=float, default=5.0)
a = ap.parse_args()

def num(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


rows, seen, raw_by_ucnt = [], set(), {}
for line in open(a.log, encoding="utf-8", errors="replace"):
    if line.startswith("S6_RAW_OFFSET"):
        m = re.search(r"UCNT=([0-9A-Fa-f]+) RAW_OFFSET_PS=(-?\d+)", line)
        if m:
            raw_by_ucnt.setdefault(int(m.group(1), 16), int(m.group(2)))
        continue
    if not line.startswith("S6_INTERLEAVED_SAMPLE"):
        continue
    d = dict(re.findall(r"(\w+)=(\S+)", line))
    if d.get("COHERENT") != "1" or "CKO_PS" not in d:
        continue
    if d["UCNT"] in seen:
        continue
    seen.add(d["UCNT"])
    rows.append({"t": float(d["elapsed_ms"]) / 1000.0, "ucnt": int(d["UCNT"], 16),
                 "cko": int(d["CKO_PS"]), "state": d.get("SERVO_STATE"),
                 "setp": num(d.get("SETP_PS")), "dms": num(d.get("DMS_PS")),
                 "tv": d.get("STATUS_TIME_VALID")})

best, cur_start, last = 0.0, None, None
for r in rows:
    ok_retain = abs(r["cko"]) <= a.retain_ps and r["state"] == "4" and r["tv"] == "1"
    gap_ok = last is None or (r["t"] - last["t"]) <= a.max_gap_s
    if cur_start is not None and ok_retain and gap_ok:
        best = max(best, r["t"] - cur_start["t"])
    else:
        cur_start = r if (abs(r["cko"]) < a.entry_ps and r["state"] == "4" and r["tv"] == "1") else None
    last = r

ck = [r["cko"] for r in rows]
dms = [r["dms"] for r in rows]
jumps = sum(1 for p, q in zip(rows, rows[1:]) if p["dms"] is not None and q["dms"] is not None and abs(q["dms"] - p["dms"]) > 2000)
mean = sum(ck) / len(ck) if ck else 0
sd = (sum((c - mean) ** 2 for c in ck) / (len(ck) - 1)) ** 0.5 if len(ck) > 1 else 0
states = {}
for r in rows:
    states[r["state"]] = states.get(r["state"], 0) + 1
raw = [raw_by_ucnt[r["ucnt"]] for r in rows if r["ucnt"] in raw_by_ucnt]
rmean = sum(raw) / len(raw) if raw else 0
rsd = (sum((c - rmean) ** 2 for c in raw) / (len(raw) - 1)) ** 0.5 if len(raw) > 1 else 0
out = {
    "raw_single_exchange_offset": {"n": len(raw), "min_ps": min(raw) if raw else None,
        "max_ps": max(raw) if raw else None, "mean_ps": round(rmean, 1), "sd_ps": round(rsd, 1)},
    "unique_updates": len(rows),
    "span_s": round(rows[-1]["t"] - rows[0]["t"], 3) if rows else 0,
    "cko_min_ps": min(ck) if ck else None, "cko_max_ps": max(ck) if ck else None,
    "cko_mean_ps": round(mean, 1), "cko_sd_ps": round(sd, 1),
    "abs_cko_le_60": sum(1 for c in ck if abs(c) <= 60),
    "abs_cko_le_120": sum(1 for c in ck if abs(c) <= 120),
    "dms_jumps_over_2ns": jumps,
    "state_counts": states,
    "best_strict_hold_s": round(best, 3),
    "required_hold_s": a.hold_s,
    "verdict": "PASS_CKO_HOLD" if best >= a.hold_s else "FAIL_CKO_HOLD",
}
print(json.dumps(out, indent=2))
sys.exit(0 if out["verdict"] == "PASS_CKO_HOLD" else 1)
