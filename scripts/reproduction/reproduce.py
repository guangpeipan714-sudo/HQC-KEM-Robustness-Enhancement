"""Verify the frozen inputs and reproduce figures for the JCEN manuscript."""

import argparse
import csv
import hashlib
import math
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = Path(__file__).resolve().parent
MANIFEST = ROOT / "data/metadata/SHA256SUMS.txt"


def verify_inputs():
    count = 0
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        expected, name = line.split("  ", 1)
        with (ROOT / name).open("rb") as handle:
            actual = hashlib.file_digest(handle, "sha256").hexdigest()
        if actual != expected:
            raise SystemExit(f"SHA-256 mismatch for {name}")
        count += 1
    print(f"Verified {count} archived files", flush=True)


def verify_replayed_table(reference, generated):
    with reference.open(newline="", encoding="utf-8-sig") as handle:
        archived = list(csv.DictReader(handle))
    with generated.open(newline="", encoding="utf-8-sig") as handle:
        replay = list(csv.DictReader(handle))
    if len(archived) != len(replay):
        raise SystemExit("Replayed table has a different number of rows")
    for old, new in zip(archived, replay):
        if old.keys() != new.keys():
            raise SystemExit("Replayed table has different columns")
        for field, expected in old.items():
            if expected == new[field]:
                continue
            try:
                equal = math.isclose(float(expected), float(new[field]), rel_tol=1e-12, abs_tol=1e-14)
            except (ValueError, TypeError):
                equal = False
            if not equal:
                raise SystemExit(f"Replayed table differs in field {field}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    verify_inputs()
    subprocess.run(
        [sys.executable, str(ROOT / "scripts/analysis/verify_frozen_data.py")],
        check=True,
    )
    out = args.output_dir.resolve()
    # Reject an existing directory so archived outputs cannot be overwritten.
    out.mkdir(parents=True, exist_ok=False)
    for name in ("plot_figure04_en.py", "plot_figure06_en.py", "plot_figures11_12_en.py"):
        subprocess.run(
            [sys.executable, str(SCRIPTS / name), "--output-dir", str(out)],
            check=True,
        )
    markov = out / "revised_markov"
    subprocess.run(
        [sys.executable, str(ROOT / "scripts/analysis/analyze_revised_markov.py"),
         "--output-dir", str(markov)],
        check=True,
    )
    verify_replayed_table(
        ROOT / "data/processed/revised_markov/results.csv", markov / "results.csv"
    )
    print("Verified the replayed Markov pilot summary")
    print(f"Figures 4, 6, 11 and 12 exported to {out}")


if __name__ == "__main__":
    main()
