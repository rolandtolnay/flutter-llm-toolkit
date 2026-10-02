# Folder Structure

Feature folders directly under `lib/`, shared code under `lib/common/`.

## Organization

- One folder per feature directly under `lib/`: `lib/account/`, `lib/games/`
- Screens at the feature root: `account/account_screen.dart`, `account/edit_account_screen.dart`
- `widgets/` subfolder when 2+ widgets exist in the feature
- `provider/` subfolder when 2+ provider or state files exist in the feature
- `domain/` subfolder for entities, DTOs and API classes
- Shared code in `lib/common/`: `widgets/`, `extensions/`, `util/`, `theme/`, `storage/`, `data/` (clients, logging)
- Generated code that is not beside its source (translations, assets, proto) in `lib/generated/`; build_runner output stays next to its source as `*.g.dart` / `*.gr.dart`

## Subfeatures

- Split large features into subfeatures: `games/library/`, `games/details/`
- Each subfeature repeats the same structure: screens at root, optional `widgets/`, `provider/` and `domain/`

## Example

```text
lib/
  account/
    account_screen.dart
    edit_account_screen.dart
    widgets/
      account_avatar.dart
      account_form.dart
    provider/
      account_provider.dart
      edit_account_provider.dart
    domain/
      account_entity.dart
      account_api.dart

  games/
    library/
      games_library_screen.dart
      widgets/
      provider/
      domain/
    details/
      game_details_screen.dart
      widgets/
      provider/
      domain/

  common/
    widgets/
    extensions/
    util/
    theme/
    storage/
  generated/
```

## Anti-Patterns (flag these)

- `lib/features/` wrapper or a `presentation/` layer: `lib/features/home/presentation/screens/` → `lib/home/home_screen.dart`
- Single widget in `widgets/` (keep at feature root until 2+)
- Single provider in `provider/` (keep at feature root until 2+)
- Models scattered at the feature root instead of `domain/`
- Barrel files that only re-export
