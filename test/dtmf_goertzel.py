import sys
import wave
import numpy as np

BLOCK_SIZE = 512
FRAC_BITS = 10
POWER_SHIFT = 2 * (BLOCK_SIZE.bit_length() - 1)

def goertzel_sprevs(samples, sample_rate, target_freq, frac_bits=FRAC_BITS):
    scale = 1 << frac_bits
    omega0 = 2.0 * np.pi * target_freq / sample_rate
    cr_int = round(float(np.cos(omega0)) * scale)

    s_prevs = []

    s_prev = 0
    s_prev2 = 0
    for x in samples:
        x = int(x)
        # Fixed-point multiply: integer multiply, then rescale by
        # right-shifting off the fractional bits -- free in hardware.
        term = (s_prev * cr_int) >> (frac_bits-1)
        s = x + term - s_prev2
        s_prevs.append(s_prev)
        s_prev2 = s_prev
        s_prev = s

    return s_prevs


def goertzel_power_fixed(samples: np.ndarray, sample_rate: float,
                          target_freq: float, frac_bits: int = FRAC_BITS) -> int:
    scale = 1 << frac_bits
    omega0 = 2.0 * np.pi * target_freq / sample_rate
    cr_int = round(float(np.cos(omega0)) * scale)
    print(cr_int)

    s_prevs = []

    s_prev = 0
    s_prev2 = 0
    for x in samples:
        x = int(x)
        # Fixed-point multiply: integer multiply, then rescale by
        # right-shifting off the fractional bits -- free in hardware.
        term = (s_prev * cr_int) >> (frac_bits-1)
        s = x + term - s_prev2
        s_prevs.append(s_prev)
        s_prev2 = s_prev
        s_prev = s

    print(s_prevs)

    cr_s_prev = (s_prev * cr_int) >> frac_bits  # = cos(omega0) * s_prev
    power = s_prev2 ** 2 + s_prev ** 2 - 2 * cr_s_prev * s_prev2

    return power >> POWER_SHIFT

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
    wave_data, sample_rate = load_wav_mono(sys.argv[1])
    goertzel_power_fixed(wave_data[0:10], sample_rate, 697)
