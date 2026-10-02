# Riverpod

Riverpod 3 with code generation. This file covers the choices this codebase makes on top of the framework; the Riverpod docs cover the rest.

## Provider Shapes

- Functional `@riverpod` for values derived from other providers or a one-shot fetch with no methods.
- Class-based `@riverpod class Foo extends _$Foo` when the provider has methods that change state (actions, pagination, selection).
- API and service objects are plain classes exposed through a functional provider: `@riverpod FooApi fooApi(Ref ref) => FooApi(ref.watch(clientProvider));`
- Dependencies read inside a Notifier go through a getter, so the class body stays free of `ref.read` noise: `FooApi get _api => ref.read(fooApiProvider);`

## Lifecycle

- `@Riverpod(keepAlive: true)` for state that matches the app lifecycle or is expensive to rebuild: auth, current user, selected account, list providers, config.
- Default auto-dispose for everything else, and always for providers with parameters, so each parameter value does not pin memory forever. `ref.cacheFor(duration)` (see `common_kit.md`) bridges the gap when a family needs a short grace period.
- `ref.mounted` after every `await` inside a Notifier before touching `state` or `ref`; the provider may have been disposed or rebuilt during the await.
- `ref.onDispose` for subscriptions, stream controllers and SDK listeners created in `build`.
- Automatic retry on error is disabled at the container (`retry: (count, error) => null`) so a failed fetch surfaces immediately instead of retrying with backoff behind a loading state.

## Actions

Discrete user actions are their own on-demand providers, not methods on the data provider they affect:

```dart
@riverpod
class CreateItem extends _$CreateItem {
  ItemApi get _api => ref.read(itemApiProvider);

  @override
  Future<ItemEntity?> build() async => null;

  Future<void> create(CreateItemDto dto) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _api.create(dto));
    if (!ref.mounted) return;
    state = result;
    ref.invalidate(itemListProvider);
  }
}
```

- `build()` returns `null`: the provider has no data until the action runs, and `isLoading` doubles as the button's loading flag.
- `AsyncValue.guard` captures the error in state; the method returns `void` and never rethrows.
- The screen observes the outcome: `ref.listen(createItemProvider, (_, next) => next.whenOrNull(data: ..., error: ...))`, or `ref.listenOnError(createItemProvider)` when success needs no handling. Guard known errors first, then null-guard the success value.
- Several independent actions on one screen each get a provider. `GenericState` (keyed by int) covers one-off actions that would not justify a named provider.

## Mutations and Refresh

After a side effect, pick one:

1. Set `state` directly when the API returns the updated entity.
2. `ref.invalidateSelf()` to refetch from the source.
3. `ref.invalidate(otherProvider)` for every provider whose data the mutation made stale (lists after create, detail after update).

Refreshing a list that already has data keeps the old items visible: `state = const AsyncLoading<T>().retainPrevious(state)` before the fetch (see `common_kit.md`). Pull-to-refresh invalidates; pagination appends.

## Watching and Reading

- `ref.watch` in `build` for dependencies; `ref.watch(provider.future)` to await an async dependency; `ref.watch(provider.select((s) => s.field))` to narrow rebuilds.
- Several independent async dependencies: `final (a, b) = await (ref.watch(aProvider.future), ref.watch(bProvider.future)).wait;`
- `ref.read` only in event handlers and Notifier methods. Calling `ref.read(fooProvider.notifier).doThing()` from `onPressed` is the standard way UI triggers work.
- `ref.listen` in `build` for side effects (toasts, navigation). Never navigate or show dialogs directly in `build`.
- Streams from SDKs or Firestore are bridged inside a Notifier: subscribe in `build`, write `state` on events, cancel in `ref.onDispose`. Returning the raw stream from a `Stream` provider is fine when no transformation or merge is needed.

## Parameters (Families)

- Parameters are `build` arguments on a Notifier or extra arguments after `ref` on a function.
- Every parameter type must have value equality: primitives, enums, or `Equatable` classes. Never a raw `List` or `Map`.
- Scope the family on identity, not on the whole object, when the object changes often: `build(String accountId)` rather than `build(AccountEntity account)`.

## Riverpod 2 → 3

Projects still on Riverpod 2 differ in these places; the shapes above assume 3.

- Generated refs are gone: every provider takes `Ref ref`, not `FooRef ref`.
- `ref.mounted` exists; in 2 the equivalent was a manual `var disposed = false` flag set in `onDispose`.
- `AutoDisposeNotifier`/`AutoDisposeAsyncNotifier` merged into `Notifier`/`AsyncNotifier`; keepAlive is only the annotation flag.
- `StateProvider`, `StateNotifierProvider` and `ChangeNotifierProvider` moved to `package:flutter_riverpod/legacy.dart`; new code uses Notifiers.
- `ProviderObserver.providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace)`; the context carries `provider` and `container`.
- Providers retry on error with exponential backoff by default; this codebase turns that off at the container.
- `riverpod_lint` runs as a native analyzer plugin declared under `plugins:` in `analysis_options.yaml` (see the bundled `analysis_options.yaml`), not through `custom_lint`.
- `AsyncValue.copyWithPrevious` is internal; the `retainPrevious` extension wraps it.

## Anti-Patterns (flag these)

- `useState<bool>` as a loading flag for an async action → action provider `isLoading`
- `try/catch` inside a Notifier method → `AsyncValue.guard`
- `state = ...` after an `await` without `ref.mounted` → guard it
- Methods like `save()`/`delete()` on the list provider → dedicated action providers
- Provider with parameters marked `keepAlive: true` → auto-dispose, `cacheFor` if needed
- `List<String>` as a family parameter → `Equatable` wrapper or identity key
- Navigation or `showDialog` inside `build` → `ref.listen` callback
