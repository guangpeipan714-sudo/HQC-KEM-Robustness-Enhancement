load("src/hqc_prototype.sage")

Q = 1 << 64
M = Q - 1
seed = bytes.fromhex("0123456789abcdeffedcba9876543210")
s0 = int.from_bytes(seed[:8], "little")
s1 = int.from_bytes(seed[8:], "little")
x = (s0 | 1) & M
if x == 0 or x == M:
    x = 0x9E3779B97F4A7C15
r_q = R_LOW_Q64 + (s1 % SPAN_Q64)

assert R_LOW_Q64 <= r_q < R_LOW_Q64 + SPAN_Q64
assert r_q < 4 * Q

states = []
for _ in range(64 + 4):
    t = (x * (M - x)) >> 64
    x = ((r_q * t) >> 64) & M
    states.append(x)

expected = b"".join(_le_u64(value) for value in states[64:68])
actual = logistic_chaos_bytes(seed, len(expected), burn_in=64)
assert actual == expected

print("Q64 recurrence consistency: OK")
print("Q = %d, M = %d, r_Q = %d" % (Q, M, r_q))
print("first four post-burn states = %s" %
      ", ".join(str(value) for value in states[64:68]))
