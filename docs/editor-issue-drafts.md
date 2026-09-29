# Operational editor implementation issue drafts

Parent: https://github.com/jkeywo/the-incredible-diary/issues/2

Status: approved and published. See [published issues](editor-issues.md) for GitHub links. The draft slice identifiers below are retained as the approved breakdown record; live issue bodies contain real dependency links. Parent PRD #2 was not modified.

## Current implementation context

The repository now contains the committed foundation, not just the original probe. The foundation has deterministic ticks, serializable dialogue/action state, per-tick history and diagnostics, continuation compatibility checks, checksummed save journaling and a diagnostic harness. Its content is still a narrow two-room schema with hard-coded actors/rooms and limited dialogue commands. Extend these existing interfaces instead of building a second simulation. Existing regression and full-leg evidence provide starting points, not proof of new editor functionality.

The baseline was committed in `37aca55`; the foundation implementation is in `866505f`, followed by save/performance/controller evidence. Uncommitted character/prop artwork and harness changes are outside this planning task and must not be swept into it. There are no existing editor implementation issues or comments on PRD #2 at review time.

All slices include necessary schema/runtime integration, UI and behavioural tests. AFK means implementation decisions can be made within the approved design; HITL marks the unresolved external authentication/hosting arrangement. All local authoring behaviour targets Windows and web. Cross-device synchronization covers authored content and referenced assets, not game saves, recorded simulation history or undo journals.

## E1 — Edit and resume a paused scene through one authoring document

Type: AFK. PRD stories: 1, 2, 3, 8, 14, 16, 17, 28 (initial authoring transaction coverage).

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Replace the diagnostic source-edit workflow with a minimal operational paused editor backed by an authoring document. Edit the existing Dialogue Manager scene, undo/redo the edit, and resume or step using the validated document. Preserve invalid text as a draft distinct from the last applied valid content. Establish document command interfaces that later tools will share.

### Acceptance criteria
- [ ] Pausing opens editing; resuming closes editing and automatically validates/applies a coherent content version. No separate Apply action and no edits while running.
- [ ] Syntax, command/reference and compatibility failures keep the editor paused and identify the offending content; failed historical continuation preserves later history.
- [ ] Text editing has grouped undo/redo operations with meaningful labels; undo affects content, not simulation time.
- [ ] Editing active dialogue never implicitly replays commands. Existing foundation compatibility rules are retained or extended with explicit regression evidence.
- [ ] Demonstrate edit → undo → redo → resume → changed future behaviour on Windows/web; tests exercise public document and application behaviour.

### Blocked by
https://github.com/jkeywo/the-incredible-diary/issues/10 — validated foundation interfaces and integrated evidence.

## E2 — Import a background and draw playable room geometry

Type: AFK. PRD stories: 3, 4, 5, 16, 17, 26 (local asset handling).

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Create/edit a room using an imported image and drawn walkable regions. Integrate the authored geometry with direct player/NPC navigation, rather than just drawing an editor overlay. Use a project asset manifest with stable references portable between native and browser storage.

### Acceptance criteria
- [ ] Select an image through supported native/web import flows and display it under editable walkable geometry.
- [ ] Create, move and remove geometry through shared document transactions and undo/redo; display geometry diagnostics.
- [ ] Resume and demonstrate movement constrained by the authored geometry without changing engine code.
- [ ] Missing assets and invalid geometry produce actionable errors without losing the draft; distinguish authored geometry from temporary hazards.
- [ ] Tests cover asset-reference consistency, coordinate mapping and navigable behaviour; demonstrate both exports.

### Blocked by
E1.

## E3 — Connect rooms and place working local interactions

Type: AFK. PRD stories: 3, 5, 6, 16, 17.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Place doors, props and explicit interaction positions over backgrounds; connect two rooms and configure a timed interaction using supported simulation commands. Extend the foundation's fixed connection model sufficiently to play an authored arrangement.

### Acceptance criteria
- [ ] Edit room connections and door endpoints visually and observe Amelia/NPCs crossing correctly in play.
- [ ] Place an interaction, configure its duration/effect through supported data and complete it in play.
- [ ] Choices remain local to Amelia and never auto-walk her to an authored position.
- [ ] Broken required connections and unreachable interaction positions block advancement; intentional conditional access does not fail merely because currently blocked.
- [ ] Shared undo/redo reverses placements and connection edits coherently, including references; tests cover the authored end-to-end traversal/action.

### Blocked by
E2.

## E4 — Author an NPC and its schedule in visual and source views

Type: AFK. PRD stories: 3, 7 (schedules), 16, 17.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Create/edit actor definitions and scheduled commitments through forms/timelines and a source view backed by the same document. Generalize the relevant hard-coded foundation assumptions only as needed to run an authored actor schedule across rooms.

