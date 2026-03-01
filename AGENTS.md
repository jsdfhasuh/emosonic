# AGENTS.md

This repository is a Flutter/Dart app (EmoSonic). Use this file for agent onboarding.

## Rules files
- Cursor rules: none found (.cursor/rules/ or .cursorrules do not exist)
- Copilot instructions: none found (.github/copilot-instructions.md does not exist)

## Build, lint, test

### Setup
- Install deps: `flutter pub get`

### Code generation
- Generate Freezed/JSON/Riverpod code: `flutter pub run build_runner build --delete-conflicting-outputs`

### Lint
- Analyze project: `flutter analyze`
- Analyze a file: `flutter analyze lib/services/audio_player_service.dart`

### Tests
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/models/search_result_test.dart`
- Run widget tests only: `flutter test test/widget_test.dart`

### Build
- Android release APK: `flutter build apk --release`
- Android debug APK: `flutter build apk --debug`
- Windows release: `flutter build windows --release`

## Code style guidelines

### Formatting
- Use Dart formatter defaults (`dart format` / IDE format).
- Prefer trailing commas in multi-line argument lists and collection literals.
- 2-space indentation is expected in all new code.

### Imports
- Order imports in 3 groups with a blank line between:
  1) `dart:`
  2) `package:`
  3) relative (`../` or `./`)
- Keep import lists minimal; remove unused imports.
- Use selective imports (`show Foo`) when only a small subset is needed.

### Files and naming
- File names: lower_snake_case.dart
- Class/enum names: PascalCase
- Function/method names: verb-first camelCase (e.g., `getSongsByAlbum`)
- Variables/fields: camelCase
- Constants: lowerCamelCase with `const` or `static const` (avoid ALL_CAPS)

### Types and models
- Avoid `dynamic` and `Object?` unless required by APIs.
- Prefer explicit types for public fields and return values.
- Data models use Freezed + json_serializable; keep `part` directives aligned:
  - `part 'file.freezed.dart';`
  - `part 'file.g.dart';`
- Use `Map<String, dynamic>` for JSON.

### State management (Riverpod)
- Providers live in `lib/providers/`.
- Use `ref.watch` in build methods to trigger rebuilds.
- Use `ref.read` for one-off actions (commands, event handlers).
- Prefer `StateNotifierProvider` for mutable state with logic; keep state immutable.

### Async and lifecycle
- `async` methods should return `Future<T>`.
- Always `await` futures unless explicitly fire-and-forget.
- Check `mounted` before UI updates after `await` in widgets.

### Error handling and logging
- Use `try/catch` around I/O, network, and prefs calls.
- Log via `Logger('ClassName')` from `lib/core/utils/logger.dart`.
- Avoid swallowing exceptions without a log or comment.

### UI patterns
- Reuse existing widgets in `lib/ui/widgets/` before creating new ones.
- Keep platform-specific behavior inside services or small helpers.
- Avoid blocking work on the UI thread; offload heavy work where possible.

### Testing
- Tests are under `test/`.
- Prefer focused unit tests for model parsing and service behavior.
- Use widget tests only when logic cannot be covered by unit tests.
- Most features are manually verified by the author; document manual verification steps when adding or changing behavior.

### Codegen workflow
- After editing Freezed/JSON/Riverpod annotations, re-run build_runner.
- Do not edit generated files (`*.g.dart`, `*.freezed.dart`) by hand.

## Project layout
- `lib/core/` utilities, constants, cache, theme
- `lib/data/` models and API clients
- `lib/providers/` Riverpod providers
- `lib/services/` audio and platform services
- `lib/ui/` screens and widgets

## CI hints
- GitHub Actions builds Android + Windows on tag `v*`.
- CI runs code generation before building.

## When unsure
- Search existing implementations before adding new utilities.
- Prefer the smallest change that satisfies the requirement.
