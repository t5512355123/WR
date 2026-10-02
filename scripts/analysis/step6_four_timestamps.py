"""Same-producer four-stamp identities. Data PASS is never Step6 PASS."""
import argparse
import json
import re
from collections import Counter
from fractions import Fraction
from pathlib import Path

WORDS = 86
RECORDS = 16
SCALED_PER_SEC = 10**9 * 65536


def signed(value, bits):
    return value - (1 << bits) if value & (1 << (bits-1)) else value


def int64(w, at):
    return signed((w[at] << 32) | w[at+1], 64)


def time_value(w, at):
    # Incorrect stamps hide bits in secs. Reject, do not clear/fabricate them.
    if (w[at] >> 24) & 0xc0 == 0x80:
        raise ValueError('incorrect timestamp flag')
    return int64(w, at)*SCALED_PER_SEC + int64(w, at+2)


def ps(scaled):
    return Fraction(scaled*1000, 65536)


def decode(w):
    if len(w) != WORDS or any(not 0 <= x < 2**32 for x in w):
        raise ValueError('record word count/range')
    if w[9] != 1 or w[6] >> 24 != 9 or w[12] != 0:
        raise ValueError('not normal-feedback E2E DelayResp')
    if (w[2] & 0xffff) not in range(6) or w[2] >> 16 not in range(6):
        raise ValueError('unknown servo state')
    raw = [time_value(w, 16+i*4) for i in range(4)]
    cal = [time_value(w, 32+i*4) for i in range(4)]
    deltas = [time_value(w, 48+i*4) for i in range(4)]
    rtt, dms, mean, cko = [time_value(w, 64+i*4) for i in range(4)]
    raw_rtt, asym = time_value(w, 80), int64(w, 84)
    corrected = [raw[0]+deltas[0], raw[1]-deltas[1],
                 raw[2]+deltas[2], raw[3]-deltas[3]]
    if corrected != cal:
        raise ValueError('raw/calibrated fixed-delta mismatch')
    rf, rr = raw[1]-raw[0], raw[3]-raw[2]
    cf, cr = cal[1]-cal[0], cal[3]-cal[2]
    if raw_rtt != rf+rr or rtt != cf+cr:
        raise ValueError('RTT four-stamp identity mismatch')
    if cko != dms-cf:
        raise ValueError('CKO/DMS/forward identity mismatch')
    # Production first rounds RTT to integer ps, then >>1 and converts back;
    # picos_to_pp_time/picos_to_interval each have sub-ps rounding conventions.
    if abs(ps(mean)-ps(rtt)/2) > 2 or abs(ps(dms)-ps(mean+asym)) > 2:
        raise ValueError('meanDelay/asymmetry identity mismatch')
    return {'serial': w[0], 'ucnt': w[1], 'pre_state': w[2] >> 16,
        'state': w[2] & 0xffff, 'setp_before': signed(w[3],32),
        'setp_after': signed(w[4],32), 'sync_seq': w[5] >> 16,
        'delay_seq': w[5] & 0xffff, 'source': tuple(w[6:9]),
        'writes': w[10], 'inits': w[11], 'spll_inits': w[13],
        'flags': w[14], 'result': signed(w[15],32),
        'raw_forward': ps(rf), 'raw_return': ps(rr), 'forward': ps(cf),
        'return': ps(cr), 'rtt': ps(rtt), 'raw_rtt': ps(raw_rtt),
        'dms': ps(dms), 'cko': ps(cko), 'asym': ps(asym),
        'deltas': tuple(ps(x) for x in deltas)}


def parse_page(text, page, prior_id=None, prior_total=None):
    headers = re.findall(r'^TS4_PAGE v=1 snapshot=([0-9a-f]{8}) total=([0-9a-f]{8}) page=(\d+) count=(\d+) words=(\d+)\r?$', text, re.M)
    if len(headers) != 1:
        raise ValueError('missing/duplicate TS4 page header')
    sid, total, p, count, words = headers[0]
    count = int(count)
    if int(p) != page or count != RECORDS or int(words) != WORDS:
        raise ValueError('unexpected TS4 page/count/schema')
    if prior_id is not None and (sid, total) != (prior_id, prior_total):
        raise ValueError('changed TS4 snapshot')
    if len(re.findall(rf'^TS4_END snapshot={sid} page={page}\r?$', text, re.M)) != 1:
        raise ValueError('missing/duplicate TS4 page completion')
    rows = re.findall(r'^TS4_V1 idx=(\d+) words=([^\r\n]+)\r?$', text, re.M)
    if len(rows) != 1 or int(rows[0][0]) != page:
        raise ValueError('wrong TS4 index/record count')
    words = rows[0][1].split()
    if len(words) != WORDS or any(not re.fullmatch('[0-9a-f]{8}', x) for x in words):
        raise ValueError('malformed TS4 payload')
    w = [int(x,16) for x in words]
    if w[0] != (int(total,16)-count+page+1)&0xffffffff:
        raise ValueError('TS4 ring serial mismatch')
    return sid, total, decode(w)


