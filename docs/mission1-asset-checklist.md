# Mission 1 first-playable asset status

This is an implementation checklist under `03_Updated_GDD.md`, not a design
change. Art needs to read clearly at the current 1160 × 740 fixed screen size;
final polish can follow playtesting.

## Ready to place in Godot

- Five room scenes in `assets/rooms/mission_1/`: docks, foyer, cabins and
  corridor, disconnected controls and steam rooms, and party salon. The docks
  scene has separate moving water and ship layers behind a fixed pier/stairs.
- Ten character scenes in `assets/characters/mission_1/`: Amelia, three
  provisional rescue roles, the ex-army archetype, a recolourable sailor and
  four recolourable generic guests. All have four-facing idle, walk, talk and
  interaction cycles. Amelia, sailor and rescue roles have Mission 1 action
  clips. The three rescue roles can be recast without changing the base art.
- Nine stateful prop scenes in `assets/props/mission_1/`: cabin and service
  doors, suitcase, bag hiding place, code panel, drink, chandelier, steam vent
  and the foundation valve. Their first-playable visual states are in
  transparent sheets and can be switched by name in Godot.
- Character 1's stained movement, Character 3's held steam casualty clip, and
  four effect scenes in `assets/effects/mission_1/`. Steam, chandelier dust,
  drink splash and the anonymous spiking hand are connected to their props.
- Diary title and blank spread art plus reusable first-playable interface scenes
  in `assets/ui/mission_1/`: resizable speech bubble, title opening transition,
  action wheel, code panel, clock/progress HUD, diary notice/tab, interaction
  highlight and outcome card.

## Remaining visual assets

| Area | First-playable assets needed |
| --- | --- |
| Interface content | Populate the blank diary pages, mission result wording, witnessed evidence and context-specific action labels from authored Mission 1 data. Decide the reset presentation when recorded-history rewind is wired; the GDD's backward page flip remains the fallback. The reusable first-playable UI art is ready. |

## Remaining audio

The [first-playable CC0 audio shortlist](mission1-audio-shortlist.md) names
candidate music, ambience and event sounds with source and licence links.

- Dock water/ship and party crowd ambience; simple footsteps for hard floor.
- Bag movement and doors; control demonstration, keypad entry/accept/reject,
  valve and steam start/stop.
- Chandelier creak and crash, shove, glass spill, coughing and crew alarm.
- Minimal discovery, casualty and success cues. Music can be added after the
  first playable communicates the rescue chain clearly.

## Scene authoring still required

The room `.tscn` files are visual layers and empty placement nodes. The prop
scenes have named visual states but are not placed in rooms or tied to world
flags. The title now opens onto a controllable dock/foyer slice with a separate
save; the full rescue sequence is still to be assembled. Walkable
polygons, logical connections, actor paths, interaction
positions, hazard areas, timing and state changes still need to be authored in
the game and editor. The existing foundation harness remains a two-room
feasibility test, not Mission 1.
