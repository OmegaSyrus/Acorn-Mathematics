# What is kept, and for how long

Proposed (parent app plan v2). The 24-month limit is not yet approved by
Terrence. Nothing here applies until a family outside his own pairs, and the
privacy policy review comes before that.

## Collected

Parent email and sign-in ids; child nickname, optional birth year, a picture
chosen from the game's set; random device and profile ids; play events;
saves. Never collected: real names, birthdays, photos, voice, location,
contacts, advertising ids. No ads, no third-party analytics.

## Kept

| Data | Kept for | Then |
| --- | --- | --- |
| Raw event batches | while the family is active, up to 24 months after the child's last play | deleted by the scheduled retention job |
| Daily rollups | as long as the raw events they came from | rebuilt or deleted with them |
| Snapshots | the latest per device per child per game | replaced on each upload; deleted with the child |
| Settings | while the child exists | deleted with the child |
| Manifests | for good | no child data in them |
| Consent records | as long as the family exists, plus what the law asks after | |
| A family with no activity for 24 months | | an email warning, 30 days, then deleted |

## On the device

The play log keeps about 2 MB (the current file and one before it). Once
sync is on, it never rotates away lines that have not been uploaded. A
device never holds another family's data. Reset on the main menu clears the
profile's save; removing a profile clears its save file.

## Delete and export

- Per child and per family, from the parent app, and reachable from the
  game's Grown-ups panel (it links to the web page; Apple and Google Play
  require deletion to be easy to reach).
- Delete removes raw events, rollups, snapshots, settings and the child row
  within 30 days, backups included. Devices of a deleted family get `gone`
  and play on unpaired.
- Export is one zip: the family, children, devices, settings, every snapshot
  and every raw event batch as stored.
