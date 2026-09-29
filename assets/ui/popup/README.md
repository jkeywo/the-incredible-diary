# Player popup artwork

Nine PNGs make up the panel: `top_left`, `top`, `top_right`, `left`,
`body`, `right`, `bottom_left`, `bottom`, `bottom_right`.
`nine_piece_style.gd` draws all nine. Corners stay at 40 display pixels;
edges stretch along their length and the body fills the remaining rectangle.
Content has a 28-pixel inset. Tiny panels shrink corners to fit.

`tab.png` is a separate stretchable tab. `popup_skin.gd` supplies selected,
unselected and hover states, typography and buttons. Apply its `decorate`
helper to individual AcceptDialogs, never to the project or editor theme.
The returned VBoxContainer accepts custom content; `add_message` adds wrapped
dialog text. These dialogs retain Godot's confirmation/cancellation signals.

Used by settings, New Game confirmation, the voyage-load error, and the
reusable code-entry, voyage-summary and notification components. The latter
three are presentation components, not additional live screens in Mission 1.
Speech bubbles keep their own shape. The in-game diary uses
`assets/ui/mission_1/open_diary.tscn` and its existing `diary_open.png`.

## Source and packing

Generated with the built-in imagegen tool. Original outputs are in `source/`.
Run Godot with `--headless --path . --script res://tools/pack_popup_art.gd`
to resize and extract the nine adjacent regions and trim/package the tab.
The panel source is reduced to 384 square pixels and split at 48 and 336.
No repainting is performed during packing.

### Panel prompt

Create a production-ready 2D game UI background texture, a single square navy leather and antique brass Art Deco popup panel, for a pixel-art 1920s ocean liner diary game. Orthographic flat front view, no perspective. Exactly square panel fills the entire square image edge to edge. Thin double brass rule border running along all four sides, small elegant stepped geometric Art Deco details only in the four corners, each corner decoration wholly within outer 12 percent of image. Entire central 76 percent is uninterrupted very dark navy leather, extremely subtle fine pixel texture, uniform brightness, perfect for pale readable UI text. Straight edge strips have no ornament except the continuous parallel gold lines, so they can stretch cleanly. Crisp pixel-art craftsmanship matching a dark navy gold-embossed diary cover. No text, no letters, no buttons, no tabs, no objects, no mockup, no drop shadow, no surrounding margin. This will be sliced into 9 rectangular regions for a resizable game panel. Opaque navy body.

### Tab prompt

Create a single production-ready blank settings-menu tab texture for a 1920s ocean liner pixel-art game with navy leather and antique gold Art Deco diary-cover UI. One horizontal rectangle 3:1 aspect ratio centered, flat orthographic front view. Dark navy subtly textured leather body with a narrow antique gold double-line outline, neatly stepped bevels only at two top corners, simple straight lower edge. Restrained, crisp pixel-art, no glow, no shadow. Large clean blank navy center to hold a short text label supplied by game code. Transparent outside the tab, tightly cropped to the tab bounds. No text, no symbols, no letters, no extra elements. It must stretch horizontally as a nine-patch with top corner detail kept within outer 10% width.
