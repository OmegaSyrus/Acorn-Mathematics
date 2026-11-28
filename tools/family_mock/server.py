#!/usr/bin/env python3
"""A local stand-in for the family backend's /v1 API (docs/contract/api-v1.md),
built from docs/contract/samples, for the sync add-on (addons/acorn_family)
and tools/family_e2e. Python standard library only; everything in memory.

    python3 -I tools/family_mock/server.py [--port 8787] [--manual] [--approve-after 1]

Point the game or the e2e script at it:

    ACORN_FAMILY_URL=http://127.0.0.1:8787/v1

Pairing approves itself on the poll after --approve-after polls (default 1),
like a parent tapping Approve; with --manual it waits for
POST /v1/devices/pair/approve {"code": "..."} (no sign-in needed here).
The family starts with the sample's child (Bear, c_9b2f00e1a7c4) and the
sample's settings plus a bedtime. Event lines and snapshots are checked with
the contract's schemas (tools/contract/check.py's checker), the way the
backend checks them. Extra, for tests and poking around (not in /v1):

    GET    /mock/state                everything the mock holds, as JSON
    DELETE /v1/devices/{dev}          remove a tablet: its next call hears 410 gone
    PATCH  /v1/children/{c}/games/{g}/settings   change a setting (no sign-in here)
"""
import argparse
import gzip
import importlib.util
import json
import os
import re
import secrets
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CONTRACT = os.path.join(ROOT, "docs", "contract")

_spec = importlib.util.spec_from_file_location("contract_check", os.path.join(ROOT, "tools", "contract", "check.py"))
check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check)

GAME = re.compile(r"^[a-z][a-z0-9-]{1,31}$")
DEV = re.compile(r"^d_[0-9a-f]{16}$")
PROFILE = re.compile(r"^p_[0-9a-f]{12}$")
CHILD = re.compile(r"^c_[0-9a-f]{12}$")
PICTURE = re.compile(r"^[a-z0-9_]{1,32}$")
ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
MAX_CHILDREN = 12


def load(rel):
    with open(os.path.join(CONTRACT, rel), encoding="utf-8") as f:
        return json.load(f)


SAMPLE_PAIR = load("samples/api-pair.json")
SAMPLE_SETTINGS = load("samples/settings.json")
MANIFEST = load("samples/manifest.json")
EVENT_SCHEMA = load("schemas/event.v2.schema.json")
SNAPSHOT_SCHEMA = load("schemas/snapshot.v1.schema.json")


class ApiError(Exception):
    STATUS = {"bad_request": 400, "unauthorized": 401, "forbidden": 403, "not_found": 404,
              "conflict": 409, "gone": 410, "too_large": 413, "unprocessable": 422}

    def __init__(self, code, detail="", **extra):
        super().__init__(detail)
        self.code, self.detail, self.extra = code, detail, extra

    @property
    def status(self):
        return self.STATUS.get(self.code, 400)


def need(cond, detail, code="bad_request"):
    if not cond:
        raise ApiError(code, detail)


