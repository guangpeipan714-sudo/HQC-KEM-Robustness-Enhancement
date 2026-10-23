# Online Resource 1: NIST-reported-size engineering supplement

This archive contains the executable source and tabular outputs supporting the component-level results shown in manuscript Fig. 15. The experiment sizes deterministic synthetic byte strings using the HQC-128, HQC-192, and HQC-256 public-key and ciphertext lengths reported in NIST IR 8545. It isolates the entropy-diversification and context-binding layers; it is not a complete HQC implementation, a conformance test, or a whole-KEM benchmark.

## Contents

- `src/hqc_prototype.sage`: reduced-scale prototype and engineering-test functions.
- `experiments/standard_size_engineering_test.sage`: experiment entry point.
- `experiments/plot_standard_size_results.py`: plotting source for manuscript Fig. 15.
- `results/standard_size_engineering/*.csv`: tabular timing, allocation, and perturbation-response results.
- `results/standard_size_engineering/*.json`: machine-readable metadata and full distribution summaries.

## Run

From the extracted archive root, with SageMath available:

```bash
sage experiments/standard_size_engineering_test.sage
```

The experiment writes its outputs under `results/standard_size_engineering/`. The plotting script requires Python with Matplotlib and NumPy and reads the CSV files from that directory.

## Scope and reproducibility

The timing outputs record the SageMath/Python/operating-system environment used for the supplied run. Synthetic transcript inputs and perturbation positions are deterministically seeded. Absolute measurements remain platform-specific. The archive does not contain personal data, human-participant data, or confidential source material.
