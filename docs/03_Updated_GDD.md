# The Incredible Diary of Lady Amelia Ashcombe

## Current game design document

Companion records: [Original research](01_Original_Research.md) · [Unabridged design grill](02_Full_Grilling_Session.md)

Updated: 28 September 2026. Consolidated through Q135 and the user's correction to Q136; earlier decisions recovered from the user-provided saved HTML on 28 September 2026.

This file is the authoritative current design. It replaces Design_Grill_Working_Notes.md; the research and full grill transcript remain historical companion records. Later explicit user decisions override earlier selections and assistant suggestions. Historical alternatives appear only in the superseded-decisions section. This is a design specification, not a claim that any build exists or has passed testing.

**Working surname:** Ashcombe was supplied by the assistant in response to the user's request to invent a surname. The title remains a working title.

## Playtest corrections — 29 September 2026

These later user decisions supersede conflicting layout and diary details below.

- The first mission's HUD title is **All Aboard**. Exits label the party room **Salon**.
- The Salon is above the Foyer, reached by its central stair from the start. The Cabin Corridor is a dead end off the Foyer. A tight service passage connects the Salon's right exit to the far half of the steam room; the controls half remains accessible from the Foyer.
- The steam operator uses the sailor sprite. Code entry uses the standard interaction wheel: digits 1–6, Clear and Commit.
- On the docks, the passenger complains to a sailor about missing luggage. The suitcase is deeper in the luggage area. Retrieving it permits early boarding; hiding it delays boarding. The sailor searches and recovers it before boarding, clearing its hidden state. The delay remains part of that run's schedule after recovery.
- Closed cabin doors block movement and offer Open; open doors offer Close when the doorway is clear.
- The pocket watch and its hands use sprites. Idle poses keep feet planted; movement has constant speed and continuous animation. Casualties stop on their final frame.
- Inspection reports visible evidence without stating when the event happened or predicting an intervention's consequences.
- The in-game diary conceals Amelia's name and omits loop numbers. It records only witnessed observations in the current run, with hour and minute timestamps. Reset clears the written entries while retaining learned interaction knowledge.
- Editor menus begin to the right of the settings cog.

### Further playtest corrections — 29 September 2026

- If Boy retrieves the luggage, the searching sailor automatically thanks him on a later close approach, once per loop. Automatic sailor recovery does not earn thanks.
- All refreshment errands take place in the Salon. Drinks come from its bar. Each guest can be asked once per loop; learned preferences survive resets.
- Cabin reading shares the door prop and remains available with the door open. No separate nameplate or occupant text is drawn in the world; reading produces a thought and learns the occupant.
- Cabin directions are available only in the Foyer, before the guest finds their cabin or receives correct directions. Wrong directions retain the existing detour and deadline rules.
- Room transitions use rectangles spanning the doorway width. Permanent destination labels and circles are removed; Highlight reveals the rectangles.
- A short chime sounds at each voyage-hour boundary, including during accelerated waiting. Loading and rewind do not replay chimes.
- The poisoned glass sits at the right edge of the Salon bar at background-glassware scale. A smaller hand emerges behind a pillar before pickup. The existing spiking-to-drinking rescue interval is retained.
- Code entry is available at the steam controls immediately, without requiring the demonstration. The active vent physically blocks the trapped half's exit and steam fills that half of the room; shutdown clears both.
- Three incidental sailors and four incidental guests circulate, using the left edge of the Cabin Corridor as a spawn/despawn closet. Two sailors watch the demonstration before resuming rounds. They have no rescue or hospitality objectives.
- Errand completion, cabin discovery, incidental positions and effect timing are recorded in the current leg. Rewind shows the recorded state.

### Mobile browser controls — clarified 29 September 2026

Touch play uses one virtual movement joystick. Interactions are activated by tapping their option buttons directly, including More… and steam-panel digits, Clear and Commit; mouse clicks also activate these buttons. Four compact touch buttons provide Diary, hold-to-Wait, Highlight and Cancel in a 2×2 grid at the bottom right. Rewind is available inside the diary. On touch devices, Settings includes a Controls tab with a saved Left/Right movement joystick preference; the button grid moves to the opposite side. When each side margin has room for the joystick and its touch area, the game stays centred at its fixed aspect ratio and the controls occupy those margins, with the four buttons in a vertical column. Narrow and portrait screens retain the overlaid joystick and 2×2 button grid. There is no selection joystick or Act button. Each finger is tracked independently, allowing movement and interaction together. Modal screens, focus loss and resizing release held controls. The mobile interface omits pause/editor controls.

### Opening audio — clarified 29 September 2026

The main menu plays the saved destination room's music and ambience when Continue is available; otherwise it uses the new game's starting room. Playback starts at half the normal in-game amplitude, after respecting the player's volume preferences. Continue preserves the active tracks and raises their volume smoothly to normal during the book-opening transition. New leaves the preview unchanged until confirmation, then crossfades to the starting room's audio over that same transition. Cancelling New does not affect playback. The existing players transfer into gameplay so tracks shared by the menu and destination do not restart.

### Resource loading — clarified 29 September 2026

PC and web use the same staged loading flow. Initial loading prepares the title, Settings and docks, including docks audio. The title prepares the Continue or New destination in the background. A room prefetches adjacent rooms; character art is prepared as characters arrive. Shared resources are reused across rooms and future missions. Web downloads are cached separately from personal saves; PC prepares the same resources from its installed files.

If Continue or New is selected before its destination is ready, a full-size diary flicks pages above a loading bar, then the existing swipe transition opens into play. If travel or a character arrival outruns preparation, simulation time waits until the required resources are ready. Recorded history is unchanged. Failed loading offers recovery, and New does not erase an existing voyage until its destination is ready. A saved room's title audio starts when that room is ready.

### Chandelier staging — clarified 29 September 2026

The chandelier hangs above the compass rose at the centre of the Grand Foyer. The guest's danger position, shove interaction and wreckage inspection share that floor position. The fixture visibly drops from overhead with accelerating downward motion, then changes to wreckage and dust at impact. The fall is sampled from recorded simulation time, including during rewind.

### Interaction menu — clarified 29 September 2026

Use a Sims-inspired arrangement around the nearest interaction target: up to four separate textured option buttons on each side. Buttons use the game's navy-and-brass art style. Eight choices fit without paging. Longer lists show seven actions and a final **More…** option; additional pages cycle back to the first. Mouse clicks, number keys 1–8, and right-stick selection with X confirmation all address the visible choices.

### Dialogue presentation — clarified 29 September 2026

Conversations play out as alternating spoken lines in textured bubbles above the speaker. Thoughts use a distinct cloud outline and trailing dots, with the same navy-and-brass texture palette. Text appears with a typewriter effect; line timing and speaker identity are recorded with simulation history so pausing, saving and rewinding preserve what was shown. The diary records witnessed speech after its text has appeared. Character labels use roles and keep Amelia's identity secret. Inspections use thoughts; status text remains for controls and system feedback.

### Passenger movement and staging — clarified 29 September 2026

Passengers appear on the docks during Hour 1, board after their prerequisites, visit cabins and hold conversations before taking their places for significant events. They walk through connected rooms at a constant speed. Characters have solid foot-level collision with each other and Amelia; recorded history includes their resolved positions. Closed cabin doors block movement and passengers open doors on their routes. The missing suitcase starts in the clear aisle left of the luggage stacks. Stationary animations keep the feet planted while the upper body moves, with the visible soles aligned to the floor and a contact shadow.

## 1. Identity and intended experience

