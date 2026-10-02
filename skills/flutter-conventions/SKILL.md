---
name: flutter-conventions
description: Conventions and proven patterns for Flutter apps built with Riverpod, flutter_hooks and auto_route. Use when implementing or changing Flutter code.
---

# Flutter Conventions

How this family of apps is built. The rules below apply to every change; the `references/` files hold the shapes for specific tasks and are read when the task touches them. Project `AGENTS.md` files add project-specific facts (commands, backend, branding) and override anything here when they conflict.

Stack: Flutter stable, Riverpod 3 with code generation, flutter_hooks, auto_route, easy_localization, Equatable, `package:collection`, `package:logging`, Lucide icons. Backends vary (gRPC, REST over Dio, Firebase); the layering does not.

## Architecture

Three layers, one direction of dependency:

```
API (domain/)  →  Provider (provider/)  →  UI (screens, widgets/)
```

- The API class talks to the backend and returns domain entities. Transport types (proto messages, JSON maps, Firestore snapshots) are converted in the API class via extension methods colocated with the entity and never leave `domain/`.
- Providers own state and orchestrate API calls. Business rules live in entity computed properties (`bool get canDelete => isOwner && !isArchived`), not in widgets or providers.
- UI reads providers and triggers notifier methods. It never calls an API or touches storage directly.

These three boundaries are the invariants of the codebase. Everything else in this file is a default to follow unless the project says otherwise.

## Project Structure

Feature folders directly under `lib/` (`lib/account/`, `lib/payment/`), screens at the feature root, and `domain/`, `provider/`, `widgets/` subfolders created when two or more files justify them. Shared code lives in `lib/common/` (`widgets/`, `extensions/`, `util/`, `theme/`, `storage/`, `data/`). No `features/` wrapper, no `presentation/` layer, no barrel files. Details: `references/folder_structure.md`.

Before creating a widget, look in `lib/common/widgets/` and the feature's `widgets/`; reuse beats a near-duplicate.

## Widgets

- Screens are `HookConsumerWidget`; smaller widgets are `HookWidget` or `StatelessWidget`. `StatefulWidget` only when a hook cannot express the lifecycle.
- Inside `build()`: providers, then hooks, then derived values, then widget variables in render order. Always-shown subtrees are local variables, conditional ones are `_buildX()` methods, large or reused or stateful ones are their own widget in their own file. No file-private widget classes.
- Helpers needing four or more locals (hooks, controllers) are closures inside `build()`; otherwise class methods. Pass `WidgetRef` alone when a helper needs both ref and context (`ref.context`).
- Styling comes from `context.color`, `context.typography` and the spacing constants (`kGapItem`, `kGapSection`, `kSide`, `kCorner`); icons from `LucideIcons`. No hex literals or magic numbers in widgets.
- Shared widgets (`AppPrimaryButton`, `AppBottomSheet`, `AppTextField`, `AppChip`) are written in `lib/common/widgets/` on top of Material widgets and the theme tokens. No third-party component kit; the app owns its design system.

Details: `references/widget_style_guide.md`, `references/hooks.md`, `references/design_principles.md`.

## State and Actions

- Data that outlives a screen lives in a provider; a widget keeps only ephemeral UI state (focus, a local toggle) in hooks.
- Each user action is an on-demand action provider (`Future<T?> build() async => null`) whose method uses `AsyncValue.guard`, checks `ref.mounted` after awaits, and invalidates the providers it made stale. The action's `isLoading` drives the button; the screen reacts to the outcome through `ref.listen` / `ref.listenOnError`.
- First-load errors render inline with a retry that invalidates the provider. Action errors show a toast via `listenOnError` and the user retries by tapping again. Refreshes keep existing content visible.
- Complex state is a sealed type switched exhaustively, never a set of booleans.

Details: `references/riverpod.md`, `references/error_handling.md`.

## Modern Dart

Use the newest syntax the project's SDK constraint allows (`environment: sdk:` in `pubspec.yaml`):

- Switch expressions, records, patterns and sealed classes (Dart 3.0+).
- `Column(spacing:)` / `Row(spacing:)` (Flutter 3.27+) when every gap is equal; `.divide(widget)` when the separator is a real widget or the children are inline spans.
- Dot shorthands (`alignment: .center`, `padding: .all(16)`) when the type is inferred (Dart 3.10+).
- Primary constructors where the SDK and lints accept them.
- `package:collection` helpers (`sorted`, `firstWhereOrNull`, `groupBy`) over manual loops and mutation.

## Where to Look

| Task touches | Read |
|---|---|
| New feature's API, entity, DTO | `references/rest_api.md` (REST and gRPC variant) |
| Providers, families, lifecycle, mutations | `references/riverpod.md` |
| Exceptions, error display, crash reporting | `references/error_handling.md` |
| Screen layout, extraction, build order | `references/widget_style_guide.md` |
| Hooks, controllers, StatefulWidget migration | `references/hooks.md` |
| State modelling, widget APIs, abstraction decisions | `references/design_principles.md` |
| Lists, pagination, skeletons, empty and error states | `references/lists.md` |
| Filters, sorting, filter sheets | `references/filter_sort.md` |
| Client-side search | `references/entity_search.md` |
| Forms, validation, submit | `references/forms.md` |
| Bottom sheets, dialogs, confirmations | `references/sheets_dialogs.md` |
| Multi-step flows, drafts | `references/wizard.md` |
| Routes, tabs, deep-linkable screens, typed results | `references/navigation.md` |
| App entry, flavors, container | `references/app_bootstrap.md` |
| Log levels, what to log where, transport logging, crash reporter routing | `references/logging.md` |
| Splash, startup checks, forced update | `references/startup_gate.md` |
| Auth state, sign-out, account selection | `references/auth_session.md` |
| Analytics, support, purchases or push SDK wrappers | `references/sdk_session.md` |
| Preferences, secure storage, caches | `references/storage.md` |
| Translations and the codegen script | `references/localization.md` |
| Colors, typography, dark mode | `references/theme.md` |
| Shared extensions and hooks a new app needs | `references/common_kit.md` |
| Lint setup for a new project | `references/analysis_options.yaml` |

## Finishing

Run code generation after changing providers, routes or serialisable models, then `dart analyze` (through `fvm` when the project uses it). Before reporting a Flutter change as done, run the `flutter-code-quality` check on the changed files and apply its findings.