### Acceptance criteria
- [ ] Create an actor and authored commitments without editing engine code, then observe the resulting movement in play.
- [ ] Editing either visual or source representation updates the same valid document; invalid source remains a preserved draft and is not silently replaced by a generated view.
- [ ] Missing actors/rooms and malformed schedule values receive actionable diagnostics; meaningful timing conflicts are explained without asserting puzzle solvability.
- [ ] Undo/redo works across schedule forms, timeline drags and source changes in chronological order.
- [ ] Tests demonstrate changed schedule behaviour and reject incompatible active-state edits without damaging the run.

### Blocked by
E3.

## E5 — Author a conditioned storylet that triggers a scene

Type: AFK. PRD stories: 3, 7 (storylets), 8, 16, 17.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Create a storylet with required characters, time window, conditions and an associated Dialogue Manager scene through forms and source. Connect it to the deterministic runtime so changing eligibility changes actual scene availability or execution. Extend the narrow foundation adapter using explicit supported commands, not unrestricted runtime mutation from editor widgets.

### Acceptance criteria
- [ ] Author and execute a scene gated by a character, a time window and a world condition.
- [ ] Visual/source changes share document identity and undo/redo; malformed source remains recoverable.
- [ ] Missing scene/actor/storylet references and invalid commands block resume with an actionable explanation.
- [ ] Selection and effects remain deterministic; completed effects do not replay merely because an unrelated scene changed.
- [ ] Tests cover eligible/blocked transitions, authored command effects and intentional inaccessible content without treating puzzles as validation failures.

### Blocked by
E4.

## E6 — Diagnose authored content against recorded history

Type: AFK. PRD stories: 9, 10, 11, 12, 13, 14, 28.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Integrate any-room navigation, read-only NPC/storylet inspectors, tick/event stepping and the scrubber into the operational editor. Inspect the newly authored schedules/storylets using foundation-recorded state and diagnostics. Explicitly continue from a prior moment using current validated content.

### Acceptance criteria
- [ ] Inspect any room independently of Amelia; show actor state, intended behaviour and condition-by-condition storylet explanations.
- [ ] Scrubbing presents recorded results from the content active then; draft changes never cause hypothetical reinterpretation.
- [ ] Debug inspection grants no player knowledge and offers no teleport, variable overrides or debug knowledge grants.
- [ ] Tick/event stepping stops paused; Resume from here validates before replacing future history; incompatible changes explain why restart is required.
- [ ] Tests cover mixed authoring plus scrub/resume workflows and recorded diagnostics across content versions, reusing foundation regression coverage.

### Blocked by
E5.

## E7 — Recover drafts and shared undo/redo after reopening

Type: AFK. PRD stories: 15, 16, 17, 18, 19 (baseline contract), 25 (local failures), 28.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Persist authoring drafts, assets, the shared transaction journal and its HEAD baseline separately from the game save. Restore an unfinished multi-tool editing session after native restart or fresh browser session, including invalid source and redo operations. Provide failure reporting and recovery behaviour.

### Acceptance criteria
- [ ] A mixed map/schedule/scene editing session autosaves and reopens with correct undo and redo order and descriptive labels.
- [ ] Unfinished invalid source survives closing even though it cannot resume; last valid runtime content is not confused with the draft.
- [ ] HEAD-change input clears authoring undo/redo while preserving protected draft content; unchanged HEAD retains it. Verify this contract independently before live sync integrates it.
- [ ] Simulation scrub/reset does not undo authoring changes or clear its journal; authoring undo does not rewind simulation.
- [ ] Interrupted writes, denied/quota-exhausted browser storage and corrupted journals are reported and handled without silently replacing recoverable work.
- [ ] Verify fresh-process and fresh-page persistence on Windows/web, not only in-process reload.

### Blocked by
E5.

## E8 — Sign in to GitHub and open a project on both clients

Type: HITL. PRD stories: 20, 25, 26, 27.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Deliver a working sign-in, repository/branch selection and authored-project open flow on Windows and the Pages-hosted web build. Resolve the external authentication/hosting arrangement with the owner, then implement and exercise it against a dedicated test repository. GitHub Pages is the static game host, not a server-side authentication service.

### Acceptance criteria
- [ ] Owner confirms the authentication registration/hosting arrangement and integration-test repository; record the chosen contract and required configuration. Do not assume a paid provider.
- [ ] Both clients authenticate, list/select accessible repositories/branches and load a project with referenced assets into the editor.
- [ ] Explicitly handle repositories without a valid authored-project manifest; do not interpret arbitrary repository files as project content.
- [ ] Cancellation, expired authorization and denied access preserve local drafts; loading another project does not silently overwrite them.
- [ ] No client secret/token enters Git-tracked assets, public bundles or logs; implement minimum required permissions and appropriate session storage.
- [ ] Test authentication boundary/failure cases via a fake transport and demonstrate the real flow on Windows and Pages, without requiring browser access to a Git executable.

