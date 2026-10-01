# Common Kit

The extensions and helpers every app carries under `lib/common/`. Other references and the quality checklist assume they exist; scaffold them first in a new app.

## extensions/widget_ref_ex.dart

```dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart'; // ProviderListenable

extension WidgetRefExtension on WidgetRef {
  /// Calls [onCondition] only on the false→true edge of [predicate]. Call from build().
  void listenForCondition<T>(
    ProviderListenable<T> provider,
    bool Function(T state) predicate,
    void Function(T state) onCondition,
  ) {
    listen(provider, (previous, next) {
      if (predicate(next) && (previous == null || !predicate(previous))) onCondition(next);
    });
  }

  void listenOnError<T>(
    ProviderListenable<T> provider, {
    void Function(Object)? onError,
    bool Function(Object)? ignoreIf,
  }) {
    listen(provider, (previous, next) {
      if (next is! AsyncValue) return;
      next.whenOrNull(
        error: (e, _) {
          if (ignoreIf?.call(e) ?? false) return;
          onError?.call(e);
          AppToast.showError(context, error: e);
        },
      );
    });
  }
}
```

- `onError` runs in addition to the toast (analytics, focus changes); `ignoreIf` suppresses the toast for errors the screen handles in its own flow, e.g. `ignoreIf: (e) => e is EmailNotFoundException`.
- `listenForCondition` drives one-shot reactions such as popping after a mutation succeeds.

## extensions/async_value_loading_ext.dart

```dart
extension AsyncValueRetainPrevious<T> on AsyncValue<T> {
  AsyncValue<T> retainPrevious(AsyncValue<T> previous, {bool isRefresh = true}) {
    // ignore: invalid_use_of_internal_member
    return copyWithPrevious(previous, isRefresh: isRefresh);
  }
}
```

- Wraps Riverpod's internal `copyWithPrevious`, so it can break on a Riverpod upgrade; keep it in this one file.
- `isRefresh: false` for pagination (`const AsyncLoading<T>().retainPrevious(state, isRefresh: false)`); see `lists.md`.

## extensions/compact_map.dart

```dart
extension CompactMapIterable<T> on Iterable<T> {
  Iterable<E> compactMap<E>(E? Function(T element) f) sync* {
    for (final value in this) {
      if (f(value) case final mapped?) yield mapped;
    }
  }

  Iterable<R> compactMapIndexed<R>(R? Function(int index, T element) convert) sync* {
    var index = 0;
    for (final element in this) {
      if (convert(index++, element) case final result?) yield result;
    }
  }
}

extension CompactMapMap<K, V> on Map<K, V> {
  Map<NK, NV> compactMap<NK, NV>(MapEntry<NK, NV>? Function(MapEntry<K, V> entry) f) {
    final result = <NK, NV>{};
    for (final entry in entries) {
      if (f(entry) case final mapped?) result[mapped.key] = mapped.value;
    }
    return result;
  }
}
```

## extensions/list_divider_ext.dart

```dart
extension ListDivider on Iterable<Widget> {
  Iterable<Widget> divide(Widget separator) sync* {
    if (isEmpty) return;
    final iterator = this.iterator..moveNext();
    yield iterator.current;
    while (iterator.moveNext()) {
      yield separator;
      yield iterator.current;
    }
  }

  /// Emits no separators when [skip] is true (e.g. a configurable gap of 0).
  Iterable<Widget> maybeDivide(Widget separator, {bool skip = false}) => skip ? this : divide(separator);
}
```

`extension TextSpanDivider on Iterable<InlineSpan>` declares the same `divide(InlineSpan separator)` body for `Text.rich` children. Use `children: items.map(ItemTile.new).divide(const SizedBox(height: kGapItem)).toList()` instead of building separators by index.

## extensions/build_context_ext.dart

Spacing constants are top-level `const`s; theme accessors are `BuildContext` extensions. Token internals live in `theme.md`.

| Name | Value / type | Use |
|---|---|---|
| `kSide` | `16.0` | Horizontal screen padding |
| `kGapItem` | `8.0` | Between items inside one group |
| `kGapGroup` | `16.0` | Between titled groups on a screen |
| `kGapSection` | `24.0` | Between distinct sections |
| `kGapSectionXl` | `32.0` | Between major or unrelated sections |
| `kScrollEndPadding` | `40.0` | Bottom padding of scrollable pages |
| `kCorner` | `12.0` | Radius of cards and buttons |
| `kBouncingPhysics` | `AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())` | Scrollables that must bounce and pull-to-refresh when short |
| `context.color` | app color tokens | All colours |
| `context.typography` | app text styles | All text styles |
| `context.theme` | `ThemeData` | Material fallbacks only |
| `context.brightness` / `context.darkMode` | `Brightness` / `bool` | Brightness branches (`isDark` in older apps) |
| `context.topSafeArea` / `context.bottomSafeArea` | `double` | `MediaQuery.padding` top/bottom |
| `context.screenWidth` / `context.screenHeight` / `context.keyboardHeight` | `double` | Size and `viewInsets.bottom` |
| `context.isTopMostRoute` | `bool` | `ModalRoute.of(this)?.isCurrent` |
| `Color.filter` | `ColorFilter` | `srcIn` tint for SVG icons |

