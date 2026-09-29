# Shared pause editor

`PauseEditor` is an autoload. Space / controller Back routes through it for every
scene. Gameplay scenes do not need to instantiate an editor or bind pause.
The title screen opts out until its opening transition has enabled gameplay.

The default editor pauses the SceneTree, shows a scene tree and an inspector in
draggable, resizable panels, and supports closing, minimising, restoring, undo
and redo. The inspector edits exported booleans, numbers and string enums;
numeric export ranges are respected. These edits last for the current scene
session. Free-form content, resources and paths are excluded because they need
domain validation before applying changes.

A scene with `toggle_pause_editor()` supplies its own authoring adapter. The
foundation harness uses this to retain its recorded simulation, validation,
source editors, history and GitHub workflow. Its pause shortcut still routes
through the shared autoload. The default inspector does not yet provide those
content-authoring features to Mission 1.

`tests/pause_editor_test.gd`, included in `tools/dev.ps1 Test`, covers default
activation without scene setup, title gating, paused property undo/redo,
disabled edits while running, all four walk directions, frozen simulation and
animation, recorded tutorial frames, continued Mission 1 state, shared panel
lifecycle and authoring-adapter delegation.

## Amelia walk art

The latest appearance correction makes Amelia read as a boy, with cropped hair
and a boxy uniform across walk, standing and action sprites. The earlier prompts
below are historical; [the current art prompts](amelia-boyish-art.json) supersede
their appearance descriptions.

`assets/characters/player_walk.png` is a separate four-facing walk atlas. Idle,
talk and action art retain their existing atlas. `tools/pack_player_walk.py`
crops and aligns the generated source to 32 × 48 cells. No additional runtime
dependency is needed on Windows or web.

The source `assets/characters/walk_source/player_cycle.png` was generated with
the built-in imagegen tool, using `player_sprites.png` as the character/style
reference. Final prompt:

> Game sprite animation asset, transparent alpha background, 4x4 evenly spaced grid of 16 full-body sprites. Reference is the exact slender adult Amelia female steamship purser in navy uniform and cap; retain proportions and pixel-art palette, NOT chibi. Four rows: down/front, LEFT profile, back/up, RIGHT profile. Four columns per row show distinct walking poses: left-foot contact, passing, right-foot contact, passing. CRITICAL ARM MOTION: shoulders remain in fixed place, left arm swings FORWARD when RIGHT leg is forward, right arm swings BACK at the same instant. Reverse these arms in column 3. Column 1 versus 3 must have clearly opposite arm positions. In side views forward arm angles about 30 degrees forward at shoulder, rear arm about 25 degrees back, gently bent elbows, hands displaced visibly far from hips. In passing columns 2 and 4 both arms hang near the torso and feet come TOGETHER below pelvis with one knee bent. Contact columns feet spread APART with the opposite leg forward in column 3. Preserve left/right limb identity by consistent front/behind layering; no identical repeated stride pictures. Front/back rows similarly opposite swinging arms and alternating raised knees. Common scale, cell centers, foot baseline per row; ample transparent gutters. No ground, backdrop, shadow, text or grid. This sheet must animate smoothly in order 1-2-3-4-loop with real counter-swing of arms and legs, not a fixed pose wobbling.

Final refinement, also using built-in imagegen:

> Edit this sprite animation sheet. Keep the 4x4 grid and same Amelia character, uniform, scale and transparent background. IMPORTANT FIX ONLY THE CONTACT POSES IN COLUMN THREE: in row 2 (left-facing profile), the NEAR arm currently points left/forward just like column 1. Change the NEAR arm in column 3 to swing BACKWARD to screen RIGHT, with the near elbow/hand visibly to the RIGHT of the torso. The far arm swings LEFT in front of the body. Near leg likewise must be forward left in column 3 (opposite near arm). In row 4 (right-facing profile), change the NEAR arm in column 3 to swing BACKWARD to screen LEFT, with hand clearly to the LEFT of torso. Far arm swings RIGHT, near leg forward RIGHT. Near sleeve/arm is drawn on TOP of torso so which arm is near is completely unambiguous. These column-3 side-view poses must visibly differ from column 1: the arm closest to the viewer points behind the character, not in front. Maintain all other twelve sprites exactly, especially passing poses in columns 2 and 4. No backdrop/shadow/text. Actual transparent alpha.
