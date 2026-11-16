"""Makes Ellwynn's mouth tracks: for every voice file in audio/voice/ellwynn/,
the loudness every 1/15 s becomes a mouth frame (0 closed, 1 half, 2 open),
written to content/ellwynn_mouth.json as one string of digits per file.
Run it again whenever voice files are added or replaced:
    python3 -I tools/voice/mouth_tracks.py
Needs ffmpeg and numpy."""
import json, pathlib, subprocess
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
VOICE = ROOT / "audio" / "voice" / "ellwynn"
OUT = ROOT / "content" / "ellwynn_mouth.json"
FPS = 15
RATE = 16000
HALF, OPEN = 0.18, 0.5   # of the file's loudest frame


def track(path: pathlib.Path) -> str:
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", str(path), "-ac", "1", "-ar", str(RATE),
                          "-f", "s16le", "-"], check=True, capture_output=True).stdout
    s = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    hop = RATE // FPS
    n = len(s) // hop
    rms = np.array([np.sqrt(np.mean(s[i * hop:(i + 1) * hop] ** 2)) for i in range(n)])
    top = rms.max() if n and rms.max() > 0 else 1.0
    out = []
    for v in rms / top:
        out.append("2" if v >= OPEN else "1" if v >= HALF else "0")
    # never hold the same open frame for long: alternate so it reads as talking
    for i in range(2, len(out)):
        if out[i] == "2" and out[i - 1] == "2" and out[i - 2] == "2":
            out[i] = "1"
    return "".join(out)


def main() -> None:
    tracks = {}
    for f in sorted(VOICE.glob("*.mp3")) + sorted(VOICE.glob("*.ogg")) + sorted(VOICE.glob("*.wav")):
        tracks["res://" + f.relative_to(ROOT).as_posix()] = track(f)
    OUT.write_text(json.dumps({"version": 1, "fps": FPS, "tracks": tracks}, indent=2) + "\n")
    for k, v in tracks.items():
        print(k, v)


if __name__ == "__main__":
    main()
