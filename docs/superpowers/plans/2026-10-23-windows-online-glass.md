# Windows Online Glass Implementation Plan

> **For agentic workers:** Execute this approved plan inline, task by task, using test-driven-development and systematic-debugging. The optional subagent-driven-development/executing-plans skills are not installed; no delegation is needed.

**Goal:** Deliver the existing Windows reader with an upgraded engine, real online search/reading, Liquid Glass controls and high-refresh compatibility.

**Architecture:** Preserve existing repository, cache and reader interfaces. Add a bounded official-site client/parser, integrate normal website verification, and isolate display metrics from Android-only refresh-rate channels. Use the existing GPU glass pipeline with explicit fallback.

**Tech Stack:** Flutter 3.47.0, Dart, Flutter Windows C++ runner, official website HTML, existing shared preferences/local storage.

## Global Constraints

- Keep local TXT/EPUB files, progress, bookmarks, layout and animations.
- No fictitious network results or performance certification. Verification is user-operated in the normal official website.
- Follow display vsync at 60/120/144Hz; never change global display settings.
- Friends perform final Windows presentation/performance acceptance; provide reproducible commands and reports.
- Design: `docs/superpowers/specs/2026-10-23-windows-online-glass-design.md`.

### Task 1: Reproducible upgraded engine

**Files:** `.flutter-version`, `pubspec.yaml`, `pubspec.lock`, `Build-Windows.ps1`, `.github/workflows/windows.yml`, `WINDOWS.md`.

**Interfaces:** All build paths consume the same verified SDK pin and execute `flutter analyze`, targeted tests, and `flutter build windows --release`.

- [x] Fetch official 3.47.0 SDK, run `flutter --version --machine`, preserve its revision in validation evidence.
- [x] Resolve dependencies and run the unchanged Windows/local regression set to establish the baseline.
- [ ] Pin the verified version and update build/CI. Run the build preflight with a wrong SDK to verify a clear failure; run with the correct SDK to proceed.
- [x] Commit the engine/build change.

### Task 2: Real official-site connectivity

**Files:** `lib/online/official_site_client.dart`, `lib/online/official_site_parser.dart`, `lib/online/official_site_repository.dart`, `lib/online/official_site_page.dart`, `lib/main.dart`, `lib/library_state.dart`, `test/official_site_test.dart`.

**Interfaces:** `OfficialSiteRepository implements NovelRepository`; `searchPage(String query, {int page = 1, bool refresh = false})` produces real `NovelPage`; `chapters(int id)` preserves volume/chapter IDs and `chapterContent(int novelId, NovelChapter chapter)` produces reader content. A transport function makes response parsing testable with real page fixtures.

- [x] Inspect normal official page/form contracts and retain small representative fixtures under `test/fixtures/official_site/`.
- [x] Add failing parser/client tests for result IDs, title/author, paging, volume/chapter IDs, body text/images, and explicit validation/restricted-content errors. Example assertion: `expect(result.items.single.title, '测试书名');` with a hand-checked fixture.
- [x] Implement the parser and transport, validate every redirected destination, bound response sizes/timeouts and distinguish service errors.
- [x] Add normal website verification UI and resume the failed action after user completion; never automate verification.
- [x] Wire the repository into Windows and remove forced local navigation. Run the new tests plus offline/reader/navigation regressions and a live request probe.
- [x] Commit connectivity changes and record actual live outcome.

### Task 3: Display-aware smooth rendering

**Files:** `lib/frame_rate_settings.dart`, `lib/ui_frame_capture.dart`, `lib/windows/desktop_display.dart`, `lib/low_performance_page.dart`, `integration_test/windows_performance_test.dart`, `test/desktop_display_test.dart`.

**Interfaces:** Display observations expose current monitor Hz and per-frame budget. A recorded frame report consumes the selected display Hz rather than a hard-coded 120Hz constant.

- [x] Add a failing behavioral test in which a 10ms raster frame exceeds the 120Hz budget but fits the 60Hz budget; verify monitor changes update the budget.
- [x] Implement display metrics observation and a Windows settings path without Android method calls. Keep engine vsync, time-based animation and background idle behavior.
- [ ] Add benchmark scenes for shelf drag, scroll, page turn and menu opening, with environment/refresh-rate metadata and frame distributions.
- [x] Run display/report tests and existing render/motion regressions; commit.

### Task 4: Liquid Glass controls

**Files:** `lib/glass_palette.dart`, `lib/easy_glass.dart`, `lib/native_effects.dart`, `lib/glass_dock.dart`, `lib/app_search_field.dart`, `lib/app_interactions.dart`, existing glass widget tests.

**Interfaces:** Existing GlassAppearance transparency and PerformanceScope remain the source of appearance and motion settings; normal controls share bounded backdrop passes.

- [x] Add focused tests for legible controls at transparency extremes, keyboard interaction and reduced motion; exercise both shader-supported and fallback behavior.
- [x] Refine capsule geometry, optical tint/edges and interaction continuity using existing components. Reuse existing shelf and reader motion.
- [x] Render/inspect light and dark screens and record any unavailable GPU validation. Run glass, navigation and reader animation regressions.
- [ ] Profile identified expensive scenes and change only verified hotspots; commit.

### Task 5: Windows delivery and acceptance

**Files:** `WINDOWS-VALIDATION.md`, `tools/Package-Windows.ps1`, `tools/Validate-Windows.ps1`, `outputs/` delivery archives and instructions.

**Interfaces:** Packaging includes complete EXE/DLL/data, exact corresponding source, version/revision metadata and performance instructions. Acceptance exports reports to a user-selected directory.

- [x] Run complete static analysis and appropriate regression suite. Build and run native targets available on this host.
- [ ] Build the Windows release on an available Windows runner; include complete runtime dependencies and license/source notices.
- [ ] Execute Windows smoke/performance scenes or explicitly keep them pending for the friend's machine. Do not relabel old binaries as new.
- [ ] Inspect final archive contents and audit every approved requirement against test/build/runtime evidence.

## Execution checkpoint — 2026-10-23

Implemented inline: pinned engine, public website client/parser/repository, dedicated WebView2 login/verification and retry, native reader/cache integration, monitor-aware settings and JSON timing capture, Windows glass treatment, build/package/CI scripts and friend acceptance guide. Final app analyzer: clean. Flutter unit/widget regression: 868 passed, 9 platform skips. Tool tests: Python 25 and Node 18 passed.

The four performance scenes are selected and recorded from the app's performance page and described in WINDOWS-ACCEPTANCE.md; real Windows benchmark reports have not yet been collected. Native smoke remains integration_test/windows_smoke_test.dart. Tests use authored parser contracts and an actual generated fetch script; live account success is pending. A live browser reached the official login page.

Open work: execute the pinned Windows build and packaging preflight, native GPU smoke and real account/read flow; collect the friend's display/performance results. The current macOS host cannot cross-compile the Windows application. Prepared workflow: .github/workflows/windows.yml. No external repository has been modified or new EXE claimed.

Public upload authorized by user: create a new public GitHub repository and retain open-source licensing. Repository: https://github.com/rayem-prog/Wenku8-Windows-Glass . Added COPYING, component license copies and dated Windows modification notices. Added a real PowerShell build/package fixture check for CI. New optional-GPU-load tests: 2 passed; related glass/performance regressions: 32 passed. Windows native build and actual display reports remain required.
