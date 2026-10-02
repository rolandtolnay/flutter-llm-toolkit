# Filter and Sort

Typed filter state, the applied-filter provider that lists watch, enum sort with a derived provider, and the sort/filter chip row.

## Layout

- `lib/<feature>/provider/`: `item_filter_state.dart`, `item_filter_provider.dart`, `item_sort.dart` (enum plus the selection notifier), `sorted_items_provider.dart`
- `lib/<feature>/widgets/`: `item_filter_sheet.dart`, `item_sort_sheet.dart`, `item_sort_filter_row.dart`
- The filter's transport conversion lives in the feature's API file (`lib/<feature>/domain/item_api.dart`)

## Choosing the Shape

- Simple criteria → `enum` (sort order, single status)
- Options with properties or behaviour → `sealed class`
- Multiple filter properties → dedicated `Filter` state class

## Filter State

```dart
class ItemFilterState extends Equatable {
  final Iterable<ItemStatus>? statusList;
  final DateTime? fromDate;
  final DateTime? toDate;

  const ItemFilterState({this.statusList, this.fromDate, this.toDate});

  /// Each selected status counts as 1; a date range counts as 1.
  int get filterCount => [
    statusList?.length,
    fromDate != null || toDate != null ? 1 : 0,
  ].fold(0, (acc, e) => acc + (e ?? 0));

  /// Chip labels for the applied filters.
  Iterable<String> get enabledFilters => [
    ...(statusList ?? []).map((e) => e.title),
    if (fromDate != null || toDate != null)
      [fromDate, toDate].map((d) => d == null ? '…' : DateFormat.yMMMd().format(d)).join(' – '),
  ];

  bool isStatusFiltered(ItemStatus status) => (statusList ?? []).contains(status);

  ItemFilterState addingStatus(ItemStatus status) =>
      copyWith(statusList: () => [...(statusList ?? []), status]);

  ItemFilterState removingStatus(ItemStatus status) {
    final list = (statusList ?? []).where((e) => e != status);
    return copyWith(statusList: () => list.isEmpty ? null : list);
  }

  ItemFilterState copyWith({
    Iterable<ItemStatus>? Function()? statusList,
    DateTime? Function()? fromDate,
    DateTime? Function()? toDate,
  }) {
    return ItemFilterState(
      statusList: statusList != null ? statusList() : this.statusList,
      fromDate: fromDate != null ? fromDate() : this.fromDate,
      toDate: toDate != null ? toDate() : this.toDate,
    );
  }

  @override
  List<Object?> get props => [statusList, fromDate, toDate];
}
```

- `null` means "not filtered"; removing the last selection collapses back to `null` so an emptied filter equals the default
- `copyWith` takes `T? Function()?` so callers can set a field to `null`
- Helpers return new instances (`adding*`/`removing*`, or `toggling*` for set-valued fields); state is never mutated
- Fields that always have a value use non-null defaults instead: `this.owned = OwnedStatus.all`, `this.gameTypes = const {}`

## Applied Filter Provider

```dart
@Riverpod(keepAlive: true)
class ItemFilter extends _$ItemFilter {
  @override
  ItemFilterState build() => const ItemFilterState();

  // ignore: use_setters_to_change_properties
  void applyState(ItemFilterState state) => this.state = state;

  void clearAll() {
    if (state.filterCount == 0) return;
    state = const ItemFilterState();
  }
}
```

- The list provider `ref.watch`es it in `build()`, so applying a filter refetches from page one (see `lists.md`)
- Server-paginated lists send the filter to the API; complete local collections filter in a derived provider with an `Iterable<Entity>` extension (`filterBy(filter)`), never in the list widget

## API Conversion

```dart
// In the API file — keeps the proto type out of providers and UI
extension on ItemFilterState {
  ListItemsRequest_Filter toDtoFilter() {
    return ListItemsRequest_Filter(
      states: statusList?.map((e) => e.toDto()).nonNulls,
      startCreateTime: fromDate != null ? Timestamp.fromDateTime(fromDate!) : null,
      endCreateTime: toDate != null ? Timestamp.fromDateTime(toDate!) : null,
    );
  }
}

// request
filter: filter?.filterCount == 0 ? null : filter?.toDtoFilter(),
```

