load("src/hqc_prototype.sage")
os.chdir("matlab")

test_ciphertext_integrity_uv(
    num_trials=500,
    flip_bits_list=(1, 2, 4, 8, 16),
    components=("u", "v", "full_ct"),
    new_ciphertext_each_trial=True,
    save_path="ciphertext_integrity_uv.mat",
)
