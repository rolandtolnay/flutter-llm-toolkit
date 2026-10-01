# Design Principles

Structural choices that decide how code changes later. Apply while designing state, widget APIs and provider graphs, before the code exists.

## Three Lenses

Ask these of every non-trivial design:

- **State modelling** — can this code represent an invalid state? Boolean combinations, stringly-typed status and repeated decision logic say yes.
- **Responsibility boundaries** — if feature X is removed or changed, how many files change? Scattered `if (featureEnabled)`, 6+ widget parameters and callback chains carrying flags say too many.
- **Abstraction timing** — is this abstraction earned or speculative? One implementation behind an interface is speculative; duplicated logic that drifts is overdue.

## State & Types

**Make invalid states unrepresentable.** Three or more booleans travelling together, or the same flag checks repeated across files, become a sealed type where each variant is one valid state and carries its own data.

```dart
sealed class ItemMode {
  const ItemMode();
}
final class ItemModeNormal extends ItemMode { const ItemModeNormal(this.bonus); final Bonus? bonus; }
final class ItemModeTutorial extends ItemMode { const ItemModeTutorial(); }
final class ItemModeExpired extends ItemMode { const ItemModeExpired(); }
```

**Centralise decisions in factories.** When widgets receive raw data only to decide what to render, move the decision into a factory on the sealed type and let widgets switch exhaustively.

```dart
factory ItemMode.fromContext({required Item item, required User? user, required bool isTutorial}) {
  if (item.isExpired) return const ItemModeExpired();
  if (isTutorial) return const ItemModeTutorial();
  return ItemModeNormal(user?.applyBonus(item.reward));
}

Widget build(BuildContext context) => switch (mode) {
  ItemModeExpired() => const ExpiredBadge(),
  ItemModeTutorial() => TutorialGlow(child: ClaimButton(mode: mode)),
  ItemModeNormal() => ClaimButton(mode: mode),
};
```

**One owner per state, derive the rest.** Long-lived state lives in a provider; widgets keep only ephemeral UI state (focus, a transient toggle). Derived values are computed getters or `select`, never a `useState` kept in sync by `useEffect`.

**Group data clumps.** The same three parameters in several signatures become a record (`({int base, int? boosted})`) or a small class when behaviour is needed (`bool get hasBonus => multiplier != null`).

## Structure

**Isolate optional features in wrappers.** When over a third of a widget serves one optional feature, extract a wrapper that owns that feature's state and composes the core widget via a builder. The core widget does not know the feature exists, and removing the feature removes one file.

**Extract shared visual patterns as variants.** The same decoration or layout in two or more places becomes one widget with an enum or sealed variant, and the per-variant styling lives in an extension on the variant type in the same file.

```dart
enum RewardStyle { filled, outlined, disabled }

extension on RewardStyle {
  BoxDecoration decoration(BuildContext context) => switch (this) {
    RewardStyle.filled => BoxDecoration(color: context.color.primary, borderRadius: BorderRadius.circular(kCorner)),
    RewardStyle.outlined => BoxDecoration(border: Border.all(color: context.color.primary), borderRadius: BorderRadius.circular(kCorner)),
    RewardStyle.disabled => BoxDecoration(color: context.color.gray400, borderRadius: BorderRadius.circular(kCorner)),
  };
}
```

**Composition over configuration.** A widget with mutually exclusive booleans or more than 6–8 parameters is several widgets. Split into focused widgets (`PrimaryButton`, `GhostButton`), accept a `child` slot for custom content, or take a sealed `variant` when the variants genuinely share a body.

## Dependencies

**Pass data, not callback parades.** A child receives one typed object (often the sealed mode above) plus the callbacks it owns. Parents stop knowing the child's decision logic, and the child's API survives requirement changes.

**Keep the provider graph a tree.** Root providers hold core entities and match the app lifecycle (`keepAlive: true`); branch providers combine and filter them; leaf providers are screen-specific and are never watched by other providers. If the graph cannot be drawn as a tree, a provider is doing two jobs.

**Enforce sequences with types, not comments.** "Call init first" becomes a type that only exists after init (`Uninitialized.init() → Initialized`), or a builder whose `build()` is the only way to get the product. Misuse then fails at compile time.

## Pragmatism

**Abstract on the second real case.** An interface with one implementation, a factory producing one type, or configuration nobody varies is removed in favour of the concrete class. When the second implementation arrives, the right abstraction is visible in the actual difference.

**One error strategy everywhere.** Actions capture errors in `AsyncValue` via `AsyncValue.guard`; screens surface them through `ref.listenOnError`; first-load errors render inline with a retry that invalidates the provider. A try/catch in a widget or a bespoke error dialog on one screen is the smell. Details in `error_handling.md`.

## Anti-Patterns (flag these)

- Three or more booleans describing one thing's state → sealed type
- `if/else` chain choosing which widget to render, duplicated across widgets → factory on a sealed type plus `switch`
- `useState` mirrored from a provider via `useEffect` → derive with `select` or a getter
- Widget with mutually exclusive `isPrimary`/`isSecondary`/`isDestructive` flags → separate widgets or a sealed variant
- Leaf provider watched by another provider → promote it to a branch or split it
- Interface with a single implementation "for later" → concrete class
- Comments saying "must call X before Y" → type-state or builder
