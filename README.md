# HQC-KEM Robustness Enhancement

This repository contains the SageMath implementation and experimental scripts associated with the paper on robustness-enhanced HQC-KEM using multi-source entropy integration, Q64 fixed-point Logistic transformation, and transcript-bound key derivation.

## Overview

The repository provides a reduced-scale SageMath prototype for studying randomness-source degradation, deterministic Q64 Logistic transformation, multi-source entropy integration, and transcript-bound key derivation in an HQC-like KEM workflow.

This is a reduced-scale SageMath prototype. It is intended for mechanism validation, statistical evaluation, and relative performance comparison. It is not a standards-compliant or production-grade HQC implementation. The prototype parameters do not correspond to the standardized HQC-1, HQC-3, or HQC-5 parameter sets.

The Logistic map is a deterministic nonlinear transformation and is not treated as an independent entropy source. Entropy robustness depends on an independent auxiliary entropy source. SHAKE256 performs the cryptographic mixing and whitening. The code is research software and must not be used to protect production data.

The implementation keeps the original notebook's tightly coupled structure in one SageMath source file. Thin experiment entry points call the original functions without changing algorithms, parameters, formulas, or experimental logic.

## Repository Structure

```text
.
|-- README.md
|-- LICENSE
|-- .gitignore
|-- src/
|   `-- hqc_prototype.sage
|-- experiments/
|   |-- core_smoke_test.sage
|   |-- randomness_test.sage
|   |-- autocorrelation_test.sage
|   |-- logistic_sensitivity_test.sage
|   |-- key_sensitivity_test.sage
|   |-- plaintext_avalanche_test.sage
|   |-- entropy_degradation_test.sage
|   |-- tampering_test.sage
|   `-- performance_test.sage
|-- matlab/
|   |-- selected post-processing scripts
|   `-- data files used by those scripts
`-- docs/
    |-- environment.md
    |-- provenance.md
    `-- reproducibility.md
