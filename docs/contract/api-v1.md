# The /v1 API

Games call only these paths, never Supabase directly, so shipped game
versions keep working if the service underneath changes. `/v1` is never
broken: a new need is a new optional field, or a `/v2` path beside it.

Base address: the project's own `https://<project>.supabase.co/functions/v1`
until the domain exists (Terrence's to-do), then `https://api.<domain>/v1`.
The game keeps the base address in one setting so a build can point at
staging.

## Who calls what

| Caller | Proves who it is with |
| --- | --- |
| Parent web app | Supabase Auth session (email link, Google first) |
| Game on a device | `Authorization: Device <token>` from pairing |
| Anyone else | nothing; only `pair/start` and `pair/poll` work |

## Calls

```text
POST  /v1/auth/email/start            POST /v1/auth/{provider}/callback
POST  /v1/identities/link             DELETE /v1/identities/{id}
POST  /v1/devices/pair/start          POST /v1/devices/pair/approve     GET /v1/devices/pair/poll
POST  /v1/devices/join/{provider}     (Steam or Xbox silent join, later)
GET   /v1/family                      POST /v1/family/children          POST /v1/family/invites
PUT   /v1/devices/{dev}/profiles      (which local profile is which child)
PUT   /v1/events/{game}/{dev}/{first_seq}-{last_seq}
GET   /v1/children/{child}/games/{game}/snapshots     PUT .../snapshots/{dev}
GET   /v1/children/{child}/games/{game}/settings      PATCH .../settings
GET   /v1/children/{child}/games/{game}/report?from=&to=
PUT   /v1/games/{game}/manifests/{code}
GET   /v1/family/export               DELETE /v1/family
```

## Pairing (no child ever types a login)

1. Game: `POST /v1/devices/pair/start` with `{game, dev, app, code}`.
   Answer: `{pair_id, code: "K7Q-42M", qr_url, expires_in: 600}`. The game
   shows the code and a QR behind the parent PIN.
2. Parent, signed in on their phone: `POST /v1/devices/pair/approve` with
   `{code, device_name: "Kitchen tablet"}`. The server records consent
   (version, time, method) the first time a family pairs.
3. Game polls `GET /v1/devices/pair/poll?pair_id=` every 3 s (backing off).
   Once approved: `{device_token, family, children: [{child, nickname, picture}]}`.
   The token goes in `user://device_token.json`, which is never backed up.
4. Game: `PUT /v1/devices/{dev}/profiles` with the roster's non-guest
   profiles and the child each one is (picked on the tablet, behind the PIN).

## Events

`PUT /v1/events/{game}/{dev}/{first_seq}-{last_seq}` with
`Content-Encoding: gzip`, body = the event lines (`family.event`, any
version) for that sequence range, one per line, at most 256 KB compressed.

- Same range sent again: `200 {"stored": false, "duplicate": true}`.
- Lines whose `dev` differs from the path, or whose profile the device has
  not mapped: stored, flagged, left out of reports until mapped.
- The game saves its upload position only after a `2xx`, and the play log
  never rotates away unsent lines.
- Guest profiles' lines are never sent.

## Snapshots

`PUT .../snapshots/{dev}` with a `family.snapshot` body. The server keeps
the latest per child per game per device (`rev` must be higher than the
stored one, else `409` with the stored rev). `GET .../snapshots` returns
every device's latest for that child; the game merges them.

## Settings

`GET .../settings` returns `family.settings`. `PATCH .../settings` with
`{"fields": {"daily_minutes": {"value": 30, "rev_seen": 6}}}`; the server
sets `rev`, `at` and `by` and answers with the whole document. Latest
change wins per field. Unknown keys for that game's manifest: `422`.

## Errors

`{"error": "<code>", "detail": "<text>"}` with codes `bad_request`,
`unauthorized`, `not_found`, `conflict`, `too_large`, `rate_limited`,
`gone` (device removed by the parent: the game drops its token and plays
on unpaired).
