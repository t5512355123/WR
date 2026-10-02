#!/usr/bin/env python3
"""Verify the full sampled 60/120 ps hysteresis + 300 s goal, fail closed."""
import argparse
import json
from pathlib import Path
import re

def fields(line):
    return {key:value.strip("{}") for key,value in
            re.findall(r"(\w+)=(\{[^}]*\}|\S+)",line)}

def analyze(path,required_ms=300000,max_gap_ms=1000,max_update_age_ms=2000):
    text=Path(path).read_text()
    rows=[fields(line) for line in text.splitlines() if line.startswith("S6_STRICT_SAMPLE ")]
    done=[fields(line) for line in text.splitlines() if line.startswith("S6_STRICT_DONE ")]
    errors=[]
    if len(done)!=1 or done[0].get("timeout_count")!="0" or done[0].get("invalid_count")!="0":
        errors.append("missing/failed transport completion")
    if not rows: errors.append("no samples")
    if "S6_STRICT_STOP " in text: errors.append("observer stopped on reset/untrusted data")
    signature=None; board=None; previous=None; last_unique=None
    entry=None; start=None; best=0; best_window=None; current_unique=0
    outside=0; entry_count=0; untrusted=0; state_counts={}; cko_values=[]
    for row in rows:
        try:
            t=int(row["row_end_ms"]); k=int(row["CKO_PS"]); u=int(row["UCNT"],16)
            epoch0=int(row["EPOCH_BEFORE"],16)&0xffff
            epoch1=int(row["EPOCH_AFTER"],16)&0xffff
            state=int(row["SERVO_STATE"])
            needed=("READS_VALID","FRAME_VALID","TRUSTWORTHY","STEP1_GATE","LOCK_GATE")
            trusted=all(row[n]=="1" for n in needed) and row["RESET_CHANGED"]=="0"
            trusted=trusted and epoch0==epoch1 and int(row["EPOCH_AGE_MS"])<=1000
            trusted=trusted and -2147483648<=k<=2147483647
            raw=int(row["CKO_RAW"],16)
            trusted=trusted and raw==k&0xffffffff
            current_sig=row["RESET_SIGNATURE"]
            if signature is None: signature=current_sig; board=row["board"]
            if signature!=current_sig or board!=row["board"]:
                errors.append("reset signature or board changed"); trusted=False
            if previous:
                dt=t-previous["t"]
                du=(u-previous["u"])&0xffffffff
                trusted=trusted and 0<dt<=max_gap_ms and du in (0,1)
                if du==0 and (k,state)!=(previous["k"],previous["state"]): trusted=False
            else: du=1
            if du==1: last_unique=t
            trusted=trusted and last_unique is not None and t-last_unique<=max_update_age_ms
            master_ok=(row.get("MASTER_HEALTH_VALID")=="1" and
                row.get("MASTER_TIME_VALID")=="1" and row.get("MASTER_LINK_GATE")=="1" and
                row.get("MASTER_RESET_CHANGED")=="0" and
                0<=int(row.get("MASTER_AGE_MS","999999"))<=1500)
            if row.get("MASTER_RESET_CHANGED")=="1":
                errors.append("Master reset signature changed")
            qualified=trusted and master_ok and row["TIME_VALID"]=="1" and state==4 and abs(k)<=120
            if trusted:
                cko_values.append(k); state_counts[state]=state_counts.get(state,0)+1
                if row["TIME_VALID"]=="1" and abs(k)>120: outside+=1
            else: untrusted+=1
            if qualified and abs(k)<60 and du==1:
                entry_count+=1
                if entry is None: entry=t
            if not qualified:
                start=None; entry=None; current_unique=0
            elif entry is not None:
                if start is None: start=t; current_unique=0
                current_unique+=du
                span=t-start
                if span>=best:
                    best=span
                    best_window={"start_ms":start,"end_ms":t,"entry_ms":entry,
                                 "unique_updates":current_unique}
            previous={"t":t,"u":u,"k":k,"state":state}
        except (KeyError,ValueError):
            errors.append("malformed row"); start=None; entry=None; previous=None
    passed=not errors and outside==0 and best>=required_ms
    return {"verdict":"PASS_SAMPLED_STRICT_GOAL" if passed else
            ("INCONCLUSIVE" if errors else "NOT_ESTABLISHED"),
        "required_duration_ms":required_ms,"maximum_qualified_span_ms":best,
        "best_window":best_window,"rows":len(rows),"fresh_strict_entry_observations":entry_count,
        "pointwise_valid_outside_retention":outside,"rejected_rows":untrusted,
        "trusted_cko_range_ps":[min(cko_values,default=None),max(cko_values,default=None)],
        "states":state_counts,"errors":sorted(set(errors)),
        "scope":"Coherent Slave publication, bracketed live health and interleaved fresh Master validity, contiguous sampled producer updates. Not analogue skew or cycle-atomic cross-domain proof."}

if __name__=="__main__":
    p=argparse.ArgumentParser(); p.add_argument("trace"); p.add_argument("--required-ms",type=int,default=300000)
    args=p.parse_args(); result=analyze(args.trace,args.required_ms)
    print(json.dumps(result,indent=2))
    raise SystemExit(0 if result["verdict"]=="PASS_SAMPLED_STRICT_GOAL" else 1)
