#!/usr/bin/env python3
"""Generate Earn It's built-in alarm sounds (App/Sounds/EarnIt_<name>.caf).

Every sound is synthesised here, so the app owns them outright. Melodies are public-domain
compositions (composer died > 70 years ago, or traditional) in our own performance:
  reveille     traditional bugle call
  morningMood  Edvard Grieg (1843-1907), Peer Gynt - Morning Mood
  furElise     Ludwig van Beethoven (1770-1827), Fur Elise

Format required by iOS alarm sounds: <= 30 s, CAF, linear PCM 16-bit, 22.05 kHz mono.

    python3 scripts/generate_sounds.py            # all sounds
    python3 scripts/generate_sounds.py radar furElise
"""
import math
import pathlib
import struct
import subprocess
import sys
import tempfile
import wave

RATE = 22050
LENGTH = 30.0
TAU = 2 * math.pi
OUT = pathlib.Path(__file__).resolve().parent.parent / "App" / "Sounds"


def ramp(x, length, edge=0.005):
    return max(0.0, min(1.0, x / edge, (length - x) / edge))


def note_hz(name):
    """'C5', 'D#4', 'G#5' -> frequency."""
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave + 1) - 69) / 12)


# ---- instruments: (time since note start, note length, freq) -> sample -----------------------

def bugle(x, length, f):
    env = min(1.0, x / 0.03) * (0.85 + 0.15 * math.exp(-x * 6)) * min(1.0, (length - x) / 0.04)
    return env * sum(a * math.sin(TAU * f * k * x) for k, a in ((1, .5), (2, .32), (3, .22), (4, .12), (5, .07)))


def flute(x, length, f):
    vib = 1 + 0.004 * math.sin(TAU * 5.5 * x)
    env = min(1.0, x / 0.06) * min(1.0, max(0.0, (length - x) / 0.08))
    return env * (0.8 * math.sin(TAU * f * vib * x) + 0.12 * math.sin(TAU * 2 * f * x) + 0.05 * math.sin(TAU * 3 * f * x))


def piano(x, length, f):
    env = math.exp(-x * 2.6) * min(1.0, x / 0.004)
    return env * (0.6 * math.sin(TAU * f * x) + 0.25 * math.sin(TAU * 2.003 * f * x) + 0.1 * math.sin(TAU * 3.01 * f * x))


def marimba(x, length, f):
    env = math.exp(-x * 7) * min(1.0, x / 0.003)
    return env * (0.8 * math.sin(TAU * f * x) + 0.2 * math.sin(TAU * 4 * f * x))


def melody(notes, instrument, beat, gap=0.0):
    """notes: [(name or None, beats)] -> (sample function, loop duration)."""
    events, t = [], 0.0
    for name, beats in notes:
        dur = beats * beat
        if name:
            events.append((t, dur, note_hz(name)))
        t += dur
    loop = t + gap

    def fn(time):
        tc = time % loop
        v = 0.0
        for start, dur, f in events:
            if start <= tc < start + dur * 1.6:          # let notes ring a little
                v += instrument(tc - start, dur * 1.6, f)
        return v
    return fn


# ---- the original five ------------------------------------------------------------------------

def classic(t):
    tc = t % 1.0
    for b in (0.0, 0.15, 0.30, 0.45):
        if b <= tc < b + 0.09:
            e = ramp(tc - b, 0.09)
            return e * (0.55 * math.sin(TAU * 1760 * t) + 0.30 * math.sin(TAU * 3520 * t) + 0.15 * math.sin(TAU * 880 * t))
    return 0.0


def chime(t):
    tc = t % 2.0
    v = 0.0
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        start = i * 0.18
        if tc >= start:
            x = tc - start
            v += math.exp(-x * 3.0) * min(1.0, x / 0.004) * (0.7 * math.sin(TAU * f * x) + 0.3 * math.sin(TAU * f * 2.01 * x))
    return v * 0.45


def siren(t):
    tc = t % 0.9
    if tc > 0.8:
        return 0.0
    f0, f1, d = 600.0, 1500.0, 0.8
    phase = TAU * (f0 * tc + (f1 - f0) * tc * tc / (2 * d))
    return ramp(tc, 0.8, 0.01) * (0.8 * math.sin(phase) + 0.2 * math.sin(2 * phase))


def digital(t):
    tc = t % 1.2
    if tc >= 0.8:
        return 0.0
    f = 1000.0 if int(tc / 0.2) % 2 == 0 else 1500.0
    return ramp(tc % 0.2, 0.2) * 0.6 * sum(math.sin(TAU * f * k * t) / k for k in (1, 3, 5))


def pulse(t):
    tc = t % 0.65
    if tc >= 0.35:
        return 0.0
    return ramp(tc, 0.35, 0.01) * (0.6 * math.sin(TAU * 440 * t) + 0.3 * math.sin(TAU * 880 * t) + 0.1 * math.sin(TAU * 1320 * t))


# ---- new in this release ----------------------------------------------------------------------

def radar(t):
    """Rising sonar pings, 3 per second, then a pause."""
    tc = t % 1.6
    for i, f in enumerate((1200, 1500, 1800)):
        start = i * 0.25
        if start <= tc < start + 0.22:
            x = tc - start
            return math.exp(-x * 14) * min(1.0, x / 0.003) * (0.75 * math.sin(TAU * f * x) + 0.25 * math.sin(TAU * 2 * f * x))
    return 0.0


