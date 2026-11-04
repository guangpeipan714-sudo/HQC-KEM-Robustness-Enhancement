# -*- coding: utf-8 -*-
"""fig4: bifurcation diagram of the logistic map  x_{n+1} = r * x_n * (1 - x_n).

Rebuilt from the original fig4.svg geometry; the stray arrow tail that
protruded above the "deep-chaos range" label in the bottom-left corner is
fixed by starting both annotation arrows cleanly from the text-box edge.
"""
import argparse
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Arial', 'Helvetica', 'DejaVu Sans'],
    'svg.fonttype': 'none',   # keep real <text> elements in SVG
    'pdf.fonttype': 42,
    'ps.fonttype': 42,
})

def output_directory():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', required=True, type=Path)
    output = parser.parse_args().output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    return output


ORANGE = '#c75b12'
BLUE = '#2f6ea2'
SHADE = '#fbe9d8'
GREY = '#333333'

# ---- figure / axes geometry identical to the original (pt-based) --------
FW, FH = 445.422148 / 72., 316.384482 / 72.          # inches
fig = plt.figure(figsize=(FW, FH))
ax = fig.add_axes([32.502217 / 445.422148,
                   (316.384482 - 287.268857) / 316.384482,
                   (436.609648 - 32.502217) / 445.422148,
                   (287.268857 - 3.6) / 316.384482])

# ---- bifurcation data ---------------------------------------------------
n_r, n_skip, n_keep = 900, 1000, 120
r = np.linspace(2.9, 4.0, n_r)
x = np.full(n_r, 0.4)
for _ in range(n_skip):                      # discard transients
    x = r * x * (1.0 - x)
R = np.repeat(r, n_keep)
X = np.empty(n_r * n_keep)
for k in range(n_keep):                      # collect asymptotic states
    x = r * x * (1.0 - x)
    X[k::n_keep] = x

# deep-chaos shading first (below the scatter)
ax.axvspan(3.9, 4.0, facecolor=SHADE, edgecolor=SHADE, alpha=0.6, zorder=0)

ax.scatter(R, X, s=1.0, marker='s', linewidths=0,
           facecolors=BLUE, alpha=0.55, zorder=1, rasterized=True)

# chaos-onset marker line
ax.axvline(3.5699, color=ORANGE, lw=1.0, ls=(0, (5, 4)), zorder=3)

# ---- axes styling --------------------------------------------------------
ax.set_xlim(2.9, 4.0)
ax.set_ylim(0.0, 1.02)
ax.set_xticks(np.arange(3.0, 4.001, 0.2))
ax.set_yticks(np.arange(0.0, 1.001, 0.2))
ax.tick_params(axis='both', which='major', direction='out', length=3,
               width=0.8, colors=GREY, labelsize=7.5, labelcolor=GREY)
ax.set_xlabel('Control parameter r', fontsize=8.5)
ax.set_ylabel('Asymptotic state x', fontsize=8.5)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
for s in ('bottom', 'left'):
    ax.spines[s].set_color(GREY)
    ax.spines[s].set_linewidth(0.8)

# ---- annotations (fixed: arrows start at the text-box edge) -------------
ann = dict(fontsize=7.5, fontweight='bold', color=ORANGE,
           arrowprops=dict(arrowstyle='-|>', mutation_scale=8.0,
                           color=ORANGE, lw=0.9,
                           shrinkA=1.0, shrinkB=1.5,
                           connectionstyle='arc3,rad=0.0'))
ax.annotate('Period-doubling limit r∞ ≈ 3.5699', xy=(3.5699, 0.956),
            xytext=(2.93, 0.985), **ann)
ax.annotate('Nominal Q64 interval [3.9, 4.0)', xy=(3.92, 0.41),
            xytext=(2.95, 0.157), **ann)


# Export the same sampled real-valued orbits with terminology aligned to the manuscript.
root = output_directory()
fig.savefig(root / 'figure04_en.pdf', dpi=600)
fig.savefig(root / 'figure04_en.svg', dpi=600)
fig.savefig(root / 'figure04_en.png', dpi=600)
plt.close(fig)
