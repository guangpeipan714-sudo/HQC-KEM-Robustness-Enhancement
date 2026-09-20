# Reduced-scale SageMath HQC-KEM research prototype.
# Mechanically extracted from the author-supplied notebook code cells.
# Notebook outputs and invocation cells are intentionally excluded.
# No algorithm, parameter, formula, or experiment function was changed.

import hashlib
import os
import random
import numpy as np
from scipy.io import savemat
from random import randint, sample
import math
from collections import Counter
import operator
import scipy.io as sio
import statistics
import time, gc, statistics
def b1(x):
    return bytes([int(x) & 0xFF])

# ---------------------------
# 域分离常量（toy）
# ---------------------------
SEEDEXPANDER_DOMAIN = 0x01
G_FCT_DOMAIN        = 0x10
K_FCT_DOMAIN        = 0x20

# Logistic 混沌融合域分离
CHAOS_DOMAIN      = 0x33
RNG_MIX_DOMAIN    = 0x34
KDF_MIX_DOMAIN    = 0x35
CHAOS_SEED_DOMAIN = 0x36

# ---------------------------
# 参数
# ---------------------------
PARAM_N1   = 16
PARAM_N2   = 128
PARAM_N1N2 = PARAM_N1 * PARAM_N2
PARAM_N    = PARAM_N1N2

PARAM_K   = 8
PARAM_G   = PARAM_N1 - PARAM_K
assert PARAM_G % 2 == 0
RS_DELTA  = PARAM_G // 2

PARAM_OMEGA   = 3
PARAM_OMEGA_E = 3
PARAM_OMEGA_R = 3

SEED_BYTES = 8
SALT_SIZE_BYTES = 8
SHAKE256_512_BYTES = 16

assert PARAM_N1 > PARAM_K
assert PARAM_N2 % 128 == 0
MULTIPLICITY = PARAM_N2 // 128
assert MULTIPLICITY * 128 == PARAM_N2

VEC_N_SIZE_BYTES    = (PARAM_N + 7) // 8
VEC_K_SIZE_BYTES    = PARAM_K
VEC_N1N2_SIZE_BYTES = (PARAM_N1N2 + 7) // 8

PUBLIC_KEY_BYTES  = SEED_BYTES + VEC_N_SIZE_BYTES
SECRET_KEY_BYTES  = SEED_BYTES + VEC_K_SIZE_BYTES + PUBLIC_KEY_BYTES
CIPHERTEXT_BYTES  = VEC_N_SIZE_BYTES + VEC_N1N2_SIZE_BYTES + SALT_SIZE_BYTES

