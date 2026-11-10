# كلمات سهمية — Arabic Arrowwords

An Arabic RTL puzzle game for Android and iOS, with a FastAPI dictionary server,
SQLite progress on the phone, and **75 validated offline levels**. Dedicated to:

> إلى أبي الغالي جوهر، بكل الحب والتقدير

The application uses no LLM, account system, Firebase, analytics SDK, or remote
player database. The expanded dictionary is included in `backend/words.db`; the
original starter dictionary and reviewed medium/hard words also work on a new DB
without downloading any external data.

## Run the backend

Python **3.10+**:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements-dev.txt
.\.venv\Scripts\python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

On macOS/Linux use `.venv/bin/python`. API documentation: http://127.0.0.1:8000/docs.
Set `WORDS_DB` to use another SQLite file. Startup applies additive schema v3
migrations; existing IDs, answers, clues and origin fields remain. Invalid legacy
records are excluded from generation, without deleting them. A pre-upgrade copy of
this workspace's original database is in `backend/backups/words-before-upgrade.db`.
Use SQLite's backup API before upgrading a live deployment.

| Endpoint | Behavior |
|---|---|
| `/api/health` | Eligible pair counts, distinct answers by difficulty, sources and measured-frequency coverage |
| `/api/words?difficulty=easy&limit=100` | Easy vocabulary with difficulty and provenance |
| `/api/words?difficulty=medium&limit=100` | Medium vocabulary |
| `/api/words?difficulty=hard&limit=100` | Hard vocabulary |
| `/api/puzzles/generate?level=10` | Easy, default 8×8 |
| `/api/puzzles/generate?level=35` | Medium, default 9×9 |
| `/api/puzzles/generate?level=75` | Hard, default 10×10 |
| `/api/knowledge/{word_id}` | Attributed dictionary card, review status and timestamps |
| `/api/knowledge?category=language&limit=20` | Filtered, paginated cards (limit 1–100) |
| `/api/knowledge/random?difficulty=medium` | One available card of that difficulty |
| `/api/knowledge/categories` | Arabic category labels and actual card counts |
| `/api/knowledge/{word_id}/quiz` | Three unambiguous choices, or 404 when unavailable |

`limit` (1–500), `offset`, `length` (2–10), and the existing `seed` argument remain
accepted for words. Pagination is now stable ascending ID, using indexes; `seed`
does not reorder pages. Responses add `nextOffset` and difficulty metadata.
An explicit puzzle `size` (6–12) remains supported. Old puzzle fields (`cells`,
`words`, `direction`, `clueCell`, `answer`) remain; new metadata is additive.
Vocabulary shortages return HTTP 422 with Arabic guidance and the requested
category. The server never substitutes easier words for hard levels.

## Dictionary and difficulty

The actual included dictionary has **76,373 eligible pairs / 33,173 distinct
answers**. Reproduce the audit with:

```powershell
cd backend
.\.venv\Scripts\python audit_dictionary.py --output vocabulary_report.json
```

| Level band | Difficulty | Arabic | Pairs | Distinct answers in category |
|---|---|---|---:|---:|
| 1–20 | easy | سهل | 6,951 | 1,345 |
| 21–50 | medium | متوسط | 22,407 | 7,304 |
| 51+ | hard | صعب | 47,015 | 25,083 |

Different meanings/clues of the same answer can fall in different categories, so
category answer counts do not sum to the global distinct count. Difficulty belongs
to an answer–clue pair. Reviewed familiarity overrides apply consistently per word.

75,868 pairs originate from Arabic WordNet, 297 from the starter dictionary, and
208 from the additional reviewed fallback dictionary. **73,626 stored pairs have
measured frequency metadata**; the other 2,747 are explicitly marked as heuristic.
Full source and import hashes are in `backend/vocabulary_report.json`.

The importer scans the supplied AWN4 WN-LMF XML directly with `defusedxml`; it does
not read unrelated lexicons from a global `wn` cache. It preserves hamza, alif
maqsura and taa marbuta, removes presentation forms/tatweel/diacritics, rejects
multiword or malformed answers, invalid/unsuitable definitions, and normalized
answer leaks. Unique answer/clue constraints make repeat imports safe. Source
synsets, archive hashes, rank/count/source and classification method remain in SQLite.