### Dock tutorial and optional hospitality — agreed 29 September 2026

A new game begins with Boy in the middle of the docks and the captain beside
the gangway. Contextual WASD/left-stick prompts teach movement; approaching the
captain teaches the interaction wheel and Report for duty. The captain addresses
the player only as Boy and instructs him to explore the ship, help with luggage,
bring refreshments and show guests to their cabins. Voyage time, arrivals and
hazards remain frozen while movement and spoken dialogue run. The final line
starts the clock; the captain walks up the gangway and disappears. Guests enter
the docks before their existing boarding commitments. Diary resets skip this
tutorial; an unfinished tutorial resumes from its save.

| Guest | Cabin | Refreshment |
|---|---|---|
| Mr. Felix Harcourt (luggage owner) | 1, middle | Lemonade |
| Miss Evelyn Vale (chandelier guest) | 2, left | Sparkling water |
| Mrs. Mabel Pritchard (steam guest) | 3, right | Tea |

These names replace provisional passenger labels in dialogue. The player's
speaker label is Boy. All cabin doors have a reading action, including when open; no separate
nameplate text is drawn. Inspecting a plate teaches its occupant. Asking about
refreshments reveals the guest's preference; learned preferences and cabin
assignments survive diary resets, while written observations remain per-run.

Optional errands have helpful and mischievous choices. Boy carries one drink
from the Salon bar and can return it to choose another. Correct
drinks receive thanks; wrong drinks are refused with personalised complaints and
remain carried. Each guest permits one wrong-drink reaction and one successful
delivery per loop. After rejection only the requested drink can be offered to
that guest. Refreshments do not replace the poisoned glass or change schedules.

Cabin directions offer inspected cabin numbers. Correct directions receive
thanks. Wrong directions make the guest visit the named door, read its plate,
complain about the mismatch, and return without entering the wrong cabin.
Directions are offered only in the Foyer before cabin discovery. Detours remain
available outside critical scenes, with sufficient
time for travel, reaction and return before the next commitment. One wrong
detour per guest per loop is allowed, followed by correct directions. Blocked
detours return early; scheduled commitments take priority. No stacked detours,
checklist or reward system. Existing luggage hiding/retrieval retains its
boarding consequences.

Recorded-frame indices advance independently of voyage ticks during the
tutorial. Saves and history include tutorial progress, dialogue, resolved actor
positions, carried drinks and errand outcomes. Older journals retain their
recorded frames and load with the tutorial completed.

A pixel-art time-loop rescue game set aboard a 1920s Mediterranean cruise ship, in which Amelia observes passengers and crew, learns their routines, and uses ordinary interventions, later diary powers, and increasing authority to construct a timeline in which everyone survives. Individual rescues are insufficient: their timing and consequences must fit together.

The framing is reading the diary of our great-great-aunt, found in a dusty loft. We play Amelia, a girl dressed as a boy. The Mission 8 conspiracy clue reveals this and enables outfit switching, granting additional access and many more options during the investigation playthrough. The title's “Lady” foreshadows a potential sequel; it is not a newly assigned starting rank.

**Visual presentation — clarified 29 September 2026:** Amelia must read as a boy at gameplay sprite size. Keep cropped hair and a straight, boxy uniform silhouette consistent across standing, walking and action poses; do not introduce a visible bun or a fitted feminine silhouette.

**Amelia starts as a junior purser / general ship’s clerk.** Her role covers passenger requests, tickets, manifests, messages, keys, complaints and coordination between departments. She receives two promotions during the voyage. Each expands legitimate ship access and social authority through defined responsibilities. This was recovered from the saved conversation; Q136 was an erroneous repeat question, not an unresolved design choice. Exact promoted titles and permission lists remain examples rather than confirmed specifics.

Mission 1 has the tone of a comedy of errors: inconvenient, apparently rude interventions save lives. In particular, Amelia repeatedly inconveniences Character 1 to keep them away from a poisoned drink.

Each ordinary level is the journey between two ports. A campaign map shows progress along the cruise; saving everyone on a leg in one run permits advancement. Mission 1's later-defined dock opening remains part of its specific onboarding design.

The original motivation was to combine individually learned rescues into one compatible successful timeline, rather than merely save each person once across separate attempts. The proposed weird hotel was explicitly replaced by the Mediterranean cruise setting.

### Design commitments

- Intersecting NPC behaviour and authored story blocks with state preconditions are part of the original concept. Original Q7 confirms a hybrid: authored hourly anchors for important scenes and commitments, with simple goal/priority logic for mundane activities and responses between them. Other technical architecture proposals in the research response remain advisory.

- Learning should produce better plans and shorter routes through familiar discoveries.
- Schedules are repeatable; changes should be understandable consequences of interventions, with explicitly defined exceptions such as the changing code.
- Several deliberately supported rescue solutions are the intended design, with tolerance for small execution errors.
- Knowledge, navigation, timing and coordination drive difficulty.
- Physical and social interventions are both core systems (original Q5, C). Amelia can change circumstances directly or influence beliefs and actions; successful plans combine both. This does not establish an unrestricted conversation simulator.
- Failure remains useful for observation. A death does not automatically terminate a run.
- Conspiracy investigation is optional for normal campaign completion and provides a subsequent replay arc.

## 2. Scope: whole game, MVP and first playable

| Scope | Agreed content and depth |
|---|---|
| Whole game | High-level campaign, progression, replay, optional conspiracy chain and endings. Normal legs have 4–5 endangered people and last 8–10 in-game Hours. Full campaign includes Mission 8; total mission count is not recovered. |
| MVP | Three legs including a compact finale, a complete rescue campaign, investigation revisits, and a good-ending replay. Medium-detail system scope; later-leg content is not yet specified. |
| First playable | Mission 1: three endangered characters, six Hours, ordinary interventions and diary reset. Detailed representative rescue chain described below. Reality rewriting is not required here. |

Provisional clock rate: approximately three real minutes per in-game Hour. This gives about 18 minutes of normal-speed clock time for Mission 1, and 24–30 minutes for normal mature legs. Diary pauses, accelerated waiting and repeated loops change actual playtime. The exact start/end convention for the six-Hour clock still needs implementation definition; do not silently shorten Hour 6.

The Mission 8 reveal belongs to the full campaign. No decision has moved it into the three-leg MVP.

## 3. Campaign progression and investigation

### Authored continuity between legs

Original Q1 selected specific, authored consequences between legs rather than an unrestricted continuously evolving simulation. Selected relationships, possessions, ship conditions or arrangements may influence later legs; these were example categories, not a commitment to every listed system. This differs from carrying objects out of a failed/reset attempt, which is not allowed.

The exact handling of these dependencies during freely selected non-linear revisits is not yet reconciled in the accessible record. Preserve the authored-continuity goal without restoring the superseded whole-voyage finale or inventing automatic downstream invalidation. Later rules explicitly protect earlier successful completions after failed revisits.

### Powers, ranks and delegation

| Stage | Diary capability |
|---|---|
| Level 1 | Loop/reset through the diary. |
| Level 2 | Location rewriting: At [Hour], [Person] is in [Location]. |
| Level 3 | Possession rewriting: who holds an item at a given Hour. |
| Later levels | Further powers unlock per level; categories are not specified in the accessible record. |

Exactly two rank promotions occur during the voyage, at designated campaign milestones after completing the relevant legs. They unlock both physical access and social authority through defined domains of responsibility, rather than merely opening individual doors. Powers unlock per level independently of rank milestones; they do not alternate with promotions by rule.

### Recovered diary-writing rules

