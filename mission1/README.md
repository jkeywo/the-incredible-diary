# Mission 1: the unmooring party

Choose **New** or **Continue** on the title screen. `play.tscn` now runs the
rescue mission from 1:00 to 5:30, including the dock tutorial.
`main.gd` remains the authoring feasibility probe.

## Play

- New games begin with a frozen-clock tutorial. Follow the WASD / left-stick
  prompt below Boy, approach the captain, and select **Report for duty**.
  The captain's final instruction starts time and guest arrivals. Diary resets
  skip the tutorial; Continue restores it exactly if unfinished.
- WASD / left stick moves Boy. Walk into a doorway to change screens.
- Only the nearest target offers actions. Click a button, press its number, or
  choose with the right stick and confirm with X. The menu stays over that target.
- Tab / Y opens the diary and pauses simulation time.
- Hold F / B to wait at 20x speed. Acceleration stops at the next Hour; release
  and press again to wait through another Hour.
- H / A highlights available interactions. Escape / B interrupts an action,
  closes code entry, or leaves the cabin-directions submenu.
- Enter three digits using 1–6 or the controller wheel. Enter / the wheel's
  Confirm submits; Backspace / Clear clears all digits. Entry does not pause.
- R or the diary’s rewind button turns back the diary after the first death. A second press skips the
  recorded rewind. Learned procedures, drink preferences and cabin assignments survive; written observations and physical state
  and the three-digit code reset. The end-of-leg summary stays readable until
  Enter / A starts the next attempt.
- Space opens the existing shared pause editor. Mission rules live in
  `simulation.gd`; room geometry and connections live in `rooms.gd`. The separate
  Test Level retains the foundation's structured authoring tools.

The brass pocket watch is driven by simulation time. It shows Hour 1 at 1:00,
and ends at 5:30. Each watch Hour lasts 120 real seconds at normal speed. Diary and editor pauses stop its hands;
waiting and recorded rewind change them with the simulation.

## Optional hospitality and mischief

The Salon bar supplies lemonade, sparkling water and tea. Ask a
guest once per loop for their preference, collect one drink, then offer it.
Asking, collecting, returning and serving are available only in the Salon. A wrong drink
earns a complaint and remains carried; return it to the bar to choose another.
Each guest accepts one correct drink and reacts to one wrong drink per loop.

Inspect cabin nameplates to learn their occupants: Felix Harcourt (1, middle),
Evelyn Vale (2, left), and Mabel Pritchard (3, right). Give cabin directions opens
a choice of inspected cabin numbers. Wrong directions produce a visit to that
door, a complaint, and a return to the guest's normal activity. They are offered
only in the Foyer before the guest discovers their cabin, and when there is
enough time before the next appointment. Blocked detours
return early. One wrong detour per guest per loop; correct directions remain
available afterwards. These optional favours do not affect rescue outcomes or
replace the poisoned drink. Luggage hiding still changes boarding time.

Save schema 3 records frame indices separately from voyage ticks, including
movement and speech while the tutorial clock is frozen. Schema 2 journals load
with their original history and the tutorial completed. `hospitality.gd` owns
guest names, preferences, errand outcomes and temporary routes.

## Implemented route (spoilers)

1. On the docks, hear the luggage mix-up before the owner boards, then hide the
   bag beside the baggage screen. A familiar loop permits inspection to recover
   the lead. The normal boarding opportunity is 80 seconds into Hour 1.
2. In Hour 2, stand by the engineer in the left controls room. Hear the complete
   demonstration to learn how the controls work and hear the current code.
   Code entry is available immediately, even before hearing the demonstration.
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

`tools/dev.ps1 Test` runs the original probe, foundation checks and Mission
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

## Further playtest changes

The searching sailor thanks Boy on a later close approach if Boy retrieved the
bag. Door reading uses thoughts rather than visible nameplates. Subtle unlabelled rectangular room exits remain visible; Highlight strengthens
them. Arrivals land inside the room, clear of the crossing zone. Each voyage-hour
boundary chimes. Three incidental sailors and four guests circulate; two sailors
watch the demonstration.

Steam blocks the far exit physically and fills the trapped half with smoke.
The smaller poisoned glass sits on the Salon bar; the hand and steam visuals
follow recorded voyage time during pause, Continue and rewind.


## Movement, hazards and contextual hints

Main rooms have two triangular guest gathering groups and one sailor group,
with reserved places facing inward. The service passage stays clear. Principal
guests pause in the Foyer for about 20 real seconds before their first cabin
visit; directions can extend that visit without moving major appointments.

The operator leaves after the demonstration, then travels back for checks on
voyage watch boundaries at :00 and :30. He speaks before restoring pressure.
Keeping pressure off until the accident saves the passenger; later restarts
cannot undo that rescue.

The chandelier guest paces and frets on her final visit. She cannot be body
blocked during the approach, but Shove remains available during its warning.
The wreckage blocks its floor footprint, with space to walk around and inspect
it. Her casualty position leaves the body partly visible. The poisoned glass
leaves the bar at pickup and appears empty beside the actual collapse position.

Contextual thoughts teach Highlight on first Foyer entry, Wait after ten real
seconds without gameplay input, and Diary when rewind unlocks. Each hint is
shown once per new game, retained through Continue and resets. They queue behind
dialogue, with Diary taking priority. Idle time excludes unfocused play, menus,
dialogue, actions, opening tutorial and rewind. Prompts follow keyboard,
controller or touch input. Highlight outlines sprite silhouettes in gold;
interactions without a sprite use filled circles. Action names stay in the menu.