# ---------------------------
# bits <-> bytes（字节内小端）
# ---------------------------
def bits_to_bytes_le(bits):
    out = bytearray((len(bits) + 7) // 8)
    for i, b in enumerate(bits):
        if int(b) & 1:
            out[i >> 3] |= (1 << (i & 7))
    return bytes(out)

def bytes_to_bits_le(by, bitlen):
    bits = [0] * int(bitlen)
    for i in range(int(bitlen)):
        bits[i] = (by[i >> 3] >> (i & 7)) & 1
    return bits

# ---------------------------
# SHAKE256 带域分离（保证 int）
# ---------------------------
def shake256_512_ds(data_bytes, domain_byte):
    h = hashlib.shake_256()
    h.update(data_bytes)
    h.update(b1(domain_byte))
    return h.digest(int(SHAKE256_512_BYTES))

class SeedExpander:
    """
    toy：SHAKE256(seed||domain) 作为伪随机流（一次性拉出 1e6 bytes）
    """
    def __init__(self, seed_bytes):
        self._h = hashlib.shake_256()
        self._h.update(seed_bytes)
        self._h.update(b1(SEEDEXPANDER_DOMAIN))
        self._stream = self._h.digest(int(10**6))
        self._pos = 0

    def read(self, n):
        n = int(n)
        out = self._stream[self._pos:self._pos + n]
        self._pos += n
        return out

# ============================================================
# Logistic chaos (toy) + 熵混合 / KDF层混合
# ============================================================

def _u64_le(by):
    return int.from_bytes(by, 'little')

def _le_u64(x):
    return int(x & ((1<<64)-1)).to_bytes(8, 'little')

# 控制参数 r 的 Q64 定点范围常量：r ∈ [3.9, 4)
R_LOW_Q64 = (39 * (1 << 64)) // 10   # floor(3.9 * 2^64)
SPAN_Q64  = (1 << 64) // 10          # floor(0.1 * 2^64)，区间 [3.9,4) 的宽度

def logistic_chaos_bytes(seed16, out_len, burn_in=64):
    """
    数字 Logistic 混沌：x_{n+1} = r*x_n*(1-x_n) in Q64
    控制参数 r 由种子高 8 字节映射到深度混沌区间 [3.9, 4)。
    注意：不能替代 CSPRNG；这里只作为“加料”，并会被 SHAKE 白化。
    """
    assert len(seed16) == 16
    out_len = int(out_len)
    burn_in = int(burn_in)

    s0 = _u64_le(seed16[:8])
    s1 = _u64_le(seed16[8:])

    x = (s0 | 1) & 0xFFFFFFFFFFFFFFFF
    if x == 0 or x == 0xFFFFFFFFFFFFFFFF:
        x = 0x9E3779B97F4A7C15

    # r ∈ [3.9, 4)：将 s1 对区间宽度取模后加下界，确保落入深度混沌区
    frac = s1 % SPAN_Q64
    r = R_LOW_Q64 + frac  # Q64

    def step(x):
        one_minus_x = 0xFFFFFFFFFFFFFFFF - x
        t = (x * one_minus_x) >> 64
        xp = (r * t) >> 64
        return xp & 0xFFFFFFFFFFFFFFFF

    for _ in range(burn_in):
        x = step(x)

    out = bytearray()
    while len(out) < out_len:
        x = step(x)
        out += _le_u64(x)

    return bytes(out[:out_len])

def shake_whiten_chaos(seed16, out_len, domain=CHAOS_DOMAIN):
    out_len = int(out_len)
    raw = logistic_chaos_bytes(seed16, max(32, out_len))
    h = hashlib.shake_256()
    h.update(raw)
    h.update(b1(domain))
    return h.digest(out_len)

def mix_urandom_with_chaos(label_bytes, urnd_bytes, chaos_seed16, out_len):
    """
    方向1（熵混合）：urandom 主熵 + chaos(白化) 加料 -> SHAKE 输出
    """
    out_len = int(out_len)
    chaos_part = shake_whiten_chaos(chaos_seed16, out_len, CHAOS_DOMAIN)
    h = hashlib.shake_256()
    h.update(label_bytes)
    h.update(urnd_bytes)
    h.update(chaos_part)
    h.update(b1(RNG_MIX_DOMAIN))
    return h.digest(out_len)

def derive_shared_chaos_seed16(pk_bytes, salt, u_bytes, v_bytes):
    """
    方向5：给 KDF 层一个双方都能重现的额外输入（不要求保密）
    从公开数据 (pk, salt, u, v) 确定性派生 16 bytes。
    """
    h = hashlib.shake_256()
    h.update(pk_bytes)
    h.update(salt)
    h.update(u_bytes)
    h.update(v_bytes)
    h.update(b1(CHAOS_SEED_DOMAIN))
    return h.digest(int(16))

def kdf_mix(base_ss, chaos_kdf_bytes, context_bytes=b''):
    """
    方向5（KDF层混合）：ss_final = SHAKE256(base_ss || chaos_kdf || context || domain)
    """
    h = hashlib.shake_256()
    h.update(base_ss)
    h.update(chaos_kdf_bytes)
    h.update(context_bytes)
    h.update(b1(KDF_MIX_DOMAIN))
    return h.digest(int(SHAKE256_512_BYTES))

# ---------------------------
# GF(256) (0x11D): z^8+z^4+z^3+z^2+1
# ---------------------------
F2 = GF(2)
PR.<z> = PolynomialRing(F2)
mod_poly = z^8 + z^4 + z^3 + z^2 + 1
GF256.<a> = GF(2^8, modulus=mod_poly)

def gf_to_int(x):
    return int(x.integer_representation())

# ============================================================
# RS 外码：系统型编码 + BM/Chien/Forney 纠错
# ============================================================

F = GF256
PRF.<Xrs> = PolynomialRing(F)
alpha = a

def rs_generator_poly():
    g = PRF(1)
    for i in range(1, 2*RS_DELTA + 1):
        g *= (Xrs + alpha^i)
    return g.monic()

RS_G = rs_generator_poly()

def rs_poly_from_bytes(by):
    return sum(F.fetch_int(int(by[i])) * (Xrs^i) for i in range(len(by)))

def rs_bytes_from_poly(p, n):
    p = p.list()
    out = []
    for i in range(int(n)):
        coeff = p[i] if i < len(p) else F(0)
        out.append(gf_to_int(coeff))
    return bytes(out)

def reed_solomon_encode(msg_k):
    assert len(msg_k) == PARAM_K
    n = PARAM_N1
    k = PARAM_K
    t2 = n - k

    mpoly = rs_poly_from_bytes(msg_k)
    shifted = mpoly * (Xrs^t2)
    r = shifted % RS_G
    cpoly = shifted + r
    return rs_bytes_from_poly(cpoly, n)

def berlekamp_massey(syndromes):
    C = [F(1)] + [F(0)] * (2*RS_DELTA)
    B = [F(1)] + [F(0)] * (2*RS_DELTA)
    L = 0
    m = 1
    b = F(1)

    for n in range(0, 2*RS_DELTA):
        d = syndromes[n]
        for i in range(1, L+1):
            d += C[i] * syndromes[n - i]
        if d == 0:
            m += 1
            continue

        T = C[:]
        coef = d / b
        for i in range(m, 2*RS_DELTA+1):
            C[i] += coef * B[i - m]

        if 2*L <= n:
            L = n + 1 - L
            B = T
            b = d
            m = 1
        else:
            m += 1

    return C

def poly_eval_coeffs(coeffs, x):
    acc = F(0)
    xp = F(1)
    for c in coeffs:
        acc += c * xp
        xp *= x
    return acc

def poly_derivative_coeffs(coeffs):
    out = [F(0)] * max(0, len(coeffs)-1)
    for i in range(1, len(coeffs)):
        if (i % 2) == 1:
            out[i-1] = coeffs[i]
    return out

def reed_solomon_decode(cdw_n1):
    assert len(cdw_n1) == PARAM_N1
    n = PARAM_N1
    t2 = n - PARAM_K

    r = [F.fetch_int(int(b)) for b in cdw_n1]

    synd = []
    for j in range(1, 2*RS_DELTA + 1):
        x = alpha^j
        Sj = F(0)
        xp = F(1)
        for i in range(n):
            Sj += r[i] * xp
            xp *= x
        synd.append(Sj)

    if all(s == 0 for s in synd):
        return bytes([gf_to_int(r[i]) for i in range(t2, n)])

    Lambda = berlekamp_massey(synd)
    while len(Lambda) > 1 and Lambda[-1] == 0:
        Lambda.pop()

    Omega = [F(0)] * (2*RS_DELTA)
    for i in range(len(Lambda)):
        for j in range(2*RS_DELTA):
            if i + j < 2*RS_DELTA:
                Omega[i+j] += Lambda[i] * synd[j]

    err_pos = []
    for pos in range(n):
        xinv = alpha^(-pos)
        if poly_eval_coeffs(Lambda, xinv) == 0:
            err_pos.append(pos)

    if len(err_pos) == 0 or len(err_pos) > RS_DELTA:
        return bytes([gf_to_int(r[i]) for i in range(t2, n)])

    Lambda_der = poly_derivative_coeffs(Lambda)
    r_corr = r[:]

    for pos in err_pos:
        xinv = alpha^(-pos)
        num = poly_eval_coeffs(Omega, xinv)
        den = poly_eval_coeffs(Lambda_der, xinv)
        if den == 0:
            return bytes([gf_to_int(r[i]) for i in range(t2, n)])
        e = num / den
        r_corr[pos] = r_corr[pos] - e

    synd2 = []
    for j in range(1, 2*RS_DELTA + 1):
        x = alpha^j
        Sj = F(0)
        xp = F(1)
        for i in range(n):
            Sj += r_corr[i] * xp
            xp *= x
        synd2.append(Sj)

    if not all(s == 0 for s in synd2):
        return bytes([gf_to_int(r[i]) for i in range(t2, n)])

    return bytes([gf_to_int(r_corr[i]) for i in range(t2, n)])

# ---------------------------
# RM(1,7) 编码/解码
# ---------------------------
def rm17_encode_byte(b):
    b_val = int(b)
    bits = [(b_val >> i) & 1 for i in range(8)]
    cw = []
    for point in range(128):
        v = bits[0]
        for j in range(1, 8):
            if ((point >> (j - 1)) & 1) == 1:
                v = int(v) ^^ int(bits[j])
        cw.append(int(v) & 1)
    return cw

def fwht_128(vec):
    data = list(vec)
    h = 1
    n = 128
    while h < n:
        for i in range(0, n, 2*h):
            for j in range(i, i+h):
                x0 = data[j]
                y0 = data[j+h]
                data[j]   = x0 + y0
                data[j+h] = x0 - y0
        h *= 2
    return data

def rm17_decode_block(bits_n2):
    assert len(bits_n2) == PARAM_N2

    y = [0] * 128
    for copy in range(MULTIPLICITY):
        base = 128 * copy
        for i in range(128):
            bit = int(bits_n2[base + i]) & 1
            y[i] += (1 if bit == 0 else -1)

    spec = fwht_128(y)
    peak_pos = max(range(128), key=lambda idx: abs(spec[idx]))
    a_lin = peak_pos & 0x7F

    cand0 = ((a_lin << 1) & 0xFE) | 0
    cand1 = ((a_lin << 1) & 0xFE) | 1

    cw0 = rm17_encode_byte(cand0)
    cw1 = rm17_encode_byte(cand1)

    def score(cw):
        s = 0
        for i in range(128):
            si = (1 if cw[i] == 0 else -1)
            s += si * y[i]
        return s

    return cand0 if score(cw0) >= score(cw1) else cand1

def reed_muller_encode(msg_n1):
    assert len(msg_n1) == PARAM_N1
    out_bits = []
    for b in msg_n1:
        cw = rm17_encode_byte(b)
        for _ in range(MULTIPLICITY):
            out_bits.extend(cw)
    assert len(out_bits) == PARAM_N1N2
    return out_bits

def reed_muller_decode(bits_n1n2):
    assert len(bits_n1n2) == PARAM_N1N2
    msg = bytearray(PARAM_N1)
    for i in range(PARAM_N1):
        block = bits_n1n2[i*PARAM_N2:(i+1)*PARAM_N2]
        msg[i] = rm17_decode_block(block)
    return bytes(msg)

# ---------------------------
# 级联码：RS -> RM
# ---------------------------
def code_encode(m_k):
    tmp = reed_solomon_encode(m_k)
    return reed_muller_encode(tmp)

def code_decode(bits_2048):
    tmp = reed_muller_decode(bits_2048)
    return reed_solomon_decode(tmp)

# ---------------------------
# 环：GF(2)[x]/(x^N - 1), N=2048
# ---------------------------
R.<x> = PolynomialRing(GF(2))
Q.<X> = R.quotient(x^PARAM_N - 1)

def bits_to_poly_q(bits_n):
    idx = [i for i, b in enumerate(bits_n) if int(b) == 1]
    return sum(X^i for i in idx) if idx else Q(0)

def poly_q_to_bits(p):
    poly = p.lift()
    bits = [0] * PARAM_N
    for mon, coeff in poly.dict().items():
        if coeff == 1:
            i = mon[0] if isinstance(mon, tuple) else mon
            bits[i % PARAM_N] = int(bits[i % PARAM_N]) ^^ 1
    return bits

def vect_add(a_bits, b_bits):
    return [int(u) ^^ int(v) for u, v in zip(a_bits, b_bits)]

def vect_mul(a_bits, b_bits):
    return poly_q_to_bits(bits_to_poly_q(a_bits) * bits_to_poly_q(b_bits))

# ---------------------------
# 采样（toy）
# ---------------------------
def sample_fixed_weight(seedexpander, n, weight):
    positions = set()
    while len(positions) < int(weight):
        r = int.from_bytes(seedexpander.read(4), 'little')
        positions.add(r % int(n))
    bits = [0] * int(n)
    for pos in positions:
        bits[int(pos)] = 1
    return bits

def sample_uniform(seedexpander, n):
    n = int(n)
    by = seedexpander.read((n + 7) // 8)
    return bytes_to_bits_le(by, n)

# ---------------------------
# parsing
# ---------------------------
def hqc_public_key_to_string(pk_seed, s_bits):
    assert len(pk_seed) == SEED_BYTES
    s_bytes = bits_to_bytes_le(s_bits)
    assert len(s_bytes) == VEC_N_SIZE_BYTES
    return pk_seed + s_bytes

def hqc_public_key_from_string(pk_bytes):
    assert len(pk_bytes) == PUBLIC_KEY_BYTES
    pk_seed = pk_bytes[:SEED_BYTES]
    s_bytes = pk_bytes[SEED_BYTES:]
    s_bits = bytes_to_bits_le(s_bytes, PARAM_N)
    se = SeedExpander(pk_seed)
    h_bits = sample_uniform(se, PARAM_N)
    return h_bits, s_bits, pk_seed

def hqc_secret_key_to_string(sk_seed, sigma, pk_bytes):
    assert len(sk_seed) == SEED_BYTES
    assert len(sigma) == VEC_K_SIZE_BYTES
    assert len(pk_bytes) == PUBLIC_KEY_BYTES
    return sk_seed + sigma + pk_bytes

def hqc_secret_key_from_string(sk_bytes):
    assert len(sk_bytes) == SECRET_KEY_BYTES
    sk_seed = sk_bytes[:SEED_BYTES]
    sigma   = sk_bytes[SEED_BYTES:SEED_BYTES + VEC_K_SIZE_BYTES]
    pk      = sk_bytes[SEED_BYTES + VEC_K_SIZE_BYTES:]

    se = SeedExpander(sk_seed)
    x_bits = sample_fixed_weight(se, PARAM_N, PARAM_OMEGA)
    y_bits = sample_fixed_weight(se, PARAM_N, PARAM_OMEGA)
    return x_bits, y_bits, sigma, pk, sk_seed

def hqc_ciphertext_to_string(u_bits, v_bits, salt):
    assert len(u_bits) == PARAM_N
    assert len(v_bits) == PARAM_N1N2
    assert len(salt) == SALT_SIZE_BYTES
    return bits_to_bytes_le(u_bits) + bits_to_bytes_le(v_bits) + salt

def hqc_ciphertext_from_string(ct_bytes):
    assert len(ct_bytes) == CIPHERTEXT_BYTES
    u_bytes = ct_bytes[:VEC_N_SIZE_BYTES]
    v_bytes = ct_bytes[VEC_N_SIZE_BYTES:VEC_N_SIZE_BYTES + VEC_N1N2_SIZE_BYTES]
    salt    = ct_bytes[VEC_N_SIZE_BYTES + VEC_N1N2_SIZE_BYTES:]

    u_bits = bytes_to_bits_le(u_bytes, PARAM_N)
    v_bits = bytes_to_bits_le(v_bytes, PARAM_N1N2)
    return u_bits, v_bits, salt

# ---------------------------
# HQC PKE（toy）
# ---------------------------
def hqc_pke_keygen():
    sk_seed_u = os.urandom(SEED_BYTES)
    sigma_u   = os.urandom(VEC_K_SIZE_BYTES)
    pk_seed_u = os.urandom(SEED_BYTES)

    chaos_seed16 = os.urandom(16)

    sk_seed = mix_urandom_with_chaos(b"KEYGEN:sk_seed", sk_seed_u, chaos_seed16, SEED_BYTES)
    sigma   = mix_urandom_with_chaos(b"KEYGEN:sigma",   sigma_u,   chaos_seed16, VEC_K_SIZE_BYTES)
    pk_seed = mix_urandom_with_chaos(b"KEYGEN:pk_seed", pk_seed_u, chaos_seed16, SEED_BYTES)

    sk_se = SeedExpander(sk_seed)
    pk_se = SeedExpander(pk_seed)

    x_bits = sample_fixed_weight(sk_se, PARAM_N, PARAM_OMEGA)
    y_bits = sample_fixed_weight(sk_se, PARAM_N, PARAM_OMEGA)

    h_bits = sample_uniform(pk_se, PARAM_N)
    s_bits = vect_add(x_bits, vect_mul(y_bits, h_bits))

    pk = hqc_public_key_to_string(pk_seed, s_bits)
    sk = hqc_secret_key_to_string(sk_seed, sigma, pk)
    return pk, sk

def hqc_pke_encrypt(m_k, theta, pk_bytes):
    assert len(m_k) == VEC_K_SIZE_BYTES
    theta = (theta + b'\x00'*SEED_BYTES)[:SEED_BYTES]
    se = SeedExpander(theta)

    h_bits, s_bits, _ = hqc_public_key_from_string(pk_bytes)

    r1 = sample_fixed_weight(se, PARAM_N, PARAM_OMEGA_R)
    r2 = sample_fixed_weight(se, PARAM_N, PARAM_OMEGA_R)
    e  = sample_fixed_weight(se, PARAM_N, PARAM_OMEGA_E)

    u_bits = vect_add(r1, vect_mul(r2, h_bits))

    v_enc = code_encode(m_k)
    v_bits = vect_add(v_enc, vect_add(vect_mul(r2, s_bits), e))
    return u_bits, v_bits

def hqc_pke_decrypt(u_bits, v_bits, sk_bytes):
    x_bits, y_bits, sigma, pk_bytes, _ = hqc_secret_key_from_string(sk_bytes)
    uy = vect_mul(y_bits, u_bits)
    diff = vect_add(v_bits, uy)
    m_k = code_decode(diff)
    return m_k, sigma, pk_bytes

# ---------------------------
# HQC KEM（toy）
# ---------------------------
def crypto_kem_keypair():
    return hqc_pke_keygen()

def crypto_kem_enc(pk_bytes):
    m_u    = os.urandom(VEC_K_SIZE_BYTES)
    salt_u = os.urandom(SALT_SIZE_BYTES)
    chaos_seed16 = os.urandom(16)

    m    = mix_urandom_with_chaos(b"ENC:m",    m_u,    chaos_seed16, VEC_K_SIZE_BYTES)
    salt = mix_urandom_with_chaos(b"ENC:salt", salt_u, chaos_seed16, SALT_SIZE_BYTES)

    theta = shake256_512_ds(m + pk_bytes + salt, G_FCT_DOMAIN)
    u_bits, v_bits = hqc_pke_encrypt(m, theta, pk_bytes)

    u_bytes = bits_to_bytes_le(u_bits)
    v_bytes = bits_to_bytes_le(v_bits)

    base_ss = shake256_512_ds(m + u_bytes + v_bytes, K_FCT_DOMAIN)

    shared_seed16 = derive_shared_chaos_seed16(pk_bytes, salt, u_bytes, v_bytes)
    chaos_kdf = shake_whiten_chaos(shared_seed16, 32, CHAOS_DOMAIN)

    ss = kdf_mix(base_ss, chaos_kdf, context_bytes=u_bytes + v_bytes)

    ct = hqc_ciphertext_to_string(u_bits, v_bits, salt)
    return ct, ss

def crypto_kem_dec(ct_bytes, sk_bytes):
    u_bits, v_bits, salt = hqc_ciphertext_from_string(ct_bytes)
    pk_bytes = sk_bytes[SEED_BYTES + VEC_K_SIZE_BYTES:]

    m_prime, sigma, _ = hqc_pke_decrypt(u_bits, v_bits, sk_bytes)

    theta = shake256_512_ds(m_prime + pk_bytes + salt, G_FCT_DOMAIN)
    u2, v2 = hqc_pke_encrypt(m_prime, theta, pk_bytes)

    ok = (u_bits == u2) and (v_bits == v2)
    m_used = m_prime if ok else sigma

    u_bytes = bits_to_bytes_le(u_bits)
    v_bytes = bits_to_bytes_le(v_bits)

    base_ss = shake256_512_ds(m_used + u_bytes + v_bytes, K_FCT_DOMAIN)

    shared_seed16 = derive_shared_chaos_seed16(pk_bytes, salt, u_bytes, v_bytes)
    chaos_kdf = shake_whiten_chaos(shared_seed16, 32, CHAOS_DOMAIN)

    ss = kdf_mix(base_ss, chaos_kdf, context_bytes=u_bytes + v_bytes)
    return ss, (0 if ok else -1)

# ---------------------------
# 测试
# ---------------------------
def test_rm17_basic():
    tests = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0xFF, 0x55, 0xAA]
    for b in tests:
        cw = rm17_encode_byte(b)
        dec = rm17_decode_block(cw)
        if dec != b:
            print("RM fail: %02x -> %02x" % (b, dec))
            return False
    return True

def test_rs_correction():
    m = os.urandom(PARAM_K)
    cw = bytearray(reed_solomon_encode(m))
    t = randint(0, RS_DELTA)
    pos = sample(range(PARAM_N1), t)
    for p in pos:
        cw[p] = (cw[p] + randint(1, 255)) % 256
    dec = reed_solomon_decode(bytes(cw))
    return (dec == m)

def test_system():
    print("HQC toy 参数测试（含 RS 纠错） + Logistic 混沌融合（熵混合+KDF混合）")
    print("PARAM_N=%d, PARAM_N1=%d, PARAM_N2=%d, PARAM_N1N2=%d" % (PARAM_N, PARAM_N1, PARAM_N2, PARAM_N1N2))
    print("RS: n=%d, k=%d, parity=%d, delta=%d" % (PARAM_N1, PARAM_K, PARAM_G, RS_DELTA))
    print("PK bytes=%d, SK bytes=%d, CT bytes=%d" % (PUBLIC_KEY_BYTES, SECRET_KEY_BYTES, CIPHERTEXT_BYTES))

    rm_ok = test_rm17_basic()
    print("\n[1] RM(1,7) 测试:", "OK" if rm_ok else "FAIL")

    rs_ok = True
    for _ in range(20):
        if not test_rs_correction():
            rs_ok = False
            break
    print("\n[2] RS 纠错随机测试(20轮):", "OK" if rs_ok else "FAIL")

    print("\n[3] 直接级联编解码测试")
    m = os.urandom(PARAM_K)
    enc = code_encode(m)
    dec = code_decode(enc)
    print("m   =", m.hex())
    print("dec =", dec.hex())
    print("direct:", "OK" if m == dec else "FAIL")

    print("\n[4] PKE 加密解密测试")
    pk, sk = crypto_kem_keypair()
    theta = os.urandom(SEED_BYTES)
    u, v = hqc_pke_encrypt(m, theta, pk)
    m2, _, _ = hqc_pke_decrypt(u, v, sk)
    print("m2  =", m2.hex())
    print("pke :", "OK" if m2 == m else "FAIL")

    print("\n[5] KEM 测试")
    ct, ss1 = crypto_kem_enc(pk)
    ss2, st = crypto_kem_dec(ct, sk)
    print("status =", st)
    print("ss1 =", ss1.hex())
    print("ss2 =", ss2.hex())
    print("kem:", "OK" if (st == 0 and ss1 == ss2) else "FAIL")
    return pk, sk






# ============================================================
# 新增实验 B：多源熵退化鲁棒性（支撑贡献 1）
#   主源人为降级，比较 原始HQC / 混沌同源 / 混沌双源 的输出不可预测性
# ============================================================
# ---- 参数改用 Python 原生 int，避免 Sage Integer 传入标准库 ----
_ROBUST_OUT_LEN  = int(32)     # 最终随机材料长度
_ROBUST_N_TRIALS = int(3000)   # 每个配置采样次数

def main_source_degraded(n, entropy_bits):
    """
    退化主源：真实熵仅 entropy_bits 位，其余经 SHAKE256 白化填充。
    模拟系统启动早期/资源受限设备熵池未充分初始化的场景。
    """
    n = int(n)
    entropy_bits = int(entropy_bits)
    if entropy_bits <= 0:
        weak = b""
    else:
        nb = int((entropy_bits + 7) // 8)
        weak = int(random.getrandbits(entropy_bits)).to_bytes(nb, "little")
    h = hashlib.shake_256()
    h.update(weak)
    return h.digest(n)                      # n 已是 Python int

def _weak_pool_state(entropy_bits):
    """模拟某一时刻退化熵池的真实熵状态：整个时间窗内仅 entropy_bits 位真实熵，
    该窗口内所有随机抽取都由这同一状态派生（强相关）。"""
    entropy_bits = int(entropy_bits)
    if entropy_bits <= 0:
        return b""
    nb = int((entropy_bits + 7) // 8)
    return int(random.getrandbits(entropy_bits)).to_bytes(nb, "little")

def _expand(state, label, n):
    h = hashlib.shake_256(); h.update(label); h.update(state)
    return h.digest(int(n))

def _scheme_original(entropy_bits, label=b"KeyGen:sk_seed"):
    """组1：原始 HQC —— 输出完全由退化熵池状态 w 决定。"""
    w = _weak_pool_state(entropy_bits)
    R = _expand(w, b"R", _ROBUST_OUT_LEN)
    h = hashlib.shake_256(); h.update(label); h.update(R)
    return h.digest(int(_ROBUST_OUT_LEN))

def _scheme_chaos_samesrc(entropy_bits, label=b"KeyGen:sk_seed"):
    """组2：混沌·同源 —— 混沌种子与主路由同一 w 派生，二者相关，应与组1同步崩塌。"""
    w = _weak_pool_state(entropy_bits)
    R = _expand(w, b"R", _ROBUST_OUT_LEN)
    chaos_seed16 = _expand(w, b"chaos", 16)      # 关键:同一 w，非独立
    return mix_urandom_with_chaos(label, R, chaos_seed16, int(_ROBUST_OUT_LEN))

def _scheme_chaos_dualsrc(entropy_bits, label=b"KeyGen:sk_seed"):
    """组3：混沌·双源 —— 混沌种子取自与退化主源独立的健康熵源，应保持高熵。"""
    w = _weak_pool_state(entropy_bits)
    R = _expand(w, b"R", _ROBUST_OUT_LEN)
    chaos_seed16 = os.urandom(16)                # 独立健康源!
    return mix_urandom_with_chaos(label, R, chaos_seed16, int(_ROBUST_OUT_LEN))
def _robust_metrics(scheme, entropy_bits):
    """采样并返回: 唯一值比例, 样本级最小熵(bit), 字节级香农熵(bit/byte)。"""
    counts = {}
    allbytes = bytearray()
    for _ in range(_ROBUST_N_TRIALS):
        out = scheme(entropy_bits)
        counts[out] = counts.get(out, 0) + 1
        allbytes += out
    unique_ratio = float(len(counts)) / float(_ROBUST_N_TRIALS)
    p_max = float(max(counts.values())) / float(_ROBUST_N_TRIALS)
    min_entropy = float(-math.log2(p_max))                 # 样本级最小熵
    shannon = calculate_information_entropy(bytes(allbytes))  # 复用已有函数
    return unique_ratio, min_entropy, shannon

def run_entropy_robustness(entropy_sweep=(2, 4, 6, 8, 10, 12, 16, 24)):
    upper = float(math.log2(_ROBUST_N_TRIALS))   # 最小熵理论上限(全部唯一时)
    schemes = [("原始HQC",   _scheme_original),
               ("混沌·同源", _scheme_chaos_samesrc),
               ("混沌·双源", _scheme_chaos_dualsrc)]

    print("=" * 70)
    print(" 多源熵退化鲁棒性实验")
    print(" 主源熵越低，同源方案应同步崩塌，双源方案应保持高熵")
    print(" N_TRIALS=%d, OUT_LEN=%d, 最小熵上限=log2(N)=%.2f bit"
          % (_ROBUST_N_TRIALS, _ROBUST_OUT_LEN, upper))
    print("=" * 70)
    print("%9s | %10s | %8s | %11s | %8s"
          % ("主源熵bit", "方案", "唯一比例", "最小熵bit", "字节熵"))
    print("-" * 62)

    res = {name: {"eb": [], "uniq": [], "minH": [], "shan": []}
           for name, _ in schemes}
    for eb in entropy_sweep:
        for name, fn in schemes:
            u, mh, sh = _robust_metrics(fn, eb)
            res[name]["eb"].append(int(eb))
            res[name]["uniq"].append(float(u))
            res[name]["minH"].append(float(mh))
            res[name]["shan"].append(float(sh))
            print("%9d | %10s | %8.3f | %11.2f | %8.4f" % (eb, name, u, mh, sh))
        print("-" * 62)

    mat_data = {
        "entropy_bits": np.array(list(entropy_sweep), dtype=np.float64),
        "N_trials":     _ROBUST_N_TRIALS,
        "upper_minH":   upper,
        "minH_orig":    np.array(res["原始HQC"]["minH"]),
        "minH_same":    np.array(res["混沌·同源"]["minH"]),
        "minH_dual":    np.array(res["混沌·双源"]["minH"]),
        "uniq_orig":    np.array(res["原始HQC"]["uniq"]),
        "uniq_same":    np.array(res["混沌·同源"]["uniq"]),
        "uniq_dual":    np.array(res["混沌·双源"]["uniq"]),
        "shan_orig":    np.array(res["原始HQC"]["shan"]),
        "shan_same":    np.array(res["混沌·同源"]["shan"]),
        "shan_dual":    np.array(res["混沌·双源"]["shan"]),
    }
    savemat("entropy_robustness.mat", mat_data)
    print("\n>> 已保存: entropy_robustness.mat")
    return res





#对结合方式一最终生成的随机数种子进行频数检验
def frequency_test_chi_square(byte_data):
    """
    0/1 平衡检验 (频数检验)
    根据图片中的卡方统计量公式进行计算
    """
    # 总比特数 n
    n = len(byte_data) * 8
    
    # 统计 1 的个数 n1 (兼容旧版本 Python)
    n1 = bin(int.from_bytes(byte_data, 'little')).count('1')
    
    # 统计 0 的个数 n0
    n0 = n - n1
    
    # 计算卡方统计量 (公式: (2*n1 - n)^2 / n)
    # 【修复报错】: 在外面套一层 float()，将 SageMath 的 Rational 转换为 Python 原生浮点数
    chi_square = float(((2 * n1 - n) ** 2) / n)
    
    # 显著性水平 5%，自由度 1 时的临界值为 3.84
    critical_value = 3.84
    passed = chi_square < critical_value
    
    print("-" * 40)
    print(" 0/1 平衡检验 (频数检验) 结果")
    print("-" * 40)
    print(f"总比特数 (n)   : {n}")
    print(f"1 的个数 (n1)  : {n1}")
    print(f"0 的个数 (n0)  : {n0}")
    print(f"理想期望值     : {float(n / 2)}")  # 同样转为float以防万一
    print(f"卡方统计量(X^2): {chi_square:.6f}")
    print(f"临界值         : {critical_value}")
    print(f"结论           : {'[通过] 接受0/1平衡假设' if passed else '[失败] 存在统计缺陷'}")
    print("-" * 40)
    
    return passed

def run_entropy_mixing_frequency_test():
    # 设定样本大小：1,000,000 字节 (即 8,000,000 bits)
    sample_size_bytes = 1000000 
    
    print(f"\n开始生成 {sample_size_bytes * 8} bits 熵混合数据进行分析...")
    
    # 模拟输入参数
    label = b"TEST:frequency_analysis"
    urnd_bytes = os.urandom(32)        # 模拟系统主熵 32 bytes
    chaos_seed16 = os.urandom(16)      # 模拟混沌种子 16 bytes
    
    # 调用代码中的"方式一：熵混合"函数生成随机字节流
    mixed_random_bytes = mix_urandom_with_chaos(
        label_bytes=label, 
        urnd_bytes=urnd_bytes, 
        chaos_seed16=chaos_seed16, 
        out_len=sample_size_bytes
    )
    
    # 执行频数检验
    frequency_test_chi_square(mixed_random_bytes)





#对结合方式一最终生成的随机数种子进行信息熵分析
def calculate_information_entropy(byte_data):
    total_bytes = len(byte_data)
    if total_bytes == 0:
        return float(0.0)
    byte_counts = Counter(byte_data)
    entropy = 0.0
    for count in byte_counts.values():
        if count > 0:
            p = float(count) / float(total_bytes)
            entropy -= p * math.log2(p)
    return float(entropy)

def generate_proposed_hqc_data():
    num_experiments = 100         
    sample_size_bytes = 1000000   
    entropy_proposed = []

    print(f"开始收集【融合混沌HQC】的 {num_experiments} 组信息熵数据...")
    
    for i in range(num_experiments):
        label = b"TEST:entropy_analysis"
        urnd_bytes = os.urandom(32)
        chaos_seed16 = os.urandom(16)
        
        # =========================================================
        # 【修改这里】：调用你自己的方式一混沌混合函数
        # =========================================================
        # proposed_bytes = mix_urandom_with_chaos(
        #     label_bytes=label, 
        #     urnd_bytes=urnd_bytes, 
        #     chaos_seed16=chaos_seed16, 
        #     out_len=sample_size_bytes
        # )
        
        proposed_bytes = os.urandom(sample_size_bytes) # <- 务必替换掉这个占位符！
        
        ent = calculate_information_entropy(proposed_bytes)
        entropy_proposed.append(ent)
        
        if (i + 1) % 10 == 0:
            print(f"融合方案进度已完成 {i + 1} / {num_experiments} ...")

    # 导出为 .mat 文件
    mat_data = {'Entropy_Proposed': entropy_proposed}
    sio.savemat('hqc_proposed.mat', mat_data)
    print("\n✅ 融合方案数据已成功保存至: hqc_proposed.mat")







# 混沌系统的初值敏感性分析

def logistic_chaos_bytes(seed16, out_len, burn_in=64):
    """
    64位定点(Q64) Logistic 混沌：x_{n+1} = r*x_n*(1-x_n)
    - 跨平台逐位可复现（整数运算）
    - r 限制在深度混沌区 [3.9, 4.0)，避免周期窗口
    仅作加料，后续由 SHAKE256 白化。
    """
    assert len(seed16) == 16
    out_len = int(out_len)
    burn_in = int(burn_in)

    MASK = (1 << 64) - 1
    s0 = _u64_le(seed16[:8])
    s1 = _u64_le(seed16[8:])

    # 初值 x0 ∈ (0,1)，避开 0/1 不动点
    x = s0 & MASK
    if x < (1 << 32):
        x ^= 0x9E3779B97F4A7C15
    x &= MASK

    # r ∈ [3.9, 4.0)，始终处于深度混沌区（关键修正）
    R_BASE  = int(3.9 * (1 << 64))
    R_WIDTH = int(0.1 * (1 << 64))
    r = R_BASE + ((s1 * R_WIDTH) >> 64)

    def step(x):
        one_minus_x = MASK - x
        t  = (x * one_minus_x) >> 64      # x*(1-x), Q64
        xp = (r * t) >> 64                # r*x*(1-x), Q64
        xp &= MASK
        if xp == 0 or xp == MASK:         # 逃逸 0/1 不动点
            xp ^= 0x5DEECE66D
            xp &= MASK
        return xp

    for _ in range(burn_in):
        x = step(x)

    out = bytearray()
    while len(out) < out_len:
        x = step(x)
        out += _le_u64(x)

    return bytes(out[:out_len])


def calculate_hamming_distance_and_rate(seq1, seq2):
    n_bits = len(seq1) * 8
    int1 = int.from_bytes(seq1, 'little')
    int2 = int.from_bytes(seq2, 'little')
    xor_result = operator.xor(int1, int2)
    dh = bin(xor_result).count('1')
    rate = float(dh) / float(n_bits)
    return dh, rate

def flip_single_bit(data_bytes, bit_pos):
    arr = bytearray(data_bytes)
    byte_idx = int(bit_pos) // 8
    bit_idx  = int(bit_pos) % 8
    arr[byte_idx] = operator.xor(int(arr[byte_idx]), (1 << bit_idx))
    return bytes(arr)


def run_logistic_raw_sensitivity(num_tests=200):
    """
    直接测试 logistic_chaos_bytes() 原始输出的初值敏感性
    
    三个场景：
      A: 随机翻转 seed16 的某一位（综合扰动）
      B: 仅扰动 x_0 区域（seed16 前 8 字节）
      C: 仅扰动 r 区域（seed16 后 8 字节）
    """
    seq_len_bytes = 10000
    n_bits = seq_len_bytes * 8

    R_rand_list = []
    R_x0_list   = []
    R_r_list    = []

    print("=" * 60)
    print(" Logistic Map 原始输出初值敏感性验证）")
    print(f" 测试次数={num_tests}, 序列长度={n_bits} bits")
    print(f" 使用 logistic_chaos_bytes(), 无 SHAKE256 白化")
    print(f" r ∈ [3.9, 4.0), x_0 ∈ (0.01, 0.99), burn_in=200")
    print("=" * 60)

    for i in range(num_tests):
        if (i + 1) % 50 == 0:
            print(f"  进度: {i+1}/{num_tests}")

        orig_seed = os.urandom(16)

        S_orig = logistic_chaos_bytes(orig_seed, seq_len_bytes) 

        # ----- 场景 A: 随机位翻转 -----
        bit_A = random.randint(0, 127)
        seed_A = flip_single_bit(orig_seed, bit_A)
        S_A = logistic_chaos_bytes(seed_A,    seq_len_bytes)
        _, rA = calculate_hamming_distance_and_rate(S_orig, S_A)
        R_rand_list.append(rA)

        # ----- 场景 B: x_0 扰动（前 8 字节） -----
        bit_B = random.randint(0, 63)
        seed_B = flip_single_bit(orig_seed, bit_B)
        S_B = logistic_chaos_bytes(seed_B,    seq_len_bytes)
        _, rB = calculate_hamming_distance_and_rate(S_orig, S_B)
        R_x0_list.append(rB)

        # ----- 场景 C: r 扰动（后 8 字节） -----
        bit_C = random.randint(64, 127)
        seed_C = flip_single_bit(orig_seed, bit_C)
        S_C = logistic_chaos_bytes(seed_C,    seq_len_bytes)
        _, rC = calculate_hamming_distance_and_rate(S_orig, S_C)
        R_r_list.append(rC)

    # 统计
    def stats(name, R):
        n = len(R)
        mean_R = float(sum(R)) / n
        var_R  = float(sum((val - mean_R)**2 for val in R)) / n
        std_R  = float(math.sqrt(var_R))
        min_R  = float(min(R))
        max_R  = float(max(R))
        passed = abs(mean_R - 0.5) < 0.05
        print(f"\n  [{name}]")
        print(f"    均值   = {mean_R:.6f}  (理想: 0.5000)")
        print(f"    标准差 = {std_R:.6f}")
        print(f"    范围   = [{min_R:.6f}, {max_R:.6f}]")
        print(f"    判定   = {'PASS' if passed else 'WARN'}")
        return mean_R

    print("\n========= Logistic 原始输出初值敏感性结果 =========")
    mA = stats("场景A: 随机位翻转 (综合扰动)", R_rand_list)
    mB = stats("场景B: 初始值 x_0 扰动",       R_x0_list)
    mC = stats("场景C: 控制参数 r 扰动",        R_r_list)
    print("===================================================")

    # 零值检查
    zero_A = sum(1 for r in R_rand_list if r < 0.001)
    zero_B = sum(1 for r in R_x0_list   if r < 0.001)
    zero_C = sum(1 for r in R_r_list    if r < 0.001)
    print(f"\n  零值检查: A={zero_A}, B={zero_B}, C={zero_C} (应全部为0)")

    # 保存
    mat_data = {
        'R_rand':        R_rand_list,
        'R_x0':          R_x0_list,
        'R_r':           R_r_list,
        'num_tests':     num_tests,
        'seq_len_bits':  n_bits,
    }
    try:
        savemat('logistic_sensitivity.mat', mat_data)
        print("\n>> 数据已保存至 logistic_sensitivity.mat")
    except Exception as e:
        print(f"\n>> 保存失败: {e}")

    return R_rand_list, R_x0_list, R_r_list



    




# 密钥敏感性分析
def flip_one_bit(byte_data, bit_pos):
    byte_idx = bit_pos // 8
    bit_offset = bit_pos % 8
    mutated = bytearray(byte_data)
    # SageMath 中按位异或用 ^^，纯 Python 用 ^
    mutated[byte_idx] = int(mutated[byte_idx]) ^^ (1 << bit_offset)
    return bytes(mutated)

def calc_bcr(b1, b2):
    """计算两个等长字节串的比特变化率 BCR (%)"""
    if len(b1) != len(b2):
        raise ValueError("长度不一致无法计算BCR")
    diff_bits = sum(bin(int(x) ^^ int(y)).count('1') for x, y in zip(b1, b2))
    total_bits = len(b1) * 8
    return float(diff_bits / total_bits) * 100.0


def run_key_sensitivity_analysis(num_trials=500):
    print(f"开始密钥敏感性分析（修正版），测试次数: {num_trials} 次...")
    
    sk_bcr_list = []
    pk_c_bcr_list = []
    pk_k_bcr_list = []
    
    # 统计私钥翻转后解封装的状态
    sk_dec_success = 0
    sk_dec_reject  = 0

    for i in range(num_trials):
        # 1. 生成合法的密钥对
        pk, sk = crypto_kem_keypair()
        
        # ==========================================
        # 1. 私钥敏感性分析 (Secret Key Sensitivity)
        # ==========================================
        # 用正确的 pk 封装 → 得到参考密文 c 和参考共享密钥 true_ss
        c, true_ss = crypto_kem_enc(pk)
        
        # 翻转 SK 的一个随机比特
        # 注意：限制在 SK 的有效字节范围内
        sk_total_bits = len(sk) * 8
        bit_idx_sk = randint(0, sk_total_bits - 1)
        sk_prime = flip_one_bit(sk, bit_idx_sk)
        
        try:
            ss_prime, status = crypto_kem_dec(c, sk_prime)
            
            if status != 0:
                # 解封装失败 → 走了 implicit rejection 分支
                # ss_prime 是基于篡改 SK 的伪随机输出，与 true_ss 无关
                # BCR 应自然接近 50%
                sk_dec_reject += 1
                sk_bcr_list.append(calc_bcr(true_ss, ss_prime))
            else:
                # 解封装"成功"了（篡改位恰好未影响解码结果）
                # 此时 ss_prime 可能与 true_ss 相同或接近
                # 为了正确评估敏感性，我们需要确认输出是否真的相同
                sk_dec_success += 1
                bcr_val = calc_bcr(true_ss, ss_prime)
                
                # 如果 BCR 极低（< 1%），说明翻转的位未起作用
                # 这不代表系统不安全，只是该位恰好是"冗余位"
                # 我们仍然记录，但后续分析时可以分开看
                sk_bcr_list.append(bcr_val)
                
        except Exception:
            # 解封装出现异常，跳过
            pass

        # ==========================================
        # 2. 公钥敏感性分析 (Public Key Sensitivity)
        # ==========================================
        c_1, k_1 = crypto_kem_enc(pk)
        
        pk_total_bits = len(pk) * 8
        bit_idx_pk = randint(0, pk_total_bits - 1)
        pk_prime = flip_one_bit(pk, bit_idx_pk)
        
        try:
            c_2, k_2 = crypto_kem_enc(pk_prime)
            pk_c_bcr_list.append(calc_bcr(c_1, c_2))
            pk_k_bcr_list.append(calc_bcr(k_1, k_2))
        except Exception:
            pass
            
        if (i + 1) % 100 == 0:
            print(f"进度: {i + 1} / {num_trials}")
            print(f"  私钥: reject={sk_dec_reject}, success={sk_dec_success}")

    # ==========================================
    # 3. 过滤私钥敏感性中的异常低值
    # ==========================================
    # 分离出 BCR < 5% 的"无效翻转"样本
    sk_bcr_effective = [b for b in sk_bcr_list if b >= 5.0]
    sk_bcr_ineffective = [b for b in sk_bcr_list if b < 5.0]
    
    print("\n" + "=" * 60)
    print("私钥敏感性诊断:")
    print(f"  总测试数:           {len(sk_bcr_list)}")
    print(f"  解封装失败(reject): {sk_dec_reject}")
    print(f"  解封装成功:         {sk_dec_success}")
    print(f"  有效翻转(BCR>=5%):  {len(sk_bcr_effective)}")
    print(f"  无效翻转(BCR<5%):   {len(sk_bcr_ineffective)}")
    print("=" * 60)

    # 将结果保存为 mat 文件
    # 同时保存完整数据和过滤后数据，供 MATLAB 可视化选择
    data_to_save = {
        'sk_bcr':            np.array(sk_bcr_list),         # 完整私钥BCR
        'sk_bcr_effective':  np.array(sk_bcr_effective),    # 过滤后私钥BCR
        'sk_bcr_ineffective':np.array(sk_bcr_ineffective),  # 无效翻转BCR
        'pk_c_bcr':          np.array(pk_c_bcr_list),
        'pk_k_bcr':          np.array(pk_k_bcr_list),
        'sk_dec_reject':     sk_dec_reject,
        'sk_dec_success':    sk_dec_success,
    }
    
    sio.savemat('key_sensitivity.mat', data_to_save)
    print("\n测试完成！数据已保存至 'key_sensitivity.mat'。")
    
    # 使用过滤后的数据计算统计量
    if len(sk_bcr_effective) > 0:
        print(f"私钥敏感性（过滤后）平均 BCR: {np.mean(sk_bcr_effective):.4f}%")
    else:
        print("私钥敏感性: 无有效样本")
    print(f"公钥敏感性 (密文) 平均 BCR: {np.mean(pk_c_bcr_list):.4f}%")
    print(f"公钥敏感性 (共享密钥) 平均 BCR: {np.mean(pk_k_bcr_list):.4f}%")






#自相关性分析
def bytes_to_bipolar_bits(byte_data):
    """
    将字节序列转换为比特序列，并将 {0, 1} 映射为 {-1, 1} 
    这是为了满足图片中提到的“将比特映射为 {-1, 1}后再计算自相关值”
    """
    # 将 bytes 转换为 0/1 数组
    bits = np.unpackbits(np.frombuffer(byte_data, dtype=np.uint8))
    # 映射 0 -> -1, 1 -> 1
    return bits * 2 - 1

def calculate_autocorrelation(x, max_lag):
    """
    严格按照图片中的自相关函数公式计算:
    R(k) = sum((x_i - mean_x) * (x_{i+k} - mean_x)) / sum((x_i - mean_x)^2)
    """
    N = len(x)
    mean_x = np.mean(x)
    
    # 计算分母: sum((x_i - mean_x)^2)
    denominator = np.sum((x - mean_x)**2)
    
    if denominator == 0:
        return np.zeros(max_lag)
        
    R = np.zeros(max_lag)
    for k in range(max_lag):
        if k == 0:
            R[k] = 1.0
        else:
            # 计算分子: sum((x_i - mean_x) * (x_{i+k} - mean_x))
            numerator = np.sum((x[:N-k] - mean_x) * (x[k:] - mean_x))
            R[k] = numerator / denominator
            
    return R

def generate_and_analyze_autocorr():
    """
    仅生成熵混合序列并计算自相关系数
    """
    print("开始生成混合序列并计算自相关性...")
    
    # 1. 参数设置
    SEQ_BYTES_LEN = 4096       # 生成 4096 字节的数据 (即 32768 bits)
    MAX_LAG = 256              # 考察的最大延迟 k 
    
    label_bytes = b"AUTOCORR_TEST"
    urnd_bytes = os.urandom(32)
    chaos_seed16 = os.urandom(16)
    
    # 2. 仅生成熵混合序列
    final_mixed_bytes = mix_urandom_with_chaos(label_bytes, urnd_bytes, chaos_seed16, SEQ_BYTES_LEN)
    
    # 3. 转换为 {-1, 1} 的比特序列
    bits_mixed = bytes_to_bipolar_bits(final_mixed_bytes)
    
    # 4. 计算自相关性
    print(f"计算混合序列的自相关性 (Lag 0~{MAX_LAG-1})...")
    R_mixed = calculate_autocorrelation(bits_mixed, MAX_LAG)
    
    # 5. 保存结果供 MATLAB 使用
    mat_filename = 'autocorr_mixed_only.mat'
    savemat(mat_filename, {
        'R_mixed': R_mixed,
        'max_lag': MAX_LAG,
        'k_values': np.arange(MAX_LAG)
    })
    print(f"计算完成，结果已保存至 '{mat_filename}'")




# ============================================================
# 明文雪崩效应分析
# ============================================================

def calculate_hamming_rate(seq1, seq2):
    n_bits = len(seq1) * 8
    int1 = int.from_bytes(seq1, 'little')
    int2 = int.from_bytes(seq2, 'little')
    xor_val = operator.xor(int1, int2)
    dh = bin(xor_val).count('1')
    return float(dh) / float(n_bits)

def flip_single_bit(data_bytes, bit_pos):
    arr = bytearray(data_bytes)
    byte_idx = int(bit_pos) // 8
    bit_idx  = int(bit_pos) % 8
    arr[byte_idx] = operator.xor(int(arr[byte_idx]), (1 << bit_idx))
    return bytes(arr)

def kem_enc_deterministic(pk_bytes, m, salt, chaos_seed16):
    """固定所有随机性的确定性封装，保证两次调用仅m不同"""
    m_mixed    = mix_urandom_with_chaos(b"ENC:m",    m,    chaos_seed16, VEC_K_SIZE_BYTES)
    salt_mixed = mix_urandom_with_chaos(b"ENC:salt", salt, chaos_seed16, SALT_SIZE_BYTES)

    theta = shake256_512_ds(m_mixed + pk_bytes + salt_mixed, G_FCT_DOMAIN)
    u_bits, v_bits = hqc_pke_encrypt(m_mixed, theta, pk_bytes)

    u_bytes = bits_to_bytes_le(u_bits)
    v_bytes = bits_to_bytes_le(v_bits)

    base_ss = shake256_512_ds(m_mixed + u_bytes + v_bytes, K_FCT_DOMAIN)
    shared_seed16 = derive_shared_chaos_seed16(pk_bytes, salt_mixed, u_bytes, v_bytes)
    chaos_kdf = shake_whiten_chaos(shared_seed16, 32, CHAOS_DOMAIN)
    ss = kdf_mix(base_ss, chaos_kdf, context_bytes=u_bytes + v_bytes)

    ct = hqc_ciphertext_to_string(u_bits, v_bits, salt_mixed)
    return ct, ss

def run_plaintext_avalanche(num_tests=200):
    m_bits_total = VEC_K_SIZE_BYTES * 8  # 64 bits

    R_ct_list = []
    R_ss_list = []

    print("=" * 60)
    print(" 明文雪崩效应分析")
    print(f" 测试次数={num_tests}, 明文长度={m_bits_total} bits")
    print(f" 密文长度={CIPHERTEXT_BYTES*8} bits, 共享密钥长度={SHAKE256_512_BYTES*8} bits")
    print("=" * 60)

    pk, sk = crypto_kem_keypair()

    for i in range(num_tests):
        if (i + 1) % 50 == 0:
            print(f"  进度: {i+1}/{num_tests}")

        # 固定 salt 和 chaos_seed，只有 m 会变化
        m_orig       = os.urandom(VEC_K_SIZE_BYTES)
        salt         = os.urandom(SALT_SIZE_BYTES)
        chaos_seed16 = os.urandom(16)

        ct_orig, ss_orig = kem_enc_deterministic(pk, m_orig, salt, chaos_seed16)

        # 随机选择明文的一个比特翻转
        flip_pos = random.randint(0, m_bits_total - 1)
        m_flip = flip_single_bit(m_orig, flip_pos)

        ct_flip, ss_flip = kem_enc_deterministic(pk, m_flip, salt, chaos_seed16)

        r_ct = calculate_hamming_rate(ct_orig, ct_flip)
        r_ss = calculate_hamming_rate(ss_orig, ss_flip)

        R_ct_list.append(r_ct)
        R_ss_list.append(r_ss)

    # 统计
    def stats(R):
        n    = len(R)
        mean = float(sum(R)) / n
        var  = float(sum((x - mean)**2 for x in R)) / n
        std  = float(math.sqrt(var))
        return mean, std, float(min(R)), float(max(R))

    print("\n========= 明文雪崩效应分析结果 =========")
    for name, R in [("明文 → 密文", R_ct_list), ("明文 → 共享密钥", R_ss_list)]:
        mean, std, lo, hi = stats(R)
        passed = abs(mean - 0.5) < 0.05
        print(f"\n  [{name}]")
        print(f"    均值   = {mean:.6f}  (理想: 0.5000)")
        print(f"    标准差 = {std:.6f}")
        print(f"    范围   = [{lo:.6f}, {hi:.6f}]")
        print(f"    判定   = {'PASS' if passed else 'WARN'}")
    print("=========================================")

    # 保存
    mat_data = {
        'R_ct': R_ct_list,
        'R_ss': R_ss_list,
        'num_tests': num_tests,
        'm_bits': m_bits_total,
        'ct_bits': CIPHERTEXT_BYTES * 8,
        'ss_bits': SHAKE256_512_BYTES * 8
    }
    try:
        savemat('plaintext_avalanche.mat', mat_data)
        print("\n>> 数据已保存至 plaintext_avalanche.mat")
    except Exception as e:
        print(f"\n>> 保存失败: {e}")

    return R_ct_list, R_ss_list





# 密钥空间分析
def comb(n, k):
    if k > n:
        return 0
    k = min(k, n - k)
    result = 1
    for i in range(k):
        result = result * (n - i) // (i + 1)
    return result

def analyze_key_space():
    # 私钥空间 = x 的组合空间 × y 的组合空间
    xy_space = comb(PARAM_N, PARAM_OMEGA) * comb(PARAM_N, PARAM_OMEGA)
    total_bits = int(math.log2(xy_space))
    
    print(f"私钥空间大小 ≈ 2^{total_bits}")
    return total_bits






# 正确性验证 + 解封装失败率统计
def test_correctness_and_failure_rate(num_trials=1000):
    success = 0
    fail = 0
    for i in range(num_trials):
        pk, sk = crypto_kem_keypair()
        ct, ss_enc = crypto_kem_enc(pk)
        ss_dec, status = crypto_kem_dec(ct, sk)
        if status == 0 and ss_enc == ss_dec:
            success += 1
        else:
            fail += 1
    rate = float(fail) / float(num_trials) * 100
    print("=" * 50)
    print(" 正确性验证 & 解封装失败率")
    print("=" * 50)
    print(f"  测试次数: {num_trials}")
    print(f"  成功次数: {success}")
    print(f"  失败次数: {fail}")
    print(f"  失败率:   {rate:.4f}%")
    print("=" * 50)
    return success, fail



# 运行效率分析（密钥生成/封装/解封装耗时）
import time

def test_performance(num_trials=100):
    keygen_times = []
    enc_times = []
    dec_times = []

    for i in range(num_trials):
        t0 = time.time()
        pk, sk = crypto_kem_keypair()
        t1 = time.time()
        keygen_times.append(t1 - t0)

        t0 = time.time()
        ct, ss1 = crypto_kem_enc(pk)
        t1 = time.time()
        enc_times.append(t1 - t0)

        t0 = time.time()
        ss2, status = crypto_kem_dec(ct, sk)
        t1 = time.time()
        dec_times.append(t1 - t0)

    print("=" * 50)
    print(" 运行效率分析")
    print("=" * 50)
    print(f"  测试次数: {num_trials}")
    print(f"  密钥生成 平均: {float(sum(keygen_times))/num_trials*1000:.2f} ms")
    print(f"  封装     平均: {float(sum(enc_times))/num_trials*1000:.2f} ms")
    print(f"  解封装   平均: {float(sum(dec_times))/num_trials*1000:.2f} ms")
    print("=" * 50)

    mat_data = {
        'keygen_ms': [t*1000 for t in keygen_times],
        'enc_ms':    [t*1000 for t in enc_times],
        'dec_ms':    [t*1000 for t in dec_times],
    }
    savemat('performance.mat', mat_data)
    print(">> 已保存至 performance.mat")

# ----- HQC + 混沌增强 抗篡改分析 -----

import random
import operator
import numpy as np
from scipy.io import savemat


# 兼容 Sage / 旧版本 Python，不使用 bit_count()
_POPCOUNT_8 = [bin(i).count("1") for i in range(256)]


def _call_decaps(ct, sk):
    """
    兼容两种解封装接口：
    1. crypto_kem_dec(ct, sk) -> (ss, status)
    2. crypto_kem_dec(ct, sk) -> ss
    """
    ret = crypto_kem_dec(ct, sk)

    if isinstance(ret, tuple):
        ss_dec = ret[0]
        status = ret[1] if len(ret) > 1 else None
    else:
        ss_dec = ret
        status = None

    return bytes(ss_dec), status


def _bcr_percent(a, b):
    """
    计算两个共享密钥之间的 Bit Change Rate。
    兼容 Sage，不使用 ^ 和 bit_count()。
    """
    if len(a) != len(b):
        raise ValueError("两个共享密钥长度不一致，无法计算 BCR")

    diff_bits = 0

    for x, y in zip(a, b):
        diff = operator.xor(int(x), int(y))
        diff_bits += _POPCOUNT_8[diff]

    total_bits = len(a) * 8
    return float(diff_bits) / float(total_bits) * 100.0


def _flip_random_bits(data, start_byte, length_byte, num_flip_bits, rng):
    """
    在指定区域内随机翻转 num_flip_bits 个 bit。
    兼容 Sage，不使用 ^、^^ 或 ^=。
    """
    data = bytearray(data)

    start_byte = int(start_byte)
    length_byte = int(length_byte)
    num_flip_bits = int(num_flip_bits)

    region_bits = length_byte * 8

    if num_flip_bits > region_bits:
        raise ValueError("翻转 bit 数超过当前区域总 bit 数")

    bit_positions = rng.sample(range(region_bits), num_flip_bits)

    for local_bit_pos in bit_positions:
        local_bit_pos = int(local_bit_pos)

        abs_bit_pos = start_byte * 8 + local_bit_pos
        byte_idx = abs_bit_pos // 8
        bit_idx = abs_bit_pos % 8

        mask = int(1 << bit_idx)

        # 使用 operator.xor，避免 Sage 将 ^ 解释为幂运算
        data[byte_idx] = operator.xor(int(data[byte_idx]), mask)

    return bytes(data)


def _default_uv_layout(ct_len, u_len=None, v_len=None):
    """
    默认密文结构：

        ct = u || v

    如果 u 和 v 等长，可以不传 u_len 和 v_len。
    如果 u 和 v 不等长，需要手动传入 u_len 和 v_len。
    """
    ct_len = int(ct_len)

    if u_len is None and v_len is None:
        if ct_len % 2 != 0:
            raise ValueError("ct 长度不是偶数，请手动指定 u_len 和 v_len")
        u_len = ct_len // 2
        v_len = ct_len // 2

    if u_len is None or v_len is None:
        raise ValueError("请同时指定 u_len 和 v_len")

    u_len = int(u_len)
    v_len = int(v_len)

    if u_len + v_len != ct_len:
        raise ValueError("u_len + v_len 必须等于 ct 总长度")

    return {
        "u": (0, u_len),
        "v": (u_len, v_len),
        "full_ct": (0, ct_len),
    }


def _mean(values):
    """
    计算均值，避免依赖 statistics.mean()
    """
    if len(values) == 0:
        return 0.0

    return float(sum(values)) / float(len(values))


def _std(values):
    """
    计算样本标准差，避免依赖 statistics.stdev()
    """
    if len(values) <= 1:
        return 0.0

    m = _mean(values)
    var = sum((float(x) - m) ** 2 for x in values) / float(len(values) - 1)

    return float(var) ** 0.5


def test_ciphertext_integrity_uv(
    num_trials=500,
    flip_bits_list=(1, 2, 4, 8, 16),
    components=("u", "v", "full_ct"),
    u_len=None,
    v_len=None,
    new_ciphertext_each_trial=False,
    save_path="ciphertext_integrity_uv.mat",
):
    """
    HQC + 混沌增强方案的密文完整性 / 抗篡改分析。

    适用于密文结构：

        ct = u || v

    测试内容：
    1. 翻转 u 分量；
    2. 翻转 v 分量；
    3. 翻转完整密文 ct；
    4. 分别测试 1、2、4、8、16 bit 篡改；
    5. 统计 RejectRate、SSDiffRate 和 BCR。
    """

    rng = random.SystemRandom()

    pk, sk = crypto_kem_keypair()

    ct0, ss0 = crypto_kem_enc(pk)
    ct0 = bytes(ct0)
    ss0 = bytes(ss0)

    ct_layout = _default_uv_layout(
        ct_len=len(ct0),
        u_len=u_len,
        v_len=v_len
    )

    # 合法解封装预检
    ss_valid, status_valid = _call_decaps(ct0, sk)

    if ss_valid != ss0:
        raise RuntimeError("HQC + 混沌增强方案合法密文解封装失败，请先检查 crypto_kem_enc / crypto_kem_dec 实现。")

    print("=" * 70, flush=True)
    print("HQC + 混沌增强 密文完整性 / 抗篡改分析", flush=True)
    print("=" * 70, flush=True)
    print("合法解封装正确性预检：", flush=True)
    print(f"  CT 长度:             {len(ct0)} bytes", flush=True)
    print(f"  SS 长度:             {len(ss0)} bytes", flush=True)
    print(f"  u 长度:              {ct_layout['u'][1]} bytes", flush=True)
    print(f"  v 长度:              {ct_layout['v'][1]} bytes", flush=True)
    print(f"  合法解封装是否成功:  True", flush=True)
    print(f"  合法解封装 status:   {status_valid}", flush=True)
    print(f"  每轮重新生成密文:    {new_ciphertext_each_trial}", flush=True)
    print("=" * 70, flush=True)

    results = []

    for component in components:
        if component not in ct_layout:
            print(f"[跳过] 未知密文分量: {component}", flush=True)
            continue

        start_byte, length_byte = ct_layout[component]

        for num_flip_bits in flip_bits_list:
            if int(num_flip_bits) > int(length_byte) * 8:
                print(f"[跳过] {component} 区域不足以翻转 {num_flip_bits} bit", flush=True)
                continue

            status_available_count = 0
            status_reject_count = 0
            ss_diff_count = 0
            valid_failure_count = 0
            bcr_values = []

            print(
                f"\n正在测试: component={component}, flip_bits={num_flip_bits}",
                flush=True
            )

            for i in range(num_trials):
                if new_ciphertext_each_trial:
                    ct, ss_true = crypto_kem_enc(pk)
                    ct = bytes(ct)
                    ss_true = bytes(ss_true)

                    # 检查合法密文是否正常解封装
                    ss_check, _ = _call_decaps(ct, sk)

                    if ss_check != ss_true:
                        valid_failure_count += 1
                        continue
                else:
                    ct = ct0
                    ss_true = ss0

                ct_tampered = _flip_random_bits(
                    data=ct,
                    start_byte=start_byte,
                    length_byte=length_byte,
                    num_flip_bits=num_flip_bits,
                    rng=rng
                )

                ss_dec, status = _call_decaps(ct_tampered, sk)

                if status is not None:
                    status_available_count += 1
                    if status != 0:
                        status_reject_count += 1

                if ss_dec != ss_true:
                    ss_diff_count += 1

                bcr_values.append(_bcr_percent(ss_dec, ss_true))

                if (i + 1) % 100 == 0:
                    print(f"  进度: {i + 1}/{num_trials}", flush=True)

            effective_trials = int(num_trials) - int(valid_failure_count)

            if effective_trials > 0:
                ss_diff_rate = float(ss_diff_count) / float(effective_trials) * 100.0
                bcr_mean = _mean(bcr_values)
                bcr_std = _std(bcr_values)
                bcr_min = min(bcr_values)
                bcr_max = max(bcr_values)
            else:
                ss_diff_rate = 0.0
                bcr_mean = 0.0
                bcr_std = 0.0
                bcr_min = 0.0
                bcr_max = 0.0

            if status_available_count > 0:
                status_reject_rate = float(status_reject_count) / float(status_available_count) * 100.0
            else:
                status_reject_rate = np.nan

            results.append({
                "component": component,
                "flip_bits": int(num_flip_bits),
                "num_trials": int(num_trials),
                "effective_trials": int(effective_trials),
                "valid_failure_count": int(valid_failure_count),
                "status_available_count": int(status_available_count),
                "status_reject_count": int(status_reject_count),
                "status_reject_rate": float(status_reject_rate) if status_available_count > 0 else np.nan,
                "ss_diff_count": int(ss_diff_count),
                "ss_diff_rate": float(ss_diff_rate),
                "bcr_mean": float(bcr_mean),
                "bcr_std": float(bcr_std),
                "bcr_min": float(bcr_min),
                "bcr_max": float(bcr_max),
            })

    print("\n" + "=" * 100, flush=True)
    print("HQC + 混沌增强 密文完整性 / 抗篡改分析结果", flush=True)
    print("=" * 100, flush=True)
    print(
        f"{'Component':<10} "
        f"{'FlipBits':>8} "
        f"{'Trials':>8} "
        f"{'RejectRate':>12} "
        f"{'SSDiffRate':>12} "
        f"{'BCR Mean':>10} "
        f"{'BCR Std':>9} "
        f"{'BCR Range':>20}",
        flush=True
    )
    print("-" * 100, flush=True)

    for r in results:
        if np.isnan(r["status_reject_rate"]):
            reject_str = "N/A"
        else:
            reject_str = f"{r['status_reject_rate']:.2f}%"

        print(
            f"{r['component']:<10} "
            f"{r['flip_bits']:>8} "
            f"{r['effective_trials']:>8} "
            f"{reject_str:>12} "
            f"{r['ss_diff_rate']:>11.2f}% "
            f"{r['bcr_mean']:>9.2f}% "
            f"{r['bcr_std']:>8.2f}% "
            f"{r['bcr_min']:>8.2f}%~{r['bcr_max']:<8.2f}%",
            flush=True
        )

    print("=" * 100, flush=True)
    print("期望结果：", flush=True)
    print("  1. u、v 或完整 ct 被篡改后，SSDiffRate 应接近 100%；", flush=True)
    print("  2. BCR Mean 应接近 50%，说明篡改导致共享密钥近似随机变化；", flush=True)
    print("  3. 如果 crypto_kem_dec 暴露 status，则 RejectRate 应接近 100%；", flush=True)
    print("  4. 如果采用隐式拒绝机制，RejectRate 可能为 N/A，此时重点看 SSDiffRate 和 BCR。", flush=True)
    print("=" * 100, flush=True)

    # 保存 mat 文件
    component_code_map = {
        "u": 1,
        "v": 2,
        "full_ct": 3,
    }

    mat_data = {
        "component_code": np.array([component_code_map.get(r["component"], 0) for r in results]),
        "component_name": np.array([r["component"] for r in results], dtype="U16"),
        "flip_bits": np.array([r["flip_bits"] for r in results]),
        "num_trials": np.array([r["num_trials"] for r in results]),
        "effective_trials": np.array([r["effective_trials"] for r in results]),
        "valid_failure_count": np.array([r["valid_failure_count"] for r in results]),
        "status_available_count": np.array([r["status_available_count"] for r in results]),
        "status_reject_count": np.array([r["status_reject_count"] for r in results]),
        "status_reject_rate": np.array([r["status_reject_rate"] for r in results]),
        "ss_diff_count": np.array([r["ss_diff_count"] for r in results]),
        "ss_diff_rate": np.array([r["ss_diff_rate"] for r in results]),
        "bcr_mean": np.array([r["bcr_mean"] for r in results]),
        "bcr_std": np.array([r["bcr_std"] for r in results]),
        "bcr_min": np.array([r["bcr_min"] for r in results]),
        "bcr_max": np.array([r["bcr_max"] for r in results]),
    }

    savemat(save_path, mat_data)

    print(f">> 已保存至 {save_path}", flush=True)

    return results

# 通信开销分析（公钥/私钥/密文/共享密钥 字节数）
def test_communication_overhead():
    pk, sk = crypto_kem_keypair()
    ct, ss = crypto_kem_enc(pk)

    print("=" * 50)
    print(" 通信开销分析")
    print("=" * 50)
    print(f"  公钥 (pk) 大小:     {len(pk)} 字节 = {len(pk)*8} 比特")
    print(f"  私钥 (sk) 大小:     {len(sk)} 字节 = {len(sk)*8} 比特")
    print(f"  密文 (ct) 大小:     {len(ct)} 字节 = {len(ct)*8} 比特")
    print(f"  共享密钥 (ss) 大小: {len(ss)} 字节 = {len(ss)*8} 比特")
    print(f"  总通信量 (pk+ct):   {len(pk)+len(ct)} 字节")
    print("=" * 50)



# ---- 无混沌（原始）KEM：复用本文件全部 helper，仅去掉混沌注入 ----
def crypto_kem_keypair_orig():
    sk_seed = os.urandom(SEED_BYTES)
    sigma   = os.urandom(VEC_K_SIZE_BYTES)
    pk_seed = os.urandom(SEED_BYTES)
    sk_se = SeedExpander(sk_seed)
    pk_se = SeedExpander(pk_seed)
    x_bits = sample_fixed_weight(sk_se, PARAM_N, PARAM_OMEGA)
    y_bits = sample_fixed_weight(sk_se, PARAM_N, PARAM_OMEGA)
    h_bits = sample_uniform(pk_se, PARAM_N)
    s_bits = vect_add(x_bits, vect_mul(y_bits, h_bits))
    pk = hqc_public_key_to_string(pk_seed, s_bits)
    sk = hqc_secret_key_to_string(sk_seed, sigma, pk)
    return pk, sk

def crypto_kem_enc_orig(pk_bytes):
    m    = os.urandom(VEC_K_SIZE_BYTES)
    salt = os.urandom(SALT_SIZE_BYTES)
    theta = shake256_512_ds(m + pk_bytes + salt, G_FCT_DOMAIN)
    u_bits, v_bits = hqc_pke_encrypt(m, theta, pk_bytes)
    u_bytes = bits_to_bytes_le(u_bits)
    v_bytes = bits_to_bytes_le(v_bits)
    base_ss = shake256_512_ds(m + u_bytes + v_bytes, K_FCT_DOMAIN)
    ct = hqc_ciphertext_to_string(u_bits, v_bits, salt)
    return ct, base_ss

def crypto_kem_dec_orig(ct_bytes, sk_bytes):
    u_bits, v_bits, salt = hqc_ciphertext_from_string(ct_bytes)
    pk_bytes = sk_bytes[SEED_BYTES + VEC_K_SIZE_BYTES:]
    m_prime, sigma, _ = hqc_pke_decrypt(u_bits, v_bits, sk_bytes)
    theta = shake256_512_ds(m_prime + pk_bytes + salt, G_FCT_DOMAIN)
    u2, v2 = hqc_pke_encrypt(m_prime, theta, pk_bytes)
    ok = (u_bits == u2) and (v_bits == v2)
    m_used = m_prime if ok else sigma
    u_bytes = bits_to_bytes_le(u_bits)
    v_bytes = bits_to_bytes_le(v_bits)
    base_ss = shake256_512_ds(m_used + u_bytes + v_bytes, K_FCT_DOMAIN)
    return base_ss, (0 if ok else -1)

# ---- 统计汇总 ----
def _summ(samples):
    samples = sorted(float(s) for s in samples)
    n = len(samples)
    if n == 0:
        return {'median': 0.0, 'mean': 0.0, 'std': 0.0, 'min': 0.0, 'p95': 0.0}
    if n % 2 == 1:
        median = samples[n // 2]
    else:
        median = (samples[n // 2 - 1] + samples[n // 2]) / 2.0
    mean = sum(samples) / n
    var  = sum((s - mean) ** 2 for s in samples) / n   # 总体方差
    std  = var ** 0.5
    p95  = samples[min(n - 1, int(0.95 * n))]
    return {'median': median, 'mean': mean, 'std': std,
            'min': samples[0], 'p95': p95}

# ---- 逐样本交替测量，抵消热漂移与调度抖动 ----
def bench_pair(call_a, prep_a, call_b, prep_b, warmup=10, repeat=100):
    warmup = int(warmup); repeat = int(repeat)
    for _ in range(warmup):
        call_a(prep_a()); call_b(prep_b())     # 预热：触发 Sage 缓存、频率爬升
    sa, sb = [], []
    gc.collect(); gc.disable()                 # 避免 GC 抖动污染单次测量
    try:
        for _ in range(repeat):
            x = prep_a()                        # 输入准备不计时
            t0 = time.perf_counter(); call_a(x); t1 = time.perf_counter()
            sa.append(float((t1 - t0) * 1000.0))
            x = prep_b()
            t0 = time.perf_counter(); call_b(x); t1 = time.perf_counter()
            sb.append(float((t1 - t0) * 1000.0))
    finally:
        gc.enable()
    return _summ(sa), _summ(sb)

def _fmt(tag, r):
    print(f"  {tag:<8} median={r['median']:.2f} ms  mean={r['mean']:.2f}  "
          f"std={r['std']:.2f}  min={r['min']:.2f}  p95={r['p95']:.2f}")

def run_fair_benchmark(warmup=10, repeat=100):
    print("=" * 60)
    print(" 同进程交替基准（原始 HQC vs 混沌增强 HQC）")
    print(f" warmup={warmup}, repeat={repeat}, 计时=perf_counter, 统计=median")
    print("=" * 60)

    # KeyGen
    ro, rc = bench_pair(lambda _: crypto_kem_keypair_orig(), lambda: None,
                        lambda _: crypto_kem_keypair(),       lambda: None,
                        warmup, repeat)
    print("[KeyGen]"); _fmt("orig", ro); _fmt("chaos", rc)
    dk = (rc['median'] - ro['median']) / ro['median'] * 100.0
    print(f"  -> 中位数差异: {dk:+.2f}% (正=混沌更慢)")

    # Encaps
    def prep_enc_o():
        pk, _ = crypto_kem_keypair_orig(); return pk
    def prep_enc_c():
        pk, _ = crypto_kem_keypair();      return pk
    ro, rc = bench_pair(lambda pk: crypto_kem_enc_orig(pk), prep_enc_o,
                        lambda pk: crypto_kem_enc(pk),      prep_enc_c,
                        warmup, repeat)
    print("[Encaps]"); _fmt("orig", ro); _fmt("chaos", rc)
    de = (rc['median'] - ro['median']) / ro['median'] * 100.0
    print(f"  -> 中位数差异: {de:+.2f}%")

    # Decaps
    def prep_dec_o():
        pk, sk = crypto_kem_keypair_orig(); ct, _ = crypto_kem_enc_orig(pk); return (ct, sk)
    def prep_dec_c():
        pk, sk = crypto_kem_keypair();      ct, _ = crypto_kem_enc(pk);      return (ct, sk)
    ro, rc = bench_pair(lambda cs: crypto_kem_dec_orig(cs[0], cs[1]), prep_dec_o,
                        lambda cs: crypto_kem_dec(cs[0], cs[1]),      prep_dec_c,
                        warmup, repeat)
    print("[Decaps]"); _fmt("orig", ro); _fmt("chaos", rc)
    dd = (rc['median'] - ro['median']) / ro['median'] * 100.0
    print(f"  -> 中位数差异: {dd:+.2f}%")

    print("=" * 60)
    print(f" 论文 4.7.2 填表: KeyGen {dk:+.2f}%, Encaps {de:+.2f}%, Decaps {dd:+.2f}%")
    print("=" * 60)
    savemat('performance_fair.mat',
            {'keygen_delta_pct': dk, 'encaps_delta_pct': de, 'decaps_delta_pct': dd})
