"""Render the English version of Figure 6 from the saved batch statistics."""
import argparse
import csv
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import FormatStrFormatter
import numpy as np

SOURCE = Path(__file__).resolve().parents[2] / 'data/processed/figures/figure6_verified_entropy.csv'


def output_directory():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True, type=Path)
    output = parser.parse_args().output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    return output


def main():
    output = output_directory()
    with SOURCE.open(encoding='utf-8-sig') as handle:
        rows = list(csv.DictReader(handle))
    assert len(rows) == 10
    arms = ['A_joint', 'B']
    batches = {arm: {} for arm in arms}
    for row in rows:
        assert int(row['samples']) == 20000 and int(row['bytes']) == 160000
        batches[row['arm']][int(row['batch'])] = float(row['byte_shannon_bits_per_byte'])
    assert all(set(batches[arm]) == set(range(5)) for arm in arms)
    values = {arm: np.array([batches[arm][i] for i in range(5)]) for arm in arms}

    plt.rcParams.update({
        'font.family': 'sans-serif', 'font.sans-serif': ['Arial', 'DejaVu Sans'],
        'font.size': 8.5, 'axes.labelsize': 8.5, 'axes.titlesize': 9,
        'axes.spines.top': False, 'axes.spines.right': False, 'axes.linewidth': .7,
        'svg.fonttype': 'none', 'pdf.fonttype': 42, 'savefig.dpi': 600,
    })
    fig, ax = plt.subplots(figsize=(5.511811, 3.149606))  # 140 by 80 mm
    fig.subplots_adjust(left=.16, right=.97, bottom=.29, top=.88)
    offsets = np.linspace(-.12, .12, 5)
    for i in range(5):
        ax.plot([offsets[i], 1+offsets[i]], [values['A_joint'][i], values['B'][i]],
                color='#C2C2C2', lw=.6, zorder=1)
    for x, arm, color in zip(range(2), arms, ['#3F6F94', '#BD6B36']):
        v = values[arm]
        ax.scatter(x+offsets, v, s=17, color=color, edgecolors='white', linewidths=.35, zorder=3)
        ax.errorbar(x+.25, v.mean(), yerr=v.std(ddof=1), fmt='D', color='#222222',
                    markerfacecolor='white', markersize=4, capsize=3, elinewidth=.9, zorder=4)
    ax.set_xlim(-.35, 1.42)
    ax.set_ylim(7.990, 8.000)
    ax.set_yticks(np.arange(7.990, 8.0001, .002))
    ax.yaxis.set_major_formatter(FormatStrFormatter('%.3f'))
    ax.set_xticks([.05, 1.05], ['Direct SHAKE256 fusion', 'Q64 + SHAKE256 fusion'])
    ax.set_ylabel('Byte Shannon entropy (bits/byte)')
    ax.set_title('Uniform inputs', pad=8)
    ax.grid(axis='y', color='#E6E6E6', linewidth=.5)
    ax.set_axisbelow(True)
    fig.text(.16, .145, 'Five paired batches, with 160,000 output bytes per batch and method.')
    fig.text(.16, .085, 'Lines connect paired batches. Diamonds show the mean ± sample SD.')
    stem = output / 'figure06_en'
    fig.savefig(stem.with_suffix('.pdf'))
    fig.savefig(stem.with_suffix('.svg'))
    fig.savefig(stem.with_suffix('.png'), dpi=600)
    plt.close(fig)


if __name__ == '__main__':
    main()