### Blocked by
E7 — portable content/asset representation and durable workspace protection.

## E9 — Commit valid authored content and assets explicitly

Type: AFK. PRD stories: 3, 19, 21, 22, 25, 26, 27.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Provide Commit & sync with a change summary and commit message, initially for an unchanged remote HEAD. Validate the complete authored project, commit its content/assets as one coherent version and update the local baseline. Other clients can open the committed version using E8. Incoming concurrent changes are detected and preserved for the subsequent sync slices.

### Acceptance criteria
- [ ] Invalid scripts and structural errors block committing with links to offending content; local autosave still preserves them.
- [ ] A valid project with a new background asset can be committed from either client and opened by the other with working references.
- [ ] Resume/step/autosave never create commits; only explicit Commit & sync does.
- [ ] Successful HEAD movement clears authoring undo/redo; failed or rejected updates with unchanged HEAD retain it.
- [ ] Game saves, simulation history, local undo journals and credentials are excluded from GitHub project commits.
- [ ] Detect remote-head races without force overwrite; ambiguous network responses reconcile remote state before retrying, avoiding duplicate/lost commits.
- [ ] Test commit planning and failures through fake transport and a real disposable-repository round trip.

### Blocked by
E8.

## E10 — Pull and integrate non-conflicting remote changes

Type: AFK. PRD stories: 3, 19, 23, 25, 26.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Extend synchronization to retrieve newer remote content, fast-forward clean workspaces and automatically integrate non-conflicting local/remote changes using their common baseline. Validate the combined result before activating it; do not equate text-clean merges with valid projects.

### Acceptance criteria
- [ ] Two clients editing independent content converge without manually resolving a merge; no local draft is silently lost.
- [ ] Fast-forward, diverged non-conflicting history and repeat sync have deterministic, idempotent outcomes.
- [ ] Referenced assets are transferred coherently; deletions and incoming references are validated.
- [ ] A fetch alone leaves undo/redo intact; adopting a different HEAD clears it while preserving any protected uncommitted work.
- [ ] Invalid combined content is preserved for correction, blocks resume/commit and is never partially activated; unresolved conflicts are reported for E11.
- [ ] Simulate remote races and interrupted downloads, then verify Windows-to-web-to-Windows integration on the test repository.

### Blocked by
E9.

## E11 — Preserve conflicts on branches and resolve them remotely

Type: AFK. PRD stories: 19, 22, 24, 25, 26.

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
When automatic integration cannot safely combine changes, preserve the valid local version on a separate branch, display its status and provide a GitHub link for remote resolution. Afterwards retrieve the resolved version through the ordinary sync flow. Do not build a merge editor.

### Acceptance criteria
- [ ] Conflicting changes never overwrite either version or force-update the shared branch.
- [ ] Valid local content and assets are preserved on a uniquely identified branch; invalid drafts stay local and block conflict-preservation commits until corrected.
- [ ] UI explains the conflict, points to the remote branch/comparison and lets the author retry after remote resolution, without embedded conflict-resolution controls.
- [ ] Repeated retries/restarts recover the existing conflict handoff rather than creating uncontrolled duplicate branches.
- [ ] Retrieving the remotely resolved result validates before application and resets authoring history only when HEAD changes.
- [ ] Test text, asset and semantic/reference conflicts plus network failures; demonstrate one real remotely resolved conflict across the two clients.

### Blocked by
E10.

## E12 — Demonstrate complete authoring, recovery and cross-client sync

Type: AFK. PRD stories: 1–28 (integrated completion evidence).

### Parent
https://github.com/jkeywo/the-incredible-diary/issues/2

### What to build
Create a two-room scenario entirely through the editor, run it, diagnose and fix it from history, reopen the unfinished authoring session and synchronize it between Windows and Pages. Extend the existing foundation tests with editor integration and repeatable GitHub transport checks; preserve evidence of real-client flows.

### Acceptance criteria
- [ ] Create rooms, connections, an NPC schedule and a conditioned dialogue/action scene without modifying engine code; play the result on Windows and hosted web.
- [ ] Demonstrate mixed-panel undo/redo, invalid-draft recovery, correct HEAD boundaries and separation of simulation history from authoring history.
- [ ] Scrub actual history, identify a blocking condition, edit while paused and resume safely; prove old history was not reinterpreted.
- [ ] Complete Windows commit → web retrieve/edit/commit → Windows retrieve, including assets, plus the branch-based remote conflict workflow.
- [ ] Exercise offline, expired-auth and interrupted-storage/network cases without lost drafts; inspect public artifacts/logs for credential leakage.
- [ ] Run proportionate automated behavioural checks and native/web demonstrations; report browser versions, residual limitations and external service configuration.
- [ ] Do not claim the full editor complete on the strength of mocked transport, localhost authentication, the old probe or export success alone.

### Blocked by
E6 and E11; E11 transitively includes E7's persistence work.
