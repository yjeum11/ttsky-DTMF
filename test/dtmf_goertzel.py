import sys
import wave
import numpy as np

BLOCK_SIZE = 512
FRAC_BITS = 10
POWER_SHIFT = 2 * (BLOCK_SIZE.bit_length() - 1)

ROW_FREQS = [697, 770, 852, 941]
COL_FREQS = [1209, 1336, 1477, 1633]

def truncate_signed(val, bits):
    # 1. Clear the higher-order bits (Unsigned mask)
    val = val & ((1 << bits) - 1)
    # 2. Apply two's complement sign extension if the sign bit is set
    if val & (1 << (bits - 1)):
        val -= (1 << bits)
    return val

def get_coeffs():
    scale = 1 << FRAC_BITS
    omega0 = [2.0 * np.pi * target_freq / 44100 for target_freq in COL_FREQS]
    cr_int = [round(float(np.cos(x)) * scale) for x in omega0]
    print(cr_int)

def all_goertzel_sprevs(samples, sample_rate, frac_bits=FRAC_BITS):
    scale = 1 << frac_bits

    s_prev = [0] * 7
    s_prev2 = [0] * 7
    s_prevs = []

    for x in samples:
        for i, target_freq in enumerate(ROW_FREQS + COL_FREQS):
            omega0 = 2.0 * np.pi * target_freq / sample_rate
            cr_int = round(float(np.cos(omega0)) * scale)
            x = int(x)
            term = (s_prev[i] * cr_int) >> (frac_bits-1)
            s = x + term - s_prev2[i]
            s_prev2[i] = s_prev[i]
            s_prev[i] = s
        s_prevs.append(s_prev.copy())

    return s_prevs

def goertzel_sprevs(samples, sample_rate, target_freq, frac_bits=FRAC_BITS):
    scale = 1 << frac_bits
    omega0 = 2.0 * np.pi * target_freq / sample_rate
    cr_int = round(float(np.cos(omega0)) * scale)

    s_prevs = []

    s_prev = 0
    s_prev2 = 0
    for x in samples:
        x = int(x)
        term = (s_prev * cr_int) >> (frac_bits-1)
        s = x + term - s_prev2
        s_prev2 = s_prev
        s_prev = s
        s_prevs.append(s_prev)

    return s_prevs

def all_powers(samples):
    res = []
    for i, target_freq in enumerate(ROW_FREQS + COL_FREQS):
        res.append(goertzel_power_fixed(samples, 44100, target_freq))
    return res

def goertzel_power_fixed(samples: np.ndarray, sample_rate: float,
                          target_freq: float, frac_bits: int = FRAC_BITS) -> int:
    scale = 1 << frac_bits
    omega0 = 2.0 * np.pi * target_freq / sample_rate
    cr_int = round(float(np.cos(omega0)) * scale)

    s_prevs = []

    s_prev = 0
    s_prev2 = 0
    for x in samples:
        x = int(x)
        term = (s_prev * cr_int) >> (frac_bits-1)
        s = x + term - s_prev2
        s_prev2 = s_prev
        s_prev = s
        s_prevs.append(s_prev)

    s_prev = truncate_signed(s_prev, 20)
    s_prev2 = truncate_signed(s_prev2, 20)
    # s_prev  &= 0xfffff # 20 bits
    # s_prev2 &= 0xfffff
    s_prev >>= (POWER_SHIFT // 2)
    s_prev2 >>= (POWER_SHIFT // 2)

    cr_s_prev = (s_prev * cr_int) >> (frac_bits - 1)  # = cos(omega0) * s_prev
    power = s_prev2 ** 2 + s_prev ** 2 - cr_s_prev * s_prev2

    # print("power: ", power)

    return power

def get_max_rowcol(samples, sample_rate):
    row_powers = []
    col_powers = []
    for row in ROW_FREQS:
        row_powers.append(goertzel_power_fixed(samples, sample_rate, row))
    for col in COL_FREQS:
        col_powers.append(goertzel_power_fixed(samples, sample_rate, col))

    row_idx = np.argmax(row_powers)
    col_idx = np.argmax(col_powers)

    print(f"row idx: {row_idx}")
    print(f"col idx: {col_idx}")

    return (row_idx, col_idx)

def load_wav_mono(path: str):
    with wave.open(path, "rb") as wf:
        n_channels = wf.getnchannels()
        sample_width = wf.getsampwidth()
        sample_rate = wf.getframerate()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)

    if sample_width != 1:
        raise ValueError(
            f"Expected unsigned 8-bit PCM, got {sample_width * 8}-bit. "
            "Use make_test_wav.py to generate 8-bit test files."
        )

    data = np.frombuffer(raw, dtype=np.uint8).astype(np.float64) - 128.0
    # data = (255*np.ones(44100)).astype(np.float64) - 128.0

    if n_channels > 1:
        data = data.reshape(-1, n_channels).mean(axis=1)

    return data, sample_rate

if __name__ == "__main__":
    # wave_data, sample_rate = load_wav_mono(sys.argv[1])
    get_coeffs()
    # print(all_goertzel_sprevs(wave_data[0:512], sample_rate))
    # goertzel_power_fixed(wave_data[0:8], sample_rate, 697)
