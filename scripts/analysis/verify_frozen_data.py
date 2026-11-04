"""Verify bundled evidence and optionally the original confirmation archives."""

import argparse
import hashlib
import json
from pathlib import Path, PureWindowsPath


ROOT = Path(__file__).resolve().parents[2]


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def check(path, expected):
    if sha256(path) != expected:
        raise ValueError(f"SHA-256 mismatch: {path}")


def check_entropy():
    raw = ROOT / "data/raw/entropy_assessment"
    saved = ROOT / "data/processed/entropy_assessment"
    summary = {}
    for item in read_json(raw / "manifest.json")["models"]:
        name = item["model"]
        data = (raw / item["file"]).read_bytes()
        if len(data) != item["sample_count"] or set(data) != {0, 1}:
            raise ValueError(f"Invalid byte-per-symbol sequence: {name}")
        source_sha256 = hashlib.sha256(data).hexdigest()
        iid, non_iid = (
            read_json(saved / name / f"{track}_official.json")
            for track in ("iid", "non_iid")
        )
        if any(
            result["sha256"] != source_sha256 or result["errorLevel"] != 0
            for result in (iid, non_iid)
        ):
            raise ValueError(f"Input hash or tool status mismatch: {name}")
        iid_case = iid["testCases"][0]
        iid_pass = all(
            iid_case[key]
            for key in (
                "passedChiSquareTests",
                "passedIidPermutationTests",
                "passedLongestRepeatedSubstringTest",
            )
        )
        non_iid_case, = [
            case for case in non_iid["testCases"] if case["testCaseDesc"] == "Overall"
        ]
        summary[name] = {
            "samples": len(data),
            "iid_pass": iid_pass,
            "iid_estimate_used": iid_case["hOriginal"] if iid_pass else None,
            "non_iid_estimate": non_iid_case["hOriginal"],
        }
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--confirmation-dir", type=Path)
    args = parser.parse_args()

    try:
        manifest = read_json(ROOT / "data/metadata/frozen_data_manifest.json")
        for item in manifest:
            check(ROOT / item["file"], item["sha256"])
        summary = check_entropy()
        print(f"Verified {len(manifest)} bundled evidence files.")
        if args.confirmation_dir is not None:
            source = ROOT / "data/processed/joint_comparison/source_hashes.json"
            inputs = read_json(source)
            for item in inputs:
                check(args.confirmation_dir / PureWindowsPath(item["file"]).name, item["sha256"])
            print(f"Verified {len(inputs)} original confirmation batches.")
        print(json.dumps(summary, indent=2))
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
