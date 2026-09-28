# Mission 1 opening slice

`opening.tscn` is the scene beneath the title diary. Amelia starts in the open
middle of the docks; WASD or left stick moves her after the book transition.
The central gangway leads into the foyer, and the foyer entrance returns to
the docks. This is the first controllable opening, not the full six-Hour rescue
simulation.

The separate `user://mission1_opening_v1.json` slot stores the latest room,
position, facing and elapsed time **with the current leg's recorded position
history**. Continue loads the valid slot. New asks before clearing its primary,
staged and backup files; the Test Level's foundation save is untouched. The
slot can be migrated when Mission 1's complete simulation and history schema
are implemented.
