"""Render the Fig. 6 Shannon-entropy comparison from regenerated source data.

Figure contract
---------------
Core conclusion: both evaluated SHAKE256 output paths have byte-level Shannon
entropy close to 8 bit/byte, with no claim of higher entropy for either path.
Archetype: single-panel quantitative comparison.
Replicate unit: one independently generated 1,000,000-byte output (n=100).
"""

import argparse
import csv
import json
from pathlib import Path

import matplotlib as mpl
mpl.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FormatStrFormatter
import numpy as np

from audit_panel_alignment import require_matplotlib_panel_alignment


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, default=Path("matlab"))
    parser.add_argument("--output-dir", type=Path, default=Path("results/shannon_entropy"))
    parser.add_argument("--paper-dir", type=Path)
    args = parser.parse_args()

    rows = []
    with (args.data_dir / "shannon_entropy_source_data.csv").open(
            newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    original = np.asarray([float(row["original_hqc"]) for row in rows])
    enhanced = np.asarray([float(row["enhanced_hqc"]) for row in rows])
    if original.size != 100 or enhanced.size != 100:
        raise ValueError("Fig. 6 requires 100 observations for each construction")
    if not (np.isfinite(original).all() and np.isfinite(enhanced).all()):
        raise ValueError("Entropy data contain non-finite values")
    if np.any(original > 8.0) or np.any(enhanced > 8.0):
        raise ValueError("Byte-level Shannon entropy cannot exceed 8 bit/byte")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    if args.paper_dir is not None:
        args.paper_dir.mkdir(parents=True, exist_ok=True)

    mpl.rcParams.update({
        "font.family": "sans-serif",
        "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans", "sans-serif"],
        "font.size": 7.2,
        "axes.labelsize": 7.5,
        "xtick.labelsize": 7.0,
        "ytick.labelsize": 7.0,
        "axes.linewidth": 0.75,
        "pdf.fonttype": 42,
        "svg.fonttype": "none",
    })

    fig, ax = plt.subplots(figsize=(3.50, 2.65), constrained_layout=True)
    colors = ["#4C78A8", "#E07B39"]
    bp = ax.boxplot(
        [original, enhanced],
        tick_labels=["Original HQC", "Enhanced HQC"],
        widths=0.48,
        patch_artist=True,
        showfliers=False,
        medianprops={"color": "#202020", "linewidth": 1.1},
        boxprops={"linewidth": 0.9},
        whiskerprops={"linewidth": 0.9},
        capprops={"linewidth": 0.9},
    )
    for box, color in zip(bp["boxes"], colors):
        box.set_facecolor(color)
        box.set_edgecolor(color)
        box.set_alpha(0.35)

    rng = np.random.default_rng(20261023)
    for x_pos, values, color in zip([1, 2], [original, enhanced], colors):
        jitter = rng.uniform(-0.115, 0.115, values.size)
        ax.scatter(
            x_pos + jitter,
            values,
            s=7.5,
            color=color,
            alpha=0.58,
            edgecolors="none",
            rasterized=False,
            zorder=3,
        )

    combined = np.concatenate([original, enhanced])
    lower = float(combined.min())
    span = max(8.0 - lower, 1e-6)
    ax.set_ylim(lower - 0.10 * span, 8.0 + 0.08 * span)
    ax.axhline(8.0, color="#6B6B6B", linewidth=0.8, linestyle=(0, (3, 2)), zorder=1)
    ax.text(
        0.99,
        8.0,
        "Maximum = 8 bit/byte",
        transform=ax.get_yaxis_transform(),
        ha="right",
        va="bottom",
        color="#555555",
        fontsize=7.0,
    )
    ax.set_ylabel("Shannon entropy (bit/byte)")
    ax.yaxis.set_major_formatter(FormatStrFormatter("%.5f"))
    ax.tick_params(direction="out", length=3, width=0.7)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.grid(axis="y", color="#D9D9D9", linewidth=0.45, alpha=0.7)
    ax.set_axisbelow(True)

    base = args.output_dir / "fig6"
    require_matplotlib_panel_alignment(
        fig,
        json_out=str(base) + ".alignment.json",
        overlay_svg=str(base) + ".alignment.svg",
        tolerance_pt=1.5,
        gutter_tolerance_pt=1.5,
        strict=True,
    )
    fig.savefig(str(base) + ".pdf", bbox_inches="tight")
    fig.savefig(str(base) + ".svg", bbox_inches="tight")
    fig.savefig(str(base) + ".tiff", dpi=600, bbox_inches="tight")
    fig.savefig(str(base) + ".png", dpi=300, bbox_inches="tight")
    if args.paper_dir is not None:
        fig.savefig(args.paper_dir / "fig6.pdf", bbox_inches="tight")
    plt.close(fig)

    with (args.output_dir / "fig6_source_data.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["replicate", "original_hqc", "enhanced_hqc"])
        for index, (orig, enh) in enumerate(zip(original, enhanced), start=1):
            writer.writerow([index, "%.12f" % orig, "%.12f" % enh])

    summary = {
        "replicates_per_group": 100,
        "bytes_per_replicate": 1000000,
        "original": {
            "mean": float(np.mean(original)),
            "median": float(np.median(original)),
            "sample_sd": float(np.std(original, ddof=1)),
            "min": float(np.min(original)),
            "max": float(np.max(original)),
        },
        "enhanced": {
            "mean": float(np.mean(enhanced)),
            "median": float(np.median(enhanced)),
            "sample_sd": float(np.std(enhanced, ddof=1)),
            "min": float(np.min(enhanced)),
            "max": float(np.max(enhanced)),
        },
        "inference": "Descriptive only; no significance test was performed.",
    }
    (args.output_dir / "fig6_summary.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
