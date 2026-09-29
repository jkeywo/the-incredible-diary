# Two-room test-bed valve

Mission 1's stateful prop sheets and loadable Godot scenes are documented in
`mission_1/README.md`. They include this valve as a reusable two-state scene.

`valve_states.png` is a transparent 64 × 48 sprite sheet with two 32 × 48
cells: open/steaming, then closed. The valve wheel faces the camera on top of
a floor-standing machine. Its cabinet has a visible top and right side for the
room's three-quarter projection. `foundation/harness.gd` draws the cell selected by the
recorded `close_valve` flag, including while inspecting earlier ticks.

The source art was made with the built-in imagegen tool. Prompt: “Compact
chunky 1920s shipboard pixel art; two identical floor-standing
steam-control machines with a visible top and right cabinet side; front-facing brass wheel on top; open state has visible steam and a
red indicator, closed state has no steam and a green indicator; transparent
background; designed for 32 × 48 cells.” Run `tools/build_valve_sprite.py` with
Pillow to regenerate the sheet.
