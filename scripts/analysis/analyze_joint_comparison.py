"""Secondary reanalysis: literal R+C SHAKE versus historical Q64 branch.

The datasets and other outcomes had already been inspected before this analysis
was specified. This is not a newly preregistered confirmatory experiment.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import numpy as np

from frozen_analysis import train_ridge, score, abs_interval, roc_rows


def dump(path,obj):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(obj,ensure_ascii=False,indent=2),encoding='utf-8')


def csvout(path,rows):
    with path.open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)


def interval(g):
    n=len(g);alpha=.05/36;q=math.log(4/alpha)
    rad=math.sqrt(2*np.var(g,ddof=1)*q/n)+14*q/(3*(n-1))
    d=float(g.mean())
    return d,max(-1.,d-rad),min(1.,d+rad)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-dir', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    source, output = args.input_dir, args.output_dir
    output.mkdir(parents=True, exist_ok=False)
    models=['uniform','biased55','biased60','biased70','biased80','low_support_h2','low_support_h4','low_support_h8','low_support_h16']
    config={'analysis_kind':'secondary reanalysis of previously generated confirmation samples',
            'prior_data_visibility':True,'new_preregistration':False,
            'direct_arm':'A_joint = SHAKE256(label||R||C||0x34,8)',
            'chaos_arm':'B = original effective-Sage mix(label,R,C,8)',
            'primary_classifier':'one common pooled ridge D, 64 output bits, lambda=1, unpenalized intercept, threshold=.5',
            'training':'batches 0,1; 40000 positives per arm; U duplicated only for class balancing',
            'testing':'batches 2,3,4; 60000 independently generated rows per arm; same U and same D',
            'simultaneous_family':'18 conditions x 2 signed contrasts = 36; family alpha=.05',
            'secondary':'per-arm trained ridge descriptive only, no extra superiority testing',
            'note':'This direct one-SHAKE arm differs in SHAKE call count from original B; equal-structure two-SHAKE A remains the historical causal ablation.'}
    dump(output/'analysis_specification.json',config)
    rows=[];rocs=[];input_hashes=[]
    for model in models:
        for regime in ['healthy','fixed']:
            batches=[]
            for i in range(5):
                p=source/f'{model}_{regime}_batch{i}.npz'
                input_hashes.append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
                with np.load(p) as z:batches.append({k:z[k] for k in ['R','C','A_joint','B','U']})
            tr={k:np.concatenate([b[k] for b in batches[:2]]) for k in batches[0]}
            te={k:np.concatenate([b[k] for b in batches[2:]]) for k in batches[0]}
            common=train_ridge(np.concatenate([tr['A_joint'],tr['B']]),np.concatenate([tr['U'],tr['U']]))
            su=score(te['U'],common);pred_u=(su>=.5).astype(float)
            adv={};ais={};detail={};saved={'common_U':su}
            for arm in ['A_joint','B']:
                s=score(te[arm],common);g=(s>=.5).astype(float)-pred_u
                d,lo,hi=interval(g);ais[arm]=abs_interval(lo,hi);adv[arm]=abs(d)
                detail[arm]={'signed_difference':d,'signed_CI':[lo,hi],'advantage_CI':ais[arm],
                             'positive_rate':float((s>=.5).mean()),'uniform_rate':float(pred_u.mean())}
                rr,auc=roc_rows(s,su,{'model':model,'regime':regime,'arm':arm,'classifier':'common'})
                detail[arm]['auc']=auc;rocs.extend(rr);saved['common_'+arm]=s
            sec={}
            for arm in ['A_joint','B']:
                fit=train_ridge(tr[arm],tr['U']);s=score(te[arm],fit);u=score(te['U'],fit)
                sec[arm]={'advantage':abs(float((s>=.5).mean()-(u>=.5).mean())),'weights':fit[0].tolist(),'intercept':fit[1]}
                saved['separate_'+arm]=s;saved['separate_U_'+arm]=u
            low=ais['A_joint'][0]-ais['B'][1];high=ais['A_joint'][1]-ais['B'][0]
            row={'model':model,'regime':regime,'test_n':len(te['U']),
                 'Adv_joint_common_D':adv['A_joint'],'Adv_chaos_common_D':adv['B'],
                 'Delta_common_D':adv['A_joint']-adv['B'],'Delta_CI_low':low,'Delta_CI_high':high,
                 'excludes_2pp_improvement':high<.02,'positive_interval':low>0,
                 'separate_D_Adv_joint_descriptive':sec['A_joint']['advantage'],
                 'separate_D_Adv_chaos_descriptive':sec['B']['advantage']}
            rows.append(row)
            dump(output/f'{model}_{regime}_classifier.json',{'result':row,'common_weights':common[0].tolist(),'common_intercept':common[1],
                                                          'common_details':detail,'separate_classifiers_descriptive':sec})
            np.savez_compressed(output/f'{model}_{regime}_scores.npz',**saved)
    csvout(output/'joint_vs_chaos.csv',rows);csvout(output/'ROC.csv',rocs)
    dump(output/'results.json',rows);dump(output/'source_hashes.json',input_hashes)
    print(json.dumps(rows,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
