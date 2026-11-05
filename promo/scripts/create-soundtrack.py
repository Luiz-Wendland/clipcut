#!/usr/bin/env python3
"""Original deterministic 120 BPM synth score + editorial SFX, no samples.

Requires NumPy. All notes, envelopes and percussion are synthesized here.
"""
from pathlib import Path
import subprocess
import wave
import numpy as np

RATE = 48000
DURATION = 32
rng = np.random.default_rng(718)
mix = np.zeros((RATE * DURATION, 2), dtype=np.float64)


def add(sound, at, gain=1, pan=0):
    start = round(at * RATE)
    end = min(len(mix), start + len(sound))
    if end <= start:
        return
    p = np.clip(pan, -1, 1)
    mix[start:end, 0] += sound[:end-start] * gain * np.sqrt((1-p)/2)
    mix[start:end, 1] += sound[:end-start] * gain * np.sqrt((1+p)/2)


def clock(duration):
    return np.arange(round(duration * RATE)) / RATE


def note(midi, duration, kind='bell'):
    t = clock(duration)
    f = 440 * 2 ** ((midi-69)/12)
    if kind == 'bass':
        s = np.sin(2*np.pi*f*t) + .22*np.sin(4*np.pi*f*t)
        env = np.minimum(t/.009, 1) * np.exp(-t*5) * np.minimum((duration-t)/.04, 1)
    elif kind == 'pad':
        s = (np.sin(2*np.pi*f*t) + .35*np.sin(2*np.pi*f*1.002*t) + .12*np.sin(4*np.pi*f*t))
        env = np.minimum(t/.24, 1) * np.minimum((duration-t)/.45, 1) * .7
    else:
        s = np.sin(2*np.pi*f*t + .8*np.sin(2*np.pi*f*2*t)*np.exp(-t*9))
        env = np.minimum(t/.004, 1) * np.exp(-t*6) * np.minimum((duration-t)/.05, 1)
    return s * env


# D minor / Bbmaj7 / Fmaj7 / Cadd9. Sixteen bars, with a break before the outro.
chords = [(50, 57, 60, 64), (46, 53, 57, 60), (41, 53, 57, 60), (48, 55, 62, 64)]
for bar in range(16):
    chord = chords[(bar//2) % 4]
    at = bar * 2
    for j, pitch in enumerate(chord):
        add(note(pitch+12, 2.3, 'pad'), at, .055, (j-1.5)/2)
    if bar >= 2 and bar < 14:
        for step in range(8):
            pitch = chord[[0, 2, 1, 3, 2, 1, 3, 2][step]] + 24
            sound = note(pitch, .65)
            pos = at + step*.25
            add(sound, pos, .09, np.sin(step*1.7)*.65)
            add(sound, pos+.375, .022, -np.sin(step*1.7)*.65)
        for beat in range(4):
            t = clock(.35)
            kick = np.sin(2*np.pi*(46*t + 105*.028*(1-np.exp(-t/.028)))) * np.exp(-t*18)
            add(kick, at+beat*.5, .43)
            add(note(chord[0]-12 if chord[0] > 45 else chord[0], .36, 'bass'), at+beat*.5+.25, .18)
        for beat in [1, 3]:
            t = clock(.16)
            noise = rng.standard_normal(len(t))
            noise = np.concatenate(([0], np.diff(noise)))
            add(noise*np.exp(-t*38), at+beat*.5, .065, .1)
        for step in range(8):
            t = clock(.07)
            noise = rng.standard_normal(len(t))
            hat = np.concatenate(([0], np.diff(noise))) * np.exp(-t*85)
            add(hat, at+step*.25, .025 if step % 2 else .016, (-1)**step*.5)

# Cut accents and filtered noise sweeps aligned to editorial scene boundaries.
for at in [4, 9, 17, 23, 28]:
    t = clock(.55)
    noise = rng.standard_normal(len(t))
    smooth = np.convolve(noise, np.ones(18)/18, mode='same')
    add(smooth*np.sin(np.pi*t/.55)**2, at-.55, .19, -.35)
    add(note(38, .8, 'bass'), at, .24)
for at in [10.5, 12.5, 18.5, 20.5, 24, 27]:
    t = clock(.045)
    add((np.sin(2*np.pi*1500*t) + rng.standard_normal(len(t))*.3)*np.exp(-t*140), at, .075, .25)
for pitch, at in [(74, 28), (77, 28.25), (81, 28.5)]:
    add(note(pitch, 1.6), at, .14)

# Soft limiting and final fades. Leave headroom; no hard clipping.
mix = np.tanh(mix * 1.15)
fade = np.minimum(np.arange(len(mix))/(RATE*.05), 1)
fade *= np.minimum((len(mix)-1-np.arange(len(mix)))/(RATE*1.25), 1)
mix *= fade[:, None]
mix *= .83 / max(.83, np.max(np.abs(mix)))
out = Path(__file__).resolve().parents[1] / 'public' / 'audio' / 'clipcut-original.wav'
out.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(out), 'wb') as wav:
    wav.setnchannels(2)
    wav.setsampwidth(2)
    wav.setframerate(RATE)
    wav.writeframes((mix*32767).astype('<i2').tobytes())
normalized = out.with_name('clipcut-original-normalized.wav')
subprocess.run([
    'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(out),
    '-af', 'loudnorm=I=-16:TP=-1.5:LRA=9', '-ar', str(RATE),
    '-c:a', 'pcm_s16le', str(normalized),
], check=True)
normalized.replace(out)
print(f'Created original 32s stereo score: {out}')