- Writing a permitted diary entry makes it true: powers directly manipulate reality.
- Rewrites have limited uses per level/leg. The numerical allowance and exact replenishment rules have not yet been specified in the recovered material.
- Each power supplies a bounded sentence template. Available people, objects, locations, facts and times come from discovered information; explicit constraints govern valid combinations.
- This is a reusable system, not unrestricted natural-language wishing or only a list of bespoke story edits.
- Original Q4 selected earning the next ability after saving everyone on the preceding leg. Completing Level 1 therefore grants location rewriting for Level 2; completing Level 2 grants possession rewriting for Level 3. The later explicit first-death tutorial makes the initial reset ability an onboarding exception, acquired within Level 1.
- The next level requires the newly unlocked power. Its first passenger rescue for which the power naturally makes sense teaches its use; subsequent rescues combine it with existing abilities.
- Progression begins with reset in Level 1, location rewriting in Level 2, and the later-agreed possession rewriting in Level 3.
- Example promoted titles, detailed access lists, and suggested plausibility restrictions in the original assistant text are not treated as separately approved rules.

Delegation is necessary on some legs and becomes more prominent at later ranks. Helpers require specific conditions established in that loop, such as information, assistance or cover for duties. Higher rank both unlocks larger assignments and simplifies familiar requests. Availability, access and practical means still matter.

Revisiting an earlier leg retains unlocked diary powers but restores the rank appropriate to that leg. Retained powers are what make previously inaccessible conspiracy clues obtainable.

### Investigation and endings

1. Save everyone on ordinary legs to advance. Conspiracy clues are not required to reach the finale or achieve a complete rescue victory.
2. The first finale automatically reveals a clue suggesting more to discover in earlier legs.
3. Completed legs can be selected freely. Each clue points to the next level to investigate, creating a non-linear sequence through the voyage.
4. Obtaining a clue requires saving everyone in the same run. The clue's contents are revealed only on the mission success screen.
5. A failed investigation attempt retains only a reminder of where to investigate, not the clue contents or its next lead.
6. Failed revisits do not erase previous successful leg completions or access to unlocked destinations.
7. The investigation chain eventually returns to the final level, where a second clue unlocks the good ending.
8. Achieving that ending requires a final replay of the last leg: stop the conspiracy through interventions while saving everyone there. No final replay of the entire voyage is required.
9. Saving everyone but failing to stop the conspiracy yields the standard ending. The final clue remains unlocked for another attempt.

Investigation resolves through following people, timing and interventions, not a formal evidence-assembly interface. Some relevant interactions still need their knowledge requirements met in the current loop.

Culprit identities can wait for the conspiracy run. Mission 1's poisoning investigation reveals the immediate danger without identifying who is responsible.

## 4. Time, schedules, reset and persistence

### Time and schedules

- A persistent analogue clock face shows the current Hour and progress towards the next.
- The diary pauses time. Interaction wheels and manual code entry do not.
- Dialogue consumes game time. The accepted recommendation is fixed costs per dialogue step rather than costs determined by reading speed; the precise presentation implementation remains to be worked out.
- Accelerated waiting keeps Amelia in place while the simulation continues. It stops at the next Hour boundary or earlier when the player releases the control.
- Major scheduled scenes and plan changes generally begin on the Hour; NPCs still move and act continuously within it (original Q6). This is an authoring cadence, not a turn-based simulation or a claim that every event can occur only at a boundary.
- Most conditions are fixed within each Hour slot. An action crossing a boundary continues if its requirements still hold.
- NPC schedules repeat unless affected by the player. A run-specific code is an explicit variable exception, not general schedule randomness.
- Hybrid NPC behaviour (original Q7, C): authored major commitments anchor the Hour; simple goals/priorities fill gaps and handle disruptions. This must satisfy the later repeatability rule: the same state and interventions produce the same behaviour, rather than introducing random schedule drift.
- Direct conversation may briefly delay an NPC's departure. Afterwards they catch up to the current schedule, shortening or skipping missed activity instead of shifting every later Hour.
- Substantial deliberate distractions require authored interactions. Their labels state Amelia's intention, not the resulting rescue solution.

### Failure and reset

- Amelia cannot die in the first playable.
- Another character's death immediately produces a diary notification naming them, without revealing an unobserved location or cause.
- The first death introduces the diary reset through a brief tutorial. Players may reset or continue investigating.
- Once introduced, manual diary reset is available anywhere at any time; no cabin, desk or ritual location is required (original Q9, B). If a leg ends without everyone saved, it resets automatically. The later-agreed outcome summary must remain readable before that reset; no exact summary dismissal or timing behaviour has been specified.
- Original Q9 allowed protagonist death as a possible reset trigger. This does not apply to the first playable, where the later decision explicitly makes Amelia unable to die. It does not establish lethal hazards for later missions.
- Reset returns the entire leg to Hour 1, on the docks in Mission 1. It is not an Hour checkpoint or a rewind to an arbitrary moment.
- Preferred reset presentation: visible high-speed reversal of events, if technically feasible. A second press skips it.
- Agreed fallback: diary pages flip backwards, then the opening scene returns, also skippable.
- The Hour 6 failure summary confirms survivors and casualties, but explains only what Amelia witnessed. It does not disclose off-screen causes or supply a solution.

### Persistence matrix

| Information/state | After diary reset |
|---|---|
| Diary observations and learned general information | Retained. |
| Current world's actions, object states, relationships, ship conditions and schedule deviations | Return to the leg-start state; physical evidence cannot be carried out of a discarded attempt. |
| Knowledge-gated interactions | Hidden until the initial lead is rediscovered; prerequisites must be satisfied again. |
| Previously learned shortcuts to rediscovery | Available as shorter routes to obtaining current-loop knowledge. |
| Full steam demonstration procedure | General understanding retained after the first viewing. |
| Steam code | Changes per run; current value must be obtained again. |
| Earned campaign clues and unlocked powers | Retained. |
| Previous successful mission completions | Retained. |

This distinguishes remembering what to do from satisfying a current-loop interaction gate. Immediate physical responses such as “Shove” do not require prior-loop discovery.

### Saving and quitting

One automatically and continuously updated save slot preserves the exact current time, world state and diary. Loading resumes the latest state. There are no manual save slots for undoing mistakes; deliberate retries use diary reset. Technical save frequency and atomic-write details are implementation matters, not additional player rules.

**Simulation history is part of the game save — confirmed:** persist the current leg's recorded history alongside its current state. Closing and loading must retain the history needed to visibly rewind the played run when restarting a level, as well as for editor scrubbing. Saving only the latest snapshot is insufficient. History is cleared at the agreed leg reset/start boundary after rewind completes or is skipped. This is a production requirement, not a capability already implemented by the probe.

## 5. View, movement and interaction

### Screen and space

- Fixed overhead view shows the entire current screen.
- All areas on that screen are visible and count as witnessed regardless of walls or geometry. A screen may show disconnected rooms.
- Automatic observation still concerns visible events, not hidden container contents or an obscured person's identity.
- Speech has separate proximity rules; seeing speakers does not grant their words.
- First-playable target: five or six rooms with a circular route and one discoverable shortcut. Exact room-to-screen mapping remains to be drawn, especially for the two-room controls screen.
- The shortcut requires learned opening knowledge, reacquired per loop with a shorter route once familiar. Its specific content is not yet defined.

### Current controls

