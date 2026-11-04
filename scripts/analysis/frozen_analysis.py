"""Numerical helpers copied from the frozen paired ablation analysis."""
import csv

import numpy as np


def write_csv(path, rows):
    if not rows:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def bits(data):
    return np.unpackbits(data, axis=1, bitorder='little').astype(float)


def train_ridge(positive, negative):
    x = np.concatenate([bits(positive), bits(negative)])
    y = np.r_[np.ones(len(positive)), np.zeros(len(negative))]
    xm, ym = x.mean(axis=0), y.mean()
    xc = x-xm
    w = np.linalg.solve(xc.T@xc + np.eye(x.shape[1]), xc.T@(y-ym))
    return w, float(ym-xm@w)


def score(data, wb):
    return bits(data)@wb[0]+wb[1]


def abs_interval(lo, hi):
    return (0. if lo <= 0 <= hi else min(abs(lo), abs(hi)), max(abs(lo), abs(hi)))


def roc_rows(pos, neg, meta):
    s = np.r_[pos, neg]
    y = np.r_[np.ones(len(pos)), np.zeros(len(neg))]
    order = np.argsort(-s, kind='stable')
    s, y = s[order], y[order]
    idx = np.r_[np.flatnonzero(np.diff(s)), len(s)-1]
    tpr = np.r_[0., np.cumsum(y)[idx]/len(pos)]
    fpr = np.r_[0., np.cumsum(1-y)[idx]/len(neg)]
    auc = float(np.trapezoid(tpr, fpr))
    # At most 501 points for plotting; source scores retain every row and tie.
    keep = np.unique(np.linspace(0, len(fpr)-1, min(501,len(fpr))).astype(int))
    return [{**meta, 'fpr': float(fpr[i]), 'tpr': float(tpr[i]), 'auc': auc} for i in keep], auc
