"""Analyze the independent pilot of the explicit-XOR revision."""
import argparse
import json
import math
from pathlib import Path
import numpy as np

from frozen_analysis import train_ridge, score, abs_interval, roc_rows, write_csv

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-dir', type=Path, default=ROOT / 'data/raw/revised_markov_outputs')
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    folder, out = args.input_dir, args.output_dir
    out.mkdir(parents=True, exist_ok=False)
    rows=[];rocs=[]
    for regime in ['healthy','fixed']:
        bs=[]
        for i in range(5):
            with np.load(folder/('markov_rho80_%s_batch%d.npz'%(regime,i))) as z:bs.append({k:z[k] for k in z.files})
        tr={k:np.concatenate([b[k] for b in bs[:2]]) for k in bs[0]};te={k:np.concatenate([b[k] for b in bs[2:]]) for k in bs[0]}
        fit=train_ridge(np.concatenate([tr['A_joint'],tr['B']]),np.concatenate([tr['U'],tr['U']]))
        su=score(te['U'],fit);pu=(su>=.5).astype(float);ads={};ais={};detail={};saved={'U':su}
        for arm in ['A_joint','B']:
            s=score(te[arm],fit);g=(s>=.5).astype(float)-pu;n=len(g)
            q=math.log(4/(.05/4));rad=math.sqrt(2*np.var(g,ddof=1)*q/n)+14*q/(3*(n-1))
            d=float(g.mean());lo=max(-1.,d-rad);hi=min(1.,d+rad);ads[arm]=abs(d);ais[arm]=abs_interval(lo,hi)
            detail[arm]={'signed_contrast':d,'signed_CI':[lo,hi],'advantage_CI':ais[arm]}
            rr,auc=roc_rows(s,su,{'regime':regime,'arm':arm});rocs.extend(rr);detail[arm]['auc']=auc;saved[arm]=s
        row={'version':'explicit-XOR revision','model':'markov_rho80','regime':regime,'n_train_per_arm':len(tr['U']),
             'n_test_per_arm':len(te['U']),'Adv_joint_common_D':ads['A_joint'],'Adv_chaos_common_D':ads['B'],
             'Delta_common_D':ads['A_joint']-ads['B'],'Delta_CI_low':ais['A_joint'][0]-ais['B'][1],
             'Delta_CI_high':ais['A_joint'][1]-ais['B'][0]}
        rows.append(row)
        (out/(regime+'_classifier.json')).write_text(json.dumps({'result':row,'weights':fit[0].tolist(),'intercept':fit[1],
              'details':detail,'scope':'Independent new-version pilot only; not replacement of original Markov coverage gap.'},indent=2),encoding='utf-8')
        np.savez_compressed(out/(regime+'_scores.npz'),**saved)
    write_csv(out/'results.csv',rows);write_csv(out/'ROC.csv',rocs)
    (out/'results.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    print(json.dumps(rows,indent=2))


if __name__=='__main__':main()
