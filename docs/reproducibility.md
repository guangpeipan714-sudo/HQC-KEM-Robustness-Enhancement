# Reproducibility Status

## Included and mapped

- Reduced-scale HQC-like key generation, encapsulation, decapsulation, re-encryption checking, and implicit rejection.
- Q64 Logistic transformation, SHAKE256 whitening, entropy mixing, transcript-derived material, and final KDF mixing.
- Bit-frequency, autocorrelation, sensitivity, plaintext-avalanche, entropy-degradation, ciphertext-tampering, correctness, communication-overhead, and relative-performance functions.
- Author-generated SageMath `.mat` outputs and the MATLAB post-processing scripts that consume them for the manuscript figures.

## SageMath data-generation mapping

- `entropy_robustness.mat` is written by `run_entropy_robustness()`.
- `hqc_proposed.mat` is written by `generate_proposed_hqc_data()`; the preserved placeholder limitation below still applies.
- `logistic_sensitivity.mat` is written by `run_logistic_raw_sensitivity()`.
- `key_sensitivity.mat` is written by `run_key_sensitivity_analysis()`.
- `autocorr_mixed_only.mat` is written by `generate_and_analyze_autocorr()`.
- `plaintext_avalanche.mat` is written by `run_plaintext_avalanche()`.
- `ciphertext_integrity_uv.mat` is written by `test_ciphertext_integrity_uv()`.
- `hqc_original.mat` and the four `y_*_original.mat` files are the SageMath-generated baseline counterparts. Their baseline KEM implementation is retained as `crypto_kem_keypair_orig()`, `crypto_kem_enc_orig()`, and `crypto_kem_dec_orig()`, and their field layouts match the corresponding enhanced experiment outputs.

## Known limitations

1. `generate_proposed_hqc_data()` contains an explicit author-supplied `os.urandom(...)` placeholder. It does not currently regenerate proposed-scheme Shannon-entropy data through `mix_urandom_with_chaos()`. The function is preserved verbatim, is not exposed through an experiment wrapper, and requires author confirmation before any logic change.
2. All included `.mat` files were generated in the author's SageMath/Python environment. In the final saved notebook, some baseline output invocations are not retained under their exact `hqc_original.mat` or `y_*_original.mat` file names; the author-generated files are therefore preserved unchanged alongside the baseline HQC functions and corresponding statistical procedures.
3. SageMath 9.3 is not available on the ordinary Windows `PATH`, but the existing bundled SageMath Shell successfully loaded `src/hqc_prototype.sage` and ran `experiments/core_smoke_test.sage`. The RM, RS, concatenated-code, PKE, and KEM checks completed with `OK` results.
4. MATLAB R2024b successfully executed `entropy_results.m` with the supplied data. All seven selected MATLAB scripts also passed `checkcode` without syntax errors; the remaining messages were non-fatal performance or export-option recommendations.
5. Randomized experiments use operating-system randomness. Exact samples are therefore not expected to repeat without introducing a deterministic test seed, which would change the experiment setup and has not been done.

These limitations do not authorize changing the algorithms, parameters, formulas, experiment logic, or manuscript data.
