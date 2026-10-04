#!/usr/bin/env python3
"""Guarded CKO diagnostics, separate from TIME_VALID300s qualification."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import statistics

STATES={0:'UNINITIALIZED',1:'SYNC_TAI',2:'SYNC_NSEC',3:'SYNC_PHASE',4:'TRACK_PHASE',5:'WAIT_OFFSET_STABLE'}
GUARDS=('READS_VALID','PHASE_OBSERVATION_VALID','DIAG_FRAME_VALID',
        'DIAG_EPOCH_STABLE','PHASE_CONTEXT_VALID','PHASE_CONTEXT_FRAME_VALID','PHASE_CONTEXT_MATCH')
LOCKS=('HELPER_LOCK','MAIN_LOCK','MAIN_FREQ_LOCK','MAIN_PHASE_LOCK','PSTAT_LOCK')
IDENTITY=('BOOT_GENERATION','CPU_RESET_COUNT','WR_CORE_RESET_COUNT','SI_CONFIG_DROP_COUNT')

def fields(line): return dict(token.split('=',1) for token in line.split() if '=' in token)
def board(line):
    found=re.search(r'\[([^\]]+)\]',line)
    return found.group(1) if found else 'UNKNOWN'

def analyze(text,required_ms=300000):
    rows=[]; fresh=[]; rejected=Counter(); duplicates=0; identity=None; prior=None
    lines=text.splitlines()
    raw=[line for line in lines if line.startswith('S6_INTERLEAVED_SAMPLE ')]
    for line in raw:
        row=fields(line)
        if board(line)!='1-11.2': rejected['unexpected_board']+=1; continue
        if any(row.get(k)!='1' for k in GUARDS) or row.get('RESET_CHANGED')!='0' or row.get('PHASE_CONTEXT') not in ('1','2'):
            rejected['untrusted_phase_frame']+=1; continue
        try:
            current_identity=tuple(int(row[k],16) for k in IDENTITY)
            ucnt=int(row['UCNT'],16); elapsed=int(row['elapsed_ms']); cko=int(row['CKO_PS'])
            state=int(row['SERVO_STATE']); setp=int(row['SETP_PS']); dms=int(row['DMS_PS'])
            if not -2147483648<=cko<=2147483647 or elapsed<0: raise ValueError()
        except (KeyError,ValueError): rejected['malformed_row']+=1; continue
        if identity is None: identity=current_identity
        if current_identity!=identity: rejected['identity_changed']+=1; continue
        item=dict(elapsed_ms=elapsed,cko_ps=cko,state=state,setp_ps=setp,dms_ps=dms,
                  ucnt=ucnt,time_valid=row.get('STATUS_TIME_VALID')=='1',
                  healthy=row.get('STEP1_GATE')=='1' and all(row.get(k)=='1' for k in LOCKS))
        rows.append(item)
        if prior is not None:
            delta=(ucnt-prior)&0xffffffff
            if delta==0: duplicates+=1; continue
            if delta>0x7fffffff: rejected['ucnt_regressed']+=1; continue
        prior=ucnt; fresh.append(item)
    done=[line for line in lines if line.startswith('S6_INTERLEAVED_BOARD_DONE ') and board(line)=='1-11.2']
    stops=[line for line in lines if line.startswith(('S6_INTERLEAVED_STOP ','S6_INTERLEAVED_ERROR '))]
    all_boards={board(line) for line in raw}
    span=fresh[-1]['elapsed_ms']-fresh[0]['elapsed_ms'] if len(fresh)>1 else 0
    gaps=[b['elapsed_ms']-a['elapsed_ms'] for a,b in zip(fresh,fresh[1:])]
    done_good=False
    if len(done)==1:
        try:
            d=fields(done[0]); done_good=int(d['elapsed_ms'])>=required_ms and int(d['samples'])==len(raw) and d.get('reset_stop')=='0'
        except (KeyError,ValueError): pass
    complete=(all_boards=={'1-11.2'} and done_good and not stops and len(fresh)>=3 and
              span>=required_ms and bool(gaps) and all(0<g<=2000 for g in gaps) and
              not rejected['identity_changed'] and not rejected['ucnt_regressed'] and
              len(rows)>=0.9*len(raw))
    ckos=[r['cko_ps'] for r in fresh]
    result=dict(raw_rows=len(raw),guarded_rows=len(rows),unique_update_rows=len(fresh),
                duplicate_updates=duplicates,rejected=dict(rejected),observed_span_ms=span,
                max_unique_update_gap_ms=max(gaps) if gaps else None,required_duration_ms=required_ms,
                capture_complete=bool(complete),stop_records=stops,
                state_counts={STATES.get(s,str(s)):n for s,n in Counter(r['state'] for r in fresh).items()},
                time_valid_unique_rows=sum(r['time_valid'] for r in fresh),
                healthy_unique_rows=sum(r['healthy'] for r in fresh),
                simultaneous_packet_or_physical_measurement=False,
                time_valid_300s_verdict='NOT_ASSESSED_USE_SEPARATE_VERIFIER')
    if ckos:
        x=[r['elapsed_ms']/1000 for r in fresh]; xm=statistics.mean(x); ym=statistics.mean(ckos)
        denom=sum((v-xm)**2 for v in x)
        slope=sum((v-xm)*(y-ym) for v,y in zip(x,ckos))/denom if denom else None
        result.update(cko_min_ps=min(ckos),cko_max_ps=max(ckos),cko_peak_to_peak_ps=max(ckos)-min(ckos),
                      cko_median_ps=statistics.median(ckos),cko_stddev_ps=statistics.pstdev(ckos),
                      cko_slope_ps_per_s=slope,strict_under_60_rows=sum(abs(y)<60 for y in ckos),
                      within_120_rows=sum(abs(y)<=120 for y in ckos),
                      setp_min_ps=min(r['setp_ps'] for r in fresh),setp_max_ps=max(r['setp_ps'] for r in fresh),
                      dms_min_ps=min(r['dms_ps'] for r in fresh),dms_max_ps=max(r['dms_ps'] for r in fresh))
    stable=(complete and span>=300000 and all(abs(y)<=120 for y in ckos) and all(r['healthy'] for r in fresh))
    result['cko_stable_within_120ps_300s']=('SUPPORTED_AT_SAMPLED_UPDATES' if stable else
        'NOT_ESTABLISHED' if complete else 'INCONCLUSIVE_INCOMPLETE_CAPTURE')
    return result

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('capture',type=Path)
    parser.add_argument('--required-duration-ms',type=int,default=300000)
    args=parser.parse_args()
    print(json.dumps(analyze(args.capture.read_text(),args.required_duration_ms),indent=2,sort_keys=True))
if __name__=='__main__': main()
