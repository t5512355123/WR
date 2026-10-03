"""Coherent virtual DCO-account diagnostic; not physical readback/300s proof."""
import argparse
import json
import re
from pathlib import Path

def word(s):
    if not re.fullmatch('[0-9A-Fa-f]{16}', s):
        raise ValueError('missing/full64 raw')
    return int(s, 16)

def decode(f):
    a, b = word(f['META0']), word(f['META1'])
    if a != b or (a >> 29)&7 != 1 or not a&(1<<17) or a&(7<<21):
        raise ValueError('capture coherence/schema/init/failure')
    pos, count = word(f['POSITION']), word(f['COUNTS'])
    names=('E0','E1','C0','C1','UCNT','CKO','SSTAT','LE0','LE1','LC0','LC1','H','M','P')
    if any(not re.fullmatch('[0-9A-Fa-f]{8}',f[n]) for n in names):
        raise ValueError('full32 group raw missing')
    e0,e1,c0,c1,u,k,s,le0,le1,lc0,lc1,h,m,p = [int(f[n],16) for n in names]
    if ((e0^e1)&0xffff or not(c0&1 and c1&1) or (le0^le1)&0xffff or
        not(lc0&1 and lc1&1) or not(h&1 and m&14==14 and p&2)):
        raise ValueError('WR publication/lock invalid')
    if word(f['L2'])&0xf0 or word(f['FAILED']) or word(f['FAILURE']):
        raise ValueError('L2 failure')
    start,cap_end,wr_start,wr_end,lock_start,lock_end,end = [int(f[n]) for n in
        ('start_ms','capture_end_ms','wr_start_ms','wr_end_ms','lock_start_ms','lock_end_ms','end_ms')]
    if (not 0<=start<cap_end<=wr_start<wr_end<=lock_start<lock_end<=end or
        cap_end-start>600 or wr_end-wr_start>600 or lock_end-lock_start>600 or end-start>1500):
        raise ValueError('group time bounds')
    target,applied = pos&0xffffffff,pos>>32
    starts,success = count&0xffffffff,count>>32
    if target>65535 or applied>65536 or applied%16 or (starts-success)&0xffffffff not in (0,1):
        raise ValueError('source-proven unsigned16/step16 accounting')
    return {'n':int(f['n']),'start_ms':start,'capture_end_ms':cap_end,'end_ms':end,
        'wr_start_ms':wr_start,'wr_end_ms':wr_end,'lock_start_ms':lock_start,'lock_end_ms':lock_end,
        'capture_seq':(a>>1)&0xffff,'clock50_ticks':a>>32,'target':target,
        'virtual_applied':applied,'residual':target-applied,'starts':starts,
        'success':success,'main_pending':(a>>18)&1,'tx_active':(a>>19)&1,
        'tx_owner_main':(a>>20)&1,'state':(a>>24)&7,'dir':(a>>27)&1,
        'cko_ps':k-(1<<32) if k&(1<<31) else k,'ucnt':u,
        'servo_state':(s>>8)&255,'main_max_latency_ms':(word(f['LATENCY'])&0xffffffff)/50000,
        'helper_max_latency_ms':(word(f['LATENCY'])>>32)/50000}

