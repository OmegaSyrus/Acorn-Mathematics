"""Writes content/ellwynn_cues.json, the list of every place Ellwynn speaks.

Source: the Claude Doc "Ellwynn's lines: where she speaks" (28 Nov 2026),
https://claude.ai/artifact/FfYQrhw48M3Eef5eJS5cHe . One row per cue id there.
Run: python3 -I tools/voice/make_cues.py   (then commit the json)

Fields per cue:
  id        the sheet's cue id; the drop-in files are named after it
  when      when it fires (from the sheet)
  need      "basic" or "later"
  versions  how many takes the sheet asks for (files id, id_2, id_3 ...)
  fallback  what plays while no file is dropped in:
              "placeholder"  one of the three stand-ins (Yay, Woo-hoo, Let's go)
              "tts"          the tablet's own text-to-speech reads `say`
                             (Debug > Stand-in voice turns it off)
              "quiet"        nothing
  say       stand-in words for "tts" (NOT Ellwynn's line; Terrence and
            Rachel write those). Mostly the words on screen.
  bubble    sight word shown in her bubble while it plays, or ""
  order     true: play every file in order (the intro), not one at random
  once      true: plays once per child, then never again (taught first turn)
  alias     the older code name, so say("intro") still works
"""
import json, os

P, T, Q = "placeholder", "tts", "quiet"
rows = [
 # id, need, versions, fallback, say, bubble, extra
 ("K1","basic",1,T,"Who is playing?","", {"when":"Who is playing? screen opens"}),
 ("K2","basic",3,P,"","Hi!", {"when":"A child taps their own picture"}),
 ("K3","basic",1,T,"Pick a picture!","", {"when":"New tapped: pick a picture"}),
 ("K4","basic",1,T,"Ask a grown-up to type your name.","", {"when":"The name box shows"}),
 ("K5","later",2,P,"","Yay!", {"when":"New child saved"}),
 ("M1","basic",7,T,"Hi! I'm Ellwynn. Roll the dice and count the dots. Tap the stone with that number, then tap Go. Monsters swing dice: pick the number to block. Chests have gems for the Shop. You have three hearts. Lose them all and you start again. Tap Play! Tap me to hear this again.","", {"when":"First time the menu opens, and each time she is tapped","order":True,"alias":"intro"}),
 ("M2","basic",3,P,"","", {"when":"Menu opens on a later visit","alias":"welcome"}),
 ("M3","basic",3,P,"","Go!", {"when":"Play tapped","alias":"play"}),
 ("M5","basic",2,P,"","", {"when":"Shop tapped","alias":"shop"}),
 ("M6","later",2,Q,"","", {"when":"Back from the Shop"}),
 ("M7","later",1,Q,"","", {"when":"Level: N button tapped"}),
 ("T1","basic",1,T,"Let's get across!","", {"when":"First crossing opens, hero on the shore","once":True}),
 ("T2","basic",1,T,"Tap Roll!","Roll", {"when":"The dice tray waits","once":True}),
 ("T3","basic",1,T,"Count the dots. Tap each dot to count it.","", {"when":"The die lands","once":True}),
 ("T4","basic",1,T,"Find the stone with that number, and tap it.","", {"when":"Stones light up with numbers","once":True}),
 ("T5","basic",1,T,"Now tap Go!","Go!", {"when":"A stone is picked","once":True}),
 ("T6","basic",1,P,"","Yes!", {"when":"First right hop","once":True}),
 ("T7","basic",1,T,"Oh! That stone sank. You lost a heart. You have three.","", {"when":"First wrong stone","once":True}),
 ("T8","later",1,T,"Gems! Spend them in the Shop.","", {"when":"First chest walked onto","once":True}),
 ("T9","basic",1,T,"A monster! It swings dice. Pick the shield with that number to block.","", {"when":"First fight opens","once":True}),
 ("T10","basic",1,T,"Your turn! Hit back!","", {"when":"First Shield bash turn","once":True}),
 ("T11","later",1,T,"A heart stone gives a heart back.","", {"when":"First heart stone reached","once":True}),
 ("T12","basic",1,T,"Tap the door!","", {"when":"First GO! door at the far shore","once":True}),
 ("T13","later",1,T,"A big monster! Block it, just like before.","", {"when":"First miniboss duel","once":True}),
 ("T14","basic",2,T,"Pick the number on the ball.|Now aim, and let go!","", {"when":"First boss fight (1: pick the number, 2: aim)","once":True,"order":True}),
 ("T15","later",1,Q,"","", {"when":"First pip tap on a die","once":True}),
 ("P1","basic",1,T,"Pick a world!","", {"when":"World map opens"}),
 ("P2","later",1,T,"Beat the world before it first.","", {"when":"A locked world tapped"}),
 ("P3","basic",2,T,"Roll!","", {"when":"Dice tray waits on a crossing"}),
 ("P4","basic",2,T,"Which stone is safe?","", {"when":"Dice landed, stones offered"}),
 ("P5","basic",1,T,"Roll again!","", {"when":"Roll the same guess again after a miss"}),
 ("P6","basic",1,T,"Go!","", {"when":"Far shore reached, golden arrow"}),
 ("P7","basic",2,T,"Block!","", {"when":"Fight: the monster swings"}),
 ("P8","basic",2,T,"Shield bash!","", {"when":"Fight: the hero's turn"}),
 ("P9","basic",1,T,"Tap the door!","", {"when":"Fight won, door to go on"}),
 ("P10","basic",1,T,"Try again!","", {"when":"Miniboss lost, retry button"}),
 ("P11","basic",1,T,"Pick the number!","", {"when":"Boss: pick the ball's number"}),
 ("P12","later",1,T,"No more balls.","", {"when":"Boss: out of balls"}),
 ("P13","later",1,Q,"","", {"when":"Shop opens"}),
 ("W1","basic",2,Q,"","", {"when":"Lava Caves crossing opens"}),
 ("W2","basic",2,Q,"","", {"when":"Crystal Mines crossing opens"}),
 ("W3","basic",2,Q,"","", {"when":"The Bog crossing opens"}),
 ("W4","basic",2,Q,"","", {"when":"Mushroom Forest crossing opens"}),
 ("W5","basic",2,Q,"","", {"when":"Space star track opens"}),
 ("W6","later",2,Q,"","", {"when":"Warm-up done, the level's own math starts"}),
 ("N1","basic",1,T,"Two dice! Add them up.","", {"when":"First time two dice show (Crystal 1)","once":True}),
 ("N2","later",1,Q,"","", {"when":"Bigger numbers (the top goes up)","once":True}),
 ("N3","basic",1,T,"The red die takes away!","", {"when":"First take-away (Lava 2)","once":True}),
 ("N4","basic",1,T,"Three dice!","", {"when":"First three dice (Crystal 2)","once":True}),
 ("N5","basic",1,T,"The stones show their place.","", {"when":"Star track (Space 2)","once":True}),
 ("N6","later",1,Q,"","", {"when":"Rails: only 1, 5, 10, 15 numbered (Crystal 3)","once":True}),
 ("N7","later",1,Q,"","", {"when":"Four dice (Lava 4)","once":True}),
 ("N8","later",1,T,"One die is hidden. Find the missing number!","", {"when":"Hidden die (Lava 5)","once":True}),
 ("N9","later",1,Q,"","", {"when":"Hidden die can be any (Mushroom 5)","once":True}),
 ("N10","later",1,Q,"","", {"when":"Take away across ten (Lava 6)","once":True}),
 ("N11","later",1,Q,"","", {"when":"Everything mixed (Mushroom 6, Space 6)","once":True}),
 ("C3","basic",4,Q,"","", {"when":"Right stone picked: a cheer after the number (falls back to Woo-hoo)"}),
 ("C5","basic",4,P,"","", {"when":"Chest opened (2 in 3)","alias":"chest"}),
 ("C6","basic",2,Q,"","", {"when":"Far shore reached"}),
 ("C7","later",2,Q,"","", {"when":"Star earned: crossing done with no heart lost"}),
 ("F1","basic",3,Q,"","", {"when":"A monster appears (Fight!)"}),
 ("F3","basic",3,Q,"","", {"when":"Hit blocked (sometimes)"}),
 ("F4","basic",2,Q,"","", {"when":"Took a hit, heart lost (before the number)"}),
 ("F5","basic",4,P,"","Yay!", {"when":"Monster beaten (pop-in 1 in 3)","alias":"enemy"}),
 ("F6","basic",2,Q,"","", {"when":"Fight lost, back to the start"}),
 ("F7","later",1,Q,"","", {"when":"Mimic chest snaps open"}),
 ("D1","basic",1,Q,"","", {"when":"Lava miniboss: Surtling Chief"}),
 ("D2","basic",1,T,"Look fast! The dice go dark. Tap one to light it.","", {"when":"Crystal miniboss: Svartalf Lantern Lord"}),
 ("D3","basic",1,T,"Two foes! They take turns.","", {"when":"Bog miniboss: Wisp King and Queen"}),
 ("D4","basic",1,T,"Count on! Start from the number, then count the dots.","", {"when":"Mushroom miniboss: the Hedley Kow"}),
 ("D5","basic",1,T,"Read it! Tap a number to see the dots.","", {"when":"Space miniboss: Ratatoskr"}),
 ("D6","basic",2,P,"","", {"when":"Duel won, door to the boss"}),
 ("D7","basic",2,Q,"","", {"when":"Duel lost, Try again button"}),
 ("D8","later",2,Q,"","", {"when":"Bog only: the King or the Queen is out"}),
 ("B1-lava","basic",1,Q,"","", {"when":"Boss appears: the Skeleton Dragon"}),
 ("B1-crystal","basic",1,Q,"","", {"when":"Boss appears: the Knocker King"}),
 ("B1-bog","basic",1,Q,"","", {"when":"Boss appears: Jenny Greenteeth"}),
 ("B1-mushroom","basic",1,Q,"","", {"when":"Boss appears: the Green Man"}),
 ("B1-space","basic",1,Q,"","", {"when":"Boss appears: Fenrir"}),
 ("B2-lava","basic",2,P,"","Yay!", {"when":"Skeleton Dragon beaten"}),
 ("B2-crystal","basic",2,P,"","Yay!", {"when":"Knocker King beaten"}),
 ("B2-bog","basic",2,P,"","Yay!", {"when":"Jenny Greenteeth beaten"}),
 ("B2-mushroom","basic",2,P,"","Yay!", {"when":"Green Man beaten"}),
 ("B2-space","basic",2,P,"","Yay!", {"when":"Fenrir beaten"}),
 ("B3","basic",2,Q,"","", {"when":"Lost to the boss (Oh no!)"}),
 ("B4","later",3,Q,"","", {"when":"Boss moments: new pegs, combo, big gem bucket"}),
 ("H1","basic",3,Q,"","", {"when":"Wrong stone: the sink (never the answer yet)"}),
 ("H2","later",2,Q,"","", {"when":"Lead-in before she says the right number"}),
 ("H3","basic",1,Q,"","", {"when":"The 'then' in a count-on after a miss","alias":"count_then"}),
 ("H4","basic",1,Q,"","", {"when":"The 'then' counting back on the red die","alias":"count_back_then"}),
 ("H5","later",1,Q,"","", {"when":"Hidden die help after a miss"}),
 ("H6","later",2,Q,"","", {"when":"Two misses in a row on one guess"}),
 ("H7","later",1,Q,"","", {"when":"She stops counting pips (two monsters beaten)","alias":"count_quiet"}),
 ("R1","basic",2,Q,"","", {"when":"Heart stone reached, a heart comes back"}),
 ("R2","later",2,Q,"","", {"when":"Down to the last heart"}),
 ("R3","basic",3,Q,"","", {"when":"All hearts gone, hero back at the start"}),
 ("L1","basic",2,P,"","", {"when":"Map opens after a boss win: next world opens"}),
 ("L2","later",2,Q,"","", {"when":"First clear of a world at this Level"}),
 ("L3","basic",1,P,"","Yay!", {"when":"Level complete: Space beaten, the next Level opens"}),
 ("L4","later",6,Q,"","", {"when":"Level complete, one line per Level (L4_1 .. L4_6 by Level)","order":True}),
 ("L5","later",2,Q,"","", {"when":"A world replayed that is already beaten"}),
 ("S1","basic",3,P,"","Yay!", {"when":"Bought a hero or a dragon colour"}),
 ("S2","basic",2,Q,"","", {"when":"Tapped a grey Buy: not enough yet"}),
 ("S3","later",2,Q,"","", {"when":"Put on a hero or colour (Use)"}),
]
cues = []
for cid, need, versions, fb, say, bubble, extra in rows:
    c = {"id": cid, "when": extra["when"], "need": need, "versions": versions,
         "fallback": fb, "say": say, "bubble": bubble}
    for k in ("order", "once", "alias"):
        if k in extra:
            c[k] = extra[k]
    cues.append(c)
out = {
  "version": 1,
  "_note": "Every place Ellwynn speaks, by the lines sheet's cue id. Made by tools/voice/make_cues.py; drop-in rules in docs/voice-drop-in.md.",
  "cues": cues,
}
root = os.path.join(os.path.dirname(__file__), "..", "..")
with open(os.path.join(root, "content", "ellwynn_cues.json"), "w") as f:
    json.dump(out, f, indent=1)
    f.write("\n")
print(len(cues), "cues")
