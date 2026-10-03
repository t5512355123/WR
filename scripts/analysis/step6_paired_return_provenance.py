"""Match actual Master DelayReq RX to accepted Slave T4. Never a Step6 PASS."""
import argparse
import importlib.util
import json
import re
from fractions import Fraction
from pathlib import Path


def sibling(name):
    s = importlib.util.spec_from_file_location(name, Path(__file__).with_name(name+'.py'))
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
    return m


four = sibling('step6_four_timestamps')
rx = sibling('step6_rxts_packet_diagnostic')


def analyze(path):
    path = Path(path); text = path.read_text()
    ts_result = four.analyze(path)
    errors = list(ts_result['errors'])
    identities = {}
    for role, mac, clock, port in re.findall(
            r'^PAIR_ID role=(MASTER|SLAVE) mac=([0-9a-f:]{17}) clockid=([0-9a-f]{16}) port=(\d+)$', text, re.M):
        compact = mac.replace(':', '')
        if role in identities or clock != compact[:6]+'fffe'+compact[6:] or port != '1':
            errors.append('duplicate/inconsistent live identity')
        identities[role] = clock
    if set(identities) != {'MASTER', 'SLAVE'}:
        errors.append('two live MAC identities missing')
    mac_replies = re.findall(r'^PAIR_MAC_REPLY role=(MASTER|SLAVE) status=(\w+) hex=([0-9a-fA-F]+)$', text, re.M)
    if len(mac_replies) != 2 or {r for r, _, _ in mac_replies} != {'MASTER', 'SLAVE'}:
        errors.append('live MAC raw replies missing')
    for role, status, payload in mac_replies:
        try:
            macs = re.findall(r'MAC-address: ([0-9a-fA-F:]{17})', bytes.fromhex(payload).decode('ascii'))
            if status != 'OK' or len(macs) != 1 or macs[0].replace(':', '')[:6].lower()+'fffe'+macs[0].replace(':', '')[6:].lower() != identities.get(role):
                errors.append('raw MAC provenance mismatch')
        except (ValueError, UnicodeError): errors.append('malformed raw MAC reply')
    done = re.findall(r'^PAIR_DONE master_records=(\d+) slave_records=(\d+) elapsed_ms=(\d+)$', text, re.M)
    if len(done) != 1 or done[0][:2] != ('32', '16') or not 0 < int(done[0][2]) <= 360000 or 'PAIR_STOP ' in text:
        errors.append('incomplete/deadline/stopped paired capture')
    if not re.search(r'^PAIR_SMOKE_PASS master_rows=4 slave_rows=1 ', text, re.M):
        errors.append('missing paired same-snapshot smoke')
    freezes = re.findall(r'^PAIR_FREEZE_REQUEST role=(MASTER|SLAVE) kind=(TS4|RXTS) start_ms=(\d+) end_ms=(\d+)$', text, re.M)
    if len(freezes) != 2 or [(r, k) for r, k, _, _ in freezes] != [('SLAVE', 'TS4'), ('MASTER', 'RXTS')]:
        errors.append('wrong/duplicate rapid snapshot requests')
    elif any(int(e)<int(s) for _,_,s,e in freezes) or int(freezes[1][2]) < int(freezes[0][3]):
        errors.append('invalid request intervals')

    master = {}; pages = {}; sid = total = None
    # Parse the preserved raw replies, not only derived RXTS_RECORD lines.
    for line in text.splitlines():
        if not line.startswith('RXTS_REPLY '): continue
        m = re.fullmatch(r'RXTS_REPLY board=\{DE5 \[1-11\.1\]\} capture=0 page=(\d+) start_ms=(\d+) end_ms=(\d+) status=(\w+) hex=([0-9a-fA-F]*)', line)
        if not m:
            errors.append('wrong Master target/malformed RX reply'); continue
        page, start, end, status, payload = m.groups(); page = int(page)
        try:
            if page != len(pages) or int(end)<int(start) or status != 'OK': raise ValueError('RX transport/order failed')
            raw = bytes.fromhex(payload).decode('ascii')
            h = re.findall(r'^RXTS_PAGE v=1 snapshot=([0-9a-f]{8}) total=([0-9a-f]{8}) page=(\d+) count=(\d+)\r?$',raw,re.M)
            if len(h)!=1: raise ValueError('RX header missing/duplicated')
            s,t,p,n = h[0]
            if int(p)!=page or n!='32' or (sid is not None and (s,t)!=(sid,total)): raise ValueError('RX snapshot changed')
            sid,total=s,t
            if len(re.findall(rf'^RXTS_END snapshot={sid} page={page}\r?$',raw,re.M))!=1: raise ValueError('RX completion missing/duplicated')
            rows=re.findall(r'^RXTS_V1 idx=(\d+) words=([^\r\n]+)\r?$',raw,re.M)
            if len(rows)!=4: raise ValueError('RX page rows incomplete')
            for j,(idx,data) in enumerate(rows):
                if int(idx)!=page*4+j: raise ValueError('RX index/order mismatch')
                words=data.split()
                if len(words)!=18 or any(not re.fullmatch('[0-9a-f]{8}',w) for w in words): raise ValueError('RX word schema')
                w=[int(x,16) for x in words]
                if w[0]!=(int(total,16)-32+int(idx)+1)&0xffffffff: raise ValueError('RX serial mismatch')
                period=w[17]; phase=rx.signed32(w[8]); t24p=rx.signed32(w[9])
                if period!=8000 or not 0<=phase<period or not 0<=t24p<period: raise ValueError('RX phase/calibration scale')
                raw_sec=(w[5]<<32)|w[6]; raw_ns=rx.signed32(w[7])
                expected=rx.linearize(raw_sec,raw_ns,phase,bool(w[4]&(1<<17)),t24p,period)
                actual=((w[10]<<32)|w[11],rx.signed32(w[12]),rx.signed32(w[13]),bool(w[4]&(1<<18)))
                if expected!=actual: raise ValueError('actual RX linearization mismatch')
                if w[1]>>24 != 1 or w[4]&0xffff != 1 or f'{w[2]:08x}{w[3]:08x}'!=identities.get('SLAVE'):
                    raise ValueError('Master RX is not live Slave DelayReq/port')
                key=(w[1]&0xffff,(w[1]>>16)&0xff)
                if key in master: raise ValueError('duplicate RX sequence/domain')
                # Literal time-wrpc/wrpc-socket.c conversion, including truncation.
                scaled=actual[0]*four.SCALED_PER_SEC + actual[1]*65536 + actual[2]*65536//1000
                coarse=raw_sec*four.SCALED_PER_SEC+raw_ns*65536
                master[key]={'words':w,'scaled':scaled,'coarse':coarse,'fine':scaled-coarse,
                    'correct':bool(w[4]&(1<<16)),'ahead':bool(w[4]&(1<<17)),'falling':actual[3],
                    'raw_phase':phase,'t24p':t24p}
            pages[page]=(sid,total)
        except (ValueError,UnicodeError) as exc: errors.append(str(exc))
    if set(pages)!=set(range(8)) or len(master)!=32: errors.append('incomplete32 Master history')
    if len({r['t24p'] for r in master.values()})!=1: errors.append('Master history calibration changed')

    joined=[]; tsid=tstotal=None; slave_domains=set()
    for line in text.splitlines():
        if not line.startswith('TS4_REPLY '): continue
        try:
            v=dict(re.findall(r'(\w+)=(\S+)',line)); index=int(v['page'])
            raw=bytes.fromhex(v['hex']).decode('ascii')
            tsid,tstotal,row=four.parse_page(raw,index,tsid,tstotal)
            if f'{row["source"][1]:08x}{row["source"][2]:08x}'!=identities.get('MASTER') or row['source'][0]&0xffff!=1:
                raise ValueError('Slave TS4 source is not live Master/port')
            data=re.search(r'^TS4_V1 idx=\d+ words=([^\r\n]+)',raw,re.M)
            w=[int(x,16) for x in data[1].split()]
            key=(row['delay_seq'],(row['source'][0]>>16)&0xff)
            slave_domains.add(key[1])
            mr=master.get(key)
            if mr is None: continue  # Outside overlap is counted, never fabricated.
            if not mr['correct']: raise ValueError('paired Master RX marked incorrect')
            t4=four.time_value(w,28); t3=four.time_value(w,24)
            if t4 != mr['scaled']: raise ValueError('same-sequence Master RX != accepted Slave raw T4')
            joined.append({'row':row,'rx':mr,'coarse_leg':four.ps(mr['coarse']-t3),
                'fine_correction':four.ps(mr['fine']), 'raw_t4_hi_lo':w[28:32]})
        except (ValueError,UnicodeError,KeyError) as exc: errors.append(str(exc))
    if len(joined)<8: errors.append('fewer than8 exact paired accepted updates')
    if len(slave_domains)!=1 or {k[1] for k in master} != slave_domains:
        errors.append('inconsistent two-board PTP domain')
    previous_time=None
    for data in sorted(master.values(),key=lambda r:r['words'][0]):
        if previous_time is not None and data['scaled']<=previous_time:
            errors.append('Master RX time not fresh/increasing')
        previous_time=data['scaled']
    steps=[]
    for a,b in zip(joined,joined[1:]):
        ra,rb=a['row'],b['row']
        if (rb['ucnt']-ra['ucnt'])&0xffffffff != 1: continue
        steps.append({'from_ucnt':ra['ucnt'],'to_ucnt':rb['ucnt'],
            'delay_seq_before':ra['delay_seq'],'delay_seq_after':rb['delay_seq'],
            'cko_delta_ps':float(rb['cko']-ra['cko']),
            'raw_forward_delta_ps':float(rb['raw_forward']-ra['raw_forward']),
            'raw_return_delta_ps':float(rb['raw_return']-ra['raw_return']),
            'coarse_return_delta_ps':float(b['coarse_leg']-a['coarse_leg']),
            'linearization_correction_delta_ps':float(b['fine_correction']-a['fine_correction']),
            'ahead_before':a['rx']['ahead'],'ahead_after':b['rx']['ahead'],
            'falling_before':a['rx']['falling'],'falling_after':b['rx']['falling'],
            'master_raw_phase_delta_ps':b['rx']['raw_phase']-a['rx']['raw_phase'],
            'setp_previous_action_ps':ra['setp_after']-ra['setp_before'],
            'setp_current_action_ps':rb['setp_after']-rb['setp_before'],
            'fixed_deltas_changed':rb['deltas']!=ra['deltas']})
    if len(steps)<4: errors.append('fewer than4 consecutive paired update differences')
    return {'verdict':'INCONCLUSIVE' if errors else 'PASS_PAIRED_RETURN_DATA_ONLY',
        'slave_timestamp_verdict':ts_result['verdict'],'master_records':len(master),
        'paired_updates':len(joined),'unpaired_slave_updates':ts_result['records']-len(joined),
        'paired_ucnt':[r['row']['ucnt'] for r in joined], 'consecutive_paired_differences':len(steps),
        'master_t24p_ps':sorted({r['t24p'] for r in master.values()}),
        'paired_cko_range_ps':[float(min((r['row']['cko'] for r in joined),default=0)),float(max((r['row']['cko'] for r in joined),default=0))],
        'large_cko_transition_pairs':[s for s in steps if abs(s['cko_delta_ps'])>=1000],
        'errors':sorted(set(errors)),
        'scope':'Exact source/port/domain/DelayResp sequence plus full64 time joins. Complete32/16 immutable histories; only overlapping accepted pairs used. Not simultaneous acquisition, physical accuracy, causality or strict300s PASS.'}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('trace');args=p.parse_args()
    result=analyze(args.trace);print(json.dumps(result,indent=2));raise SystemExit(bool(result['errors']))
