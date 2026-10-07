#!/usr/bin/env python3
"""Fixed-setpoint diagnostic, not a relaxed strict-goal verifier."""
import argparse
import json
from pathlib import Path
import re
from step6_strict_offset_300s import analyze as strict_analyze, fields

def query(path):
    records=[]
    for line in Path(path).read_text().splitlines():
        if not line.startswith('STEP6_VUART_QUERY_RESULT '): continue
        match=re.search(r'reply_hex=([0-9A-Fa-f]+)',line)
        if not match or 'status=OK ' not in line: continue
        text=bytes.fromhex(match[1]).decode('ascii')
        for item in re.findall(r'FIXED_V1 ([^\r\n]+)',text):
            records.append({k:int(v) for k,v in fields(item).items()})
    if len(records)!=1: raise ValueError('Expected one complete versioned fixed query')
    result=records[0]
    required={'enabled','latched','entry','writes','inits','revoked','setp',
              'spll_init','current','target'}
    if set(result)!=required: raise ValueError('Wrong fixed query schema')
    if 'reset_changed=0' not in Path(path).read_text():
        raise ValueError('Missing query generation guard')
    return result

def analyze(trace,before,after):
    errors=[]; a=query(before); b=query(after)
    if a['enabled']!=1 or a['latched']!=1 or b['latched']!=1:
        errors.append('freeze latch not established')
    for key in ('entry','writes','inits','setp','spll_init','target'):
        if a[key]!=b[key]: errors.append('changed '+key)
    if a['current']!=a['target'] or b['current']!=b['target']:
        errors.append('hardware phase adjustment not settled at endpoints')
    text=Path(trace).read_text(); values=[]; delays=[]; updates=[]; times=[]
    for line in text.splitlines():
        if not line.startswith('S6_STRICT_SAMPLE '): continue
        row=fields(line)
        if row.get('TRUSTWORTHY')!='1': continue
        for group in ('SETP','DMS'):
            if row.get(group+'_UCNT')!=row['UCNT']:
                errors.append('unmatched '+group+' update')
            try:
                if (int(row[group+'_EPOCH_BEFORE'],16)&0xffff)!=(int(row[group+'_EPOCH_AFTER'],16)&0xffff):
                    errors.append('torn '+group+' publication')
            except (KeyError,ValueError): errors.append('missing '+group+' guard')
        if any(row.get(k)!='1' for k in ('FRAME_VALID','STEP1_GATE','LOCK_GATE',
              'MASTER_TIME_VALID','MASTER_LINK_GATE')): errors.append('health loss')
        if int(row['SERVO_STATE'])!=4: errors.append('state exit')
        raw=int(row['SETP_RAW'],16); setp=raw if raw<2**31 else raw-2**32
        if setp!=a['setp']: errors.append('published setpoint changed')
        if int(row['SPLL_INIT'],16)!=a['spll_init']: errors.append('SPLL reinit')
        u=int(row['UCNT'],16)
        if updates and updates[-1]==u: continue
        if not updates and ((u-a['entry'])&0xffffffff)>=2**31:
            errors.append('capture precedes freeze entry')
        updates.append(u); values.append(int(row['CKO_PS']))
        delays.append((int(row['DMS_HI'],16)<<32)|int(row['DMS_LO'],16))
        times.append(int(row['row_end_ms']))
    if len(updates)<40 or not times or times[-1]-times[0]<55000:
        errors.append('insufficient fresh bounded diagnostic')
    if 'S6_STRICT_STOP ' in text: errors.append('observer invariant stop')
    # Source: proto-standard/servo.c, CKO = T1 - T2 + delayMS.
    # Thus DMS-CKO is the calibrated forward difference T2-T1, not raw T2-T1.
    forward=[d-k for d,k in zip(delays,values)]
    midpoint=(min(values)+max(values))/2 if values else 0
    clusters=[]
    for upper in (False,True):
        selected=[(k,d) for k,d in zip(values,delays) if (k>midpoint)==upper]
        clusters.append({'side':'upper' if upper else 'lower','count':len(selected),
            'mean_cko_ps':sum(k for k,d in selected)/len(selected) if selected else None,
            'mean_dms_ps':sum(d for k,d in selected)/len(selected) if selected else None})
    strict=strict_analyze(trace)
    if strict['errors']: errors.extend(strict['errors'])
    return {'verdict':'INCONCLUSIVE' if errors else 'PASS_FIXED_SETP_DIAGNOSTIC_ONLY',
        'before':a,'after':b,'unique_updates':len(updates),
        'fresh_cko_range_ps':[min(values,default=None),max(values,default=None)],
        'dms_range_ps':[min(delays,default=None),max(delays,default=None)],
        'calibrated_forward_t2_minus_t1_range_ps':[min(forward,default=None),max(forward,default=None)],
        'exploratory_midrange_cko_groups':clusters,
        'adjacent_cko_delta_range_ps':[
            min((y-x for x,y in zip(values,values[1:])),default=None),
            max((y-x for x,y in zip(values,values[1:])),default=None)],
        'strict_goal':strict,'errors':sorted(set(errors)),
        'scope':'Constant published SETP and counted WR writes, settled hardware endpoint readbacks, stable SPLL init; no analogue or cycle-atomic target proof. Diagnostic PASS is not Step6 PASS.'}

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('trace'); p.add_argument('before'); p.add_argument('after')
    args=p.parse_args(); result=analyze(args.trace,args.before,args.after)
    print(json.dumps(result,indent=2)); raise SystemExit(bool(result['errors']))