| Function | Keyboard | Controller |
|---|---|---|
| Move Amelia directly | WASD | Left stick |
| Choose nearby wheel option | Numbered choices | Right stick highlights an option |
| Activate option | Associated number key | X activates highlighted option |
| Code digit entry | Manual digits 1–6; exact supporting bindings not assigned | Right-stick digit wheel, X enters digit |

Interactions use a wheel, like the user's Sims reference, rather than a vertical context list. No click-to-walk or automated walk-to-interact is intended. Only one action at a time; no action queue. A toggle highlights currently available interactions across the screen; undiscovered knowledge-gated options remain hidden. Controller face buttons are X for interaction, A for Highlight, Y for Diary, and hold B for Wait. B also dismisses open menus. The diary provides a rewind button.

### Timed actions

A progress bar appears once an action begins; no advance duration label was selected. Players may interrupt, losing unfinished progress. If conditions become invalid, the action cancels immediately with clear feedback and loses progress. Most conditions are stable within an Hour. Overheard dialogue follows its own pause-window rules below.

## 6. Diary, knowledge and conversations

Schedules begin unknown and become explicit as reliable information is discovered (original Q8, B). The persistent diary updates automatically across loops; it is the in-fiction anchor for retained knowledge and the later-defined reset and rewrite mechanics.

The diary automatically records witnessed people, places, times and visible actions. It preserves observed usual schedules and marks current-loop deviations alongside them. It does not explain causal links for the player or infer unobserved events.

A relevant lead reveals a possible interaction; further information enables it. A specific relevant spoken line is sufficient to unlock what it establishes, without requiring the whole conversation. A subtle diary cue confirms actionable knowledge without naming the solution. After reset, the initial lead must be rediscovered before the interaction appears again.

### Overhearing

- Amelia must be nearby to hear words. No standing position may overhear more than one conversation at once.
- Speakers wait for her within a fixed window, then begin by the latest permissible time.
- The window must accommodate remaining dialogue before the next scheduled activity.
- Arriving late grants only remaining lines, not a restart or recap.
- Leaving listening range can pause dialogue only while there is slack: remaining window duration minus remaining dialogue duration.
- When slack is exhausted, dialogue continues without her. Returning reveals only what remains.
- Waiting is expressed by character behaviour, such as impatience or clock glances; no pause-allowance countdown is shown.

## 7. Mission 1: docks and unmooring party

### Purpose

Teach that saving an individual is not enough: all rescues must fit one timeline. The initial obvious rescue is possible but conflicts with another death. Observation reveals ways to delay exposure, prepare a mechanism, and preserve an NPC routine that buys the final rescue window.

Character 1, Character 2 and Character 3 are functional placeholders; no names are invented here.

### Intended successful sequence

| Hour | Amelia's action | Causal result |
|---|---|---|
| 1 | Hide Character 1's bag nearby on the docks. | They miss their planned boarding opportunity. Later boarding and cabin preparation postpone party arrival until Hour 4. |
| 2 | Watch the equipment demonstration; on familiar loops, catch the essential code step. | Acquire this run's steam-shutoff code. |
| 3 | Be near Character 2 and select “Shove” during the chandelier warning. | Push them clear before the chandelier falls. |
| 4 | Enter the current code and turn off steam after Character 3 becomes trapped. | They escape, meet Character 1 outside, and chatter long enough to delay the party until Hour 5. |
| 5 | Bump Character 1 after their drink is spiked. | The drink spills; their outfit is ruined, and they leave almost immediately to change. They do not return before the party ends. |
| 6 | Reach the successful mission conclusion. | Everyone survives; show victory. |

Without the bag delay, the drink intervention conflicts with the Hour 3 chandelier rescue. Without Character 3's rescue, the later chatterbox delay does not occur. This is the designed route, not yet evidence of a tested or exclusive solution.

### Character 1: delayed poisoning

Character 1 intends to attend the unmooring party. Their drink is spiked in response to their arrival, so the player cannot remove this danger in advance. Amelia could spill the drink on an early arrival, but would miss Character 2's rescue. The route therefore shifts Character 1's attendance to Hour 5.

An ordinary luggage mix-up on the docks resolves quickly but demonstrates that Character 1 refuses to board without their bags. After learning this once, inspecting the luggage on later loops restores “Hide bag.” Hiding it nearby is a brief direct interaction, requiring no inventory system. The hiding place prolongs the search, making them miss their planned boarding opportunity; later boarding and normal cabin preparation carry party arrival to Hour 4.

After Character 3's Hour 4 rescue, their unsolicited conversation delays Character 1 one more Hour. This is a preserved NPC routine, not a delegated task.

During Hour 5 Amelia bumps Character 1, spilling the poisoned drink onto their outfit before they drink. They leave to change almost as soon as they arrive; the party finishes before they return. Do not reopen why they leave or propose a repair as the final rescue.

Poison can be understood by witnessing the spiking and collapse, or by inspecting the glass afterwards. Inspection establishes poisoning only. The spiking action is visible, but the responsible person is obscured. Their identity belongs to the conspiracy investigation.

### Character 2: chandelier

A chandelier falls during Hour 3. A brief creak and subtle shake precede the fall, so audio is not required. The warning is deliberately understated rather than a long, obvious danger sequence.

“Shove” appears during the intervention window, including on the first encounter. Amelia must be close enough to push Character 2 clear. The window is a clearly signalled portion of the Hour with tolerance, not a single exact instant or most of the whole Hour. Exact seconds are tunable.

After failure, the room remains passable, with wreckage and casualty visible for inspection. Observation of later events remains possible.

### Character 3: steam and chatter

Character 3 is a chatterbox caught behind a path-blocking steam leak in Hour 4. There is no coded locked door: the steam prevents reaching the normal exit. Shutting it off lets them escape.

The controls are at the demonstration location. A single fixed screen displays two halves: controls in one room, the disconnected room containing Character 3 in the other. Amelia can operate the control while the player sees the hazard and result; both halves count as witnessed regardless of geometry. No observation window is required.

A crew member raises the alarm too late to save Character 3. This reveals the event for subsequent loops. Amelia must arrive earlier next time, after the entrapment but before it is fatal.

Turning steam off early is not a solution: a crew member restores it. After a correctly timed shutoff, Character 3 escapes before a later restart. The crew routine remains consistent. Precise trap, shutoff and restart times must be arranged to support the chosen rescue window.

Once outside, Character 3 meets Character 1 on their route and chats, postponing the party arrival until Hour 5. The dependency is learned by observing it, not by the diary explaining the chain.

### Demonstration and code

- Full demonstration occurs in Hour 2 and must be watched once to learn the general procedure.
- One step reveals a code that changes every run. Once the procedure is familiar, only that step is essential.
- The witnessed current code is recorded in the diary.
- Code contains three digits, each drawn from 1–6.
- Entry is manual. On controller, a six-option digit wheel uses right stick selection and X entry.
- After three digits, a separate “Confirm” option submits. There is no automatic submission.
- “Clear” removes the entire entry for re-entry; there is no delete-last or per-slot editing requirement.
- Wrong code: reject it and permit an immediate retry. Elapsed time is the only penalty; no lockout.
- Time continues during entry; opening the diary to check pauses time.
- Correct submission turns off steam. It does not unlock a door or combine two mechanisms.

## 8. First-playable evaluation and acceptance

**Primary playtest criterion:** without being told the solution, players learn to explain and execute the causal rescue chain. Completion time and loop count are secondary pacing observations, not the sole success criterion. No numerical pass threshold has yet been agreed.

The checks below translate accepted rules into observable implementation checks; they are not reported test results.

