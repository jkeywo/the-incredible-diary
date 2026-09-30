# Rendering depth

`mission1/render_depth.gd` owns world layers, the ground-anchor comparison and
occlusion fading. Use its named constants and `assign`; do not add numeric
layer overrides in individual assets.

| Layer | Purpose |
| --- | --- |
| SHELL_BACKGROUND | Title shell's solid backing, below room artwork |
| BACKGROUND | Flat room artwork and floor |
| ENTITY | Characters, door leaves, lower jambs and ordinary props |
| OVERHEAD | Upper arches, suspended fixtures and foreground masks |
| EFFECT | Steam and other effects that must cross world geometry |
| OVERLAY | World debug/interaction overlays |

HUD controls remain in their separate CanvasLayer. Their background fading is
independent of world depth.

## Ground anchor

Each entity's node origin is its floor contact. Authored instance `position`
stores this anchor; it is also the interaction/collision location. The editor
shows it as a crosshair and exposes X/Y controls and map placement. Existing
documents already use this field, so no save migration is needed.

Godot Y-sorts siblings in the entity container within each layer. Larger Y draws
in front. At identical Y, scene-tree order breaks the tie; equal anchors do not
trigger fading. All assigned layers are absolute, avoiding accidental changes
from a parent's layer. World translation is shared by the room and entity
containers.

Adjust a sprite's `offset`, region or child artwork to align it to its anchor;
never move the anchor to compensate for transparent image margins. Character
grounding aligns visible soles with this origin. Animation can move the artwork
without changing the sorting plane.

Apply authored state before animated poses, then calculate occlusion from the
final pose. Reapplying the same prop state must preserve its current art offset;
otherwise a hanging object's fade can be evaluated at its landing position.

Split an asset when it spans different depth rules: crew leaves and lower jambs
are ENTITY, arches OVERHEAD, all anchored to the threshold. Room-owned pieces
join the common entity container and its cleanup lifecycle. The chandelier
switches from OVERHEAD to ENTITY on landing. A glass on the bar is OVERHEAD;
after dropping it uses ENTITY. The bar mask has an explicit floor anchor while
its image offset preserves its screen placement. Steam uses EFFECT.

## Occlusion

Only objects explicitly marked as occluders fade. A visible character must have
an anchor above the object's anchor and a layer no higher than the object.
Then opaque character pixels must intersect opaque object pixels (or a frame's
polygon). Transparent animation-cell margins do not count. Such objects use
50% opacity; otherwise they return to full opacity.
Sprite margins, height thresholds and animation frame bottoms do not decide
depth. This is the same anchor/layer relation used for drawing.

Flat background art cannot occlude characters. Extract any newly required
foreground geometry into a separately anchored piece. Do not raise an entire
room backdrop to make one feature draw over a character.
