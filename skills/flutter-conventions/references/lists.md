# Lists

Async list screens with Riverpod: cursor pagination, grouped infinite lists, loading/error/empty states, the `AppAsyncListView` shell and skeletons.

## Overview

1. **Result Model**: `List<T> items`, `String? nextPageToken`, `bool hasReachedMax`
2. **List Provider**: `@Riverpod(keepAlive: true)`, `build()` for initial fetch, `loadMore()` for pagination
3. **`loadMore()`**: guard against loading/max, `.retainPrevious()`, combine items with spread
4. **Widget**: pass `isLoading`, `hasError`, `hasReachedMax` to `InfiniteList`, call `notifier.loadMore()` in `onFetchData`
5. **Filters**: `ref.watch(filterProvider)` in `build()` triggers auto-refresh on change
6. **Refresh**: `ref.invalidate(listProvider)` resets pagination

## Result Model

```dart
class ItemListResult extends Equatable {
  final List<ItemEntity> items;
  final String? nextPageToken;
  final bool hasReachedMax;

  const ItemListResult({
    this.items = const [],
    this.nextPageToken,
    this.hasReachedMax = true,
  });

  /// Nullable function wrapper: distinguishes "set to null" vs "not provided"
  ItemListResult copyWith({
    List<ItemEntity>? items,
    String? Function()? nextPageToken,
    bool? hasReachedMax,
  }) {
    return ItemListResult(
      items: items ?? this.items,
      nextPageToken: nextPageToken != null ? nextPageToken() : this.nextPageToken,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [items, nextPageToken, hasReachedMax];
}
```

## API Layer

```dart
Future<ItemListResult> getItemList({
  required AccountEntity account,
  ItemFilterState? filter,
  int pageSize = 25,
  String? pageToken,
}) async {
  final request = ListItemsRequest(
    parent: account.id,
    filter: filter?.toDto(),
    pageSize: pageSize,
    pageToken: pageToken ?? '',
  );

  final response = await _client.listItems(request);

  return ItemListResult(
    items: response.items.map((e) => e.toEntity()).toList(),
    nextPageToken: response.nextPageToken.isEmpty ? null : response.nextPageToken,
    hasReachedMax: response.items.length < pageSize,
  );
}
```

- `hasReachedMax`: `response.items.length < pageSize`
- Empty `nextPageToken` from API → `null`

## Provider

```dart
@Riverpod(keepAlive: true)
class ItemList extends _$ItemList {
  ItemApi get _api => ref.read(itemApiProvider);

  @override
  FutureOr<ItemListResult> build() async {
    final account = await ref.watch(selectedAccountProvider.future);
    if (account == null) return const ItemListResult();

    final filter = ref.watch(itemFilterProvider);

    return _api.getItemList(account: account, filter: filter);
  }

  Future<void> loadMore() async {
    if (state.isLoading) return;
    if (state.value?.hasReachedMax ?? false) return;

    state = const AsyncLoading<ItemListResult>().retainPrevious(
      state,
      isRefresh: false,
    );

    final account = await ref.read(selectedAccountProvider.future);
    if (account == null) {
      state = AsyncData(state.value ?? const ItemListResult());
      return;
    }

    state = await AsyncValue.guard(() async {
      final filter = ref.read(itemFilterProvider);
      final result = await _api.getItemList(
        account: account,
        filter: filter,
        pageToken: state.value?.nextPageToken,
      );

      return state.value!.copyWith(
        items: [...state.value!.items, ...result.items],
        nextPageToken: () => result.nextPageToken,
        hasReachedMax: result.hasReachedMax,
      );
    });
  }
}
```

- `build()`: initial fetch, `ref.watch()` dependencies for auto-refresh
- `loadMore()`: guards → `.retainPrevious()` → `AsyncValue.guard()` → spread merge
- Use `ref.watch()` in `build()`, `ref.read()` in `loadMore()`

## AsyncLoading Extension

```dart
extension AsyncLoadingRetainPrevious<T> on AsyncLoading<T> {
  AsyncValue<T> retainPrevious(
    AsyncValue<T> previous, {
    bool isRefresh = true,
  }) {
    // ignore: invalid_use_of_internal_member
    return copyWithPrevious(previous, isRefresh: isRefresh);
  }
}
```

