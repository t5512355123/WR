"""Independent post-WR Main/tracker groups; descriptive correlation, not causality."""
import argparse
import json
import re
from collections import Counter
from pathlib import Path

def s32(v): return v-(1<<32) if v & (1<<31) else v
def s64(w,i):
    v=(w[i]<<32)|w[i+1]; return v-(1<<64) if v & (1<<63) else v
def parse(text,page,sid=None,total=None):
    headers=re.findall(r'^PHIST_PAGE v=1 snapshot=([0-9a-f]{8}) total=([0-9a-f]{8}) page=(\d+) count=32 words=36\r?$',text,re.M)
    if len(headers)!=1: raise ValueError('missing/duplicate header')
    identity,t,p=headers[0]
    if int(p)!=page or (sid is not None and (identity,t)!=(sid,total)):
        raise ValueError('wrong/changed snapshot')
    if len(re.findall(rf'^PHIST_END snapshot={identity} page={page}\r?$',text,re.M))!=1:
        raise ValueError('missing/duplicate end')
    raw=re.findall(r'^PHIST_V1 idx=(\d+) words=([^\r\n]+)\r?$',text,re.M)
    if len(raw)!=2: raise ValueError('missing/duplicate rows')
    rows=[]
    for j,(idx,payload) in enumerate(raw):
        words=payload.split()
        if int(idx)!=page*2+j or len(words)!=36 or any(not re.fullmatch('[0-9a-f]{8}',x) for x in words):
            raise ValueError('index/schema/word failure')
        w=[int(x,16) for x in words]
        if w[0]!=(int(t,16)-32+int(idx)+1)&0xffffffff: raise ValueError('serial mismatch')
        if w[16]!=1 or w[26]!=1 or w[34]&1 or w[35]&1:
            raise ValueError('incoherent source group')
        if w[19] not in (1,2) or not w[24]&1: raise ValueError('invalid Main frame')
        # Source proven PHY8bit / divided DMTD, HPLL_N14. Main error uses the
        # divided16ns clock. Ptracker API normalizes then doubles modulo8ns.
        phase=s32(w[30])
        if phase<0: phase+=16384
        elif phase>=16384: phase-=16384
        phase=(phase*2)&16383
        rows.append({'serial':w[0],'ucnt':w[1],'state':w[2]&0xffff,
            'setp_before':s32(w[3]),'setp_after':s32(w[4]),'phase_writes':w[5],
            'spll_init':w[6],'ms':w[7],
            'cko_ps':(s64(w,8)*10**9*65536+s64(w,10))*1000/65536,
            'dms_ps':(s64(w,12)*10**9*65536+s64(w,14))*1000/65536,
            'main_update':w[17],'main_init':w[18],'branch':w[19],
            'main_error_raw':s32(w[20]),'main_error_ps':s32(w[20])*16000/16384 if w[19]==2 else None,
            'freq_error':s32(w[21]),'pi_x':s32(w[22]),'pi_output':s32(w[23]),
            'main_flags':w[24],'sample_n':w[25],
            'tracker_generation':w[27],'tracker_publications':w[28],
            'tracker_age_ms':(w[7]-w[29])&0xffffffff,
            'tracker_phase_ps':phase*8000//16384,'tracker_publish_flags':w[31],
            'last_ref_tag':s32(w[32]),'last_input_tag':s32(w[33])})
    return identity,t,rows