## Sort

```dart
enum ItemSort {
  recommended,
  recentlyUsed,
  mostUsed;

  String get title => switch (this) {
    recommended => tr(LocaleKeys.items_sort_recommended),
    recentlyUsed => tr(LocaleKeys.items_sort_recently_used),
    mostUsed => tr(LocaleKeys.items_sort_most_used),
  };
}

@riverpod
Future<List<ItemEntity>> sortedItems(Ref ref) async {
  final items = await ref.watch(itemCollectionProvider.future); // complete local collection
  final sort = ref.watch(itemSortSelectionProvider);

  return switch (sort) {
    ItemSort.recommended => items,
    ItemSort.recentlyUsed => items.sorted(
      (a, b) => switch ((a.lastUsedAt, b.lastUsedAt)) {
        (final DateTime aDate, final DateTime bDate) when aDate != bDate =>
          bDate.compareTo(aDate),
        (DateTime _, null) => -1, // used before never-used
        (null, DateTime _) => 1,
        _ => a.name.compareTo(b.name),
      },
    ),
    ItemSort.mostUsed => items.sorted((a, b) {
      if (a.useCount != b.useCount) return b.useCount.compareTo(a.useCount);
      return a.name.compareTo(b.name);
    }),
  };
}
```

- The applied sort is a `@Riverpod(keepAlive: true)` `Notifier<ItemSort>` (`ItemSortSelection`) with a `select(ItemSort)` method, shaped like the filter provider
- Every comparator handles `null` explicitly (nulls last) and ends in a deterministic tie-breaker
- Enum-specific display lives on the enum (`title`, icon builder, chip label/selected state for the default value)

## Sheets

- Filter and sort sheets take the applied value, edit a local draft (`useState(appliedFilters)`), and pop the draft on Apply; dismiss returns `null` and changes nothing. Sheet mechanics are in `sheets_dialogs.md`
- Option chips map over `Enum.values`, skipping the fallback case: `ItemStatus.values.where((e) => e != ItemStatus.unknown).map(makeStatusChip)`

## Sort/Filter Row

```dart
class ItemSortFilterRow extends HookConsumerWidget {
  const ItemSortFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(itemFilterProvider);
    final notifier = ref.watch(itemFilterProvider.notifier);

    Future<void> openFilters() async {
      final result = await ItemFilterSheet.show(context, appliedFilters: filter);
      if (result != null) notifier.applyState(result);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: kSide),
      child: Row(
        children: [
          if (filter.filterCount > 0)
            ...filter.enabledFilters
                .map((e) => AppChip(title: e, selected: true, onTap: openFilters))
                .divide(const SizedBox(width: 4)) // app extension: interleaves a separator
          else
            AppChip(
              title: tr(LocaleKeys.items_filter_all),
              trailing: const Icon(LucideIcons.chevronDown),
              onTap: openFilters,
            ),
          if (filter.filterCount > 0)
            TextButton(
              onPressed: notifier.clearAll,
              child: Text(tr(LocaleKeys.items_filter_clear_all)),
            ),
        ],
      ),
    );
  }
}
```

- With a sort, a leading sort chip opens the sort sheet; "Clear all" then also resets the sort to its default
- Every active-filter chip reopens the full sheet rather than removing itself

## Anti-Patterns (flag these)

- Boolean soup or filtering logic inside list widgets instead of a filter class and derived provider
- Sheet chips writing to the applied-filter provider on each tap (the list refetches mid-edit)
- Empty list left in a nullable filter field (`[]` ≠ `null`, so a cleared filter no longer equals the default state)
- Comparators without a tie-breaker, or nulls coerced to `DateTime(0)`
- Building the proto filter outside the API class