| Check | Expected behaviour |
|---|---|
| Intended route | Bag delay, current code, Shove, timed steam shutoff, chatter and drink spill produce three survivors and Hour 6 victory. |
| Early Character 1 rescue | Attending to their early drink conflicts with reaching Character 2 in time. |
| Missing Character 3 rescue | Chatterbox delay is absent; the intended Hour 5 plan cannot simply assume it occurred. |
| Early steam shutoff | Crew restoration prevents it from serving as an advance permanent fix. |
| Correctly timed shutoff | Character 3 escapes before restoration and meets Character 1. |
| Wrong code | No steam shutdown; immediate retry allowed while time continues. |
| Reset | Return to docks/Hour 1; retain diary history but refresh code and reset world/interactions. |
| Observation | Disconnected visible screen areas record events; distant conversation words remain unavailable. |
| Dialogue slack | Pause cannot extend conversation beyond its fixed window. |
| Death | Notification identifies victim only; simulation and exploration continue. |
| Save/load | Latest time, NPC/event state, current code and diary resume from the single autosave. |
| Accelerated waiting | Simulation advances normally and stops acceleration at next Hour or release. |
| Mission failure summary | Confirms casualties without revealing unwitnessed causes. |

Multiple supported solutions remain a whole-game design goal, but the user has explicitly deferred additional routes for the first playable. Implement and validate the one authored Mission 1 route; unintended bypasses should still be checked. A second route is not a first-playable acceptance requirement.

## 9. Superseded decisions: do not restore

| Old proposal/version | Current rule |
|---|---|
| Equipment fault and lengthy repair threaten Character 1 | Arrival-triggered poisoned drink; delays and final spill. |
| Opening drink spill delays Character 1 | Hide luggage on the docks. Drink spill remains the final rescue. |
| Coded door release / locked-room escape | Code stops path-blocking steam; normal door is usable once clear. |
| Automatic code entry | Manual three-digit input, digits 1–6. |
| Automatic third-digit submission / delete last | Separate Confirm and full Clear. |
| Mouse click-to-walk, vertical context menu | Direct movement and radial interaction wheel. |
| Right trigger, then bumpers plus X | Right stick selects; X activates. Left stick moves. |
| Geometry-limited observation / proposed window | Entire current screen observed regardless of geometry. Speech remains proximity-limited. |
| Provisional eight-Hour first level | Six-Hour Mission 1. |
| Original whole-voyage finale, with departure checkpoints and downstream replay after earlier changes (original Q2) | Later final-leg-only ending, free investigation revisits and protected completed legs take precedence. Do not restore the old finale checkpoint scheme. |
| Powers alternate with promotions | Powers per level; separate fixed rank milestones. |
| Q136 role-choice question | Withdrawn: junior purser, with two promotions, recovered from saved HTML. |

## 10. Remaining specification work and context recovery

### Recovered original decisions and source coverage

All five user-supplied saved HTML pages have been read as historical conversation data. Together with the original thread excerpt, they close the identified Q1–Q18 decision gap. Later explicit decisions in this chat take precedence over original choices and suggestions.

| Source in C:/Users/jkeyw/Downloads/ | Recovered coverage |
|---|---|
| Research Interactive Story Structures2.html | Original concept/research, Mediterranean cruise revision, Q1–Q4 answers, Q5 prompt. |
| Research Interactive Story Structures3.html | Overlap plus Q5 answer (physical and social interventions) and Q6 answer (continuous time in discrete Hours); Q7 prompt. |
| Research Interactive Story Structures4.html | Overlap plus Q7 answer (hybrid NPC model) and Q8 answer (automatic persistent diary); Q9 prompt. |
| Research Interactive Story Structures5.html | Q9 answer (manual reset anywhere plus automatic failed-leg reset), full Q10 role question and junior-purser/two-promotions answer; Q11 answer; Q12 prompt. |
| Research Interactive Story Structures.html | Q10 answer through Q15 answers and Q16 prompt, including responsibility-based promotions and bounded reality-writing. |
| Original referenced chat excerpt | Q14–Q18 answers, including cast size, normal-leg length and optional conspiracy layer. |

The original research response is background analysis, not a collection of approved features or independently reverified game claims. Suggested example titles, permission lists and algorithms are not automatically accepted specifications.

Reconciliations applied:

- Original whole-voyage finale and its port-checkpoint replay scheme yield to later final-leg-only ending and protected completed-leg revisits.
- Retained rank on revisits was an old assistant suggestion; the user later explicitly retained powers but restored each leg's rank.
- Original continuous-time commentary yields to later diary pause and defined dialogue costs, while wheel/code entry continues in real time.
- Suggested automatic inferred diary links yield to later player-led deduction and witnessed-event recording.
- Original Q9's possible death reset does not override first-playable Amelia invulnerability. Manual reset becomes available with the later-agreed first-death tutorial; automatic failed-leg reset must coexist with the readable Hour 6 summary.
- Original post-success power awards coexist with the later onboarding exception: reset is introduced within Mission 1, and location rewriting is earned for Mission 2.

No identified question gap remains in the original Q1–Q18 sequence. This is not a claim that every production detail has been decided. Missing implementation details should be checked against these sources before asking the user, and recommendations should never be silently promoted into decisions.

### Not yet specified in the accessible decisions

- Room/screen topology, traversable connections, travel distances and shortcut placement.
- Exact within-Hour event timings, tolerances and dialogue durations, including the crew steam restart.
- Character names, specific demonstration staging and detailed dialogue/content.
- Detailed Level 2/3 content, rewrite constraints and the MVP clue chain.
- How authored cross-leg consequences interact with non-linear investigation revisits, without undoing the agreed protection of successful completions.
- Further supported rescue routes are deferred beyond the first playable.
- Remaining controller/keyboard bindings and wheel target selection where several objects are close.
- Godot/GDScript and Dialogue Manager are selected. Production schemas, deterministic state/history, live-edit compatibility and GitHub authentication remain implementation work. Actual arbitrary-time restoration and rewind remain unproven.
- Numeric playtest targets and timing tuning after evidence from play.

Do not resume by asking these as a long questionnaire. Check source history first, then ask one consequential unresolved question at a time. Already decided material must not be presented again as options.

## 11. Research basis and interview maintenance

The inspected GDD_Research_Pack_Complete.zip in Downloads contains README, Full_GDD_Research_Report, Master_GDD_Template, Sample_Mini_GDD_Signal_and_Salvage, Editable_GDD_Section_Examples and Primary_Source_Links. It does not contain a Grill-Me skill. Extracted research copies remain under work/gdd-research.

The installed Grill-Me skill was read at C:/Users/jkeyw/.agents/skills/grill-me/SKILL.md; the anthropic-skills copy matches. It requires one question at a time, a recommendation, and resolving dependent decisions in order. Research available material rather than asking the user to repeat what it already answers.

Applied GDD guidance: define purpose before rules; scale precision by milestone; distinguish decisions, hypotheses and tunables; specify failure/recovery and feedback; use observable acceptance evidence; preserve rationale; avoid duplicate authoritative specifications. Relevant research sections are Executive summary; Writing standards, visual artefacts and acceptance criteria; Lifecycle, handover, sign-off and scale variations; and Postmortem lessons. Master template sections 1–7, 9–10 and 18–23 support this structure.

**Maintenance rule for this interview:** update `03_Updated_GDD.md` as the canonical specification. Update the affected section of this document as decisions change. Put replaced rules in the superseded table rather than leaving conflicting active versions. Check this document and available conversation before posing another question. Recommendations alone are not decisions. Q136 is withdrawn; its complete role question and answer have now been recovered, and the original Q1–Q18 decision sequence is covered. No new interview question is posed during this source-recovery update.

