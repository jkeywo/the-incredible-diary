# Mission 1: the unmooring party

Choose **New** or **Continue** on the title screen. `play.tscn` now runs the
six-Hour rescue mission; `opening.tscn` remains the earlier dock-only slice.
`main.gd` remains the authoring feasibility probe.

## Play

- WASD / left stick moves Amelia. Walk into a labelled doorway to change screens.
- Nearby actions appear in a radial wheel. Use its number, or right stick and RB.
- Tab / Y opens the diary and pauses simulation time.
- Hold F / LT to wait at 20x speed. Acceleration stops at the next Hour; release
  and press again to wait through another Hour.
- H / X highlights available interactions. Escape / B interrupts an action or closes code entry.
- Enter three digits using 1–6 or the controller wheel. Enter / the wheel's
  Confirm submits; Backspace / Clear clears all digits. Entry does not pause.
- R / Back turns back the diary after the first death. A second press skips the
  recorded rewind. Observations and learned procedures survive; physical state
  and the three-digit code reset. The end-of-leg summary stays readable until
  Enter / A starts the next attempt.
- Space opens the existing shared pause editor. Mission rules live in
  `simulation.gd`; room geometry and connections live in `rooms.gd`. The separate
  Test Level retains the foundation's structured authoring tools.

The brass pocket watch is driven by simulation time. It shows Hour 1 at 1:00,
then six complete Hours through 7:00, including the whole of Hour 6. Each Hour
lasts 180 real seconds at normal speed. Diary and editor pauses stop its hands;
waiting and recorded rewind change them with the simulation.

## Implemented route (spoilers)

1. On the docks, hear the luggage mix-up before the owner boards, then hide the
   bag beside the baggage screen. A familiar loop permits inspection to recover
   the lead. The normal boarding opportunity is 80 seconds into Hour 1.
2. In Hour 2, stand by the engineer in the left controls room. Hear the complete
   demonstration once; on subsequent loops, hearing the current code is enough.
   The demonstration waits only within its fixed window. Late arrivals hear
   remaining lines, not a replay.
3. In Hour 3, stand near the foyer guest. The chandelier creaks at 3:16 on the
   watch; its eight-second warning permits a timed Shove.
4. In Hour 4, reach the controls before the steam traps the talkative passenger
   (ten seconds into the Hour), then enter the code and confirm. An early
   shutdown is undone by the engineer. The escape takes eight seconds; an early
   rescue lets the passenger catch the luggage owner in the cabin corridor.
5. In Hour 5, bump the luggage owner after witnessing the spiking at the salon.
   His ruined outfit takes him away until the party ends.
6. Survive the full sixth Hour to complete the mission. Completion and the
   location-rewriting unlock are retained; Mission 2 itself is outside this build.

The foyer, controls, salon and cabin corridor form a circular route. The porter
makes the central stair shortcut available in Hour 4; familiar loops still need
to inspect its latch. This keeps the early drink and chandelier rescues in
conflict. These within-Hour timings and shortcut opening are implementation
choices for initial playtesting, not additions to the design's fixed rules.

## Persistence

`user://mission1_v2.journal` is a single append-only autosave, written every
simulation second and on diary/focus/exit boundaries. Each transaction stores
new recorded snapshots, current state and retained knowledge with a checksum.
Loading resumes actions, demonstration progress and code entry without replaying
completed events. A partial final transaction falls back to the last verified
transaction; the next save rewrites a clean journal. Reset rotates the previous
leg only after visible rewind finishes or is skipped. Rewind renders recorded
NPC and player positions. It never simulates the past from later edits.

The old opening save is left intact and is not treated as a full mission save.
A hard crash can lose up to one simulation second since the last transaction.
Browser persistence relies on the browser allowing IndexedDB storage.

## Verification

`tools/dev.ps1 Test` runs the original probe, foundation checks and eight Mission
1 suites covering watch hands, rooms, knowledge gates, each rescue, full victory
and failure, real doorway travel, early-rescue conflicts, exact save/resume,
corrupt-tail recovery, diary/editor pause, waiting, code entry and rewind skip.
The Mission 1 suites also run in GitHub Actions.

`tools/dev.ps1 ExportWeb` and `ExportWindows` build both targets. Native viewport
captures cover all five screens. A Chrome smoke check exercised the web title,
New, movement, diary, page reload and Continue with no script or page errors.
The save test checks recorded history and deterministic continuation; the
browser smoke check is not a complete controller or browser compatibility test.

The causal chain still needs unprompted human playtesting against the GDD's
learning criterion. Timing and presentation can be tuned from that evidence.
