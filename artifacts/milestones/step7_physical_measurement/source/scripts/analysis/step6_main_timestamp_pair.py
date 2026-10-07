"""Exact accepted-update joins of existing passive Main and timestamp histories."""
import argparse
import json
import re
from collections import Counter
from pathlib import Path

import step6_four_timestamps as ts
import step6_phase_history as ph


def analyze(path):
    text = Path(path).read_text()
    errors = []; trows = []; prows = []; tw = {}; pw = {}
    identity = {"TS4": (None, None), "PHIST": (None, None)}
    pages = Counter(); previous_end = -1
    header = "MTP_CONFIG ts4_records=16 phist_records=32 min_joined=12 max_actual_ms=480000 control_changed=0 cycle_atomic=0"
    if text.count(header) != 1:
        errors.append("missing/duplicate pair contract")
    expected = [("TS4", 0), ("PHIST", 0)] + [("PHIST", p) for p in range(1, 16)] + [("TS4", p) for p in range(1, 16)]
    reply_n = 0
    for line in text.splitlines():
        if not line.startswith(("TS4_REPLY ", "PHIST_REPLY ")):
            continue
        try:
            m = re.fullmatch(r'(TS4|PHIST)_REPLY page=(\d+) start_ms=(\d+) end_ms=(\d+) status=OK hex=([0-9a-fA-F]+)', line)
            if not m:
                raise ValueError("invalid pair reply transport")
            kind, p, start, end, payload = m.groups()
            p, start, end = int(p), int(start), int(end)
            if (reply_n >= len(expected) or (kind, p) != expected[reply_n] or
                    not 0 <= start < end <= 480000 or start < previous_end):
                raise ValueError("pair page/time order or deadline")
            raw = bytes.fromhex(payload).decode("ascii")
            sid, total = identity[kind]
            if kind == "TS4":
                sid, total, row = ts.parse_page(raw, p, sid, total)
                w = [int(x, 16) for x in re.search(r'^TS4_V1 idx=\d+ words=([^\r\n]+)', raw, re.M)[1].split()]
                if row["ucnt"] in tw:
                    raise ValueError("duplicate timestamp update")
                tw[row["ucnt"]] = w; trows.append(row)
            else:
                sid, total, group = ph.parse(raw, p, sid, total)
                for row, match in zip(group, re.finditer(r'^PHIST_V1 idx=\d+ words=([^\r\n]+)', raw, re.M)):
                    w = [int(x, 16) for x in match[1].split()]
                    if row["ucnt"] in pw:
                        raise ValueError("duplicate Main-history update")
                    pw[row["ucnt"]] = w; prows.append(row)
            identity[kind] = (sid, total); pages[kind] += 1
            previous_end = end; reply_n += 1
        except (ValueError, UnicodeError, TypeError, IndexError) as exc:
            errors.append(str(exc))
    done = re.findall(r'^MTP_DONE ts4_records=(\d+) phist_records=(\d+) elapsed_ms=(\d+)$', text, re.M)
    if (len(done) != 1 or done[0][:2] != ("16", "32") or
            not previous_end <= int(done[0][2]) <= 480000 or
            len(trows) != 16 or len(prows) != 32 or reply_n != 32 or
            "MTP_STOP " in text or not re.search(r'^MTP_SMOKE_PASS ', text, re.M)):
        errors.append("incomplete/stopped/overdeadline paired capture")
    # Reuse the unchanged source-proven live health checks; no synthetic DONE
    # supplied to the old single-history analyzers or relaxed old deadlines.
    health = {"MASTER": [], "SLAVE": []}
    for line in text.splitlines():
        if not line.startswith("TS4_HEALTH_OK "):
            continue
        m = re.fullmatch(r'TS4_HEALTH_OK role=(MASTER|SLAVE) STATUS=([0-9A-Fa-f]{16}) ESCR=([0-9A-Fa-f]{8}) H=([0-9A-Fa-f]{8}) M=([0-9A-Fa-f]{8}) P=([0-9A-Fa-f]{8}) RESET=\{(\d+ \d+ \d+ \d+ \d+)\}', line)
        if not m:
            errors.append("malformed health"); continue
        role, st, es, h, ma, p, reset = m.groups()
        st, es, h, ma, p = [int(v, 16) for v in (st, es, h, ma, p)]
        if any(not st & (1 << b) for b in (0, 1, 2, 3, 6, 7, 15, 32)) or not h & 1:
            errors.append("upstream health lost")
        if role == "MASTER" and (not st & 16 or es & 12 != 12):
            errors.append("Master validity lost")
        if role == "SLAVE" and (ma & 14 != 14 or p & 2 != 2):
            errors.append("Slave lock lost")
        health[role].append(reset)
    for role, signatures in health.items():
        if len(signatures) < 2 or len(set(signatures)) != 1:
            errors.append(role + " bracket/reset failure")
    for rows in (trows, prows):
        if any((b["ucnt"] - a["ucnt"]) & 0xffffffff != 1 for a, b in zip(rows, rows[1:])):
            errors.append("nonconsecutive source history")
    if len({(r["inits"], r["spll_inits"], r["source"]) for r in trows}) > 1:
        errors.append("timestamp generation/source changed")
    if len({(r["spll_init"], r["main_init"], r["tracker_generation"]) for r in prows}) > 1:
        errors.append("Main/tracker generation changed")
    skew = None
    if identity["PHIST"][1] and identity["TS4"][1]:
        skew = (int(identity["PHIST"][1], 16) - int(identity["TS4"][1], 16)) & 0xffffffff
        if skew > 20:
            errors.append("snapshot skew exceeds source-proven overlap")
    pm = {r["ucnt"]: r for r in prows}; joined = []
    for r in trows:
        u = r["ucnt"]
        if u not in pm:
            continue
        p, a, b = pm[u], tw[u], pw[u]
        if (b[8:12] != a[76:80] or b[12:16] != a[68:72] or b[2:6] != a[2:5] + [a[10]] or b[6] != a[13]):
            errors.append("same-update exact CKO/DMS/state/SETP/generation mismatch")
        joined.append(dict(p, forward_ps=float(r["forward"]), return_ps=float(r["return"]),
                           raw_forward_ps=float(r["raw_forward"]), raw_return_ps=float(r["raw_return"]),
                           asym_ps=float(r["asym"])))
    if len(joined) < 12:
        errors.append("fewer than12 exact joined updates")
    differences = []
    for a, b in zip(joined, joined[1:]):
        if (b["ucnt"] - a["ucnt"]) & 0xffffffff != 1:
            errors.append("nonconsecutive joined updates"); continue
        d = {"from_ucnt": a["ucnt"], "to_ucnt": b["ucnt"],
             "previous_setpoint_action_ps": a["setp_after"] - a["setp_before"],
             "main_updates": (b["sample_n"] - a["sample_n"]) & 0xffffffff,
             "tracker_publications": (b["tracker_publications"] - a["tracker_publications"]) & 0xffffffff}
        for key in ("cko_ps", "main_error_ps", "forward_ps", "return_ps", "raw_forward_ps", "raw_return_ps", "asym_ps"):
            d[key] = None if None in (a[key], b[key]) else b[key] - a[key]
        d["tracker_circular_delta_ps"] = (b["tracker_phase_ps"] - a["tracker_phase_ps"] + 4000) % 8000 - 4000
        if d["main_updates"] >= 2**31 or d["tracker_publications"] >= 2**31:
            errors.append("Main/tracker counter decreased")
        differences.append(d)
    ranges = {}
    for key in ("cko_ps", "main_error_ps", "tracker_age_ms", "pi_output", "forward_ps", "return_ps"):
        values = [r[key] for r in joined if r[key] is not None]
        ranges[key] = [min(values), max(values)] if values else []
    return {"verdict": "INCONCLUSIVE" if errors else "PASS_EXACT_UPDATE_JOIN_DATA_ONLY",
            "errors": sorted(set(errors)), "ts4_rows": len(trows), "phist_rows": len(prows),
            "freeze_skew_updates": skew, "joined_rows": len(joined), "ranges": ranges,
            "rows": joined, "differences": differences,
            "scope": "Exact same accepted WR update CKO/DMS identities; independent post-accept Main/tracker copies. Not packet-time atomic phase, randomised comparison, causal proof, physical chip readback, or300s/Step6 PASS. Original single-history readers/deadlines unchanged."}


if __name__ == "__main__":
    p = argparse.ArgumentParser(); p.add_argument("trace")
    result = analyze(p.parse_args().trace)
    print(json.dumps(result, indent=2)); raise SystemExit(bool(result["errors"]))