```powershell
cd backend
# Downloads official WordNet (~11 MB) and optional CAMeL MSA frequencies (~69 MB).
.\.venv\Scripts\python fetch_wordnet.py --with-frequency

# A local download also works; no network is used during import.
.\.venv\Scripts\python import_wordnet.py data/awn4.xml.gz --frequency-file data/MSA_freq_lists.tsv.zip

# Without the optional frequency list, use the documented heuristic.
.\.venv\Scripts\python import_wordnet.py data/awn4.xml.gz
```

Downloads use validated temporary files and atomic replacement. Missing files,
failed downloads, invalid XML, wrong lexicons, malformed frequency lists and DB
errors return a nonzero exit code with a useful message. Test databases never
modify the shipped dictionary.

Classification is deterministic and explainable:

- Measured MSA row ranks: ≤3,000 starts at score 0.4; ≤30,000 at 1.4; rarer at 2.5.
  Matches are exact after diacritic cleanup; ranks are not invented or stemmed.
- Answer length above four characters adds 0.12 per character (up to 0.9).
  Clue length above eight tokens adds 0.055 per token (up to 0.7).
- Multiple alternatives add ambiguity cost 0.2; specialized terminology adds 1.1;
  literary markers add 0.7. Scores below 1.3 are easy, below 2.5 medium, else hard.
- **Fallback:** an unmatched word starts at 1.45, meaning unknown familiarity is
  medium rather than assumed rare. Reviewed everyday/medium/literary sets provide
  known examples and enough words in each band without external data. Method names
  explicitly distinguish `corpus-rank-v1` from `fallback-heuristic-v1`, with an
  additional `reviewed-familiarity` marker where used. These rules are estimates of
  player difficulty, not claims of verified frequency for unmatched words.

Source attribution and data licenses, including CAMeL's share-alike terms, are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). WordNet was translated upstream
with AI assistance; this project's importer/generator calls no AI service.
Bulk WordNet meanings can be ambiguous and still need editorial review for a
commercial word game. The bundled puzzles use the reviewed fallback vocabulary.

## Generation and offline release

The generator uses level/size/trial seeds, indexed rotating vocabulary windows,
seeded word priorities, dedicated in-grid clues, and left/down arrows. Crossings
must match; parallel overlap, duplicate answers, unbounded answers, orphan cells,
and unintended adjacent letter runs are rejected. Every exported puzzle is
validated with explicit exceptions, including when Python runs with `-O`.
The API caches recent generated levels in memory. Reproducibility assumes the same
dictionary snapshot, parameters, and generator version; saved phone puzzles are
always authoritative after they are first opened.

```powershell
cd backend
.\.venv\Scripts\python generate_offline.py --levels 75 --workers 3
```

This writes the bundle atomically only after **all** puzzles validate, plus
`flutter_app/assets/puzzles/validation_report.json`. Current bundle: 20 easy,
30 medium, 25 hard, at least 9 words per puzzle, 399 distinct answers. Per-release
reuse caps are three/easy, seven/medium, eight/hard. The API can generate additional
levels from the expanded category-specific dictionary.

## Run Flutter

Flutter **3.27+ / Dart 3.6+**; validated here with Flutter 3.47.9 / Dart 3.13.7.
Install Android tooling or Xcode for the target device. Native Android and iOS
folders are now included.

```powershell
cd flutter_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

If using the workspace-local SDK, replace `flutter` with
`..\.tools\flutter\bin\flutter.bat`. The optional setup script discovers that SDK
too: `python scripts/setup_flutter.py`. It generates missing platforms in a
temporary project and copies **only** native folders, preserving Dart, assets,
tests and pubspec. It adds Internet permission, Arabic app names, and debug-only
local HTTP configuration. It does not touch the phone database.

Without an `API_BASE_URL` override, the app connects to
`https://kalimat-sahmiya-api.onrender.com`. Its branded splash checks `/api/health`
and allows up to 90 seconds for the server to wake up. A ready server advances
after a minimum of three seconds; retry and offline continuation are available.
Use the local URL overrides shown here when running your own backend.