_gentle_notes = [("C5", 1), ("E5", 1), ("G5", 1), ("C6", 1), ("A4", 1), ("C5", 1), ("E5", 1), ("A5", 1),
                 ("F4", 1), ("A4", 1), ("C5", 1), ("F5", 1), ("G4", 1), ("B4", 1), ("D5", 1), ("G5", 1)]
_gentle = melody(_gentle_notes, marimba, beat=0.22)


def gentleRise(t):
    """Soft marimba arpeggios that get louder over 30 seconds."""
    return _gentle(t) * (0.25 + 0.75 * min(1.0, t / 24))


_reveille = melody([
    ("G4", .5), ("C5", .5), ("E5", 1), ("C5", .5), ("E5", .5), ("G5", 1), ("E5", .5), ("C5", .5),
    ("E5", 1), ("C5", .5), ("E5", .5), ("G5", 1), ("E5", .5), ("C5", .5), ("G4", 1), ("G4", .5), ("C5", .5),
    ("E5", 1), ("C5", .5), ("E5", .5), ("G5", 1), ("E5", .5), ("C5", .5), ("E5", .5), ("C5", .5), ("G4", .5),
    ("G4", .5), ("C5", 2)], bugle, beat=0.28, gap=0.8)


def reveille(t):
    return _reveille(t)


_morning = melody([
    ("G#5", 1), ("F#5", 1), ("E5", 1), ("D#5", 1), ("E5", 1), ("F#5", 1),
    ("G#5", 1), ("F#5", 1), ("E5", 1), ("D#5", 1), ("E5", .5), ("F#5", .5), ("G#5", 1), ("F#5", 1),
    ("G#5", 1), ("B5", 1), ("G#5", 1), ("B5", 1), ("C#6", 1), ("G#5", 1), ("C#6", 1), ("B5", 1),
    ("G#5", 1), ("F#5", 1), ("E5", 3)], flute, beat=0.32, gap=0.6)


def morningMood(t):
    return _morning(t)


_elise = melody([
    ("E5", .5), ("D#5", .5), ("E5", .5), ("D#5", .5), ("E5", .5), ("B4", .5), ("D5", .5), ("C5", .5), ("A4", 1.5),
    ("C4", .5), ("E4", .5), ("A4", .5), ("B4", 1.5), ("E4", .5), ("G#4", .5), ("B4", .5), ("C5", 1.5),
    ("E4", .5), ("E5", .5), ("D#5", .5), ("E5", .5), ("D#5", .5), ("E5", .5), ("B4", .5), ("D5", .5), ("C5", .5),
    ("A4", 1.5), ("C4", .5), ("E4", .5), ("A4", .5), ("B4", 1.5), ("E4", .5), ("C5", .5), ("B4", .5), ("A4", 2)],
    piano, beat=0.36, gap=0.5)


def furElise(t):
    return _elise(t)


# ---- bonus: unlocked by inviting a friend ------------------------------------------------------

def brass(x, length, f):
    """Bright, punchy brass: fast attack, slight swell, rich harmonics."""
    env = min(1.0, x / 0.02) * (0.8 + 0.2 * min(1.0, x / 0.15)) * min(1.0, max(0.0, (length - x) / 0.05))
    vib = 1 + 0.003 * math.sin(TAU * 6 * x) * min(1.0, x / 0.3)
    return env * sum(a * math.sin(TAU * f * k * vib * x) for k, a in ((1, .45), (2, .35), (3, .25), (4, .15), (5, .1), (6, .05)))


def _drum(t, period, offset=0.0):
    tc = (t - offset) % period
    return math.exp(-tc * 18) * math.sin(TAU * 70 * tc) * 0.9 if tc < 0.25 else 0.0


# Our own fanfare (not based on any existing piece): rising D-major call, answer, big finish.
_conquer = melody([
    ("D4", .5), ("A4", .5), ("D5", 1), ("D5", .5), ("F#5", .5), ("A5", 1.5), (None, .5),
    ("G5", .5), ("F#5", .5), ("E5", .5), ("F#5", .5), ("D5", 2), (None, .5),
    ("A4", .5), ("D5", .5), ("F#5", 1), ("F#5", .5), ("A5", .5), ("D6", 1.5), (None, .5),
    ("C#6", .5), ("B5", .5), ("A5", .5), ("B5", .5), ("D6", 3)], brass, beat=0.26, gap=0.6)


def riseAndConquer(t):
    return _conquer(t) + 0.35 * _drum(t, 0.52)


SOUNDS = dict(classic=classic, chime=chime, siren=siren, digital=digital, pulse=pulse,
              radar=radar, gentleRise=gentleRise, reveille=reveille, morningMood=morningMood, furElise=furElise, riseAndConquer=riseAndConquer)


def render(name, fn):
    n = int(RATE * LENGTH)
    samples = [fn(i / RATE) for i in range(n)]
    peak = max(abs(s) for s in samples) or 1.0
    gain = 0.89 / peak
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / f"{name}.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(32767 * gain * s)))) for s in samples))
        out = OUT / f"EarnIt_{name}.caf"
        subprocess.run(["afconvert", "-f", "caff", "-d", f"LEI16@{RATE}", "-c", "1", str(wav), str(out)], check=True)
    print("wrote", out.relative_to(OUT.parent.parent))


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(SOUNDS)
    for name in wanted:
        render(name, SOUNDS[name])