The gap ladder is ordered `kGapItem < kGapGroup < kGapSection < kGapSectionXl`; pick by structural level, not by eye.

## extensions/scroll_controller_ext.dart

`extension ScrollToTop on ScrollController` adds `scrollToStart()` and `scrollToEnd()`: each returns early when `!hasClients`, then `animateTo(0 | position.maxScrollExtent, duration: AppAnimation.durationNormal, curve: Curves.easeOut)`. Typical call: `useAsyncEffect(() => controller.scrollToStart(), [items])`.

## extensions/ref_copy_ext.dart

`extension RefCopyExt on WidgetRef` declares `Future<void> copyToClipboardText(String text, {String? what})`: haptic `feedbackSelection()`, `await Clipboard.setData(ClipboardData(text: text))`, then, if `context.mounted`, an `AppToast` reading "Copied {what} to clipboard" (or "Copied to clipboard" without `what`).

## extensions/ref_ext.dart

`extension RefDebugExt on Ref` declares `void debugPrintLifecycle({String? debugName})`, which registers `onAddListener`, `onRemoveListener`, `onCancel`, `onResume` and `onDispose` callbacks that each `log.debug('$debugName <event>')`. A debugging aid for disposal and keep-alive questions; merchant-app has no committed callers.

## util/ref_cache.dart

```dart
extension AutoDisposeRefCache on Ref {
  /// Keeps an auto-dispose provider alive for [duration] after creation, even without listeners.
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
```

Call at the top of `build()` for data worth reusing across quick back-and-forth navigation (`ref.cacheFor(const Duration(minutes: 2))`) instead of making the provider `keepAlive: true`.

## util/use_init_hook.dart

```dart
void useInit(void Function() callback) => useEffect(() {
      callback();
      return null;
    }, []);

void useInitAsync(void Function() callback) => useAsyncEffect(callback, []);

/// Runs [effect] in a microtask, after the current build completes.
void useAsyncEffect(void Function() effect, [List<Object?>? keys]) {
  useEffect(() {
    Future.microtask(effect);
    return null;
  }, keys);
}

/// [effect] may return a dispose callback asynchronously; it runs on key change or unmount.
void useAsyncEffectDisposing(Future<Dispose?> Function() effect, [List<Object?>? keys]) {
  useEffect(() {
    final disposeFuture = Future.microtask(effect);
    return () => disposeFuture.then((dispose) => dispose?.call());
  }, keys);
}
```

Usage rules are in `hooks.md`. forgeblast_app keeps the same file under `lib/common/hooks/` and adds `VoidCallback useDebounce(VoidCallback callback, Duration delay)` (a `useRef<Timer?>` cancelled on unmount) and `ScrollController useScrollPagination({required VoidCallback onLoadMore, double threshold = 200.0})` (calls `onLoadMore` when within `threshold` of the bottom); add them when a widget needs them.

## util/debouncer.dart

```dart
class Debouncer {
  Debouncer([this.duration = const Duration(milliseconds: 300)]);
  final Duration duration;
  Timer? _timer;

  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(duration, callback);
  }
}
```

For notifiers and plain classes (`final _debouncer = Debouncer();` as a field). In widgets use `useDebounce`, which cancels on unmount.

## util/generic_state_provider.dart

An action provider for one-off async calls that don't deserve their own notifier, keyed by an `int` so several can run side by side.

```dart
@riverpod
class GenericState extends _$GenericState {
  @override
  Future<void> build(int key) async {}

  Future<void> perform(
    Future<void> Function() perform, {
    Exception Function(Object e, StackTrace s)? errorMapper,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(perform);
    if (!ref.mounted) return;
    state = switch (result) {
      AsyncError(:final error, :final stackTrace) when errorMapper != null =>
        AsyncError(errorMapper(error, stackTrace), stackTrace),
      _ => result,
    };
  }
}
```

```dart
final key = step.hashCode;
ref.listenOnError(genericStateProvider(key));
final loading = ref.watch(genericStateProvider(key)).isLoading;
onPressed: () => ref.read(genericStateProvider(key).notifier).perform(() => step.resendCode()),
```

Use it when the caller only needs loading and error. An action whose caller needs the result (a created entity, a success flag to pop on) gets its own named notifier.

## util/show_popup.dart

`Future<bool?> showPopUp({required BuildContext context, required String content, String? title, String? defaultActionLabel, VoidCallback? onDefaultAction, bool dismissible = true})`, a single-action adaptive alert. Behaviour and when to use it are in `sheets_dialogs.md`.

Sources: merchant-app `lib/common/extensions/{widget_ref_ex,async_value_loading_ext,compact_map,list_divider_ext,build_context_ext,scroll_controller_ext,ref_copy_ext,ref_ext}.dart`, `lib/common/util/{use_init_hook,debouncer,generic_state_provider,show_popup}.dart`, `lib/common/app_search_provider.dart`, `lib/auth/widgets/auth_details_input_widget.dart`; forgeblast_app `lib/common/hooks/use_init_hook.dart`, `lib/common/extensions/widget_ref_ex.dart`; boardbit `lib/common/extensions/{ref_ext,compact_map,build_context_ext}.dart`, `lib/common/utils/ref_cache.dart`
