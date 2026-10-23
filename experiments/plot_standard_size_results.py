#!/usr/bin/env python3
"""Plot the standard-size enhancement-layer measurements used in the paper."""

from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np


mpl.rcParams.update(
    {
        "font.family": "sans-serif",
        "font.sans-serif": ["Times New Roman", "Times", "DejaVu Serif", "serif"],
        "font.size": 9.6,
        "axes.labelsize": 10.55,
        "axes.titlesize": 10.55,
        "xtick.labelsize": 9.6,
        "ytick.labelsize": 9.6,
        "legend.fontsize": 8.8,
        "axes.linewidth": 0.8,
        "axes.spines.top": True,
        "axes.spines.right": True,
        "xtick.direction": "in",
        "ytick.direction": "in",
        "xtick.top": True,
        "ytick.right": True,
        "legend.frameon": True,
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "svg.fonttype": "none",
    }
)

BLUE = "#0072BD"
ORANGE = "#D95319"
GREY = "#666666"


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def require_alignment(fig: plt.Figure, output_stem: Path) -> None:
    audit_dir = os.environ.get("NATURE_FIGURE_AUDIT_DIR")
    if not audit_dir:
        raise RuntimeError("Set NATURE_FIGURE_AUDIT_DIR to the figure-audit scripts directory.")
    sys.path.insert(0, audit_dir)
    from audit_panel_alignment import require_matplotlib_panel_alignment

    require_matplotlib_panel_alignment(
        fig,
        json_out=str(output_stem.with_suffix(".alignment.json")),
        overlay_svg=str(output_stem.with_suffix(".alignment.svg")),
        tolerance_pt=1.5,
        gutter_tolerance_pt=1.5,
        require_panel_labels=True,
        strict=True,
    )


def build_figure(micro_rows: list[dict[str, str]], binding_rows: list[dict[str, str]]) -> plt.Figure:
    profiles = ["HQC-128", "HQC-192", "HQC-256"]
    x = np.arange(len(profiles), dtype=float)

    entropy = {row["profile"]: row for row in micro_rows if row["operation"] == "paired_entropy_overhead"}
    binding = {row["profile"]: row for row in micro_rows if row["operation"] == "paired_overhead"}

    fig, axes = plt.subplots(1, 2, figsize=(7.20, 3.00), constrained_layout=True)
    ax_a, ax_b = axes

    for offset, rows, label, color, marker in (
        (-0.09, entropy, "Entropy diversification", BLUE, "o"),
        (+0.09, binding, "Context binding", ORANGE, "s"),
    ):
        centers = np.array([float(rows[p]["median_us"]) for p in profiles])
        lows = np.array([float(rows[p]["median_ci95_low_us"]) for p in profiles])
        highs = np.array([float(rows[p]["median_ci95_high_us"]) for p in profiles])
        yerr = np.vstack((centers - lows, highs - centers))
        ax_a.errorbar(
            x + offset,
            centers,
            yerr=yerr,
            color=color,
            marker=marker,
            markersize=4.8,
            linewidth=1.25,
            capsize=2.6,
            capthick=0.9,
            label=label,
            zorder=3,
        )

    ax_a.set_xticks(x, profiles)
    ax_a.set_ylabel("Median added runtime (µs)")
    ax_a.set_ylim(30, 72)
    ax_a.set_yticks([30, 40, 50, 60, 70])
    ax_a.grid(axis="both", color="#B8B8B8", linewidth=0.6, linestyle=(0, (5, 4)), zorder=0)
    ax_a.legend(
        loc="lower left",
        bbox_to_anchor=(0, 1.015),
        ncols=1,
        handlelength=1.8,
        handletextpad=0.8,
        frameon=False,
    )

    width = 0.28
    for offset, component, label, color, marker in (
        (-width / 2, "public_key", "Public key", BLUE, "o"),
        (+width / 2, "ciphertext", "Ciphertext", ORANGE, "s"),
    ):
        rows = {row["profile"]: row for row in binding_rows if row["component"] == component}
        means = np.array([float(rows[p]["bcr_mean_pct"]) for p in profiles])
        sds = np.array([float(rows[p]["bcr_std_pct"]) for p in profiles])
        ax_b.errorbar(
            x + offset,
            means,
            yerr=sds,
            color=color,
            marker=marker,
            linestyle="none",
            markersize=4.8,
            capsize=2.8,
            capthick=0.8,
            label=label,
            zorder=3,
        )

    ax_b.axhline(50, color=GREY, linewidth=0.9, linestyle=(0, (3, 2)), zorder=1)
    ax_b.set_xticks(x, profiles)
    ax_b.set_ylabel("Derived-key bit-change ratio (%)")
    ax_b.set_ylim(44, 56)
    ax_b.set_yticks([44, 46, 48, 50, 52, 54, 56])
    ax_b.grid(axis="both", color="#B8B8B8", linewidth=0.6, linestyle=(0, (5, 4)), zorder=0)
    ax_b.legend(
        loc="lower left",
        bbox_to_anchor=(0, 1.015),
        ncols=2,
        columnspacing=1.0,
        handlelength=1.5,
        handletextpad=0.8,
        frameon=False,
    )

    for label, ax in zip(("a", "b"), axes):
        ax.annotate(
            label,
            xy=(0, 1),
            xycoords="axes fraction",
            xytext=(-14, 4),
            textcoords="offset points",
            ha="left",
            va="bottom",
            fontsize=10.55,
            fontweight="bold",
        )

    return fig


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--microbenchmark", type=Path, required=True)
    parser.add_argument("--binding", type=Path, required=True)
    parser.add_argument("--output-stem", type=Path, required=True)
    args = parser.parse_args()

    fig = build_figure(read_rows(args.microbenchmark), read_rows(args.binding))
    args.output_stem.parent.mkdir(parents=True, exist_ok=True)
    fig.canvas.draw()
    require_alignment(fig, args.output_stem)
    fig.savefig(args.output_stem.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(args.output_stem.with_suffix(".svg"), bbox_inches="tight")
    fig.savefig(args.output_stem.with_suffix(".png"), dpi=300, bbox_inches="tight")
    fig.savefig(args.output_stem.with_suffix(".tiff"), dpi=600, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()
