"""Lists which of Ellwynn's cues have a recording in audio/voice/lines/.

  python3 -I tools/voice/check_lines.py          # Basic cues missing, unknown files
  python3 -I tools/voice/check_lines.py --all    # every cue, with its takes

A file counts for a cue when its name (any case) is the cue id, or the id with
_2, _3 ... for more takes, ending .mp3, .ogg or .wav. Number takes: A0..A20
(cheerful answers, override audio/voice/ellwynn/answer-N.mp3) and Q0..Q20
(plain counting takes). Exit code 1 if a file matches no cue.
"""
import json, os, re, sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
cues = json.load(open(os.path.join(root, "content", "ellwynn_cues.json")))["cues"]
ids = {c["id"].lower(): c for c in cues}
for n in range(21):
    ids["a%d" % n] = {"id": "A%d" % n, "need": "basic", "versions": 1, "fallback": "answer-%d.mp3" % n}
    ids["q%d" % n] = {"id": "Q%d" % n, "need": "basic", "versions": 1, "fallback": "A%d" % n}
folder = os.path.join(root, "audio", "voice", "lines")
takes, unknown = {}, []
for f in sorted(os.listdir(folder)):
    base, ext = os.path.splitext(f)
    if ext.lower() not in (".mp3", ".ogg", ".wav"):
        continue
    key = base.lower()
    m = re.fullmatch(r"(.+)_(\d+)", key)
    cid = key if key in ids else (m.group(1) if m and m.group(1) in ids else None)
    if cid is None:
        unknown.append(f)
    else:
        takes.setdefault(cid, []).append(f)
show_all = "--all" in sys.argv
missing = 0
for key, c in ids.items():
    have = takes.get(key, [])
    if not have and c["need"] == "basic" and not key[0] in "aq":
        missing += 1
    if show_all or (not have and c["need"] == "basic" and key[0] not in "aq"):
        state = ", ".join(have) if have else "none (plays: %s)" % c["fallback"]
        print("%-12s %-6s wants %-2d  %s" % (c["id"], c["need"], c["versions"], state))
print("\n%d files matched, %d Basic cues still without a recording" % (sum(len(v) for v in takes.values()), missing))
for f in unknown:
    print("UNKNOWN NAME (matches no cue):", f)
sys.exit(1 if unknown else 0)