def analyze(path):
    text=Path(path).read_text(); rows=[]; errors=[]; captures={}
    if 'MAIN_DCO_CONFIG schema=2 samples=60 max_actual_ms=120000 control_changed=0 applied_position_is_virtual=1 cross_group_atomic=0' not in text:
        errors.append('missing/source-contract header')
    for line in text.splitlines():
        if line.startswith('MAIN_DCO_CAPTURE_RAW '):
            try:
                f=dict(part.split('=',1) for part in line.split()[1:]); n=int(f['n'])
                if n in captures:raise ValueError('duplicate raw capture')
                for key in ('META0','META1','POSITION','COUNTS'):word(f[key])
                captures[n]=f
            except (KeyError,ValueError) as exc:errors.append(str(exc))
            continue
        if not line.startswith('MAIN_DCO_SAMPLE '):continue
        try:
            fields=dict(part.split('=',1) for part in line.split()[1:])
            r=decode(fields)
            if r['n']!=len(rows):raise ValueError('sample missing/duplicate/order')
            raw=captures[r['n']]
            if any(fields[key]!=raw[key] for key in
                   ('META0','META1','POSITION','COUNTS','start_ms','capture_end_ms')):
                raise ValueError('raw/sample capture mismatch')
            if rows:
                prior=rows[-1]
                if (r['capture_seq']-prior['capture_seq'])&0xffff != 1:
                    raise ValueError('another observer/sequence discontinuity')
                dt=(r['clock50_ticks']-prior['clock50_ticks'])&0xffffffff
                if not 0<dt<250000000 or r['start_ms']<=prior['end_ms']:
                    raise ValueError('capture clock/time order')
                for key in ('starts','success','ucnt'):
                    if (r[key]-prior[key])&0xffffffff >= 2**31:
                        raise ValueError(key+' reset/decreased')
            rows.append(r)
        except (KeyError,ValueError) as exc:errors.append(str(exc))
    done=re.findall(r'^MAIN_DCO_DONE samples=(\d+) elapsed_ms=(\d+)$',text,re.M)
    if len(done)!=1 or done[0][0]!='60' or len(rows)!=60 or len(captures)!=60 or not 0<int(done[0][1])<=120000:
        errors.append('incomplete/overdeadline capture')
    if 'MAIN_DCO_STOP ' in text or 'MAIN_DCO_SMOKE_PASS samples=3' not in text:
        errors.append('stop/missing smoke')
    health={'MASTER':[],'SLAVE':[]}
    for line in text.splitlines():
        if not line.startswith('TS4_HEALTH_OK '):continue
        m=re.fullmatch(r'TS4_HEALTH_OK role=(MASTER|SLAVE) STATUS=([0-9A-Fa-f]{16}) ESCR=([0-9A-Fa-f]{8}) H=([0-9A-Fa-f]{8}) M=([0-9A-Fa-f]{8}) P=([0-9A-Fa-f]{8}) RESET=\{(\d+ \d+ \d+ \d+ \d+)\}',line)
        if not m:errors.append('malformed health');continue
        role,st,es,h,ma,p,reset=m.groups(); st,es,h,ma,p=[int(x,16) for x in (st,es,h,ma,p)]
        if any(not st&(1<<i) for i in (0,1,2,3,6,7,15,32)) or not h&1:
            errors.append('upstream health lost')
        if role=='MASTER' and (not st&16 or es&12!=12):errors.append('Master validity lost')
        if role=='SLAVE' and (ma&14!=14 or p&2!=2):errors.append('Slave lock lost')
        health[role].append(reset)
    for role,sigs in health.items():
        if len(sigs)<2 or len(set(sigs))!=1:errors.append(role+' reset/bracket failure')
    def extent(key):
        vals=[r[key] for r in rows]; return [min(vals),max(vals)] if vals else []
    return {'verdict':'INCONCLUSIVE' if errors else 'PASS_DCO_ACCOUNT_DATA_ONLY',
        'errors':sorted(set(errors)),'raw_captures':len(captures),'rows':rows,'ranges':{k:extent(k) for k in
            ('residual','cko_ps','main_max_latency_ms','helper_max_latency_ms')},
        'main_progress_intervals':sum(((b['success']-a['success'])&0xffffffff)>0
                                    for a,b in zip(rows,rows[1:])),
        'residual_at_least_step_rows':sum(abs(r['residual'])>=16 for r in rows),
        'scope':'Single50MHz-edge virtual position/transaction-account capture. WR and L2 groups independently guarded/read, not cycle-atomic, chip readback, causal proof, or300s/Step6 PASS. Pending-based wait may omit/pre-date residual admission.'}
if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('trace'); a=p.parse_args()
    r=analyze(a.trace); print(json.dumps(r,indent=2)); raise SystemExit(bool(r['errors']))
