# Foundation domain language

- **Authored scenario:** The validated two-room content defining rooms, actors, commitments, interactions, and a Dialogue Manager scene.
- **Run:** The current leg's live state, recorded history, and the content versions needed to inspect or resume it.
- **Authoring session:** A paused foundation run with a dialogue draft and a selected recorded tick; resume validates and applies the draft.
- **Journal:** The persistent single-slot record of a run, including its current-leg history.

# Mission 1 and visual authoring

- **Passenger commitment:** An authored journey departure and destination. Passenger routines own the ordered commitments used both to sample movement and to determine the next departure that hospitality detours must respect.
- **Mission 1 Run:** Live voyage state, learned memory and recorded current-leg frames. It restores recorded data and notebook compatibility without reconstructing past outcomes. Frame indices can advance while tutorial voyage time stays frozen.
- **Mission 1 Journal:** Checksummed persistence of a Mission 1 Run. It coordinates restoration and transaction bookkeeping; the Run owns snapshot copying and the Journal owns file recovery.
- **Authoring document:** The shared scenario draft, invalid source drafts and chronological undo/redo transactions. Named visual edit operations own scenario changes; the harness supplies form values and displays results. Whole-document replacement remains available for source and remote workflows.