- `isRefresh: true` → full screen refresh (pull-to-refresh)
- `isRefresh: false` → pagination (loading indicator at list bottom)

## Widget

```dart
class ItemInfiniteList extends HookConsumerWidget {
  const ItemInfiniteList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(itemListProvider);
    final notifier = ref.watch(itemListProvider.notifier);

    final items = useMemoized(
      () => (state.value?.items ?? []).sorted(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      ),
      [state],
    );

    if (state.value == null) {
      return state.maybeWhen(
        skipLoadingOnRefresh: false,
        error: (error, _) => ErrorRetryWidget(
          error: error,
          onRetry: () => ref.invalidate(itemListProvider),
        ),
        orElse: () => const Center(child: AppLoadingIndicator()),
      );
    }

    return InfiniteList(
      elements: items,
      itemBuilder: (context, item) => ItemListTile(item: item),
      separator: const SizedBox(height: 8),
      isLoading: state.isLoading,
      hasError: state.hasError,
      hasReachedMax: state.value?.hasReachedMax ?? false,
      onFetchData: () => notifier.loadMore(),
      loadingBuilder: (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: AppLoadingIndicator()),
      ),
      errorBuilder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(tr(LocaleKeys.common_load_more_error)),
            const SizedBox(height: 8),
            AppGhostButton(
              title: tr(LocaleKeys.common_try_again),
              onPressed: () => notifier.loadMore(),
            ),
          ],
        ),
      ),
      emptyBuilder: (context) => _buildEmptyWidget(ref),
      centerEmpty: true,
      centerLoading: true,
      onRefresh: () async {
        ref.invalidate(itemListProvider);
      },
      padding: const EdgeInsets.only(bottom: kScrollEndPadding * 2),
    );
  }

  Widget _buildEmptyWidget(WidgetRef ref) {
    return Text(
      tr(LocaleKeys.items_empty),
      style: ref.context.typography.p.copyWith(
        color: ref.context.color.mutedForeground,
      ),
    );
  }
}
```

## InfiniteList Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `elements` | `List<T>` | Yes | Items to display |
| `itemBuilder` | `Widget Function(BuildContext, T)` | Yes | Builds each item |
| `onFetchData` | `void Function()` | Yes | Called near bottom to load more |
| `isLoading` | `bool` | Yes | Loading state |
| `hasError` | `bool` | Yes | Error state |
| `hasReachedMax` | `bool` | Yes | No more pages |
| `loadingBuilder` | `WidgetBuilder` | Yes | Loading UI |
| `errorBuilder` | `WidgetBuilder` | Yes | Error UI |
| `emptyBuilder` | `WidgetBuilder` | Yes | Empty state UI |
| `separator` | `Widget?` | No | Separator between items |
| `onRefresh` | `Future<void> Function()?` | No | Pull-to-refresh callback |
| `padding` | `EdgeInsets` | No | List padding (default `EdgeInsets.zero`) |
| `centerEmpty` | `bool` | No | Center empty widget (default `false`) |
| `centerLoading` | `bool` | No | Center loading widget (default `false`) |
| `fetchThreshold` | `double` | No | Distance to bottom before fetching (default `200`) |

## Filter Integration

### Filter State

```dart
class ItemFilterState extends Equatable {
  final DateTimeRange? dateRange;
  final ItemStatus? status;

  const ItemFilterState({this.dateRange, this.status});

  int get filterCount => [dateRange, status].whereType<Object>().length;
  bool get hasFilters => filterCount > 0;

  @override
  List<Object?> get props => [dateRange, status];
}
```

### Filter Provider

```dart
@riverpod
class ItemFilter extends _$ItemFilter {
  @override
  ItemFilterState build() => const ItemFilterState();

  void setDateRange(DateTimeRange? range) {
    state = ItemFilterState(dateRange: range, status: state.status);
  }

  void setStatus(ItemStatus? status) {
    state = ItemFilterState(dateRange: state.dateRange, status: status);
  }

  void clearAll() {
    state = const ItemFilterState();
  }
}
```

