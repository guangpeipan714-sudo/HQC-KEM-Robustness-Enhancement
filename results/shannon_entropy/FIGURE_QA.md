# Fig. 6 QA record

- Core conclusion: both evaluated SHAKE256 output paths have byte-level Shannon entropy close to 8 bit/byte; the figure does not rank their cryptographic quality.
- Plot type: single-panel boxplot with all 100 independently generated observations shown for each construction.
- Replicate unit: one 1,000,000-byte output; `n=100` per construction.
- Statistics: median and interquartile range in the boxplot; whiskers use Matplotlib's default 1.5-IQR rule. No significance test was performed.
- Source data: `fig6_source_data.csv`, copied from the SageMath-generated `matlab/shannon_entropy_source_data.csv`.
- Backend: Python/Matplotlib only.
- Source validation: 20 PASS, 0 FAIL. The single simulated-data warning is a false positive caused by deterministic horizontal jitter; no scientific value is generated or altered by the plotting script.
- Panel alignment: not applicable (single panel); the alignment JSON is retained.
- PDF text audit: PASS; minimum rendered glyph size 7 pt.
- Collision audit: PASS; 0 failures and 0 warnings.
- Visual review: axes, group labels, the 8-bit/byte reference line, points, boxes, and whiskers are legible at the 88.9-mm final width; no clipping or overlap was observed.
