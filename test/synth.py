"""
Generate a synthetic unsigned 8-bit PCM DTMF WAV file with known digits,
so dtmf_goertzel.py can be validated against ground truth.
"""
import sys
import wave
import numpy as np

ROW_FREQS = [697, 770, 852, 941]
COL_FREQS = [1209, 1336, 1477, 1633]
KEYPAD = {
    "1": (697, 1209), "2": (697, 1336), "3": (697, 1477), "A": (697, 1633),
    "4": (770, 1209), "5": (770, 1336), "6": (770, 1477), "B": (770, 1633),
    "7": (852, 1209), "8": (852, 1336), "9": (852, 1477), "C": (852, 1633),
    "*": (941, 1209), "0": (941, 1336), "#": (941, 1477), "D": (941, 1633),
}

SAMPLE_RATE = 44100
TONE_MS = 1000
GAP_MS = 100

def make_tone(digit, sample_rate=SAMPLE_RATE, amplitude=0.9, noise_amplitude=0.01):
    f_row, f_col = KEYPAD[digit]
    n = int(sample_rate * TONE_MS / 1000.0)
    t = np.arange(n) / sample_rate
    tone = amplitude * (np.sin(2 * np.pi * f_row * t) + np.sin(2 * np.pi * f_col * t))
    noise = np.random.normal(0, noise_amplitude, n)
    return tone + noise


def make_gap(sample_rate=SAMPLE_RATE, noise_amplitude=0.01):
    n = int(sample_rate * GAP_MS / 1000.0)
    return np.random.normal(0, noise_amplitude, n)


def synthesize(digits, path):
    """
    Writes unsigned 8-bit PCM (0..255, 128 = silence) -- matches the WAV
    spec's convention that 8-bit samples are unsigned, unlike 16-bit+
    which are signed.
    """
    chunks = [make_gap()]
    for d in digits:
        chunks.append(make_tone(d))
        chunks.append(make_gap())
    audio = np.concatenate(chunks)
    audio = np.clip(audio, -1.0, 1.0)
    pcm = np.round(audio * 127 + 128).astype(np.uint8)

    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(1)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm.tobytes())


if __name__ == "__main__":
    digits = sys.argv[1] if len(sys.argv) > 1 else "149*45"
    out = sys.argv[2] if len(sys.argv) > 2 else "test_dtmf.wav"
    synthesize(digits, out)
    print(f"Wrote {out} (8-bit unsigned PCM) with digits: {digits}")