### Filter-Aware Empty State

```dart
Widget _buildEmptyWidget(WidgetRef ref) {
  final filterState = ref.watch(itemFilterProvider);
  final hasFilters = filterState.filterCount > 0;

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        hasFilters
            ? tr(LocaleKeys.items_empty_filtered)
            : tr(LocaleKeys.items_empty),
        style: ref.context.typography.p.copyWith(
          color: ref.context.color.mutedForeground,
        ),
      ),
      if (hasFilters) ...[
        const SizedBox(height: 16),
        AppGhostButton(
          title: tr(LocaleKeys.filter_clear_filters),
          onPressed: () => ref.read(itemFilterProvider.notifier).clearAll(),
        ),
      ],
    ],
  );
}
```

## Pull-to-Refresh

```dart
// Dismiss immediately
onRefresh: () async {
  ref.invalidate(itemListProvider);
},

// Wait for data before dismissing
onRefresh: () async {
  ref.invalidate(itemListProvider);
  return ref.read(itemListProvider.future);
},
```

- Always `RefreshIndicator.adaptive` (Material on Android, Cupertino on iOS)
- Scrollables use `kBouncingPhysics = AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())` so pull-to-refresh works when content is shorter than the viewport
- An empty state that must stay refreshable goes in `CustomScrollView(physics: kBouncingPhysics, slivers: [SliverFillRemaining(hasScrollBody: false, child: empty)])`
- Skeleton lists use `NeverScrollableScrollPhysics`

## Stale-Request Guard

A `keepAlive` list notifier rebuilds when a watched dependency changes (account, filter) while an older `loadMore()` may still be in flight. Stamp each build and drop results from an older one:

```dart
@Riverpod(keepAlive: true)
class ItemList extends _$ItemList {
  int _listRevision = 0;

  @override
  FutureOr<ItemListResult> build() async {
    _listRevision++;
    // ...same as above
  }

  Future<void> loadMore() async {
    if (state.isLoading) return;
    if (state.value?.hasReachedMax ?? false) return;

    final previous = state.value;
    final revision = _listRevision;
    state = const AsyncLoading<ItemListResult>().retainPrevious(state, isRefresh: false);

    final account = await ref.read(selectedAccountProvider.future);
    if (!ref.mounted || revision != _listRevision) return;
    if (account == null) {
      state = AsyncData(previous ?? const ItemListResult());
      return;
    }

    final next = await AsyncValue.guard(() async {
      final result = await _api.getItemList(
        account: account,
        filter: ref.read(itemFilterProvider),
        pageToken: previous?.nextPageToken,
      );
      return ItemListResult(
        items: [...?previous?.items, ...result.items],
        nextPageToken: result.nextPageToken,
        hasReachedMax: result.hasReachedMax,
      );
    });
    if (!ref.mounted || revision != _listRevision) return;
    state = next;
  }
}
```

- Check `ref.mounted` and the revision after every `await`, before any `state =`
- Merge onto the captured `previous`, not `state.value` read after the await

## StickyInfiniteGroupedList

Sliver-based infinite list with pinned group headers (e.g. orders grouped by day). Same pagination flags as `InfiniteList`.

```dart
StickyInfiniteGroupedList<OrderEntity, DateTime>(
  elements: orders, // pre-sorted; groups keep first-seen order
  groupBy: (item) => item.createdAt.startOfDay,
  groupHeaderBuilder: (context, day, items) => DayHeader(day: day, items: items),
  itemBuilder: (context, item) => OrderListTile(order: item),
  separatorBuilder: (_, _) => const SizedBox(height: 8),
  isLoading: state.isLoading,
  hasError: state.hasError,
  hasReachedMax: state.value?.hasReachedMax ?? false,
  onFetchData: notifier.loadMore,
  loadingBuilder: (_) => const Center(child: AppLoadingIndicator()),
  errorBuilder: (_) => LoadMoreErrorRow(onRetry: notifier.loadMore),
  emptyBuilder: (_) => _buildEmptyWidget(ref),
  centerEmpty: true,
  centerLoading: true,
  onRefresh: () async => ref.invalidate(orderListProvider),
)
```

