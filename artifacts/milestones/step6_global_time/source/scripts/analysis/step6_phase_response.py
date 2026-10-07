#!/usr/bin/env python3
"""Bounded phase-response diagnosis, NOT a strict Step6 PASS verifier."""
import argparse
import collections
import json
from pathlib import Path
import re

def summarize(path):
    rows=[]
    for line in Path(path).read_text().splitlines():
        if not line.startswith("S6_SERVO_PAIR_SAMPLE "): continue
        row=dict(re.findall(r"(\w+)=([^ ]+)",line))
        if row.get("READS_VALID")!="1" or row.get("COHERENT")!="1": continue
        row={**row,"ucnt":int(row["UCNT_AFTER"],16)}
        for field in ("CKO_PS","SETP_PS","DMS_PS","MU_PS","elapsed_ms","SERVO_STATE"):
            row[field]=int(row[field])
        if rows and row["ucnt"]==rows[-1]["ucnt"]: continue
        rows.append(row)
    adjacent=[]
    for a,b in zip(rows,rows[1:]):
        if (b["ucnt"]-a["ucnt"])&0xffffffff != 1: continue
        adjacent.append({"elapsed_ms":b["elapsed_ms"],
            **{f"d{f}":b[f]-a[f] for f in ("CKO_PS","SETP_PS","DMS_PS","MU_PS")},
            "state":b["SERVO_STATE"]})
    unchanged=[p for p in adjacent if p["dSETP_PS"]==0]
    large=[p for p in unchanged if abs(p["dCKO_PS"])>120]
    return {
        "scope":"UCNT-bracketed diagnosis only; publication-epoch coherence not established",
        "source":str(path),"unique_updates":len(rows),"adjacent_pairs":len(adjacent),
        "cko_range_ps":[min((r["CKO_PS"] for r in rows),default=None),max((r["CKO_PS"] for r in rows),default=None)],
        "strict_entry_updates":sum(abs(r["CKO_PS"])<60 for r in rows),
        "within_retention_band":sum(abs(r["CKO_PS"])<=120 for r in rows),
        "states":dict(collections.Counter(r["SERVO_STATE"] for r in rows)),
        "zero_setpoint_delta_pairs":len(unchanged),
        "zero_setpoint_delta_large_cko_jump_pairs":len(large),
        "largest_zero_setpoint_delta_cko_jumps":sorted(large,key=lambda p:abs(p["dCKO_PS"]),reverse=True)[:12],
        "pointwise_valid_outside_120":sum(abs(r["CKO_PS"])>120 and r.get("STATUS_TIME_VALID")=="1" for r in rows),
        "reset_changed":any(r.get("RESET_CHANGED")!="0" for r in rows),
        "conclusion":"Cannot establish 300s strict PASS or physical causal gain from this diagnostic trace."
    }
if __name__=="__main__":
    parser=argparse.ArgumentParser(); parser.add_argument("trace"); args=parser.parse_args()
    print(json.dumps(summarize(args.trace),indent=2))