```

## Requirements

- SageMath 9.3, matching the kernel metadata of the author-supplied notebook.
- Python 3.7.10 as reported by that SageMath notebook environment.
- NumPy and SciPy, including `scipy.io.savemat`.
- MATLAB R2024b for the supplied post-processing scripts. Other releases have not been validated.

See [`docs/environment.md`](docs/environment.md) for detected and recorded environment details.

## Environment

The source notebook records SageMath 9.3 and Python 3.7.10. The current Windows host contains MATLAB R2024b (24.2.0.2712019). SageMath 9.3 is not available on the ordinary Windows `PATH`, but it was detected and successfully exercised through the bundled SageMath Shell environment.

The repository does not require a nonstandard SageMath package beyond NumPy and SciPy. Any additional environment-specific package requirement is to be confirmed by the authors.

## Running the Core Implementation

Run commands from the repository root.

```bash
sage src/hqc_prototype.sage
sage experiments/core_smoke_test.sage
```

The first command loads and parses the implementation. The smoke test invokes the original Reed-Muller, Reed-Solomon, and KEM system checks.

On Windows installations where `sage` is not on the ordinary CMD or PowerShell `PATH`, open the SageMath 9.3 Shell shortcut, change to the repository root, and run the same commands there.

## Running the Experiments

Run each command from the repository root:

```bash
sage experiments/randomness_test.sage
sage experiments/autocorrelation_test.sage
sage experiments/logistic_sensitivity_test.sage
sage experiments/key_sensitivity_test.sage
sage experiments/plaintext_avalanche_test.sage
sage experiments/entropy_degradation_test.sage
sage experiments/tampering_test.sage
sage experiments/performance_test.sage
```

Experiments that emit MATLAB files change their working directory to `matlab/`, matching the file names consumed by the post-processing scripts.

The original `generate_proposed_hqc_data()` function is retained in `src/hqc_prototype.sage`, but it still contains the author-supplied `os.urandom(...)` placeholder instead of the proposed mixing call. It is therefore not exposed as a validated experiment entry point. The supplied Shannon-entropy `.mat` files can be plotted, but regeneration of those data requires author confirmation of the intended experiment logic. See [`docs/reproducibility.md`](docs/reproducibility.md).

## MATLAB Post-processing

Core cryptographic experiments and all included `.mat` datasets were generated in the SageMath/Python environment. MATLAB was used only for selected post-processing and visualization tasks.

From the repository root, examples are:

```bash
matlab -batch "cd('matlab'); autocorr_results"
matlab -batch "cd('matlab'); entropy_results"
matlab -batch "cd('matlab'); entropy_robustness"
matlab -batch "cd('matlab'); logistic_sensitivity"
matlab -batch "cd('matlab'); key_sensitivity"
matlab -batch "cd('matlab'); plaintext_avalanche"
matlab -batch "cd('matlab'); plot_hqc_integrity_compare"
```

The scripts write figures into the current MATLAB directory or into script-specific subdirectories. Generated figures are intentionally not committed.

## Mapping to Paper Experiments

| Paper Section | Experiment | Script |
| --- | --- | --- |
| Section 4.2 | Bit-frequency test | `experiments/randomness_test.sage` |
| Section 4.2 | Shannon-entropy visualization from supplied data | `matlab/entropy_results.m` |
| Section 4.2 | Autocorrelation | `experiments/autocorrelation_test.sage`, `matlab/autocorr_results.m` |
| Section 4.3 | Logistic-branch sensitivity | `experiments/logistic_sensitivity_test.sage`, `matlab/logistic_sensitivity.m` |
| Section 4.3 | Key sensitivity | `experiments/key_sensitivity_test.sage`, `matlab/key_sensitivity.m` |
| Section 4.3 | Plaintext avalanche | `experiments/plaintext_avalanche_test.sage`, `matlab/plaintext_avalanche.m` |
| Section 4.4 | Entropy-source degradation | `experiments/entropy_degradation_test.sage`, `matlab/entropy_robustness.m` |
| Section 4.5 | Ciphertext tampering | `experiments/tampering_test.sage`, `matlab/plot_hqc_integrity_compare.m` |
| Section 4.7 | Relative performance | `experiments/performance_test.sage` |

## Reproducibility Notes

- Randomized experiments use operating-system randomness and will not reproduce identical samples across runs.
- Fixed Q64 arithmetic gives deterministic Logistic evolution for identical seeds, encodings, and integer semantics.
- Statistical observations do not constitute a cryptographic security proof.
- The included `.mat` files are author-supplied outputs generated by the SageMath experiment code and consumed by the selected MATLAB scripts.
- The original-HQC comparison datasets correspond to the baseline HQC implementation and the same statistical procedures in `src/hqc_prototype.sage`. The final saved notebook does not retain every standalone invocation under the exact `y_*_original.mat` output name, so the supplied baseline outputs are preserved unchanged.
- The Shannon-entropy data-generation placeholder described above prevents a validated end-to-end regeneration of that specific dataset.
- Performance values are specific to the reduced-scale Python/SageMath prototype and must not be extrapolated to standardized HQC implementations.

## Security Disclaimer

This repository is for research and reproducibility only. It has not undergone production security review, constant-time validation, side-channel analysis, or conformance testing. It does not implement a standardized HQC parameter set. The Logistic layer introduces no new cryptographic hardness assumption and must not be treated as a cryptographically secure pseudorandom-number generator or an entropy source. Security of standardized HQC derives from its code-based assumptions and the applicable official construction, not from this prototype.

## Citation

If this repository supports published work, cite the associated paper:

```bibtex
@unpublished{cui2026hqcrobustness,
  author = {Zhiyong Cui and Guangpei Pan and Jun Zhang and Jinwei Luo and Zhen Wu},
  title  = {Multi-Source Entropy Enhancement and Context Binding for Post-Quantum HQC-KEM under Randomness-Source Degradation},
  year   = {2026},
  note   = {Manuscript submitted for publication}
}
```

Update the citation after publication.

## License

This repository retains its existing MIT License. The SageMath and MATLAB files are presented as author-supplied research code. The implementation follows the public HQC specification at the algorithmic level but does not include the official HQC C implementation. See [`docs/provenance.md`](docs/provenance.md) for provenance and attribution notes.
