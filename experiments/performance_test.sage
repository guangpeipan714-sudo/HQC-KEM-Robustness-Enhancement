load("src/hqc_prototype.sage")
os.chdir("matlab")

run_fair_benchmark(warmup=10, repeat=100)
