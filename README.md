# HQC-KEM Robustness Enhancement

[中文说明](README.zh-CN.md) · [Release history](RELEASE_NOTES_v1.2.0.md)

## Project Overview

Research artifacts for *Random-Material Fusion and Key-Context Binding for HQC-KEM under Random-Source Degradation*. The implementation is a reduced-scale SageMath HQC-KEM prototype. The `paper/jcen-preparation` branch adds reproducibility materials for the current manuscript to the released v1.2.0 baseline.

## Research Objectives

The study examines shared-key derivation and random-material fusion under degradation of the primary source. It compares existing configurations under fixed bias, serial dependence and small supports. The comparisons include direct SHAKE256 fusion and fusion with deterministic Q64 Logistic pre-diffusion.

## System Architecture

The primary source supplies random material. An independent auxiliary input supplies the conditional unpredictability assumed under primary-source degradation. The Q64 fixed-point Logistic map provides deterministic nonlinear pre-diffusion of auxiliary material, and SHAKE256 fuses the materials. Public transcript fields bind the derived key to its context.

## Algorithm Description

The reduced-scale prototype retains its SageMath core, including encoding, encapsulation, decapsulation and implicit rejection. The preparation branch keeps the released core and the historical experiment entry points intact. [Provenance](docs/provenance.md) records the implementation history.

## Repository Structure

| Path | Purpose |
|---|---|
| `src/` | Released SageMath implementation |
| `experiments/` | Historical experiment entry points and plotting scripts |
| `matlab/` | Archived MAT datasets and MATLAB post-processing |
| `results/` | Historical release outputs |
| `data/` | Current manuscript data, checksums and archive metadata |
| `scripts/reproduction/` | Frozen-data verification and current English figure export |
| `docs/` | Environment, provenance and reproducibility documentation |

## Environment Requirements

The current plotting workflow was checked with Python 3.13.10, NumPy 2.5.2 and Matplotlib 3.11.1. The archived core uses SageMath 9.3 and its Python 3.7.10 environment with NumPy and SciPy. MATLAB R2024b was used for the historical MATLAB figures. See [environment details](docs/environment.md).

## Installation

Create and activate a Python 3.13 environment, then run:

```sh
python -m pip install -r requirements.txt
```

An equivalent Conda environment is defined in `environment.yml`. SageMath and MATLAB use their own environments.

## Reproduction Instructions

From the repository root, select a new output directory:

```sh
python scripts/reproduction/reproduce.py --output-dir repro-output
```

The command checks the archived inputs against their SHA-256 manifest and generates figures from stored results. It checks the Fig. 11 and Fig. 12 source CSV against the archived MATLAB arrays and replays the Markov pilot analysis from its stored outputs. [Historical workflows](docs/reproducibility.md) document the original experiment entry points and distinguish regenerated random samples from archived data.

## Experimental Data Description

The current Fig. 6 source CSV contains five paired batches with 20,000 eight-byte outputs per method and batch. The Fig. 11 and Fig. 12 data contain 3,000 outputs per configuration and support setting. The archived bias and serial-dependence results are separate simulation studies. Historical release files retain their original names and results. [Data provenance and replay coverage](docs/data_provenance.md)

## Figure Reproduction

The command above exports Figs. 4, 6, 11 and 12 as PDF, SVG and PNG. Figure 4 uses the existing deterministic sampled-orbit plot. Figure 6 reads the current paired-batch CSV. The archived MATLAB scripts provide post-processing for Figs. 7–10, 13 and 14. [English captions](data/processed/figures/captions_en.md)

## Security Assumptions

The threat model gives the adversary access to the public transcript and control over the degraded primary random source. The auxiliary input remains independent and inaccessible to the adversary. The security analysis uses the classical random oracle model and the stated collision-bound conditions.

## Limitations

The empirical comparisons use a reduced-scale prototype and simulated sources. The relative performance of the two fusion paths varies with the input model. Public transcript data supplies context, and the Q64 transform is deterministic. Measurements apply to the tested prototype and input distributions.

## Citation

Use [CITATION.cff](CITATION.cff) for software citation. The [Zenodo version series](https://doi.org/10.5281/zenodo.23309601) records the publicly released archives. The existing v1.2.0 archive is [10.5281/zenodo.23585902](https://doi.org/10.5281/zenodo.23585902).

## License

The released implementation retains its [MIT license](LICENSE). See [provenance](docs/provenance.md) for attribution.
