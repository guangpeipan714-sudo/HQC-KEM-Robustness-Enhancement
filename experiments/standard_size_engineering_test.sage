load("src/hqc_prototype.sage")

benchmark_standard_size_enhancement(
    warmup=50,
    repeat=500,
    bootstrap_resamples=2000,
    output_dir="results/standard_size_engineering",
)

run_standard_size_context_binding(
    num_trials=500,
    bootstrap_resamples=2000,
    output_dir="results/standard_size_engineering",
)