- Optional params: `groupHeaderMinExtent`/`groupHeaderMaxExtent` (default 44), `fetchThreshold` (200), `groupSpacing` (16), `padding`
- Empty `elements` → `loadingBuilder` if loading, else `errorBuilder` if error, else `emptyBuilder` (kept refreshable); with elements, loading/error render as a footer
- `onFetchData` fires within `fetchThreshold` of the bottom only when not loading, not errored and not at max
- Headers that need their own data use a `Consumer` inside `groupHeaderBuilder` (e.g. a per-day sum provider)
- Guard `state.value == null` before it, as in the `InfiniteList` widget above
- Bounded (non-paginated) sectioned lists or grids: boardbit's `SectionedCollectionView<T extends Equatable>` takes pre-grouped `sections` and adds pinned headers and a collapsible top bar

## Loading, Error and Empty States

| Situation | Render |
|-----------|--------|
| First load | Skeleton rows from stubs (`AppAsyncListView`) or centred indicator (infinite lists) |
| First load failed (no value) | Inline `ErrorRetryWidget`; retry invalidates the provider |
| Refresh with data | Keep content (`skipLoadingOnRefresh`, `.retainPrevious()`) |
| Reload after a watched dependency changed (account switch) | Hide stale rows: `raw.isReloading ? raw.unwrapPrevious() : raw` |
| Next page failed | List footer with retry calling `loadMore()` |
| Action on an item failed (delete, update) | Toast via `ref.listenOnError(actionProvider)`; list stays |
| Loaded, no items | `emptyBuilder`, filter-aware when filters exist |

- `ErrorRetryWidget({Object? error, VoidCallback? onRetry})`: centred alert icon, the `LocalizedException` title when present, the error message and a "Try again" button (disabled when `onRetry` is null)

## AppAsyncListView

Shell for bounded (non-paginated) lists. Separates fetched entities from display items so one list can mix entity rows, headers and action rows.

```dart
class AppAsyncListView<ListItem, Entity> extends HookWidget {
  const AppAsyncListView({
    super.key,
    required this.listState,      // AsyncValue<Iterable<Entity>>
    required this.makeItems,      // List<ListItem> Function(Iterable<Entity>)
    required this.itemBuilder,    // Widget Function(BuildContext, ListItem, int)
    required this.makeStub,       // Entity Function(int index), for skeleton rows
    this.onRefresh,               // RefreshCallback? → wraps in RefreshIndicator.adaptive
    this.onRetry,                 // VoidCallback? → ErrorRetryWidget button
    this.emptyBuilder,
    this.remakeKeys,              // defaults to [entityList]
    this.stubCount = 5,
    this.skipLoadingOnReload = false,
    this.padding = const EdgeInsets.only(bottom: kScrollEndPadding),
  });
}
```

Inside `build`: `items = useMemoized(() => makeItems(listState.value ?? []), remakeKeys ?? [entityList])`, a hook-owned scroll controller that scrolls to the start when `items` changes, then `listState.when(skipLoadingOnRefresh: listState.hasValue, skipLoadingOnReload: skipLoadingOnReload, ...)`: data renders the list (with `RefreshIndicator.adaptive` when `onRefresh` is set), loading renders the same list over `List.generate(stubCount, makeStub)` inside `AppSkeletonizer` with `NeverScrollableScrollPhysics`, error renders `ErrorRetryWidget(error: e, onRetry: onRetry)` aligned slightly above centre. The list itself is `AppListView` (a `ListView.separated` that shows `emptyBuilder` when `items` is empty, suppressed while loading).

Usage with a sealed item type:

```dart
AppAsyncListView(
  listState: membersState,
  makeItems: (members) => [
    ...members.map((e) => _MemberItem(member: e)),
    ...invites.map((e) => _InviteItem(invite: e)),
    if (canInvite) _InviteButtonItem(),
  ],
  itemBuilder: (context, item, index) => switch (item) {
    _MemberItem() => MemberListTile(member: item.member),
    _InviteItem() => PendingInviteTile(invite: item.invite),
    _InviteButtonItem() => AppPrimaryButton(title: tr(LocaleKeys.members_invite), onPressed: onInvite),
  },
  makeStub: (_) => MemberEntity.stub(),
  stubCount: knownMemberCount ?? 5,
  onRefresh: () => ref.refresh(membersProvider.future),
  onRetry: () => ref.invalidate(membersProvider),
)

sealed class _ListItem {}
class _MemberItem extends _ListItem { _MemberItem({required this.member}); final MemberEntity member; }
// ...one subclass per row kind
```

