import os

load("src/hqc_prototype.sage")

previous_directory = os.getcwd()
try:
    os.chdir("matlab")
    generate_proposed_hqc_data()
finally:
    os.chdir(previous_directory)
