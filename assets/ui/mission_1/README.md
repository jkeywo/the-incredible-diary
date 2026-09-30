# Mission 1 interface art

The two diary illustrations are imagegen art prepared at the fixed 1160 × 740
viewport. `diary_closed.png` puts the book across the right half of a desk.
`diary_title_lettering.png` is a separate transparent layer with the exact
title, **THE INCREDIBLE DIARY**, in tall Art Deco capitals and **of Lady Amelia
Ashcombe** in angled cursive below. `diary_open.png` is the matching full-screen
blank spread. The large generated originals remain in `source/`.

`tools/build_mission1_ui.py` prepares the viewport art and lettering. It uses
installed Windows Agency Bold and Vivaldi for rasterized text; the font files
are not needed by Godot or the web export.

## Godot scenes

| Scene | Use |
| --- | --- |
| `title_screen.tscn` | Project startup scene. Continue appears for a valid Mission 1 save; New warns before clearing that save; Test Level opens the foundation harness; Quit exits. New and Continue place `mission1/play.tscn` beneath the book. The cover swipes aside, the feathered page interiors reveal the room, then the book frame enlarges and fades. Amelia is controllable only after `opened_to_game`. |
| `open_diary.tscn` | Blank whole-screen spread with separate empty `LeftPageContent` and `RightPageContent` regions for diary entries. |
| `speech_bubble.tscn` | Textured navy-and-brass speech/thought bubble. Set `bubble_size` and `tail_position`; call `present(line, elapsed_seconds)` for recorded typewriter progress. Speech has a pointed tail; thoughts have a cloud outline and trailing dots. Uses the existing popup texture assets. |
| `action_wheel.tscn` | Two banks of up to four navy-and-brass textured buttons. More… pages lists longer than eight. Mouse, visible-slot number keys and right-stick selection share the same option mapping. |
| `code_entry_panel.tscn` | Three code slots, six digits, separate Confirm and Clear options. Set `entered_digits` and `feedback`; selection emits an option for the simulation to handle. |
| `mission_hud.tscn` | Analogue Hour face, progress towards the next Hour, optional timed-action bar and subtle diary cue. Supply recorded world time. |
| `diary_notification.tscn` | Compact entry/death notice. Set only what the player knows; it contains no cause by default. |
| `diary_tab.tscn` | Page tab with an optional new-entry dot. |
| `interaction_highlight.tscn` | Resizable gold brackets for an available object. |
| `mission_result.tscn` | Success/failure card with externally supplied witnessed outcome text. |

The title scene starts the project and opens the current six-Hour Mission 1
rescue simulation, including the dock tutorial. The voyage journal retains the
current leg's recorded history. The diary pauses simulation time; interactions
and code entry through the action wheel leave it running, as specified in the GDD.

## Page-turn sprites

`source/page_turn.png` is an eight-frame transparent atlas (4 × 2 cells,
384 × 512 each), generated with built-in imagegen using `diary_open.png` as
the reference. `diary_page_flip.gd` registers each painted leaf to the spine,
foreshortens its raised tip, and plays the sequence over 0.64 seconds. Previous
page mirrors the same sequence. The settling leaf fades into the open book.

Prompt: one warm ivory parchment leaf turning right to left; eight stages from
flat right, through a lifting curled edge and upright leaf, to flat left;
consistent hinge, grain, golden edges and shaded underside; transparent
background, no desk, book, text or grid. Match the supplied antique diary art.
