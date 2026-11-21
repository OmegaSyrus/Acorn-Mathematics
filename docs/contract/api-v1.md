# The /v1 API

Games call only these paths, never Supabase directly, so shipped game
versions keep working if the service underneath changes. `/v1` is never
broken: a new need is a new optional field, or a `/v2` path beside it.

Base address: `https://<project>.supabase.co/functions/v1/api/v1` until the
domain exists (Terrence's to-do), then `https://api.<domain>/v1`. The game
keeps the base address in one setting so a build can point at staging.
Implementation: `supabase/functions/_shared/api.ts` in Acorn-Backend.

## Who calls what

| Caller | Header |
| --- | --- |
| Parent web app | `Authorization: Bearer <Supabase Auth access token>` (email link or Google) |
| Game on a device | `Authorization: Device <token>` from pairing |
| Game build (CI) | `Authorization: Publisher <key>` to publish a manifest |
| Scheduled job | `Authorization: Cron <key>` |
| Anyone | only `pair/start`, `pair/poll`, `health` and reading a manifest |

Parents sign in with the Supabase Auth client in the web app (email link and
Google first, more providers later). Linking a second sign-in is Supabase
Auth's identity linking, done while signed in; there is no `/v1/auth` path.
The web app also reads its own family's rows straight from the database,
limited by row-level security; the calls below are what needs more than that.

## Calls

```text
GET    /v1/health
POST   /v1/family                      {consent_version}        parent: make the family (first sign-in)
GET    /v1/family                                               parent: family, adults, children, devices + profiles
DELETE /v1/family                                               owner: delete everything
GET    /v1/family/export                                        parent: family.export JSON
POST   /v1/family/children             {nickname, birth_year?, picture?}
PATCH  /v1/children/{child}            {nickname?, birth_year?, picture?}
DELETE /v1/children/{child}                                     owner
POST   /v1/devices/pair/start          {game, dev, app, code}   anyone (the tablet)
POST   /v1/devices/pair/approve        {code, device_name}      owner or caregiver
GET    /v1/devices/pair/poll?pair_id=                           the tablet
PATCH  /v1/devices/{dev}               {name}                   owner or caregiver
DELETE /v1/devices/{dev}                                        owner or caregiver: the tablet hears "gone"
GET    /v1/devices/{dev}/profiles                               the device itself: its map + the family's children
PUT    /v1/devices/{dev}/profiles      {profiles: [...]}        the device itself
PUT    /v1/events/{game}/{dev}/{first_seq}-{last_seq}           the device itself
GET    /v1/children/{child}/games/{game}/records?days=&limit=   parent: the child's play log lines
GET    /v1/children/{child}/games/{game}/snapshots              device or parent of the family
PUT    /v1/children/{child}/games/{game}/snapshots/{dev}        the device itself
GET    /v1/children/{child}/games/{game}/settings               device or parent
PATCH  /v1/children/{child}/games/{game}/settings               device, owner or caregiver
PUT    /v1/games/{game}/manifests/{code}                        publisher
GET    /v1/games/{game}/manifests/{code|latest}                 anyone
POST   /v1/admin/retention                                      cron
```

Later (threads 5 to 8): `POST /v1/family/invites` (second adult),
`GET /v1/children/{child}/games/{game}/report`, `POST /v1/devices/join/{provider}`
(Steam or Xbox silent join).

## Family and consent

The first time a parent signs in, the web app shows the consent text and
calls `POST /v1/family` with its version (`2026-11-v1` today). That makes the
family, the parent its owner, and a consent record (version, time, method).
Nothing a tablet sends is accepted before a family exists and a parent of it
approves the pairing.

## Pairing (no child ever types a login)

1. Game: `POST /v1/devices/pair/start` with `{game, dev, app, code}`.
   Answer `201`: `{pair_id, code: "K7Q-42M", qr_url, expires_in: 600}`. The
   game shows the code and a QR behind the parent PIN. Codes skip look-alike
   letters (no 0, O, 1, I, L) and accept lower case and spaces.
2. Parent, signed in on their phone: `POST /v1/devices/pair/approve` with
   `{code, device_name: "Kitchen tablet"}`. A tablet that belongs to another
   family is refused (`409`) until that family removes it.
3. Game polls `GET /v1/devices/pair/poll?pair_id=` every 3 s, backing off:
   `{state: "waiting", expires_in}`, `{state: "expired"}`, or once approved
   `{state: "approved", device_token, family, dev, name, children: [{child, nickname, picture}]}`.
   The token is handed over once; the server keeps only its hash. It goes in
   `user://device_token.json`, which is never backed up.
4. Game: `PUT /v1/devices/{dev}/profiles` with
   `{profiles: [{profile, child, nickname, picture, guest}]}`: which local
   profile is which child, picked on the tablet behind the PIN. A Guest never
   maps to a child. Profiles are added or updated, never forgotten, so old
   events keep their child. The answer is
   `{profiles: [{profile, child, nickname, picture, guest}], children: [{child, nickname, picture}], created: [{profile, child}]}`
   (`children` and `created` added 2026-11-21; older games ignore them).
5. A profile made on the tablet after pairing (profile plan C4, 2026-11-21):
   send its item with `"child": "new"` and its `nickname` (1 to 24
   characters) and `picture`. The server makes the family child, maps the
   profile to it, and lists it in `created`. Sent again, the profile already
   maps to that child, so no second child is made. Past 12 children in the
   family the whole call answers `409 {error: "conflict", reason: "children_limit", profile}`
   and nothing in it is written. A Guest with `"child": "new"` stays unmapped.
6. `GET /v1/devices/{dev}/profiles` (profile plan C3, 2026-11-21) answers the
   same `{profiles, children}` at any time, so a tablet sees a child a parent
   added or removed on the web after pairing. A removed child leaves
   `children`; a profile that mapped to it keeps its row with `child: null`.
   Only the device itself may call it (`403` for any other device, `410` once
   a parent removed it).

## Events

`PUT /v1/events/{game}/{dev}/{first_seq}-{last_seq}`, body = event lines for
that range, one per line, `Content-Encoding: gzip` (at most 256 KB
compressed, 4 MB unpacked) or plain text.

- `201 {stored: true, lines, children, unmapped_profiles}`.
- The same range again: `200 {stored: false, duplicate: true, lines}`.
- Every line must be a JSON object; `seq` inside the range and `dev` equal
  to the path when present. Version 2 lines are checked against
  `event.v2.schema.json`; older versions are stored as they are.
- Lines of a profile the device has not mapped are stored and reported in
  `unmapped_profiles`, and stay out of reports until mapped.
- The game saves its upload position only after a `2xx`, and the play log
  never rotates away unsent lines. Guest profiles' lines are never sent.

## Play records

`GET /v1/children/{child}/games/{game}/records?days=30&limit=2000` (parents
of the family only; `days` 1 to 400, `limit` 1 to 5000) answers
`{child, game, days, lines: [...], truncated}`: the event lines of every
profile mapped to the child now, from batches received in the window,
newest first. A profile mapped after its lines were sent counts from then
on. The parent web app builds its summary from these lines.

## Snapshots

`PUT .../snapshots/{dev}` with a `family.snapshot` body (at most 512 KB).
The server keeps the latest per child per game per device: `rev` must be
higher than the stored one, else `409 {stored_rev}`. The stored copy's
`child` is set to the path's child. `GET .../snapshots` returns
`{child, game, snapshots: [...]}`, every device's latest, newest first; the
game merges them (`games/acorn-math/README.md`).

## Settings

`GET .../settings` returns `family.settings`. `PATCH .../settings` with
`{"fields": {"daily_minutes": {"value": 30}}}`. Keys and value types come
from the game's latest manifest (`int` with min and max, `bool`, `time` as
`HH:MM` or null, `enum`); an unknown key, a `scope: "device"` key or a bad
value is `422`. The server sets one new `rev` for the change, `at` and `by`
(`parent` or `device:<dev>`), and answers with the whole document. Latest
change wins per field.

## Manifests

A game build publishes its manifest (`manifest.v1.schema.json`) with
`PUT /v1/games/{game}/manifests/{code}` and the publisher key. Anyone may
read one (`GET .../{code}` or `.../latest`); they hold no child data.

## Errors

`{"error": "<code>", "detail": "<text>"}` with codes `bad_request` (400),
`unauthorized` (401), `forbidden` (403), `not_found` (404), `conflict`
(409), `gone` (410: the device was removed; the game drops its token and
plays on unpaired), `too_large` (413), `unprocessable` (422) and `internal`
(500).
