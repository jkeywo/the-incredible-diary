# Mission 2: exploration build

Choose **Dev Menu → Mission 2** on the title screen, or **Turn the Page** after winning
Mission 1. The Mission 2 button resumes its own unfinished journal; after the
schedule ends it starts a new visit. Turning the Page always starts a fresh
Mission 2 in Amelia's cabin, even when an older Mission 2 save exists.
Mission 1's journal remains separate.

Amelia starts in the left crew cabin. Open its door to enter the service
corridor. All three crew doors can be opened and closed; scheduled characters
open them as needed. Brass doorframes render above characters. The foredeck is accessible.
The upper-left foyer door remains locked. Docks remain accessible as requested
in the layout diagram.

The foyer retains the smashed chandelier from Mission 1. A janitor in blue
overalls stands beside it sweeping throughout the six-hour visit. His animation
follows recorded time, including pause and scrubbing.

The watch runs from 1:00 to 7:00: six complete hours, twelve real minutes at
normal speed. Movement, waiting, diary pause and recorded editor history use
the shared runtime. There are no rescue objectives, deaths, hospitality tasks,
rewind unlocks or victory rewards in this build. At 7:00 the schedule stops and
the diary offers a return to the menu.

## Schedules

Each column is the destination for that hour. Characters walk through actual
doors; later departures are staggered slightly to reduce doorway congestion.

| Character | 1 | 2 | 3 | 4 | 5 | 6 |
| --- | --- | --- | --- | --- | --- | --- |
| Felix | Cabin | Salon | Foredeck | Foyer | Salon | Cabin |
| Evelyn | Cabin | Foredeck | Salon | Cabin | Foyer | Salon |
| Mabel | Cabin | Foyer | Salon | Foredeck | Cabin | Salon |
| Captain | Foredeck | Foyer | Controls | Salon | Foredeck | Foyer |
| Engineer | Controls | Steam room | Crew cabin | Controls | Steam room | Crew cabin |
| Porter | Foyer | Passenger cabins | Salon | Foyer | Passenger cabins | Crew cabin |
| Dock sailor | Crew cabin | Docks | Foredeck | Steam room | Crew cabin | Foyer |

The three incidental sailors and four incidental guests also have six authored
appointments each. All schedules are in [content.gd](content.gd) and are editable
through the shared authoring system. Journal `user://mission2.journal` contains
the current state, authored content and the entire recorded leg history.

## Validation

`tools/dev.ps1 Test` includes full-duration roster movement, bidirectional doors,
save/history restoration, both Mission 1 steam collision modes, and Mission 2
presentation. Native screenshots can be produced by running
`tests/mission2_presentation_test.gd` with `-- --screenshots`.