class Mock:
    def __init__(self, approve_after=1, manual=False, base=""):
        self.lock = threading.Lock()
        self.approve_after = approve_after
        self.manual = manual
        self.base = base
        self.family = SAMPLE_PAIR["pair_poll"]["response_done"]["family"]
        self.children = [dict(c) for c in SAMPLE_PAIR["pair_poll"]["response_done"]["children"]]
        self.pairs = {}        # pair_id -> {code, game, dev, app, code_n, expires, polls, approved, token, name}
        self.devices = {}      # dev -> {token, game, name, removed}
        self.profiles = {}     # dev -> {profile: {child, nickname, picture, guest}}
        self.uploads = {}      # "game/dev/first-last" -> {lines: [...], gzip}
        self.snapshots = {}    # child -> {dev: snapshot}
        self.settings = {}     # child -> {key: {value, rev, at, by}}
        first = self.children[0]["child"]
        fields = dict(SAMPLE_SETTINGS["fields"])
        fields.setdefault("bedtime", {"value": "20:00", "rev": 7, "at": 1763291000, "by": "parent"})
        self.settings[first] = fields

    # ------------------------------------------------------------------ helpers

    def child_ids(self):
        return {c["child"] for c in self.children}

    def device(self, headers):
        h = headers.get("Authorization", "")
        parts = h.split(" ", 1)
        if len(parts) != 2 or parts[0].lower() != "device":
            raise ApiError("unauthorized", "pair this device first")
        for dev, d in self.devices.items():
            if d["token"] == parts[1].strip():
                if d["removed"]:
                    raise ApiError("gone", "this device was removed from the family")
                return dev, d
        raise ApiError("unauthorized", "unknown device token")

    def profiles_view(self, dev):
        rows = [dict(profile=p, **v) for p, v in sorted(self.profiles.get(dev, {}).items())]
        return {"profiles": rows, "children": [dict(c) for c in self.children]}

    def settings_doc(self, child, game):
        fields = self.settings.get(child, {})
        rev = max([f["rev"] for f in fields.values()] or [0])
        return {"schema": "family.settings", "v": 1, "child": child, "game": game, "rev": rev, "fields": fields}

    # ------------------------------------------------------------------ the router

    def handle(self, method, path, query, headers, raw):
        with self.lock:
            return self._handle(method, path, query, headers, raw)

    def _handle(self, method, path, query, headers, raw):
        if path == "/mock/state" and method == "GET":
            return 200, {"pairs": self.pairs, "devices": self.devices, "profiles": self.profiles,
                         "children": self.children, "uploads": self.uploads, "snapshots": self.snapshots,
                         "settings": self.settings}
        m = re.search(r"(?:^|/api)/v1(/.*)$", path)
        need(m, f"no route {method} {path}", "not_found")
        seg = [s for s in m.group(1).split("/") if s]

        def body():
            try:
                b = json.loads(raw.decode("utf-8") or "{}")
            except ValueError:
                raise ApiError("bad_request", "body is not JSON")
            need(isinstance(b, dict), "body must be a JSON object")
            return b

        if seg == ["health"] and method == "GET":
            return 200, {"ok": True, "api": "v1", "mock": True}
        if seg == ["devices", "pair", "start"] and method == "POST":
            return self.pair_start(body())
        if seg == ["devices", "pair", "poll"] and method == "GET":
            return self.pair_poll(query.get("pair_id", [""])[0])
        if seg == ["devices", "pair", "approve"] and method == "POST":
            return self.pair_approve(body())
        if len(seg) == 2 and seg[0] == "devices" and method == "DELETE":
            d = self.devices.get(seg[1])
            need(d and not d["removed"], "no such device in this family", "not_found")
            d["removed"] = True
            return 200, {"removed": True}
        if len(seg) == 3 and seg[0] == "devices" and seg[2] == "profiles":
            dev, _ = self.device(headers)
            need(dev == seg[1], "a device reads only its own profiles", "forbidden")
            if method == "GET":
                return 200, self.profiles_view(dev)
            if method == "PUT":
                return self.put_profiles(dev, body())
        if len(seg) == 4 and seg[0] == "events" and method == "PUT":
            r = re.match(r"^(\d+)-(\d+)$", seg[3])
            need(r, "range: first-last")
            return self.put_events(headers, seg[1], seg[2], int(r.group(1)), int(r.group(2)), raw)
        if len(seg) >= 5 and seg[0] == "children" and seg[2] == "games":
            child, game, what = seg[1], seg[3], seg[4]
            need(CHILD.match(child), "bad child id")
            if what == "records" and method == "GET":
                return self.records(child, game)
            dev, d = self.device(headers) if headers.get("Authorization") else (None, None)
            need(child in self.child_ids(), "no such child in this family", "not_found")
            if what == "snapshots" and len(seg) == 5 and method == "GET":
                snaps = sorted(self.snapshots.get(child, {}).values(), key=lambda s: -s.get("saved_at", 0))
                return 200, {"child": child, "game": game, "snapshots": snaps}
            if what == "snapshots" and len(seg) == 6 and method == "PUT":
                need(dev == seg[5], "a device uploads only its own snapshot", "forbidden")
                return self.put_snapshot(child, game, dev, body())
            if what == "settings" and method == "GET":
                return 200, self.settings_doc(child, game)
            if what == "settings" and method == "PATCH":
                return self.patch_settings(child, game, body(), f"device:{dev}" if dev else "parent")
        if len(seg) == 4 and seg[0] == "games" and seg[2] == "manifests" and method == "GET":
            need(seg[1] == MANIFEST["game"] and seg[3] in ("latest", str(MANIFEST["code"])), "no manifest", "not_found")
            return 200, MANIFEST
        raise ApiError("not_found", f"no route {method} /v1/{'/'.join(seg)}")

    # ------------------------------------------------------------------ pairing

    def pair_start(self, b):
        need(isinstance(b.get("game"), str) and GAME.match(b["game"]), "game: a game id")
        need(isinstance(b.get("dev"), str) and DEV.match(b["dev"]), "dev: d_ + 16 hex")
        for pid in [p for p, r in self.pairs.items() if r["dev"] == b["dev"] and not r["approved"]]:
            del self.pairs[pid]
        pid = "pr_" + secrets.token_hex(16)
        code = "".join(secrets.choice(ALPHABET) for _ in range(6))
        code = code[:3] + "-" + code[3:]
        self.pairs[pid] = {"code": code, "game": b["game"], "dev": b["dev"], "app": b.get("app"),
                           "expires": time.time() + 600, "polls": 0, "approved": False, "token": None, "name": None}
        qr = f"{self.base}/pair/{code}" if self.base else None
        print(f"[mock] pairing code {code} for {b['dev']}", flush=True)
        return 201, {"pair_id": pid, "code": code, "qr_url": qr, "expires_in": 600}

    def _approve(self, r, name="Kitchen tablet"):
        token = "dt_" + secrets.token_hex(32)
        self.devices[r["dev"]] = {"token": token, "game": r["game"], "name": name, "removed": False}
        r.update(approved=True, token=token, name=name)

    def pair_approve(self, b):
        need(isinstance(b.get("code"), str), "code: the code the tablet shows")
        code = re.sub(r"[^A-Z0-9]", "", b["code"].upper())
        code = code[:3] + "-" + code[3:] if len(code) == 6 else code
        for r in self.pairs.values():
            if r["code"] == code and not r["approved"] and r["expires"] > time.time():
                self._approve(r, (b.get("device_name") or "Tablet").strip()[:40] or "Tablet")
                return 200, {"ok": True, "dev": r["dev"], "name": r["name"], "game": r["game"]}
        raise ApiError("not_found", "no such code, or it ran out: show a new one on the tablet")

    def pair_poll(self, pid):
        need(re.match(r"^pr_[0-9a-f]{32}$", pid or ""), "pair_id")
        r = self.pairs.get(pid)
        need(r, "no such pairing; start again", "not_found")
        r["polls"] += 1
        if not r["approved"] and not self.manual and r["polls"] > self.approve_after:
            self._approve(r)
        if not r["approved"]:
            if r["expires"] < time.time():
                del self.pairs[pid]
                return 200, {"state": "expired"}
            return 200, {"state": "waiting", "expires_in": max(0, round(r["expires"] - time.time()))}
        del self.pairs[pid]
        return 200, {"state": "approved", "device_token": r["token"], "family": self.family, "dev": r["dev"],
                     "name": r["name"], "children": [dict(c) for c in self.children]}

    # ------------------------------------------------------------------ profiles

    def put_profiles(self, dev, b):
        need(isinstance(b.get("profiles"), list) and len(b["profiles"]) <= 16, "profiles: a list of at most 16")
        for p in b["profiles"]:
            need(isinstance(p, dict) and isinstance(p.get("profile"), str) and PROFILE.match(p["profile"]),
                 "profile: p_ + 12 hex")
            if p.get("child") == "new" and p.get("guest") is not True:
                n = p.get("nickname")
                need(isinstance(n, str) and 1 <= len(n.strip()) <= 24, "a new child needs a nickname of 1 to 24 characters")
                need(p.get("picture") is None or (isinstance(p["picture"], str) and PICTURE.match(p["picture"])),
                     "picture: a picture id")
        mine = self.profiles.setdefault(dev, {})
        kids = self.child_ids()
        staged, created, new_children = {}, [], []
        for p in b["profiles"]:
            guest = p.get("guest") is True
            child = None if guest else p.get("child")
            if child == "new":
                had = mine.get(p["profile"], {}).get("child")
                if had in kids:
                    child = had
                else:
                    if len(kids) >= MAX_CHILDREN:
                        raise ApiError("conflict", f"at most {MAX_CHILDREN} children", reason="children_limit",
                                       profile=p["profile"])
                    child = "c_" + secrets.token_hex(6)
                    kids.add(child)
                    new_children.append({"child": child, "nickname": p["nickname"].strip(), "picture": p.get("picture") or "fox"})
                    created.append({"profile": p["profile"], "child": child})
            need(child is None or child in kids, f"child {child} is not in this family")
            staged[p["profile"]] = {"child": child, "nickname": str(p.get("nickname") or "")[:24],
                                    "picture": str(p.get("picture") or "")[:32], "guest": guest}
        self.children += new_children
        mine.update(staged)
        out = self.profiles_view(dev)
        out["created"] = created
        return 200, out

    # ------------------------------------------------------------------ events

    def put_events(self, headers, game, dev, first, last, raw):
        me, d = self.device(headers)
        need(me == dev, "a device uploads only its own events", "forbidden")
        need(d["game"] == game, "this device was paired for another game", "forbidden")
        need(first >= 1 and last >= first, "sequence range")
        key = f"{game}/{dev}/{first}-{last}"
        zipped = "gzip" in headers.get("Content-Encoding", "")
        if len(raw) > (256 * 1024 if zipped else 4 * 1024 * 1024):
            raise ApiError("too_large", "batch too big: send fewer lines")
        if key in self.uploads:
            return 200, {"stored": False, "duplicate": True, "lines": len(self.uploads[key]["lines"])}
        if zipped:
            try:
                raw = gzip.decompress(raw)
            except (OSError, EOFError):
                raise ApiError("bad_request", "body is not valid gzip")
        lines = [l for l in raw.decode("utf-8").split("\n") if l.strip()]
        need(lines, "no lines")
        profiles, out = set(), []
        for i, l in enumerate(lines):
            try:
                e = json.loads(l)
            except ValueError:
                raise ApiError("bad_request", f"line {i + 1} is not JSON")
            need(isinstance(e, dict), f"line {i + 1} is not an object")
            if e.get("v") == 2:
                errs = check.errors(e, EVENT_SCHEMA)
                if errs:
                    raise ApiError("bad_request", f"line {i + 1}: {'; '.join(errs[:3])}")
            if "seq" in e:
                need(isinstance(e["seq"], int) and first <= e["seq"] <= last, f"line {i + 1}: seq outside {first}-{last}")
            if "dev" in e:
                need(e["dev"] == dev, f"line {i + 1}: dev is not {dev}")
            if isinstance(e.get("profile"), str):
                profiles.add(e["profile"])
            out.append(e)
        self.uploads[key] = {"lines": out, "gzip": zipped, "at": time.time()}
        mapped = self.profiles.get(dev, {})
        children = sorted({mapped[p]["child"] for p in profiles if p in mapped and mapped[p]["child"]})
        unmapped = sorted(p for p in profiles if p not in mapped)
        print(f"[mock] stored {key}: {len(out)} lines{' (gzip)' if zipped else ''}", flush=True)
        return 201, {"stored": True, "lines": len(out), "children": children, "unmapped_profiles": unmapped}

    def records(self, child, game):
        keys = {(dev, p) for dev, ps in self.profiles.items() for p, v in ps.items() if v["child"] == child}
        lines = [e for k, u in self.uploads.items() if k.startswith(game + "/") for e in u["lines"]
                 if (e.get("dev"), e.get("profile")) in keys]
        lines.sort(key=lambda e: (-e.get("t", 0), -e.get("seq", 0)))
        return 200, {"child": child, "game": game, "days": 30, "lines": lines, "truncated": False}

    # ------------------------------------------------------------------ snapshots and settings

    def put_snapshot(self, child, game, dev, snap):
        need(dev, "pair this device first", "unauthorized")
        need(self.devices[dev]["game"] == game, "this device was paired for another game", "forbidden")
        errs = check.errors(snap, SNAPSHOT_SCHEMA)
        need(not errs, "; ".join(errs[:3]))
        need(snap["game"] == game and snap["dev"] == dev, "snapshot game and dev must match the path")
        need(snap.get("child") in (None, child), "snapshot child must match the path")
        cur = self.snapshots.get(child, {}).get(dev)
        if cur and snap["rev"] <= cur["rev"]:
            raise ApiError("conflict", "an equal or newer snapshot is stored", stored_rev=cur["rev"])
        self.snapshots.setdefault(child, {})[dev] = dict(snap, child=child)
        print(f"[mock] snapshot {child}/{dev} rev {snap['rev']}", flush=True)
        return 200, {"stored": True, "rev": snap["rev"]}

    def patch_settings(self, child, game, b, by):
        need(isinstance(b.get("fields"), dict), "fields: {key: {value}}")
        specs = {s["key"]: s for s in MANIFEST["settings"]}
        for k, f in b["fields"].items():
            s = specs.get(k)
            if not s or s.get("scope") == "device":
                raise ApiError("unprocessable", f"{game} has no setting {k}")
            need(isinstance(f, dict) and "value" in f, f"{k}: {{value}}")
            v = f["value"]
            ok = {"int": lambda: isinstance(v, int) and not isinstance(v, bool) and s.get("min", v) <= v <= s.get("max", v),
                  "bool": lambda: isinstance(v, bool),
                  "time": lambda: v is None or (isinstance(v, str) and re.match(r"^([01][0-9]|2[0-3]):[0-5][0-9]$", v)),
                  "enum": lambda: v in s.get("options", [])}[s["type"]]()
            if not ok:
                raise ApiError("unprocessable", f"{k}: not a valid {s['type']}")
        fields = self.settings.setdefault(child, {})
        rev = max([f["rev"] for f in fields.values()] or [0]) + 1
        for k, f in b["fields"].items():
            fields[k] = {"value": f["value"], "rev": rev, "at": int(time.time()), "by": by}
        return 200, self.settings_doc(child, game)


def make_handler(mock):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def _go(self):
            u = urlparse(self.path)
            n = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(n) if n else b""
            try:
                status, out = mock.handle(self.command, u.path, parse_qs(u.query), self.headers, raw)
            except ApiError as e:
                status, out = e.status, dict({"error": e.code, "detail": e.detail}, **e.extra)
            except Exception as e:  # a bug in the mock: answer like the backend does
                print("[mock] internal error:", repr(e), file=sys.stderr, flush=True)
                status, out = 500, {"error": "internal", "detail": "something went wrong"}
            data = json.dumps(out).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = _go

        def log_message(self, fmt, *args):
            sys.stderr.write("[mock] %s %s\n" % (self.command, fmt % args))

    return Handler


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8787)
    ap.add_argument("--approve-after", type=int, default=1, help="polls before pairing approves itself")
    ap.add_argument("--manual", action="store_true", help="wait for POST /v1/devices/pair/approve instead")
    a = ap.parse_args()
    mock = Mock(a.approve_after, a.manual, f"http://{a.host}:{a.port}")
    srv = ThreadingHTTPServer((a.host, a.port), make_handler(mock))
    print(f"[mock] family API on http://{a.host}:{a.port}/v1 (ACORN_FAMILY_URL)", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
