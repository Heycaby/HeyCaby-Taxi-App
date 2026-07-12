#!/usr/bin/env python3
"""Generate HeyCaby driver incoming-ride ringtone (loop-friendly, no siren sweeps)."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
DURATION_SEC = 2.6
OUTPUT_PATHS = [
    Path(__file__).resolve().parents[1]
    / "apps/driver/assets/sounds/driver/ride_request_incoming.wav",
    Path(__file__).resolve().parents[1]
    / "apps/driver/ios/Runner/heycaby_ride_request.wav",
]

# Soft major triad — hotel-chime feel, not emergency alert.
STRIKES = (
    (0.00, 523.25, 0.22, 0.42),  # C5
    (0.42, 659.25, 0.20, 0.36),  # E5
    (0.82, 783.99, 0.34, 0.30),  # G5 (slightly longer tail)
)


def _adsr(
    t: float,
    attack: float,
    decay: float,
    sustain_level: float,
    release: float,
    note_len: float,
) -> float:
    if t < 0:
        return 0.0
    if t < attack:
        return t / attack
    if t < attack + decay:
        phase = (t - attack) / decay
        return 1.0 - (1.0 - sustain_level) * phase
    sustain_end = max(attack + decay, note_len - release)
    if t < sustain_end:
        return sustain_level
    if t < note_len:
        phase = (t - sustain_end) / max(release, 1e-6)
        return sustain_level * (1.0 - min(1.0, phase))
    return 0.0


def _soft_bell(freq: float, t: float, env: float) -> float:
    # Warm bell: fundamental + gentle odd harmonics, no pitch glide.
    return env * (
        0.62 * math.sin(2 * math.pi * freq * t)
        + 0.18 * math.sin(2 * math.pi * freq * 2.01 * t)
        + 0.08 * math.sin(2 * math.pi * freq * 3.02 * t)
        + 0.04 * math.sin(2 * math.pi * freq * 4.03 * t)
    )


def synthesize() -> list[float]:
    total_samples = int(SAMPLE_RATE * DURATION_SEC)
    mix = [0.0] * total_samples

    for start_sec, freq, note_len, peak in STRIKES:
        start_idx = int(start_sec * SAMPLE_RATE)
        note_samples = int(note_len * SAMPLE_RATE)
        for i in range(note_samples):
            idx = start_idx + i
            if idx >= total_samples:
                break
            t = i / SAMPLE_RATE
            env = _adsr(t, 0.004, 0.08, 0.22, 0.14, note_len) * peak
            mix[idx] += _soft_bell(freq, t, env)

    # Subtle shimmer echo — depth without siren character.
    delay_ms = 38
    delay_samples = int(SAMPLE_RATE * delay_ms / 1000)
    echo_gain = 0.14
    for idx in range(delay_samples, total_samples):
        mix[idx] += mix[idx - delay_samples] * echo_gain

    # Seamless loop: fade last 80ms into first 80ms level.
    fade_samples = int(0.08 * SAMPLE_RATE)
    for i in range(fade_samples):
        alpha = i / fade_samples
        tail_idx = total_samples - fade_samples + i
        mix[tail_idx] *= 1.0 - alpha

    peak = max(abs(s) for s in mix) or 1.0
    target_peak = 0.82
    gain = target_peak / peak
    return [max(-1.0, min(1.0, s * gain)) for s in mix]


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", int(sample * 32767)) for sample in samples
        )
        wav.writeframes(frames)


def main() -> None:
    samples = synthesize()
    for path in OUTPUT_PATHS:
        write_wav(path, samples)
        print(f"Wrote {path} ({len(samples) / SAMPLE_RATE:.2f}s)")


if __name__ == "__main__":
    main()