Android emulator uses `10.0.2.2`; iOS simulator uses `127.0.0.1`. A physical device
needs your computer's LAN address on the same network. Android debug manifest and
iOS `Info-Debug.plist` permit local HTTP; release configurations require HTTPS.

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example
```

The UI includes a purple/cream Material 3 dashboard, chapter cards, animated level
selection/unlocking, visible difficulty and coin balance, zoomable animated board,
crossing and cursor highlights, press feedback, immediate letter entry, animated
progress/rewards, a quiet victory dialog and four-step onboarding. Noto Sans Arabic
is bundled for offline typography. Explicit animations, haptics and navigation
transitions respect reduced-motion/accessibility settings.

The introduction explains reading clues, arrows, entry, completion and hints;
the dedication is retained. Its SQLite flag prevents it reappearing after completion.

## Player saves and offline behavior

For a quick development preview in Microsoft Edge, run from `flutter_app`:

```powershell
..\.tools\flutter\bin\flutter.bat run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The Edge preview uses temporary in-memory data, which resets on a full browser
reload or hot restart. Phone builds continue to use the persistent SQLite store.

The app continues to use **`jawhar_arrowwords.db` in persistent app storage**.
Migration v1→v2 adds hint count and vocabulary metadata columns; v2→v3 adds learning
tables and preferences. Neither migration
replace or rewrite existing puzzle JSON, answers, solved words, completed flags,
coin settings, or the introduction flag. Legacy puzzles remain playable.

Saved puzzles are checked before bundled assets or the API. New bundled levels
work offline immediately; levels beyond 75 need a connection for their first
download, then remain playable offline. Concurrent downloads/sync are coalesced,
failed requests can be retried, word cursors use stable paging, and Arabic error
messages distinguish unavailable/invalid downloads. Input saves are serialized;
leaving the board waits for queued saves. Hints debit coins and save the revealed
letter/count in one transaction. Completion rewards of 60 coins are transactional
and awarded once per level. Starting balance is 120; hints cost 25.

Uninstalling removes private app storage on typical devices. There is no automatic
cross-device sync or cloud backup feature in the application.

## Checks and previews

```powershell
cd backend
.\.venv\Scripts\python -m pytest -q
cd ../flutter_app
flutter pub get
flutter analyze
flutter test
# Optional: render home/game/onboarding/victory PNGs under previews/.
flutter test --dart-define=GENERATE_PREVIEWS=true test/preview_test.dart
```

Backend tests cover additive migration, import repeatability/failure, cleanup,
frequency parsing, difficulty boundaries, filtered endpoints, reproducibility,
category shortages and every packaged grid. Flutter tests cover API errors and
request coalescing, real SQLite upgrade/restart/reward/hint persistence, bundled
and downloaded offline levels, first launch, level locks, difficulty sections,
compact layouts, letter entry and completion feedback. Platform release builds
and real-device frame performance require the corresponding device toolchain.

The learning upgrade is covered by the backend and Flutter regression suites,
including real SQLite restarts, review intervals, duplicate-event protection,
optional cards, search/favorites, rapid input, zoom/pan, RTL and enlarged text.
The default suite skips the optional preview export.
Verified in this workspace: **33 backend tests and 27 Flutter tests passed**,
`flutter pub get --offline` succeeded, and `flutter analyze` reported no issues.
The browser release build and the separate preview export also passed. The export
renders ten Arabic screens; device-dimension checks additionally cover font
preferences, focus mode and pause/resume. These checks do not measure phone FPS.
The Python suite emits one upstream Starlette/httpx deprecation warning.
Flutter Doctor could not locate an Android SDK, and this Windows machine cannot
run Xcode; no APK/IPA release build or real-device performance result is claimed.

Rendered previews: [home](flutter_app/previews/home.png),
[game](flutter_app/previews/game.png), [onboarding](flutter_app/previews/intro.png),
[victory](flutter_app/previews/victory.png).
Learning previews: [dictionary](flutter_app/previews/dictionary.png),
[review](flutter_app/previews/review.png), [knowledge cards](flutter_app/previews/knowledge.png),
[knowledge sheet](flutter_app/previews/knowledge_card.png),
[levels](flutter_app/previews/levels.png), [focus mode](flutter_app/previews/focus.png).

## A quieter place to learn

The Material 3 theme uses warm ivory (`#F8F6F1`), forest green (`#315C52`), sage,
sand, soft sky blue and muted lavender, with charcoal Arabic text. It uses bundled
Noto Arabic, rounded icons, short fades and selection transitions, and a calm
completion screen. System reduced-motion settings are honored. Comfort settings
offer normal, large and extra-large type, reduced motion and focus mode; font
preferences multiply system scaling rather than replacing it. This release uses
the light relaxing theme; a separate dark palette is not implemented.