## 12. Technical direction — active design work

Confirmed in the latest user request:

- Windows PC and browser versions. Host the web build on GitHub Pages, automatically built and deployed by GitHub Actions on pushes to the default branch. Exact browser support matrix remains unspecified.
- Authorable definitions/scripts for characters, maps and storylets.
- An editor integrated into the running game, including script authoring and live editing.
- Multiple rescue routes deferred for the first playable.

Godot, the authoring stack and the editor workflow are selected below. Storage implementation, exact compatibility rules for applying live edits and remaining controls still need implementation detail. The live editor is a product requirement; an external engine editor alone does not fulfil it.

### Q137 — Shared runtime selected

Godot 4 with GDScript is the shared runtime for native PC and browser builds, using the Compatibility renderer. Build a custom in-game authoring editor and a game-content interpreter. An external Godot editor alone does not meet the integrated live-editing requirement. Exact Godot release and supported OS/browser matrix remain to be pinned.

The selected foundation separates engine code from editable character, map and storylet content. Dialogue Manager supplies scene-script syntax; the exposed command API and live-edit application semantics remain to be defined. Structured map data, visual placement tools, validation, and storylet execution diagnostics were proposed as the architecture; their detailed behaviour is not yet specified.

### Existing narrative languages — evaluation, not a selection (28 September 2026)

The user requested evaluation of existing languages before choosing custom syntax. This historical evaluation led to the confirmed stack below, resolving the authoring-language choice raised at Q138.

- **Yarn Spinner 3:** closest direct storylet match, with conditional node groups and configurable saliency (selection among eligible content). Its official Godot GDScript guide currently labels the integration alpha and documents an external `ysc` compiler. Integrated browser-side source compilation therefore needs a feasibility test; external-editor hot recompilation is not proof of in-game web editing. Use deterministic selection rather than the default random saliency policy if adopted. Sources: https://docs.yarnspinner.dev/write-yarn-scripts/advanced-scripting/saliency and https://yarnspinner.dev/docs/godot/01-gdscript-guide/ .
- **Ink:** established narrative language with conditional content; storylet selection and NPC coordination still need integration. InkGD provides a GDScript runtime, while its Godot 4 branch has no official release in the inspected README. Browser compilation is possible with inkjs, but a shared native/web authoring pipeline would still need integration. Sources: https://www.inklestudios.com/ink/ , https://github.com/ephread/inkgd , https://github.com/y-lohse/inkjs .
- **Godot Dialogue Manager:** a Godot-oriented script-like dialogue language with conditions/mutations and documented runtime compilation from text. A promising candidate for the integrated live editor, with custom scheduling/storylet selection still required. Actual native and web exports, editing and save/restore must be tested before commitment. Sources: https://github.com/nathanhoad/godot_dialogue_manager and https://github.com/nathanhoad/godot_dialogue_manager/blob/main/docs/Using_Dialogue.md .

These are narrative runtimes, not complete implementations of the ship simulation, maps, actor reservations, interruption rules or exact autosave. Recommendation: reuse an existing narrative language, with structured schedule/map/storylet metadata and a small simulation command API, before investing in a wholly new language.

### Authorized feasibility probe — completed 28 September 2026

Following the user's agreement to a probe, a project was built at `authoring-probe/`, using Godot 4.7.2-stable and Dialogue Manager 4.1.0. These are tested versions, not a commitment to a final support matrix. Both the exported Windows executable and the exported Web build in headless Chrome passed all 17 checks. The browser compiles source in the running game without a compiler service.

Verified: runtime dialogue compilation; a rescue eligibility gate; character state changes; multi-speaker dialogue; commands changing world state; save/reload at conversation boundaries without repeating completed commands; edited text and commands taking effect; syntax errors preserving the previous working script; reset retaining knowledge and content edits.

Probe edit policy: applying source restarts the scene cursor and preserves world state. This is a test policy, not the final live-edit contract. Saves were tested within the current process/page; fresh-browser persistence, continuous exact autosave, arbitrary mid-action restoration and migrations remain unverified. Maps, scheduling and storylet selection are not implemented by the probe. Native testing was headless; browser visuals were inspected.

Full result, limitations and run instructions: [authoring probe](authoring-probe/README.md).

### Authoring stack — confirmed 28 September 2026

The user accepted the proposed combination after reviewing the feasibility results:

- **Godot 4 / GDScript**, Compatibility renderer, for native PC and web.
- **Dialogue Manager** for dialogue and scene scripts.
- **Structured data** for character definitions, maps and storylet conditions/metadata.
- **GDScript** for deterministic scheduling, simulation and the command API exposed to authored scenes.
- A custom **integrated in-game editor** with live editing remains required.

This selects the stack, not the probe's provisional edit behaviour. Editor workflow, structured-data schemas and production save/restore still need specification. Multiple rescue routes remain deferred for the first playable.

### Live-edit application — confirmed

Applying a valid edit preserves the current simulation state. Changes affect subsequent actions; completed events remain completed, and past events are not recalculated. The author has an explicit restart-leg option. Structural changes that cannot safely apply to the current run require a restart, with the editor explaining why. Exact classification of such changes remains to be specified.

This supersedes the probe's provisional behaviour of restarting the scene cursor whenever source is applied. Production editing must not implicitly replay completed scene commands.

### Editor time controls — confirmed

Pausing opens the integrated editor interface. Editing, including authoring undo/redo, is only possible while paused. Resuming exits the editing interface and runs the simulation after validating and applying changes. There is no editing-while-running mode or separate pause-on-first-edit behaviour; the user's clarification supersedes that proposed distinction.

**Editor layout — confirmed 29 September 2026:** Space reveals the editor only while paused; editor hotkeys do nothing while it is hidden. Put editor actions in dropdown menus. Forms, source views, history inspection and GitHub project controls belong in floating panels that can be dragged, resized, minimised to a bottom dock, restored and closed. The game uses the full viewport when the editor is hidden. The browser build has a small four-corner fullscreen toggle at the upper right on the title screen and in play.

**Stepping — confirmed:** provide separate controls for advancing one simulation tick and advancing to the next meaningful event, such as an NPC arrival, conversation start or action completion. Each step ends paused with the editor showing the updated state. The exact event categories and simulation tick rate remain implementation details to specify. Stepping executes the simulation, so pending edits must pass the same validation/application gate as resuming; script errors block advancement.

### Visual and source authoring — confirmed

**GitHub integration — requested:** both native and web authoring clients should be able to commit authored project content to GitHub and retrieve updates, using a shared repository for synchronization. This replaces the pending choice between project-file transfer, generic cloud sync and isolated local projects. Local draft autosaving and persistent authoring undo/redo remain separate requirements. Each author enters a repository-scoped GitHub token on each device; the web client may save it in that browser's local storage, and the Windows client may save it in per-user local storage. No credential is bundled with either build or committed to the project repository. Conflict handling is confirmed below; whether editor-session history is synchronized remains unresolved.

**Commit workflow and undo boundary — confirmed:** an explicit **Commit & sync** action presents a change summary and commit message. Resuming simulation does not automatically commit. Authoring undo/redo retains changes since the current checked-out HEAD. Any change to that HEAD, including committing, pulling/merging or switching to a different commit, clears authoring undo/redo and establishes a new baseline. A failed attempt that leaves HEAD unchanged preserves history. Fetching remote information alone does not change local HEAD. Uncommitted undo/redo persists across closing and reopening while HEAD is unchanged. Earlier committed versions remain Git history, outside authoring undo/redo. Clearing undo history does not itself authorize discarding unsaved or uncommitted content.

