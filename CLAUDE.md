# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common commands

- `flutter pub get`
- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `flutter test test/widget_test.dart`
- `flutter test --plain-name "parent report shows skills and practice questions" test/widget_test.dart`
- `flutter devices`
- `flutter run -d chrome`
- `flutter build apk`
- `flutter build web`
- `flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- `flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=SUPABASE_AVATAR_BUCKET=avatars`

## High-level architecture

- `lib/main.dart` is only the entrypoint. The real app shell, tab scaffold, catalog flow, premium flow, and lesson gameplay all live in `lib/screens/home_screen.dart`. Expect many product-level changes to touch that file.
- Navigation is imperative (`Navigator.push` / `pushReplacement`), with state held mostly in `StatefulWidget`s and services passed by constructor. There is no separate state-management package. The only app-wide shared object is audio, exposed through `SmartStepsAudioScope` in `lib/services/app_audio_controller.dart`.
- The lesson/content boundary is `SituationService`. It currently returns bundled offline data from `lib/data/offline_situation_catalog.dart`, but `lib/models/situation.dart` models the data as islands → situations → detail → steps/flashcard/skills/parentReview, so the service can later be swapped to a real backend without changing the UI contract.
- `LocalProfileStorage` in `lib/services/local_profile_storage.dart` is the local persistence layer. It stores `child_profile.json`, `app_feedback.json`, and `feedback_prompt_state.json` under the app documents directory in a `SmartSteps/` folder. Initial survey completion, premium status, skill progress, and feedback prompt state are all local-first.
- The main user flow is: `LoginScreen` → optional `InitialSurveyScreen` (when no local profile exists) → `SmartStepsCatalogPage`. The catalog page is an `IndexedStack` with 4 tabs: lesson map, parent report, quick review/practice, and profile.
- `home_screen.dart` also contains the `SafetyLesson` mapping layer and the `LessonGameScreen`. A `SituationDetail` is transformed into an in-app lesson state machine: intro media → flashcard/question → wrong/correct result media → reward → parent notes.
- Parent report (`lib/screens/learn_screen.dart`) and quick review (`lib/screens/quick_review_screen.dart`) are content reuse layers over the same lesson data. Report cards derive their skill/practice/risk text from `SituationDetail`, `ParentReviewQuestion`, and locally stored `SkillProgress`.
- Styling is centralized in `lib/theme/duo_theme.dart` and reusable building blocks live in `lib/widgets/duo_components.dart`. Button press animation/sound behavior is wrapped in `lib/widgets/smartsteps_press_effect.dart`; prefer these existing primitives before adding new UI patterns.
- Media behavior is split across `video_player` for lesson clips and `audioplayers` for music/SFX/voice. Widget tests fake `VideoPlayerPlatform`, so media-related UI changes often require test updates in `test/widget_test.dart`.

## Project-specific notes

- Lesson content currently ships offline. To add a new lesson, put media under `assets/videos/*` and `assets/voices/*`, register new asset folders in `pubspec.yaml` if needed, then add the matching `SituationDetail` entry in `lib/data/offline_situation_catalog.dart`.
- Supabase is optional. It is initialized only when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided via `--dart-define`. Current usage is limited to avatar public URLs in `lib/services/registration_avatar_service.dart`; the lesson catalog does not currently depend on Supabase.
- Premium is also local-first right now. Activation code is `PREMIUM` in `LocalProfileStorage`, and premium lesson unlock rules are checked in UI code inside `lib/screens/home_screen.dart`.
- Use `.code-review-graph/graph.html` or `.code-review-graph/graph.db` before broad edits. This repo has a few large, mixed-responsibility files, especially `lib/screens/home_screen.dart`, so impact is easier to underestimate than the folder layout suggests.
- `test/widget_test.dart` is a real flow test, not the default Flutter placeholder. It covers login → survey → catalog → lesson/report behavior using injected fake services, so changes to keys, navigation, survey fields, premium flow, lesson progression, or report copy can break it.