def analyze(path):
    text = Path(path).read_text()
    errors = []; rows = []; sid = total = None
    for line in text.splitlines():
        if not line.startswith('TS4_REPLY '):
            continue
        m = re.fullmatch(r'TS4_REPLY page=(\d+) start_ms=(\d+) end_ms=(\d+) status=(\w+) hex=([0-9a-fA-F]*)', line)
        if not m:
            errors.append('malformed transport record'); continue
        page, start, end, status, payload = m.groups()
        try:
            if status != 'OK' or int(end) < int(start) or int(page) != len(rows):
                raise ValueError('transport/page order failure')
            sid, total, row = parse_page(bytes.fromhex(payload).decode('ascii'), int(page), sid, total)
            rows.append(row)
        except (ValueError, UnicodeError) as exc:
            errors.append(str(exc))
    done = re.findall(r'^TS4_DONE records=(\d+) elapsed_ms=(\d+)$', text, re.M)
    if len(done)!=1 or done[0][0]!='16' or len(rows)!=RECORDS or 'TS4_STOP ' in text:
        errors.append('incomplete bounded capture')
    elif not 0<int(done[0][1])<=360000:
        errors.append('actual capture deadline exceeded')
    if not re.search(r'^TS4_SMOKE_PASS records=2 ', text, re.M):
        errors.append('missing same-snapshot smoke')
    health = {'MASTER': [], 'SLAVE': []}
    for line in text.splitlines():
        if not line.startswith('TS4_HEALTH_OK '): continue
        m=re.fullmatch(r'TS4_HEALTH_OK role=(MASTER|SLAVE) STATUS=([0-9A-Fa-f]{16}) ESCR=([0-9A-Fa-f]{8}) H=([0-9A-Fa-f]{8}) M=([0-9A-Fa-f]{8}) P=([0-9A-Fa-f]{8}) RESET=\{(\d+ \d+ \d+ \d+ \d+)\}',line)
        if not m:
            errors.append('malformed health guard'); continue
        role, st, es, h, main, pstat, reset = m.groups()
        st,es,h,main,pstat=[int(x,16) for x in (st,es,h,main,pstat)]
        if any(not st&(1<<bit) for bit in (0,1,2,3,6,7,15,32)) or not h&1:
            errors.append('live link/clock/Helper health lost')
        if role=='MASTER' and (not st&16 or es&12!=12):
            errors.append('Master local validity lost')
        if role=='SLAVE' and (main&14!=14 or pstat&2!=2):
            errors.append('Slave lock health lost')
        health[role].append(reset)
    for role, sigs in health.items():
        if len(sigs)<2: errors.append('missing '+role+' bracket health')
        elif len(set(sigs))!=1: errors.append(role+' reset/generation changed')
    if rows:
        if len({(r['inits'], r['spll_inits'], r['source']) for r in rows})!=1:
            errors.append('changed init/source generation')
        if len({r['ucnt'] for r in rows})!=len(rows):
            errors.append('duplicate update')
    steps=[]
    for a,b in zip(rows,rows[1:]):
        distance=(b['ucnt']-a['ucnt'])&0xffffffff
        if not 0<distance<2**31:
            errors.append('update order decreased/duplicated')
        if distance!=1:
            continue
        steps.append({'from_ucnt':a['ucnt'], 'to_ucnt':b['ucnt'],
            'cko_delta_ps':float(b['cko']-a['cko']),
            'dms_delta_ps':float(b['dms']-a['dms']),
            'raw_forward_delta_ps':float(b['raw_forward']-a['raw_forward']),
            'raw_return_delta_ps':float(b['raw_return']-a['raw_return']),
            'raw_rtt_delta_ps':float(b['raw_rtt']-a['raw_rtt']),
            'asym_delta_ps':float(b['asym']-a['asym']),
            'fixed_deltas_changed':b['deltas']!=a['deltas'],
            'setp_before_delta_ps':b['setp_before']-a['setp_before'],
            'setp_previous_action_ps':a['setp_after']-a['setp_before']})
    ranges={k:[float(min(r[k] for r in rows)),float(max(r[k] for r in rows))]
            for k in ('cko','dms','raw_rtt','rtt','raw_forward','raw_return','forward','return','asym')} if rows else {}
    return {'verdict':'INCONCLUSIVE' if errors else 'PASS_COHERENT_TIMESTAMP_DATA_ONLY',
        'records':len(rows),'consecutive_pairs':len(steps),'snapshot':sid,
        'ranges_ps':ranges,'states':dict(Counter(str(r['state']) for r in rows)),
        'large_cko_transition_pairs':[s for s in steps if abs(s['cko_delta_ps'])>=1000],
        'errors':sorted(set(errors)),
        'scope':'One producer snapshot of pre-control stamps/math with pre/post action state/SETP. Not raw OOB, physical skew, causality, uninterrupted history or strict300s PASS.'}


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('trace'); args=p.parse_args()
    result=analyze(args.trace); print(json.dumps(result,indent=2))
    raise SystemExit(bool(result['errors']))