**Sync and conflicts — confirmed:** merge non-conflicting changes automatically. Do not build an in-game merge-resolution interface. When conflicts prevent automatic integration, preserve the local work on a separate branch and use GitHub's remote branch/merge workflow to resolve them; the editor can subsequently retrieve the resolved version. Never silently overwrite either side. Branch naming and the exact conflict handoff remain implementation details. This supersedes the proposal to resolve conflicts inside the paused editor.

**Commit validation — confirmed:** authored content must pass validation before committing to GitHub. Script errors block committing as well as simulation resume. Invalid or unfinished drafts still autosave locally, with undo/redo retained while HEAD is unchanged. This validation gate also applies to commits used to preserve work on a conflict branch.

**Structural validation — confirmed:** unreachable authored interaction positions, missing required room connections and references to nonexistent characters or storylets block both simulation resume and commit. Validation checks structural usability and reference integrity, not puzzle solvability: intentional dead ends, runtime obstacles and unsolved rescue routes are not inherently errors. Detailed checks must distinguish broken authored geometry/connections from deliberately conditional access.

Feasibility basis: GitHub's REST Git database API can create multi-file commits and update branch references, and its REST API supports browser CORS. The chosen per-device token flow uses this shared API adapter without an installed Git executable or authentication backend. Concurrent changes must be detected rather than overwritten. Sources: https://docs.github.com/en/rest/guides/using-the-rest-api-to-interact-with-your-git-database ; https://docs.github.com/en/rest/using-the-rest-api/using-cors-and-jsonp-to-make-cross-origin-requests ; https://docs.github.com/en/rest/authentication/keeping-your-api-credentials-secure .

Character schedules and storylet conditions have forms/timelines plus a source view, both editing the same underlying data. Dialogue Manager scenes use text editing. Exact schemas and synchronization/validation behaviour remain to be specified.

**Room map authoring — confirmed:** use supplied background artwork for each room, with walkable areas drawn over it and doors, props and interaction points placed in the integrated editor. This is the selected approach for the first playable, matching the fixed whole-room camera. Tile painting and a combined tile/background workflow are not part of the selected first-playable scope.

**Interaction positions — confirmed:** authors place one or more explicit interaction positions beside each room object, defining where characters stand to interact. Positions are authored rather than inferred from any nearby walkable point.

**Player positioning — corrected:** the player moves Amelia into interaction range using WASD/controller movement, then selects a local interaction from the wheel. Interactions cannot be selected from a distance and do not trigger automatic approach movement. Explicit authored interaction positions remain, but do not create a click-to-move or automatic walking system. This supersedes the briefly accepted automatic-approach proposal.

**Authoring draft persistence — confirmed:** automatically save authoring drafts, including unfinished or invalid scripts, so work survives closing the editor. Draft saving is separate from the game's continuous autosave and from applying changes to the simulation. Script errors still block resume; saving a draft does not require it to be runnable. The shared authoring undo/redo history also persists across closing and reopening the game, alongside the saved drafts.

**Project portability — current direction:** GitHub is the selected cross-client synchronization mechanism. Project-file import/export was proposed but not selected in that exchange; it is not an additional confirmed first-playable requirement. Whether test-run state or simulation history transfers between clients remains unresolved.

**NPC inspector — confirmed:** selecting an NPC shows their current location, activity, destination and relevant variables, alongside their schedule, intended next behaviour, and explanations of the conditions that allow or block it. For example: "Chatterbox cannot leave: steam is on." This is an authoring/debugging view, not player-facing information.

**Storylet inspector — confirmed:** show why each storylet is eligible or blocked at the inspected simulation time, including individual condition results, required characters and its time window. This is available both at the current paused moment and while inspecting earlier moments with the history scrubber. For example: "Rescue scene blocked: Chatterbox has not escaped yet." This supplements structural validation and NPC inspection; it does not expose debugging information during normal player-facing play.

**Historical inspection — clarified:** scrubbing shows actual recorded history, including the state and diagnostic results from that run. It does not evaluate later content edits against past states, infer alternative outcomes or offer a hypothetical preview. Historical diagnostics must reflect the content active at that time, not the latest draft. To observe the effect of an edit, explicitly resume from a historical moment using the latest validated content and run the simulation, creating a new continuation under the agreed rules.

**Direct simulation-state editing — rejected:** the editor does not provide temporary overrides such as teleporting an NPC, granting knowledge or changing runtime variables directly. The NPC state inspector is read-only. Changes are made through authored content and normal play; historical restoration and continuation remain available under the agreed scrubber rules.

### Editor history scrubber and room inspection — confirmed requirement

The editor provides a time scrubber to any previous time in the current run, and allows viewing any room, independently of Amelia's location. The user links this requirement to the desired visible rewind of the playthrough to the start. Historical inspection must therefore cover the whole simulated world, including rooms not visited by Amelia.

The user specifies that the new "now" updates after pausing. Working interpretation: after running and pausing again, the scrubber's latest-time endpoint updates to the newly reached simulation time.

**Historical continuation — confirmed:** an explicit **Resume from here** action restores the scrubbed moment and creates a new continuation, replacing the later history. Scrubbing alone only inspects history and does not discard it. Authors can return to a point before a failed rescue, edit content and test a new continuation.

**Content version on historical resume — confirmed:** restore the earlier world state, then continue using the latest applied content, including updated scene scripts. Historical content versions are not automatically restored. Edits incompatible with the restored state require a leg restart, with the editor explaining why. Exact compatibility rules remain to be specified.

**Simulation-history retention — confirmed:** retain the entire current leg. Starting or resetting the leg clears this history, after the rewind animation finishes or is skipped. Resuming from a historical moment replaces the subsequent simulation history as specified above. Multiple prior runs are not retained by this feature.

**Separate authoring undo/redo — confirmed requirement:** maintain a distinct history for content edits. Authoring undo/redo and simulation-time scrubbing are separate operations: scrubbing does not undo authored changes, and undoing an edit does not rewind simulation time. Simulation-history clearing does not itself clear authoring undo/redo. The edit-history scope, persistence and how undo/redo interacts with applying content remain to be specified.

**Shared authoring history — confirmed:** scripts, schedules, map edits and other authoring tools share one chronological undo/redo history. Undo/redo acts on the latest authoring operation regardless of the current panel. Labels identify the next operation, such as "Undo: move doorway". History persistence and application to the running simulation remain to be specified.

**Apply on resume — confirmed:** authoring changes, including undo/redo, are automatically validated and applied when resuming the simulation; there is no separate required Apply action. Script errors block resuming and leave the simulation paused so the author can fix them. This applies both to ordinary resume and to **Resume from here**. Validate before committing a historical continuation or discarding its later history. Edits incompatible with the restored/current state still require a leg restart under the existing rule. This replaces the earlier pending choice between explicit Apply and applying every individual edit immediately.

Implementation implication: retain enough simulation history to reconstruct prior world states; a reverse visual animation alone is insufficient for the editor. History capture, storage limits and interaction with live content edits require specification and testing; the dialogue feasibility probe does not validate these capabilities.

## 13. First-playable and editor readiness review

### Foundation implementation note (issues #3–10, 28 September 2026)

The current branch adds a separate two-room foundation harness. It implements fixed-tick movement and NPC commitments, a local timed valve action, a narrow Dialogue Manager scene adapter, per-tick whole-world history with recorded diagnostics, validated historical continuation, a checksummed single-slot journal, and visual reset through recorded snapshots. The source box edits only the scene script. This note reports implementation scope; it does not amend the agreed Mission 1 or editor requirements. Evidence and limits are in [the foundation demonstration](foundation/README.md). The original `main.gd` remains the feasibility probe.

