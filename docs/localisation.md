# Localisation

The shipped language is English. Automatic uses `navigator.languages` on web and
the OS locale on Windows, trying an exact locale and then its base language before
falling back to English. Settings offers a saved override. Language preferences
live in the existing device settings file, outside voyage saves. Web mirrors the
override into local storage so the loading screen can use it before Godot starts.

## Editing text

Edit the UTF-8 CSV catalogues in `localisation/`. `keys` contains permanent IDs,
`en` contains the English translation template, and `_notes` provides context.
`_source` preserves the deterministic English source format used by game code.
Most rows have identical `en` and `_source`; existing `%s`/`%d` source templates
use named `{arg1}` parameters in the translation column. Named parameters let
translators reorder the words without changing the simulation.

Run `python tools/localisation.py --generate` after editing. This generates
`source_text.gd`, whose constants let GDScript constant dictionaries and authored
dialogue seeds use the catalogue without depending on the active language.
Do not edit the generated file. Godot imports the CSV files into translation
resources; those generated binary resources stay out of Git.

Use new IDs when the meaning of a message changes. Update both source and English
when editing the source wording. Preserve IDs for unchanged messages. Add speaker
and situation notes for dialogue. Never put commands, actor IDs, paths or save keys
in translated text.

## Runtime interfaces

`foundation/message_text.gd` provides:

- `source(id, arguments)`: English only, for deterministic source text.
- `make_ref(id, arguments, fallback)`: serialisable ID, source revision, arguments
  and English fallback. Arguments can contain further message references.
- `resolve(reference)`: chosen-language text, with English/literal fallback.
- `plural(id, plural_id, count, arguments)`: Godot's CSV plural lookup.
- `assign(node, property, source)` and `assign_ref(...)`: update a UI property and
  retain its source so language changes can refresh it. These disable native
  translation on the node to avoid translating the result twice.
- `ui(source)`: presentation-only lookup for canvas text and existing English
  templates. The compatibility matcher recognises catalogue sources and their
  formatting parameters. Prefer explicit references for new formatted messages.
- `field(record, name)`: resolve a recorded reference, or display its literal
  field unchanged. This never guesses IDs from legacy saved text.

Native scene controls retain English text and use generated runtime aliases of
the stable catalogue IDs. Custom drawing calls `ui()` explicitly. Developer
authoring tools keep automatic translation disabled.

## Dialogue and history

Built-in scenes carry explicit `[ID:MESSAGE_ID]` tags. The custom parser strips
tags before displaying the line and preserves world commands. Author edits whose
source differs from the catalogue remain literal until matching translations
are authored. New untagged authored lines remain usable.

Schema 5 adds message references beside existing literal state fields and a
parallel list of diary records with observation ticks. Schemas 2–4 remain readable.
Entries without references retain their original wording. Changed source revisions
also fall back to the recorded wording. Neither locale selection nor catalogue
edits rewrite recorded events. Source-length timing remains in the simulation;
translated character reveal fits the same interval.

## Adding a language

1. Add its Godot locale column to the relevant CSV files. Keep named placeholders
   unchanged. Plural examples are in `plurals.csv` (including continuation rows).
2. Import in Godot, register the new `.translation` resources in project settings,
   and add the locale to `Localisation.SUPPORTED` and the settings language choices.
3. Run catalogue validation and the localisation tests. Check fonts, line breaks,
   speech bubbles, diary pagination and settings in the actual language.
4. Export both platforms. The web exporter includes translations in the initial
   package. Catalogue generation also rebuilds the standalone HTML loading shell
   with its catalogue and lookup code embedded, so direct Godot exports work too.

## Checks

- `tools/dev.ps1 CheckLocalisation` validates catalogues and generated constants.
- `tools/dev.ps1 Test` includes runtime and browser localisation tests.
- Pass `-- --pseudolocalisation` to a debug game to expand/accent text. It is not a
  selectable shipped language. Source-revision and legacy literal fallbacks stay
  literal even in this mode.
- Use `ExportWeb` and `ExportWindows` for release packaging checks.

Pass `-Python <python executable>` to `dev.ps1` if Python is not on PATH.

Language selection is in Settings → General. Automatic follows browser preferred languages on web and the OS locale on Windows; English is the shipped fallback.
