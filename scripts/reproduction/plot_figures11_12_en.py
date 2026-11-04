"""Translate the archived entropy-robustness plots using their saved statistics."""
import argparse
import csv
import hashlib
import math
import struct
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import FixedLocator

REPO = Path(__file__).resolve().parents[2]


def output_directory():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True, type=Path)
    output = parser.parse_args().output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    return output


SCHEMES = (
    ('orig', 'Original HQC', '原始HQC', '#555B63', 'o', '-'),
    ('same', 'Q64 (Same Source)', '混沌·同源', '#316EAD', 's', '--'),
    ('dual', 'Q64 (Dual Source)', '混沌·双源', '#17806F', '^', '-'),
)

plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Arial', 'DejaVu Sans'],
    'font.size': 8.5, 'axes.labelsize': 8.5, 'axes.titlesize': 9,
    'legend.fontsize': 8.5, 'axes.spines.top': False,
    'axes.spines.right': False, 'axes.linewidth': 0.7,
    'pdf.fonttype': 42, 'svg.fonttype': 'none', 'savefig.dpi': 600,
})


def load_archived_numeric_arrays(path):
    # This archive contains only uncompressed, little-endian MATLAB v5
    # numeric arrays. Reject other MAT layouts instead of guessing values.
    blob = path.read_bytes()
    assert blob.startswith(b'MATLAB 5.0 MAT-file') and blob[126:128] == b'IM'

    def elements(first, last):
        offset = first
        while offset < last:
            kind, length = struct.unpack_from('<II', blob, offset)
            end = offset + 8 + length
            assert end <= last
            yield kind, offset + 8, end
            offset = offset + 8 + (length + 7) // 8 * 8
        assert offset == last

    data = {}
    for kind, first, last in elements(128, len(blob)):
        assert kind == 14
        flags, dims, name, numeric = list(elements(first, last))
        assert flags[0] == 6 and dims[0] == 5 and name[0] == 1
        dtype, start, end = numeric
        data[blob[name[1]:name[2]].decode('ascii')] = [v[0] for v in struct.iter_unpack(
            {9: '<d', 12: '<q'}[dtype], blob[start:end])]
    return data


def save(fig, n, output):
    stem = output / f'figure{n}_en'
    fig.savefig(str(stem)+'.pdf')
    fig.savefig(str(stem)+'.svg')
    fig.savefig(str(stem)+'.png', dpi=600)
    plt.close(fig)


def main():
    output = output_directory()
    mat = REPO / 'matlab/entropy_robustness.mat'
    digest = hashlib.sha256(mat.read_bytes()).hexdigest()
    assert digest == '5798feaf602a02c5e6c531d2bc4eb0bd9084dd474215c8b7cf662e66975cff67'
    data = load_archived_numeric_arrays(mat)
    h_values = [int(h) for h in data['entropy_bits']]
    n, = data['N_trials']
    ceiling, = data['upper_minH']
    assert n > 0 and ceiling == math.log2(n)
    row8 = h_values.index(8)
    values = [data[f'uniq_{suffix}'][row8] for suffix, *_ in SCHEMES]
    assert [f'{value:.3f}' for value in values] == ['0.085', '0.085', '1.000']
    archived = REPO / 'data/processed/figures/figures11_12_source.csv'
    with archived.open(newline='', encoding='utf-8') as handle:
        rows = list(csv.DictReader(handle))
    expected = [(h, label, n, data[f'minH_{suffix}'][j], data[f'uniq_{suffix}'][j])
                for j, h in enumerate(h_values) for suffix, label, *_ in SCHEMES]
    actual = [(int(row['primary_support_parameter_h']), row['scheme'],
               int(row['number_of_outputs']), float(row['empirical_maximum_frequency_score_bits']),
               float(row['output_uniqueness_ratio'])) for row in rows]
    if actual != expected:
        raise ValueError('Figure source CSV differs from the archived MAT statistics')

    fig, ax = plt.subplots(figsize=(121/25.4, 74/25.4))
    fig.subplots_adjust(left=.18, right=.97, bottom=.20, top=.87)
    ax.bar([0, 1, 2], values, width=.58, color=[scheme[3] for scheme in SCHEMES], zorder=2)
    ax.set_xticks([0, 1, 2], [scheme[1] for scheme in SCHEMES])
    ax.set_ylabel('Output uniqueness ratio')
    ax.set_title('Primary-source support parameter h = 8', pad=8)
    ax.set_ylim(0, 1.10)
    ax.set_yticks([0, .2, .4, .6, .8, 1])
    ax.grid(axis='y', color='#E7E9EB', lw=.5)
    ax.set_axisbelow(True)
    for x, v in enumerate(values):
        ax.annotate(f'{v:.3f}', (x, v), xytext=(0, 4), textcoords='offset points', ha='center')
    save(fig, 11, output)

    fig, axs = plt.subplots(1, 2, figsize=(183/25.4, 85/25.4))
    fig.subplots_adjust(left=.135, right=.98, bottom=.19, top=.83, wspace=.42)
    for j, (ax, key, ylabel) in enumerate(zip(
            axs, ('minH', 'uniq'), ('Empirical maximum-frequency\nscore (bits)', 'Output uniqueness ratio'))):
        ax.set_title('ab'[j], loc='left', fontweight='bold', pad=5)
        if j == 0:
            ax.axhline(ceiling, color='#85888E', lw=.9, ls=':', zorder=1)
            ax.annotate('Finite-sample ceiling', (25.5, ceiling), xytext=(0, 9),
                        textcoords='offset points', ha='right', color='#555B63')
        for suffix, label, _, color, marker, ls in SCHEMES:
            ax.plot(h_values, data[f'{key}_{suffix}'], marker=marker, linestyle=ls,
                    lw=1.2, ms=4.2, color=color, label=label,
                    mfc='white' if suffix=='same' else color, mew=.9)
        ax.set(xlim=(.8, 26), xlabel='Primary-source support parameter h', ylabel=ylabel)
        ax.xaxis.set_major_locator(FixedLocator(h_values))
        ax.grid(axis='y', color='#E7E9EB', lw=.5)
        ax.set_axisbelow(True)
    axs[0].set(ylim=(0, 13.2), yticks=[0, 2, 4, 6, 8, 10, 12])
    axs[1].set(ylim=(-.035, 1.07), yticks=[0, .2, .4, .6, .8, 1])
    fig.legend(*axs[0].get_legend_handles_labels(), loc='upper center',
               bbox_to_anchor=(.53, .99), ncol=3, frameon=False, columnspacing=1.4)
    save(fig, 12, output)



if __name__ == '__main__':
    main()