Status reviewed 28 September 2026, before the foundation implementation above. This is an implementation assessment, not additional approved scope. At that review the working code was the authoring feasibility probe: it demonstrated runtime scene compilation and line-boundary save/restore in Windows and web exports. The foundation harness still does not implement the agreed Mission 1 or operational editor.

### Remaining first-playable specification

- Draw the five/six-room screen layout, connections, travel distances, interaction positions, overhearing regions and discoverable shortcut, preserving the two-room controls screen.
- Produce one complete event sheet: baseline NPC routines, player-induced branches, dialogue costs, rescue windows, steam restoration and the exact Hour 6 conclusion. Choose initial numbers and tune through play rather than reopening agreed causal design.
- Write the demonstration, discovery leads, overheard dialogue, diary entries, tutorial and outcome text; supply initial room/character/prop assets. Placeholder names and art need not block implementation.
- Complete input bindings and resolve target selection when several local interactions are in range.

### Remaining engineering and operational editor work

1. Define stable content IDs, structured schemas and scene commands for maps, actors, schedules, storylets, conditions and effects. Specify deterministic event ordering and serializable in-progress actions.
2. Prove whole-world history recording, actual historical diagnostics, arbitrary-time restoration, single-tick/event stepping and continuation with edited content. Cover dialogue cursors, movement, timed actions, random-code state and knowledge. Define compatibility rules for edits to active or deleted content; do not silently replay completed effects.
3. Implement movement/navigation, local interaction wheels, timed actions, schedules/storylets, overhearing, diary knowledge, hazards, reset, success/failure and exact continuous autosave.
4. Build the paused editor: room-background importing and placement, walkable geometry, forms/timelines and synchronized source views, inspectors, scrubber, validation and resume controls.
5. Implement draft autosave and persistent shared undo/redo, clearing authoring history when HEAD changes. Test closing/reopening on native and web. Include simulation history in the persistent game save, as now confirmed. Decide what run state, if any, syncs between devices.
6. Implement and test per-device GitHub token entry, repository/branch selection, validated commits, retrieving changes, automatic non-conflicting integration and branch-based conflict handoff. Package authored image assets with the scenario, use direct GitHub API requests from Windows and Pages, and preserve local drafts during network failures.
7. Assemble and tune Mission 1 through the editor. Verify the intended route and failure paths, then test keyboard/controller play, native graphics, browser persistence and the selected support matrix.

### Recommended build order and completion evidence

Start with a small two-room test covering a moving NPC, a timed action, dialogue and a world-changing command. Record, scrub, resume with an edit and reload it without duplicated effects. This is the highest-risk foundation shared by game and editor.

Then build authoring tools and persistence around the same data, add GitHub sync, and author the full Mission 1 sequence. Editor completion means the agreed content can be created/edited, inspected, validated, resumed, saved/reopened and synchronized between native and web clients without hand-editing engine code for ordinary content changes. First-playable completion means the Mission 1 acceptance checks in section 8 pass and an uninstructed playtest can assess whether the rescue chain is learnable.

Engineering details such as schema syntax, snapshot cadence and initial timing values can be proposed and implemented without a separate design interview question for each. Windows PC, GitHub Pages with automatic push deployment, simulation history persisted inside the game save, and per-device GitHub token entry for editor access are now confirmed. The exact browser support matrix and cross-device run-state synchronization scope remain open. GitHub Pages hosts static game files; the editor calls GitHub's API directly with the locally entered token. Later missions, additional powers and multiple rescue routes do not block this milestone.

### Repository and local development — confirmed

Repository: https://github.com/jkeywo/the-incredible-diary . Local checkout: `C:/coding/the-incredible-diary`. The repository's `docs/03_Updated_GDD.md` becomes the working copy for subsequent implementation; these conversation outputs retain the handoff snapshot. Windows and web export the same Godot project. Pushes to `main` build and deploy the web export through GitHub Actions/Pages; pull requests validate builds without deploying.


### Mission 1 playtest implementation decisions — September 2026

- Keep the cast and major event deadlines. Main rooms provide two triangular
  guest groups of three and one sailor group of three, facing inward. Keep the
  service passage for travel. Reserve distinct gathering positions.
- Door crossings, visible unlabelled transition rectangles and inward arrival
  positions are separate. Player and NPC arrivals use the same geometry and
  wait or find a clear arrival when occupied.
- Give principal guests about 20 real seconds in the Foyer before their first
  cabin visit. Directions detours may adjust cabin departure without delaying
  major appointments.
- The steam operator leaves after the demonstration and returns at subsequent
  voyage :00/:30 boundaries, allowing for travel. On finding pressure off, he
  wonders aloud before operating the machine. Record each phase. A shutdown
  lasting until the accident rescues the passenger permanently.
- The chandelier guest paces and frets during her final Foyer visit and cannot
  be body blocked during that approach. Preserve the warning and Shove window.
  Place her slightly below the fixture so the casualty is partly visible.
  Wreckage has a solid floor footprint, routes around it and an accessible
  inspection point; living characters inside can move outward.
- Remove the poisoned glass from the bar at pickup. Record its empty floor
  position beside the actual casualty and move inspection there. Keep the
  successful spill outcome separate.
- Avoid covering Boy and controls with speech. Unavoidable overlap fades the
  background, border and tail to 50% opacity, leaving text opaque.
- Teach Highlight on first Foyer entry ("I wonder what I should do?"), Wait after
  ten real seconds of eligible inactivity ("Hurry up and wait…"), and Diary on
  first rewind unlock ("Something has changed in the diary. I should open it.").
  Show device-appropriate prompts alongside thoughts without pausing voyage
  time. Exclude focus loss, dialogue, actions, menus, pause, opening tutorial
  and rewind from inactivity. Incidental mouse movement does not reset it.
- Queue hints behind dialogue, prioritise Diary, and mark each shown only when
  displayed. Retained knowledge remembers them through Continue and resets;
  recorded state contains queued and displayed thoughts.
- Highlight uses deduplicated entity targets and gold animated sprite outlines
  that retain grounding and recolouring. Sprite-less targets use filled
  circles. Remove interaction rings and floating action labels. Door rectangles
  keep their own presentation. Clear unavailable or disabled outlines.
- Save operator progress, assignments, chandelier collision state and dropped
  glass location. Older saves use defaults without rewriting recorded history.


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


### Diary magic and page turning — clarified 29 September 2026

The first body Amelia sees in a playthrough prompts: “What a tragedy. Hmmm, my
diary is shaking, I feel like I should take a look.” This applies to witnessed
deaths and later discoveries. Queue it behind current dialogue and show the
input-specific Open diary prompt. Persist its shown flag across saves and loops;
only starting a new playthrough makes it eligible again. Amelia does not know
about rewinding in advance.

The diary has turnable pages, without scrolling, and opens at the end. The final
right-hand page holds the available voyage buttons, without rewind instructions.
The rewind action reads “Turn back to the start” and has gold sparkles when
available. At voyage end, keep the outcome together on the facing page.
Previous/Next, keyboard Left/Right or Page Up/Page Down, and controller LB/RB
turn spreads. Observations retain the existing current-voyage witness rules.

Show “Turn back to the start” on the first spread as well as the last when the log spans multiple spreads. Reuse one visible button; a single-spread diary shows it only once.
