"""Validate and summarize frozen RX timestamp snapshots, not a Step6 PASS."""
import argparse
import json
import re
from collections import Counter
from pathlib import Path


def signed32(w):
    return w - (1 << 32) if w & (1 << 31) else w


def linearize(raw_sec, raw_ns, raw_phase, ahead, t24p, period):
    """Literal integer operations of the unchanged lib/net.c linearizer."""
    pr = raw_phase - t24p
    if pr < 0:
        pr += period
    pf = raw_phase - t24p + period // 2
    if pf < 0:
        pf += period
    if pf >= period:
        pf -= period
    falling = pr > 3 * period // 4 or pr < period // 4
    ns = raw_ns - period // 1000 if falling and ahead else raw_ns
    phase = pf + period // 2 if falling else pr
    if falling and phase >= period:
        phase -= period
        ns += period // 1000
    if ns >= 1000000000:
        ns -= 1000000000
        raw_sec += 1
    return raw_sec, ns, phase, falling


def analyze(path):
    text = Path(path).read_text()
    errors = []
    groups = {}
    for line in text.splitlines():
        if line.startswith("RXTS_CAPTURE_PAGE "):
            m = re.fullmatch(r"RXTS_CAPTURE_PAGE board=\{([^}]+)\} capture=(\d+) snapshot=([0-9a-f]{8}) total=([0-9a-f]{8}) page=(\d+) count=(\d+)", line)
            if not m:
                errors.append("malformed page")
                continue
            board, capture, snap, total, page, count = m.groups()
            key = board, int(capture), snap
            g = groups.setdefault(key, {"pages": {}, "rows": {}, "done": False})
            if int(page) in g["pages"]:
                errors.append("duplicate page")
            g["pages"][int(page)] = int(total, 16), int(count)
        elif line.startswith("RXTS_RECORD "):
            m = re.fullmatch(r"RXTS_RECORD board=\{([^}]+)\} capture=(\d+) snapshot=([0-9a-f]{8}) RXTS_V1 idx=(\d+) words=((?:[0-9a-f]{8} ){17}[0-9a-f]{8})", line)
            if not m:
                errors.append("malformed record")
                continue
            board, capture, snap, index, words = m.groups()
            g = groups.setdefault((board, int(capture), snap), {"pages": {}, "rows": {}, "done": False})
            if int(index) in g["rows"]:
                errors.append("duplicate index")
            g["rows"][int(index)] = [int(w, 16) for w in words.split()]
        elif line.startswith("RXTS_CAPTURE_DONE "):
            m = re.fullmatch(r"RXTS_CAPTURE_DONE board=\{([^}]+)\} capture=(\d+) snapshot=([0-9a-f]{8}) records=(\d+)", line)
            if m:
                b, c, s, n = m.groups()
                g = groups.setdefault((b, int(c), s), {"pages": {}, "rows": {}, "done": False})
                g["done"] = int(n)
            else:
                errors.append("malformed completion")
    done = re.findall(r"^RXTS_DONE completed=(\d+) required=(\d+) elapsed_ms=(\d+)$", text, re.M)
    if len(done) != 1 or done[0][0] != done[0][1] or "RXTS_STOP " in text:
        errors.append("capture incomplete/stopped")
    if not groups:
        errors.append("no snapshots")
    unique = {}
    for (board, capture, snap), g in groups.items():
        if not g["pages"]:
            errors.append("no pages for snapshot")
            continue
        total, count = next(iter(g["pages"].values()))
        if not 8 <= count <= 32 or set(g["pages"].values()) != {(total, count)} or g["done"] != count:
            errors.append("snapshot count/identity invalid")
        if set(g["pages"]) != set(range((count + 3) // 4)) or set(g["rows"]) != set(range(count)):
            errors.append("missing pages/records")
        for index, w in g["rows"].items():
            if w[0] != (total - count + index + 1) & 0xffffffff:
                errors.append("record sequence inconsistent")
            k = board, w[0]
            if k in unique and unique[k] != w:
                errors.append("record identity changed across snapshots")
            unique[k] = w
    boards = {}
    for (board, ident), w in unique.items():
        b = boards.setdefault(board, {"records": 0, "correct_records": 0,
            "messages": Counter(), "ahead": Counter(), "selection": Counter(),
            "t24p_ps": set(), "raw_phase_ps": [], "correction_ps": [],
            "rising_window_margin_ps": []})
        b["records"] += 1
        b["messages"][str(w[1] >> 24)] += 1
        b["t24p_ps"].add(signed32(w[9]))
        if not w[4] & (1 << 16):
            continue
        b["correct_records"] += 1
        sec = w[5] << 32 | w[6]
        ns, phase, t24p, period = signed32(w[7]), signed32(w[8]), signed32(w[9]), w[17]
        ahead = bool(w[4] & (1 << 17))
        if period != 8000 or not 0 <= phase < period or not 0 <= t24p < period:
            errors.append("unexpected time scale/phase/calibration")
            continue
        expected = linearize(sec, ns, phase, ahead, t24p, period)
        actual = (w[10] << 32 | w[11], signed32(w[12]), signed32(w[13]), bool(w[4] & (1 << 18)))
        if expected != actual:
            errors.append("recorded linearization does not reproduce")
        b["ahead"][str(int(ahead))] += 1
        b["selection"]["falling" if actual[3] else "rising"] += 1
        b["raw_phase_ps"].append(phase)
        b["correction_ps"].append((actual[0] - sec) * 10**12 + (actual[1] - ns) * 1000 + actual[2])
        pr = (phase - t24p) % period
        b["rising_window_margin_ps"].append(min(abs(pr - period // 4), abs(pr - 3 * period // 4)))
    for b in boards.values():
        b["t24p_ps"] = sorted(b["t24p_ps"])
        for key in ("raw_phase_ps", "correction_ps", "rising_window_margin_ps"):
            values = b.pop(key)
            b[key + "_range"] = [min(values, default=None), max(values, default=None)]
    if not boards or any(b["correct_records"] < 4 for b in boards.values()):
        errors.append("insufficient correct records")
    return {"verdict": "PASS_DIAGNOSTIC_DATA_ONLY" if not errors else "INCONCLUSIVE",
            "snapshots": len(groups), "boards": boards, "errors": sorted(set(errors)),
            "scope": "Frozen packet RAM histories; omissions between snapshots possible. Does not prove timestamp physical accuracy, CKO causality, or 300s strict validity."}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("trace")
    result = analyze(p.parse_args().trace)
    print(json.dumps(result, indent=2))
    raise SystemExit(bool(result["errors"]))