def analyze(path):
    text=Path(path).read_text(); rows=[]; errors=[]; sid=total=None
    for line in text.splitlines():
        if not line.startswith('PHIST_REPLY '): continue
        try:
            m=re.fullmatch(r'PHIST_REPLY page=(\d+) start_ms=(\d+) end_ms=(\d+) status=OK hex=([0-9a-fA-F]+)',line)
            if not m: raise ValueError('invalid reply transport')
            p,a,b,h=m.groups()
            if int(p)!=len(rows)//2 or int(b)<int(a): raise ValueError('page/time order')
            sid,total,page=parse(bytes.fromhex(h).decode('ascii'),int(p),sid,total);rows.extend(page)
        except (ValueError,UnicodeError) as exc: errors.append(str(exc))
    done=re.findall(r'^PHIST_DONE records=(\d+) elapsed_ms=(\d+)$',text,re.M)
    if len(done)!=1 or done[0][0]!='32' or len(rows)!=32 or 'PHIST_STOP ' in text:
        errors.append('incomplete capture')
    elif not 0<int(done[0][1])<=240000: errors.append('actual deadline')
    if not re.search(r'^PHIST_SMOKE_PASS records=2 ',text,re.M): errors.append('missing smoke')
    health={'MASTER':[],'SLAVE':[]}
    for line in text.splitlines():
        if not line.startswith('TS4_HEALTH_OK '):continue
        m=re.fullmatch(r'TS4_HEALTH_OK role=(MASTER|SLAVE) STATUS=([0-9A-Fa-f]{16}) ESCR=([0-9A-Fa-f]{8}) H=([0-9A-Fa-f]{8}) M=([0-9A-Fa-f]{8}) P=([0-9A-Fa-f]{8}) RESET=\{(\d+ \d+ \d+ \d+ \d+)\}',line)
        if not m: errors.append('malformed health');continue
        role,st,es,h,ma,p,reset=m.groups();st,es,h,ma,p=map(lambda x:int(x,16),(st,es,h,ma,p))
        if any(not st&(1<<i) for i in (0,1,2,3,6,7,15,32)) or not h&1: errors.append('upstream health lost')
        if role=='MASTER' and (not st&16 or es&12!=12): errors.append('Master validity lost')
        if role=='SLAVE' and (ma&14!=14 or p&2!=2): errors.append('Slave lock lost')
        health[role].append(reset)
    for role,sigs in health.items():
        if len(sigs)<2 or len(set(sigs))!=1: errors.append(role+' bracket/generation failure')
    if len({(r['spll_init'],r['main_init'],r['tracker_generation']) for r in rows})>1:
        errors.append('history generation changed')
    steps=[]
    for a,b in zip(rows,rows[1:]):
        if (b['ucnt']-a['ucnt'])&0xffffffff!=1: errors.append('nonconsecutive WR history');continue
        if not 0<((b['ms']-a['ms'])&0xffffffff)<10000:errors.append('WR history time order')
        for key in ('sample_n','main_update','tracker_publications'):
            if ((b[key]-a[key])&0xffffffff)>=2**31:
                errors.append(key+' reset/decreased; not fresh progression')
        steps.append({'from_ucnt':a['ucnt'],'to_ucnt':b['ucnt'],
            'cko_delta_ps':b['cko_ps']-a['cko_ps'],
            'main_error_delta_ps':b['main_error_ps']-a['main_error_ps'] if None not in (a['main_error_ps'],b['main_error_ps']) else None,
            'main_updates':(b['sample_n']-a['sample_n'])&0xffffffff,
            'tracker_publications':(b['tracker_publications']-a['tracker_publications'])&0xffffffff,
            'setpoint_action_before_ps':a['setp_after']-a['setp_before']})
    def extent(key):
        values=[r[key] for r in rows if r[key] is not None];return [min(values),max(values)] if values else []
    return {'verdict':'INCONCLUSIVE' if errors else 'PASS_POST_ACCEPT_PHASE_DATA_ONLY',
        'errors':sorted(set(errors)),'rows':rows,'differences':steps,
        'ranges':{k:extent(k) for k in ('cko_ps','main_error_ps','pi_output','tracker_age_ms')},
        'states':dict(Counter(str(r['state']) for r in rows)),
        'main_progress_pairs':sum(s['main_updates']>0 for s in steps),
        'tracker_progress_pairs':sum(s['tracker_publications']>0 for s in steps),
        'scope':'Post-accepted-WR coherent Main and tracker groups, independently copied. Last-bin endpoint tags are NOT all512 samples. Not packet-time atomic, causal proof, continuous300s or Step6 PASS.'}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('trace');a=p.parse_args()
    r=analyze(a.trace);print(json.dumps(r,indent=2));raise SystemExit(bool(r['errors']))
