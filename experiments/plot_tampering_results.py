#!/usr/bin/env python3
"""Create vector ciphertext-tampering figures from the archived MATLAB results."""

from __future__ import annotations

import argparse
import os
import struct
import sys
import zlib
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
        "legend.frameon": False,
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "svg.fonttype": "none",
    }
)

BLUE = "#0072BD"
ORANGE = "#D95319"
GRID = "#B8B8B8"

_MI_TYPES = {
    1: ("b", 1), 2: ("B", 1), 3: ("h", 2), 4: ("H", 2),
    5: ("i", 4), 6: ("I", 4), 7: ("f", 4), 9: ("d", 8),
    12: ("q", 8), 13: ("Q", 8),
}


def _elements(blob: bytes):
    """Yield MATLAB v5 data elements, including small-data-element tags."""
    offset = 0
    while offset + 8 <= len(blob):
        first, second = struct.unpack_from("<II", blob, offset)
        if first >> 16:
            data_type = first & 0xFFFF
            size = first >> 16
            yield data_type, blob[offset + 4:offset + 4 + size]
            offset += 8
        else:
            data_type, size = first, second
            start = offset + 8
            yield data_type, blob[start:start + size]
            offset = start + ((size + 7) // 8) * 8


def _matrix(payload: bytes) -> tuple[str, np.ndarray] | None:
    parts = list(_elements(payload))
    if len(parts) < 4:
        return None
    dims_type, dims_blob = parts[1]
    name_type, name_blob = parts[2]
    real_type, real_blob = parts[3]
    if dims_type not in _MI_TYPES or real_type not in _MI_TYPES:
        return None
    dims_fmt, dims_size = _MI_TYPES[dims_type]
    dims = struct.unpack("<" + dims_fmt * (len(dims_blob) // dims_size), dims_blob)
    name = name_blob.decode("ascii")
    real_fmt, real_size = _MI_TYPES[real_type]
    values = struct.unpack("<" + real_fmt * (len(real_blob) // real_size), real_blob)
    array = np.asarray(values)
    if dims:
        array = array.reshape(tuple(int(x) for x in dims), order="F")
    return name, np.squeeze(array)


def load_numeric_mat(path: Path) -> dict[str, np.ndarray]:
    """Read the numeric arrays used here without adding a SciPy dependency."""
    blob = path.read_bytes()
    if not blob.startswith(b"MATLAB 5.0 MAT-file"):
        raise ValueError(f"Unsupported MAT-file format: {path}")
    result: dict[str, np.ndarray] = {}
    pending = list(_elements(blob[128:]))
    while pending:
        data_type, payload = pending.pop(0)
        if data_type == 15:  # miCOMPRESSED
            pending[0:0] = list(_elements(zlib.decompress(payload)))
        elif data_type == 14:  # miMATRIX
            item = _matrix(payload)
            if item is not None:
                result[item[0]] = item[1]
    return result


def tidy_rows(data: dict[str, np.ndarray]) -> dict[str, dict[str, tuple[np.ndarray, np.ndarray]]]:
    required = ("component_code", "flip_bits", "ss_diff_rate", "bcr_mean")
    missing = [key for key in required if key not in data]
    if missing:
        raise KeyError(f"Missing fields in archived results: {', '.join(missing)}")
    component = np.asarray(data["component_code"]).reshape(-1).astype(int)
    flips = np.asarray(data["flip_bits"]).reshape(-1).astype(float)
    output: dict[str, dict[str, tuple[np.ndarray, np.ndarray]]] = {}
    for metric in ("ss_diff_rate", "bcr_mean"):
        values = np.asarray(data[metric]).reshape(-1).astype(float)
        output[metric] = {}
        for code, name in ((1, "u"), (2, "v"), (3, "full ciphertext")):
            keep = component == code
            order = np.argsort(flips[keep])
            output[metric][name] = (flips[keep][order], values[keep][order])
    return output


def require_alignment(fig: plt.Figure, stem: Path) -> None:
    audit_dir = os.environ.get("NATURE_FIGURE_AUDIT_DIR")
    if not audit_dir:
        raise RuntimeError("Set NATURE_FIGURE_AUDIT_DIR to the figure-audit scripts directory.")
    sys.path.insert(0, audit_dir)
    from audit_panel_alignment import require_matplotlib_panel_alignment

    require_matplotlib_panel_alignment(
        fig,
        json_out=str(stem.with_suffix(".alignment.json")),
        overlay_svg=str(stem.with_suffix(".alignment.svg")),
        tolerance_pt=1.5,
        gutter_tolerance_pt=1.5,
        require_panel_labels=True,
        strict=True,
    )


def build_figure(original, enhanced, metric: str, ylabel: str, ylim: tuple[float, float]):
    fig, axes = plt.subplots(1, 3, figsize=(7.20, 2.60), constrained_layout=True)
    for label, component, ax in zip(("a", "b", "c"), ("u", "v", "full ciphertext"), axes):
        x_original, y_original = original[metric][component]
        x_enhanced, y_enhanced = enhanced[metric][component]
        ax.plot(
            x_original, y_original, color=BLUE, marker="o", markersize=4.8,
            linewidth=1.25, label="Original HQC", zorder=3,
        )
        ax.plot(
            x_enhanced, y_enhanced, color=ORANGE, marker="s", markersize=4.8,
            linewidth=1.25, linestyle=(0, (5, 3)), label="Enhanced HQC", zorder=3,
        )
        ax.set_title(component)
        ax.set_xlabel("Number of flipped bits")
        ax.set_ylabel(ylabel)
        ax.set_ylim(*ylim)
        ax.set_xticks(sorted(set(x_original.tolist() + x_enhanced.tolist())))
        ax.grid(color=GRID, linewidth=0.6, linestyle=(0, (2, 2)), zorder=0)
        ax.annotate(
            label, xy=(0, 1), xycoords="axes fraction", xytext=(-14, 4),
            textcoords="offset points", ha="left", va="bottom",
            fontsize=10.55, fontweight="bold",
        )
    fig.text(0.43, 1.025, "Original HQC", color=BLUE, ha="right", va="bottom", fontsize=8.8)
    fig.text(0.57, 1.025, "Enhanced HQC", color=ORANGE, ha="left", va="bottom", fontsize=8.8)
    return fig


def save_bundle(fig: plt.Figure, stem: Path) -> None:
    stem.parent.mkdir(parents=True, exist_ok=True)
    fig.canvas.draw()
    require_alignment(fig, stem)
    fig.savefig(stem.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(stem.with_suffix(".svg"), bbox_inches="tight")
    fig.savefig(stem.with_suffix(".png"), dpi=300, bbox_inches="tight")
    fig.savefig(stem.with_suffix(".tiff"), dpi=600, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--original", type=Path, required=True)
    parser.add_argument("--enhanced", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    original = tidy_rows(load_numeric_mat(args.original))
    enhanced = tidy_rows(load_numeric_mat(args.enhanced))
    save_bundle(
        build_figure(original, enhanced, "ss_diff_rate", "Shared-secret difference rate (%)", (0, 105)),
        args.output_dir / "fig13",
    )
    save_bundle(
        build_figure(original, enhanced, "bcr_mean", "Mean BCR of shared secret (%)", (0, 100)),
        args.output_dir / "fig14",
    )


if __name__ == "__main__":
    main()
