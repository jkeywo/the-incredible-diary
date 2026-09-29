# Captain sprite

Generated with the built-in imagegen tool on 29 September 2026.
Project source: `assets/characters/source/captain.png`.
`assets/characters/captain.gd` normalises the sixteen source poses into the
existing 32 × 48 animation cells, removes faint alpha matte during import, and
uses the shared foot grounding. Rows face down, left, up and right; columns are
idle, first walking stride, talking gesture and opposite walking stride.

## Generation prompt

Create a production game sprite sheet, transparent background. One 1920s
Mediterranean cruise ship captain, dignified older man with small grey moustache,
white peaked captain cap with gold badge, navy double-breasted officer uniform,
gold sleeve braid and buttons, navy trousers, black shoes. Compact crisp pixel
art warm Art Deco palette, three-quarter top-down RPG proportions designed to
read at 32x48 pixels. EXACT regular 4 columns by 4 rows grid, 16 equally sized
cells, consistent centered feet baseline and full body height in every cell,
generous transparent gutters, no shadows, text or grid lines. Row 1 faces
down/front; row 2 strict left profile; row 3 back/up; row 4 strict right profile.
Each row columns: 1 neutral standing idle; 2 walking left-leg forward/right-arm
forward; 3 standing talking with small hand gesture feet planted; 4 walking
right-leg forward/left-arm forward. Same identity and outfit all frames. Save
as captain.png for integration in Godot.

## Transparency refinement

Remove ALL background from this sprite sheet to true transparent alpha.
Preserve all sixteen captain sprites exactly, all poses, grid positions,
colours and pixel edges. Remove brown grey black haze and all glow completely.
Empty space must be alpha zero, not black or checkerboard. Keep exact 4 by 4
grid and dimensions. No other changes.
