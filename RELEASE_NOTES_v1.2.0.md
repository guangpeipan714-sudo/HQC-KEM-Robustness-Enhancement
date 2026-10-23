# HQC-KEM Robustness Enhancement v1.2.0

This release aligns the public research code and reproducibility materials with the DCC manuscript *Multi-Source Entropy Robustness and Context Binding for the Post-Quantum HQC-KEM*.

## Corrections

- Removed a later duplicate definition that silently overrode the documented Q64 fixed-point Logistic-style recurrence.
- Documented and tested the actual two-stage integer update with `Q = 2^64`, `M = Q - 1`, two separate 64-bit right shifts, and a final 64-bit mask.
- Replaced the Fig. 6 Shannon-entropy placeholder with the executable matched baseline and enhanced paths, and regenerated the associated MAT and CSV records.
- Added a direct Q64 recurrence-consistency test and reproducible Python plotting scripts.
- Updated terminology so that NIST-reported HQC parameter profiles and component-level transcript-size tests are not described as a complete standardized HQC implementation.

## Scope

The repository remains a reduced-scale SageMath research prototype. The deterministic Q64 transform is not an independent entropy source or a CSPRNG. The standard-size supplement exercises only the entropy-diversification and context-binding components with byte-string lengths reported in NIST IR 8545; it is not an HQC conformance test or a whole-KEM benchmark.

No experimental parameters or security claims were expanded in this release.
