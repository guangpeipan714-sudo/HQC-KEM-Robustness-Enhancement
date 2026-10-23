# Reproducibility Status

## Included and mapped

- Reduced-scale HQC-like key generation, encapsulation, decapsulation, re-encryption checking, and implicit rejection.
- Q64 Logistic transformation, SHAKE256 whitening, entropy mixing, transcript-derived material, and final KDF mixing.
- Bit-frequency, autocorrelation, sensitivity, plaintext-avalanche, entropy-degradation, ciphertext-tampering, correctness, communication-overhead, and relative-performance functions.
- Author-generated SageMath `.mat` outputs and the MATLAB post-processing scripts that consume them for the manuscript figures.

## SageMath data-generation mapping

- `entropy_robustness.mat` is written by `run_entropy_robustness()`.
- `hqc_original.mat`, `hqc_proposed.mat`, and `shannon_entropy_source_data.csv` are written together by `generate_proposed_hqc_data()` through `experiments/shannon_entropy_test.sage`.
- `logistic_sensitivity.mat` is written by `run_logistic_raw_sensitivity()`.
- `key_sensitivity.mat` is written by `run_key_sensitivity_analysis()`.
- `autocorr_mixed_only.mat` is written by `generate_and_analyze_autocorr()`.
- `plaintext_avalanche.mat` is written by `run_plaintext_avalanche()`.
- `ciphertext_integrity_uv.mat` is written by `test_ciphertext_integrity_uv()`.
- `results/standard_size_engineering/standard_size_microbenchmark.*` is written
  by `benchmark_standard_size_enhancement()`.
- `results/standard_size_engineering/standard_size_context_binding.*` is written
  by `run_standard_size_context_binding()`.
- The four `y_*_original.mat` files are the SageMath-generated baseline counterparts. Their baseline KEM implementation is retained as `crypto_kem_keypair_orig()`, `crypto_kem_enc_orig()`, and `crypto_kem_dec_orig()`, and their field layouts match the corresponding enhanced experiment outputs.

## Known limitations

1. The Fig. 6 generator now executes the matched SHAKE256 baseline and `mix_urandom_with_chaos()` enhanced paths directly; `experiments/q64_recurrence_consistency_test.sage` separately checks the two shifts and 64-bit mask against emitted states.
2. Some legacy baseline output invocations are not retained under the exact four `y_*_original.mat` file names; those preserved author-generated files remain alongside the baseline HQC functions and corresponding statistical procedures.
3. SageMath 9.3 is not available on the ordinary Windows `PATH`, but the existing bundled SageMath Shell successfully loaded `src/hqc_prototype.sage` and ran `experiments/core_smoke_test.sage`. The RM, RS, concatenated-code, PKE, and KEM checks completed with `OK` results.
4. The regenerated Fig. 6 plot is produced by `experiments/plot_shannon_entropy.py`; the MATLAB scripts remain available for the other selected post-processing workflows.
5. Randomized experiments use operating-system randomness. Exact samples are therefore not expected to repeat without introducing a deterministic test seed, which would change the experiment setup and has not been done.
6. The NIST-reported-size engineering supplement uses deterministic synthetic byte
   strings whose lengths match the HQC profiles reported in NIST IR 8545. It
   isolates the proposed enhancement layer and is not a complete HQC
   implementation, conformance test, or whole-KEM performance benchmark.

These limitations do not authorize changing the algorithms, parameters, formulas, experiment logic, or manuscript data.