Speech placement avoids Boy and controls where possible. When overlap with Boy
is unavoidable, the frame, background and tail use 50% opacity while text stays
opaque. Operator progress, gathering assignments, casualty positions and hint
queues are recorded for Continue and rewind.


### Further playtest decisions — voyage pace and conclusion

The voyage clock advances 1.5 times faster: each watch hour takes two real
minutes. Movement, action progress, speech and visual effects retain their real
speed. The voyage begins at 1:00 and ends at 5:30, after nine active real minutes.
The luggage-delayed bar arrival is now 4:15 so the rescued passenger can still
intercept the luggage owner at the unchanged walking speed.

A successful Shove starts the chandelier dropping immediately. Steam pressure
shows green while on and red while off. Each reset randomly selects a different
three-digit code; Continue retains the recorded code. Spilled glasses remain on
the floor beside the spill, and the bar flowers render in front of the hidden
hand.

Speech boxes choose a position once for each line, then follow the speaker at
that fixed offset. Tails can point from any side. Overlap still fades the panel
without fading the text.

At 5:30 the open diary becomes the mission-over screen: the outcome summary is
on the left page, with buttons on the right. Failure offers the usual rewind;
victory offers **Turn the Page**. Both offer **Return to main menu**. Until the
next mission exists, Turn the Page also returns to the main menu.


### Witnesses, interaction focus and loading

Shoving moves the guest away from Boy and carries Boy forward with her. A
nearby incidental guest approaches after a rescue and says “Close shave”. If
she dies, two incidental guests approach, discuss the tragedy and remain there.
Two different guests gather after the poisoned passenger dies; one calls him a
bore. These assignments and conversation progress survive Continue and rewind.

An incidental sailor checks the steam compartment hourly, avoiding it while the
living passenger is there. Trained crew can cross the steam obstruction. A
sailor finding her body comments and stays. This is separate from the machine
operator’s half-hour checks. Entered digits appear on the machine itself.

Poisoning happens at 5:15. After spilling the drink, Boy can visit the passenger’s
cabin to apologise; the passenger refuses the apology. The mission ends at 5:30.

The interaction menu belongs to the nearest target and never combines different
targets. Its click/number-key hint disappears after three interactions. Buttons
have hover/press feedback and a quiet click with slight pitch variation. Tall
foreground props fade to 50% when their opaque pixels cover a character.

PC startup now uses an animated diary while title resources load in the
background. The engine’s brief pre-runtime splash remains static; the existing
web loading animation remains in place.


## Presentation polish

Chandelier dust, fragments and the small world jolt, drink droplets, and residual
steam are sampled from recorded frame time. Steam shutdown records whether a
cloud existed; older saves without that timestamp show their steady state.
Collision and rescue deadlines do not wait for effects to finish.

The diary pauses immediately and closes before gameplay resumes. Opening,
closing and reversal use a separate presentation controller. Its pages have
increased left padding and no duplicate speaker/notebook heading.

The watch interpolates the fractional voyage clock, shows active waiting and
briefly accents each forward hour chime. Rewind uses recorded history, with
parchment margins and a short finishing fade. Loading and historical display
never announce fresh hour changes.

The title adds an entrance, masked brass glint and saved-room/time preview.
Settings and title dialogs fade while retaining modal input and pause ownership.
The existing book opening and continuous destination audio remain in place.
The in-flight native loader remains the startup scene; the web loader waits for
both engine startup and a rendered title frame before fading away.

`mission1_polish_test.gd` covers transitions, deterministic effect sampling,
steam save/history restoration, watch interpolation, rewind skip and dialogs.
Run it with `-- --screenshots` on a rendering-capable Godot process for captures
in ignored `build/`. `node tests/loading_handoff_test.js` checks both loader
readiness orders, reduced motion, actual progress and persistent startup errors.


### Front-end controller navigation

The Continue preview occupies a reserved row below its button. Finished voyages
show their outcome instead of the last room, alongside the saved voyage time.
The title also has an explicit Settings entry.

Left stick or D-pad moves focus, A selects, and B backs out of settings and
dialogs. B on the top-level title does not quit. Menu/Start opens Settings on
the title and during gameplay. In Settings, left/right adjusts sliders in five
percentage-point steps or changes the joystick-side choice. LB/RB cycles visible
tabs and focuses the selected tab's first control. Closing restores the previous
pause state and focus. Controller events are consumed by the active menu.


### The diary's magic and pages

Seeing the first body in a playthrough queues Amelia's thought about the diary
shaking, followed by the input-specific Open diary prompt. The thought waits
behind current dialogue and persists across Continue and subsequent loops.
A New playthrough can prompt again. Unseen deaths do not trigger it.

Diary observations fill both sides of numbered spreads, without scrolling. Each
opening starts at the last spread. The final right page holds the voyage actions without explaining rewinding. Earlier spreads contain observations only. Previous /
Next buttons, Left/Right or Page Up/Page Down, and controller LB/RB turn spreads;
A selects a focused action and B closes the diary during a running voyage.
The pager measures the display font and balances the final text pages to reserve
the final right page without inserting an empty spread.

Diary discovery is once per playthrough, retained across loops and Continue. Amelia notices the diary shaking on first seeing a body; the Open diary prompt leads to a sparkling “Turn back to the start” button. The diary does not explain rewind in advance.
