# Theme

Brightness-resolved colour and typography tokens, the app `ThemeData`, the persisted theme mode and shared motion constants. Spacing constants are in `common_kit.md`.

## Access and Tokens

Widgets reach every colour and text style through `context.color` and `context.typography`. Token classes are plain `const` classes in `lib/common/theme/`; the dark class extends the light one and overrides only what differs.

```dart
extension BuildContextTheme on BuildContext {
  bool get darkMode => Theme.of(this).brightness == Brightness.dark;
  AppColorLight get color => darkMode ? const AppColorDark() : const AppColorLight();
  TypographyLight get typography => darkMode ? const TypographyDark() : const TypographyLight();
}

class AppColorLight {
  const AppColorLight();
  Color get brand500 => const Color(0xFFFA692B); // primary actions, active states
  Color get brand400 => const Color(0xFFFB8A57);
  Color get bgCanvas => const Color(0xFFF9FAFB);
  Color get textHigh => const Color(0xFF111827);
  Color get textLow => const Color(0xFF9CA3AF);
  Color get onBrand => const Color(0xFFFFFFFF);
  Color get neutralBorder => textLow.withValues(alpha: 0.24); // derived, inherits dark textLow
}

class AppColorDark extends AppColorLight {
  const AppColorDark();
  @override
  Color get brand500 => super.brand400; // boosted for contrast
  @override
  Color get bgCanvas => const Color(0xFF121212);
  @override
  Color get textHigh => const Color(0xFFF2F2F2);
}

class TypographyLight {
  const TypographyLight();
  TextStyle get headline => TextStyle(
    fontFamily: FontFamily.sourceSansPro, fontSize: 24, height: 32 / 24, // 4-pt grid
    fontWeight: FontWeight.w600, color: const AppColorLight().textHigh,
  );
  // display1, subHeadline, body1, body2, caption, overline, button
}

class TypographyDark extends TypographyLight {
  const TypographyDark();
  @override
  TextStyle get headline => super.headline.copyWith(color: const AppColorDark().textHigh);
}
```

- Name colour tokens by role (`bgCard`, `textMed`, `onBrand`) or scale step (`brand500`), never by hue.
- Typography is a small semantic scale on a 4-pt grid (explicit `height`) with the token colour baked in; the dark class only swaps colours. forgeblast_app's single `AppTypography` with `light()`/`dark()` factories is an equivalent shape.

## App Theme and Theme Mode

`AppTheme.light` / `AppTheme.dark` are static getters that build `ThemeData` (colour scheme, scaffold background, app bar, button, input and card themes) from `const AppColorLight()` / `const AppColorDark()`, so Material widgets need no per-widget styling. `Application` passes `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode: ref.watch(savedThemeModeProvider)`.

`SavedThemeMode` is the persisted-preference notifier shown in `storage.md`; it reads the stored `ThemeMode` name from cached preferences and writes it on change. Default to `ThemeMode.system` unless the product is single-mode by design (forgeblast_app defaults to dark).

## Motion Constants

```dart
class AppAnimation {
  static const curveNormal = Curves.easeInOutCubic; // move, temporary hide
  static const curveAppear = Curves.easeOutCubic;
  static const curveDisappear = Curves.easeInCubic;
  static const curveSnappy = Curves.fastOutSlowIn; // with durationNormal
  static const durationFast = Duration(milliseconds: 200); // small buttons
  static const durationNormal = Duration(milliseconds: 300); // most elements
  static const durationSlow = Duration(milliseconds: 500); // large elements, long travel
}
```

## Shadcn Variant

merchant-app uses `shadcn_ui`: `AppColor extends ShadColorScheme` adds app tokens, and `ShadApp.router` gets light/dark `ShadThemeData` built from `AppColor` constants and `AppTypography` styles. `ShadAnimatedTheme` lerps the scheme back to a base `ShadColorScheme`, so `context.color` rebuilds it via `AppColor.fromShadScheme(ShadTheme.of(this).colorScheme, this)`; `context.typography` returns `ShadTextTheme`. Use this shape only when the app is built on shadcn components.

## Anti-Patterns (flag these)

- `Color(0xFF…)`, `Colors.*` or `TextStyle(fontSize: …)` inside a widget; add or reuse a token. `copyWith(color:, fontWeight:)` on a typography style is fine.
- `Theme.of(context).colorScheme.*` in feature widgets instead of `context.color.*`.
- `context.darkMode ? … : …` in a widget to pick a colour; put the difference in an `AppColorDark` override.
- Literal `Duration(milliseconds: …)` or ad-hoc curves for UI motion instead of `AppAnimation`.

Sources: merchant-app `lib/common/extensions/build_context_ext.dart`, `lib/common/theme/{app_color,app_typography}.dart`, `lib/common/constants/app_animation.dart`, `lib/root/application.dart`; boardbit `lib/common/extensions/build_context_ext.dart`, `lib/common/theme/{app_animation,app_color,app_typography}.dart`, `lib/root/application.dart`; forgeblast_app `lib/common/theme/{app_color,app_typography,app_theme,saved_theme_mode_provider}.dart`, `lib/common/extensions/build_context_ext.dart`
