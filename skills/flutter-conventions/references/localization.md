# Localization

`easy_localization` with generated keys and an embedded loader, regenerated through a wrapper script that keeps `dart format` off the generated files.

## Dependencies

```yaml
# pubspec.yaml
dependencies:
  easy_localization: ^3.0.8
  intl: ^0.20.2

dev_dependencies:
  easy_logger: ^0.0.2  # lets you silence easy_localization's logger

flutter:
  assets:
    - assets/translations/
```

## File Structure

```
assets/translations/
  en.json
  es.json
lib/generated/translations/
  codegen_loader.g.dart    # Generated: embeds translations
  locale_keys.g.dart       # Generated: type-safe key constants
scripts/generate_localizations.dart
```

## Translation JSON

```json
{
  "app_name": "My App",
  "common": {
    "save": "Save",
    "cancel": "Cancel",
    "error": "Something went wrong"
  },
  "auth": {
    "sign_in": "Sign In",
    "welcome_back": "Welcome back, {name}!",
    "resend_code_x_s": "Resend code ({}s)"
  },
  "account": {
    "x_members": {
      "one": "{} member",
      "other": "{} members"
    }
  }
}
```

### Key Naming

- `snake_case` for all keys
- Hierarchical by feature: `feature.section.element`; validation messages under the feature that owns the field
- Prefix `x_` for keys with arguments: `x_members`, `resend_code_x_s`
- Dynamic values are placeholders in the string, never concatenated in Dart: `"{multiplier}x Premium Bonus!"`

### Interpolation and Plurals

| Type | JSON | Dart |
|------|------|------|
| Positional | `"Hello, {}"` | `tr(key, args: ['World'])` |
| Named | `"Hello, {name}!"` | `tr(key, namedArgs: {'name': 'World'})` |
| Plural | `{"zero": ..., "one": "{} item", "other": "{} items"}` | `plural(key, count)` |

Plural forms: `zero`, `one`, `two`, `few`, `many`, `other`.

## Code Generation

`easy_localization:generate` emits `.g.dart` files with non-standard indentation, and `dart format` has no exclusion mechanism (the `exclude:` in `analysis_options.yaml` only affects the analyzer). Running the generator directly means the next `dart format .` corrupts the output. The wrapper script runs both generation passes and prepends `// dart format off` (Dart 3.7+) so the formatter skips the files.

```dart
// scripts/generate_localizations.dart
library;

import 'dart:io';

const _source = 'assets/translations';
const _output = 'lib/generated/translations';
const _formatOffComment = '// dart format off';

Future<void> main() async {
  await _generate(['-S', _source, '-O', _output]);
  await _generate(['-S', _source, '-O', _output, '-f', 'keys', '-o', 'locale_keys.g.dart']);

  for (final file in Directory(_output).listSync().whereType<File>()) {
    if (!file.path.endsWith('.g.dart')) continue;
    final content = file.readAsStringSync();
    if (content.startsWith(_formatOffComment)) continue;
    file.writeAsStringSync('$_formatOffComment\n$content');
  }
}

Future<void> _generate(List<String> args) async {
  final result = await Process.run('fvm', ['dart', 'run', 'easy_localization:generate', ...args], runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
}
```

- Without FVM, run `dart` directly: `Process.run('dart', ['run', ...])`.
- Run after any change to `assets/translations/`: `fvm dart run scripts/generate_localizations.dart`
- Generated `locale_keys.g.dart` maps `auth.welcome_back` to `LocaleKeys.auth_welcome_back`; `codegen_loader.g.dart` embeds every locale map so there is no asset load at runtime.
- Editor integration: a VS Code task labelled "Generate Localizations" running the command above, referenced as `"preLaunchTask"` in every launch configuration, keeps keys current on each run and aborts the launch on malformed JSON.

## App Initialization

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  EasyLocalization.logger.enableLevels = [LevelMessages.error, LevelMessages.warning];
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('es')],
      path: 'lib/generated/translations',
      assetLoader: const CodegenLoader(),
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: const MyApp(),
    ),
  );
}
```

The app widget forwards `context.localizationDelegates`, `context.supportedLocales` and `context.locale` to `MaterialApp`.

## Usage

| Operation | Code |
|-----------|------|
| Simple text | `tr(LocaleKeys.common_save)` or `LocaleKeys.common_save.tr()` |
| Positional args | `tr(LocaleKeys.key, args: ['value'])` |
| Named args | `tr(LocaleKeys.key, namedArgs: {'name': 'value'})` |
| Plural | `plural(LocaleKeys.key, count)` |
| Get / set locale | `context.locale`, `context.setLocale(Locale('en'))` |

`tr()` works without `BuildContext`, so entities and exceptions can carry localized messages. When server content depends on language, a locale provider exposes the current locale and data providers watch it to refetch.

## Anti-Patterns (flag these)

- Running `easy_localization:generate` directly instead of the wrapper script
- Relying on `analysis_options.yaml` `exclude` to protect generated files from the formatter
- `// dart format width=80` instead of `// dart format off` (reformats instead of skipping)
- Hardcoded user-facing strings in widgets → `LocaleKeys`
- Leaving keys behind when the logic that used them is removed
