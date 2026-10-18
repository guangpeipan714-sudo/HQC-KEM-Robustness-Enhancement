# Standard-size engineering supplement

## Purpose

This supplement adds engineering evidence without representing the
reduced-scale SageMath prototype as a standardized HQC implementation. It asks
two narrow questions:

1. How much absolute time and incremental Python allocation does the proposed
   entropy-diversification and public-transcript binding layers add when their
   inputs have the security levels and byte lengths of the three HQC parameter
   profiles reported by NIST?
2. At those input lengths, does a one-bit change in either the public key or
   ciphertext always change the derived key in the sampled trials, and is the
   resulting bit-change rate centred near 50%?

## Input sizes and boundary of the claim

The byte lengths are taken from NIST IR 8545 (March 2025):

| Profile | NIST level | Public key | Ciphertext | Combined transcript |
| --- | ---: | ---: | ---: | ---: |
| HQC-128 | 1 | 2,249 B | 4,497 B | 6,746 B |
| HQC-192 | 3 | 4,522 B | 9,042 B | 13,564 B |
| HQC-256 | 5 | 7,245 B | 14,485 B | 21,730 B |

Only byte-string lengths are imported from the standardization report. The
bytes themselves are deterministic SHAKE256-generated benchmark inputs. The
experiment does not run standardized HQC key generation, encapsulation, or
decapsulation and must not be cited as a whole-KEM benchmark.

Source: NIST IR 8545, *Status Report on the Fourth Round of the NIST
Post-Quantum Cryptography Standardization Process*, March 2025,
https://doi.org/10.6028/NIST.IR.8545.

## Timing design

- Timer: `time.perf_counter()`.
- Input construction: outside timed regions.
- Warm-up: 50 alternating calls.
- Measurements: 500 paired calls per profile.
- Order control: AB/BA alternation to reduce fixed ordering bias.
- Garbage collection: disabled only during the timed loop.
- Uncertainty: deterministic 2,000-resample percentile-bootstrap confidence
  interval for the paired median difference.
- Memory: peak incremental Python allocation over 25 calls using
  `tracemalloc`; this is Python-level allocation, not process RSS.

The matched baseline applies SHAKE256 to the base secret and public transcript.
The enhanced operation derives a transcript-bound seed, performs the Q64
transformation and whitening, and applies the final KDF. Absolute overhead in
microseconds is the primary quantity; the percentage is secondary because the
baseline operation is intentionally small.

The entropy-module comparison separately measures a single 32-, 48-, or
64-byte draw at NIST security levels 1, 3, and 5. Its matched baseline expands
the primary input using SHAKE256, whereas the enhanced path adds the independent
16-byte auxiliary seed, Q64 transformation, and domain-separated SHAKE256
aggregation. These are component microbenchmarks rather than counts of random
draws made by a standardized HQC implementation.

## Context-binding design

For every profile and component (`public_key`, `ciphertext`), the experiment
performs 500 trials. Each trial flips one uniformly selected bit, recomputes the
enhanced derived key, records whether the output differs, and records the
bit-change rate over the 256-bit output. The pseudorandom bit positions are
seeded for reproducibility; the test inputs are deterministic.

This experiment demonstrates implementation-level sensitivity and binding for
the sampled inputs. It is not a proof of collision resistance, key
indistinguishability, or IND-CCA2 security.

## Outputs

The script writes both human-readable and machine-readable results:

- `standard_size_microbenchmark.csv`, `.json`, and `.mat`;
- `standard_size_context_binding.csv`, `.json`, and `.mat`.

Run from the repository root with:

```bash
sage experiments/standard_size_engineering_test.sage
```