- `makeItems` runs on stubs too, so skeleton rows have the same structure as real rows
- Pass `remakeKeys` when `makeItems` reads state other than the entity list (e.g. `[members, invites, canInvite]`)
- boardbit keeps generic item types beside the widget: `sealed class AppListItem` with `AppListHeaderItem`, `AppListEntityItem<T>`, `AppListWidgetItem`, `AppListEmptyItem`

## Skeletons

```dart
factory OrderEntity.stub({OrderState? state}) => OrderEntity(
  id: '1',
  createdAt: DateTime.now(),
  amount: MoneyEntity(currencyCode: 'GBP', amount: 10000),
  state: state ?? OrderState.succeeded,
  description: 'Test payment',
);

class AppSkeletonizer extends StatelessWidget {
  const AppSkeletonizer({super.key, required this.child, this.loading = true});

  final Widget child;
  final bool loading;

  @override
  Widget build(BuildContext context) => Skeletonizer(enabled: loading, child: child);
}
```

- Skeletons render the real widgets over stub entities, so layout does not jump when data arrives; stub text has realistic length
- `Entity.stub()` lives on the entity (domain layer) and needs no arguments for the common case
- Outside lists, wrap the real content: `AppSkeletonizer(loading: state.isLoading, child: content)`

## Checklist

### Result Model
- Extends `Equatable`
- `copyWith` uses `T? Function()?` for nullable fields
- Default: `items = const []`, `hasReachedMax = true`

### API
- Accepts `pageSize` and `pageToken`
- `hasReachedMax = response.length < pageSize`
- Empty `nextPageToken` → `null`
- DTO/proto to entity conversion in API layer

### Provider
- `@Riverpod(keepAlive: true)`
- `build()` fetches initial page, watches dependencies for auto-refresh
- `loadMore()` guards: `isLoading`, `hasReachedMax`
- `.retainPrevious(state, isRefresh: false)` for loading state
- `AsyncValue.guard()` for error handling
- `[...existing, ...new]` for immutable merge
- `ref.read()` (not `watch`) in `loadMore()`

### Widget
- Guard `state.value == null` for initial loading/error
- Pass `state.isLoading`, `state.hasError`, `state.value?.hasReachedMax` to `InfiniteList`
- `useMemoized` for expensive transforms (sorting, filtering)
- Error builder retries via `notifier.loadMore()`
- Empty builder filter-aware when filters exist
- `onRefresh` → `ref.invalidate(provider)`

### Filters
- Filter state extends `Equatable`
- Filter provider has `clearAll()` method
- List provider watches filter in `build()` for auto-refresh
- Empty state shows "clear filters" when filters active

## Anti-Patterns (flag these)

- Full-screen loader or error on refresh when data already exists
- Showing the previous account's rows while the list reloads for a new one
- `loadMore()` writing `state` after an `await` without the mounted/revision check
- Spinner instead of stub-based skeleton for bounded lists
- `ErrorRetryWidget` for item-action failures (toast them; the list is still valid)

Sources: merchant-app lib/common/widgets/list/app_async_list_view.dart, lib/common/widgets/list/app_list_view.dart, lib/common/widgets/list/sticky_infinite_grouped_list.dart, lib/common/widgets/molecules/error_retry_widget.dart, lib/common/widgets/app_skeletonizer.dart, lib/common/extensions/build_context_ext.dart, lib/payment_intent/provider/payment_intent_list_provider.dart, lib/payment_intent/payment_infinite_list.dart, lib/payment_intent/domain/payment_intent_entity.dart, lib/more/member_list_screen.dart; boardbit lib/common/widgets/list/app_async_list_view.dart, lib/common/widgets/list/sectioned_collection_view.dart
