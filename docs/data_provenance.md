# Data and implementation provenance

## Evidence used in the current manuscript

| Manuscript evidence | Repository location | Provenance |
|---|---|---|
| Figure 4 | `scripts/reproduction/plot_figure04_en.py` | Bifurcation illustration of the real-valued Logistic map with the existing prototype parameter interval |
| Figure 6 | `data/processed/figures/figure6_verified_entropy.csv` | Five paired `uniform_healthy` confirmation batches, 20,000 eight-byte outputs per arm and batch, comparing `A_joint` with `B` |
| Figures 7 and 8 | `matlab/autocorr_results.m`, `matlab/logistic_sensitivity.m` | Archived baseline/enhanced autocorrelation MAT files and the Logistic sensitivity MAT file |
| Figures 9 and 10 | `matlab/key_sensitivity.m`, `matlab/plaintext_avalanche.m` | Archived baseline/enhanced key sensitivity and plaintext avalanche MAT pairs |
| Figures 11 and 12 | `matlab/entropy_robustness.mat`, `data/processed/figures/figures11_12_source.csv` | Three configurations and eight primary-source support exponents. Figure 11 selects `h = 8`. Empirical maximum-frequency score and distinct-output fraction are finite-sample output statistics. |
| Figures 13 and 14 | `matlab/plot_hqc_integrity_compare.m` | Archived `y_ciphertext_integrity_original.mat` and `ciphertext_integrity_uv.mat` for ciphertext perturbation |
| One-SHAKE comparison | `data/processed/joint_comparison/joint_vs_chaos.csv` | Secondary analysis of 18 prior confirmation conditions, 40,000 training and 60,000 held-out outputs per arm and condition |
| Explicit-XOR Markov pilot | `data/raw/revised_markov_outputs/`, `data/processed/revised_markov/results.csv` | Separate frozen pilot at `rho = 0.8` with 4,000 training and 6,000 held-out outputs per arm and condition |
| SP 800-90B diagnostics | `data/raw/entropy_assessment/`, `data/processed/entropy_assessment/` | One million sequential byte-per-symbol observations per simulated source, assessed before Logistic and SHAKE |
| Implementation checks | `data/processed/code_checks/` | Archived boundary checks, confirmation-data compatibility check, and collector assignment check |

`A_joint` uses one SHAKE256 call over the framed primary and auxiliary inputs. `B` adds the Q64 mapping and the inner SHAKE256 step on its auxiliary path. Their comparison is therefore between full paths. The equal-structure ablation in the earlier confirmation analysis uses a separate arm `A`. The simultaneous intervals and the comparison direction are preserved in the archived tables. Positive and negative differences occur in different input models.

The current Figure 6 uses its own paired-batch CSV. The legacy `matlab/hqc_original.mat` and `matlab/hqc_proposed.mat` and the v1.2.0 `results/shannon_entropy/` files are retained as historical assets. The historical notebook's collector used an `os.urandom` placeholder. The current figure is based on the saved outputs of the two indicated fusion paths. The historical `results/standard_size_engineering/` files describe a separate component benchmark from the earlier submission.

## Implementation versions

| Source | Identifier | Use |
|---|---|---|
| Original author notebook | SHA-256 `c9ad15d9c84c410f820ccac5777849a354b197cb0f495163582601bf45be5fbc` | Historical Sage confirmation outputs were collected with the effective definition and original Sage preparse semantics. |
| `HQC_chaos_verified_core_revision.ipynb` | SHA-256 `9bde6e768a74531afb239e323a3e333935e2479fa1bc29a3304edcf08d7644dd` | Existing explicit-XOR revision used to collect the separate Markov pilot. |
| `HQC_chaos_minimal_revision.ipynb` | SHA-256 `9d223d61e1210eb0ad82ef21e368f91c0cd9d6e8b3e5ae3585ab65f052472b44` | Existing subsequent collector-only revision. The Q64 function source hash is the same as in the verified core revision. |
| Public release v1.2.0 | Commit `8eeb2e65fbd019c04137bdcafcbc2d60187b5763` | Baseline for the repository and its historical test and plotting scripts. [Zenodo v1.2.0](https://doi.org/10.5281/zenodo.23585902) |

The original notebook and the two revised notebook snapshots remain in the author workspace. The exact snapshot used for the Markov pilot appears in `worker_metadata.json`. The earlier compatibility check compared all 1,800,000 saved rows, with 551,568 distinct auxiliary inputs, against the explicit-XOR core. It found zero mismatches in the saved 32-byte Q64 prefix. This result covers those inputs. The archived core and collector checks give the scope of the boundary checks and collector assignment verification.

## Verify and replay the frozen evidence

Run from the repository root with the Python analysis environment documented in the README.

```sh
python scripts/analysis/verify_frozen_data.py
python scripts/analysis/analyze_revised_markov.py --output-dir build/markov-replay
```

The verifier checks the byte-level hashes in `data/metadata/frozen_data_manifest.json`, the encoding and input hash of each SP 800-90B sequence, and the archived diagnostic results. The Markov replay reads the ten bundled batch outputs and creates a new directory. Its primary CSV can be compared with `data/processed/revised_markov/results.csv`.

The 90 original confirmation NPZ files are stored in the author workspace under `chaos_value_ablation/data/confirmation_outputs/`. The frozen statistical table, ROC, classifier summaries and per-batch hashes are bundled. The original NPZ files are currently outside this branch and the cited v1.2.0 archive. After obtaining these frozen files, point the replay at their directory.

```sh
python scripts/analysis/verify_frozen_data.py --confirmation-dir /path/to/confirmation_outputs
python scripts/analysis/analyze_joint_comparison.py --input-dir /path/to/confirmation_outputs --output-dir build/joint-replay
```

The two analysis entry points use the archived estimators, training/test split, thresholds and interval calculation. They require new output directories. Large scores and logs remain in the author workspace, while the tables and classifier summaries included here retain their original bytes.

## SP 800-90B simulation diagnostics

The frozen inputs each store one ordered binary symbol per byte. The manifest records the simulation model, seed, encoding, sample count, and input SHA-256. The archived runs used NIST EntropyAssessment 1.1.8 at `87c104d0ed4cbc96103e7b8b38d6f2c7e0a6b289`. Run JSON files retain all estimator and status fields. The only edits remove the local machine path prefix in invocation metadata. The original and included file SHA-256 values are listed in the frozen data manifest. [NIST EntropyAssessment source](https://github.com/usnistgov/SP800-90B_EntropyAssessment/tree/87c104d0ed4cbc96103e7b8b38d6f2c7e0a6b289)

| Model | IID tests | IID estimate used (bit/sample) | Non-IID estimate (bit/sample) |
|---|---|---:|---:|
| Bernoulli, `p = 0.70` | Pass | 0.510994 | 0.321330 |
| Symmetric Markov, `rho = 0.80` | Fail | — | 0.076833 |

The diagnostics describe simulated input sources under the stated models. Device restart and physical-source health-test data are outside this assessment.