The puzzle shows the full selected clue separately from its short in-cell preview.
Cells start at a readable canvas size, with pinch/pan, zoom buttons and a fit button.
The keyboard adapts its column count to screen width and text size. Input updates
immediately; storage is queued and navigation waits for outstanding saves. Focus
mode removes extra decoration; on taller screens it pins the clue and keyboard.
Compact screens and enlarged type use scrolling to keep every control reachable.

**رحلة المعرفة** offers 60 bundled Arabic WordNet definitions plus cached cards.
Solving a word reveals a book action without opening a modal. Cards show the word,
definition, category and source, support favorites and optional quizzes, and return
directly to play. The personal dictionary **قاموس إنجازاتي** collects encountered
words and supports normalized search, category/difficulty filters, favorites,
alphabetical/recent sorting, mastered words and words due for review. The review
screen **راجع ما تعلمته** offers meaning selection and word completion in sessions
of 5, 10 or 15 words, with local statistics and encouraging achievement badges.

Phone schema v3 adds `learned_words`, `knowledge_cards`, `review_schedule`,
`learning_stats` and `learning_events`. Review intervals are deterministically
1 → 3 → 7 → 14 → 30 days, capped at 30; a miss resets the streak and interval to
one day, and puzzle mistakes/hints bring the word back for review. Correct answers,
hints, encounters, favorites, mastery, cached quizzes, session counts and comfort
preferences survive restart. Event IDs prevent repeated solve/quiz/session rewards
or counts. Educational activities do not debit or award game coins. Existing
onboarding flags, coins, saved puzzle bytes and partially filled answers are kept.

Cards are imported from the existing dictionary, without calling a language model
or adding invented facts. WordNet imports are labeled `dictionary_import`, not
human-reviewed facts; starter definitions are `unreviewed`. Only editorially
reviewed additional facts are returned as facts. No such fact corpus is bundled.
All unclassified dictionary entries stay in the language category, so the other
categories correctly remain empty until sourced content is reviewed. Quiz choices
come from source words and include an explicit first-letter/length cue: exactly
one choice satisfies the cue. No guessed semantic distractors are used.

`backend/export_knowledge.py` exports attributed offline cards and adds dictionary
IDs to bundled words without changing puzzle geometry. Existing phone saves with
no word IDs keep their original clue as an offline definition. Cached content is
used before a network request; the knowledge screen can fetch additional cards
explicitly. Sources and licenses remain visible in cards and the app information.

Pronunciation is optional and never starts automatically. It uses existing Arabic
system voices through [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels),
[Android TextToSpeech](https://developer.android.com/reference/android/speech/tts/TextToSpeech),
[Apple speech synthesis](https://developer.apple.com/documentation/avfoundation/speech-synthesis),
and browser speech synthesis. Missing voices produce an Arabic reading fallback.
No vowels are invented or added to source words. Voice quality, installed voices,
Android/iOS release builds and real-device frame performance still require device
testing. No Windows Developer Mode or additional Flutter plugin is required for
the Edge preview.

After changing bundled assets, stop the previous Flutter run and start it again.
If the installed SDK repeats the Edge debugger startup errors, its temporary
compatibility flag is:

```powershell
..\.tools\flutter\bin\flutter.bat run -d edge --no-web-experimental-hot-reload --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The flag is deprecated in this SDK; the standard Edge command above is preferred
when it runs normally. Browser preview progress, learning data and preferences
still reset on a full reload or hot restart. Phone storage remains persistent.

## Changed implementation

- Backend: `app/arabic.py`, `app/curated.py`, `app/difficulty.py`, `app/db.py`,
  `app/generator.py`, `app/main.py`, `fetch_wordnet.py`, `import_wordnet.py`,
  `generate_offline.py`, `audit_dictionary.py`, requirements and tests.
- Flutter: `lib/main.dart`, `lib/theme.dart`, models, both services, all three
  screens, board, keyboard, reusable `game_components.dart`, pubspec/lockfile,
  fonts, offline bundle/report, native Android/iOS folders and setup script.
- Verification artifacts: `backend/vocabulary_report.json`, offline validation
  report, widget/API/store tests and the optional rendered previews.
