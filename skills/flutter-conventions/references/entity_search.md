# Entity Search

Client-side filtering of a loaded collection: entities score themselves against a query, a family provider sorts them by score.

## Search Provider

`lib/common/app_search_provider.dart`:

```dart
abstract class Searchable {
  /// 0 = no match; higher = better match, shown first.
  int queryMatch(String query);
}

@riverpod
class AppSearch extends _$AppSearch {
  final _debouncer = Debouncer(Duration.zero); // coalesces bursts of keystrokes into one state write

  @override
  AppSearchResult build(Iterable<Searchable> allItems) =>
      AppSearchResult(items: allItems.sortedByQueryMatch(''), query: '');

  void filterInput(String value) {
    _debouncer.run(() {
      final query = value.trim().toLowerCase();
      state = AppSearchResult(items: allItems.sortedByQueryMatch(query), query: query);
    });
  }
}

class AppSearchResult<T extends Searchable> {
  AppSearchResult({required this.items, required this.query});
  final List<T> items;
  final String query;
  bool get hasFilter => query.isNotEmpty;
}

extension SearchableSort<T extends Searchable> on Iterable<T> {
  /// Items with score > 0, grouped by score, highest group first, source order within a group.
  List<T> sortedByQueryMatch(String query, {int Function(T, int)? overrideMatch}) {
    final byScore = <int, List<T>>{};
    for (final item in this) {
      var match = item.queryMatch(query);
      if (overrideMatch != null) match = overrideMatch(item, match);
      byScore.update(match, (list) => list..add(item), ifAbsent: () => [item]);
    }
    return byScore.entries
        .where((e) => e.key > 0)
        .sorted((a, b) => b.key.compareTo(a.key))
        .expand((e) => e.value)
        .toList();
  }
}
```

- The family parameter is the full item list, so it needs value equality (an `Equatable` entity list, or a list identity that only changes when the data does); the provider is auto-dispose and lives as long as the widget watches it
- `queryMatch` decides what an empty query means: return `1` to show everything until the user types (a picker), or `0` to show nothing, with the widget falling back to the unfiltered collection while not searching (the toggle example below)

## Make Entity Searchable

Implement `Searchable` with `queryMatch` returning relevance score (0 = no match, higher = shown first):

```dart
class CustomerEntity extends Searchable {
  final String name;
  final String? email;

  @override
  int queryMatch(String query) {
    if (query.isEmpty) return 0;

    final q = query.toLowerCase();
    var result = 0;

    if (name.toLowerCase().startsWith(q)) result = max(result, 4);
    if (email?.toLowerCase().startsWith(q) ?? false) result = max(result, 3);
    if (name.toLowerCase().contains(q)) result = max(result, 1);

    return result;
  }
}
```

## Match Scores

| Score | Meaning |
|-------|---------|
| 0 | No match (filtered out) |
| 1 | Weak (contains query) |
| 2-3 | Medium (field starts with query) |
| 4+ | Strong (primary field match) |

Use `max(result, score)` to accumulate best match across fields.

## Widget Usage

```dart
class MyListWidget extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [...];
    final searchProvider = appSearchProvider(items);
    final filtered = ref.watch(searchProvider).items.cast<MyEntity>();

    return Column(
      children: [
        TextField(
          onChanged: (input) {
            ref.read(searchProvider.notifier).filterInput(input);
          },
        ),
        Expanded(
          child: AppListView(items: filtered, ...),
        ),
      ],
    );
  }
}
```

## Patterns

### Bottom Sheet Picker

```dart
final searchProvider = appSearchProvider(countryList);
final filtered = ref.watch(searchProvider).items.cast<PhoneCountry>();

TextField(
  autofocus: true,
  onChanged: (input) {
    ref.read(searchProvider.notifier).filterInput(input);
  },
)
```

### Searchable List with Toggle

```dart
final searchProvider = appSearchProvider(customers);
final filtered = ref.watch(searchProvider).items.cast<CustomerEntity>();

final searchController = useTextEditingController();
final searching = useState(false);

useAsyncEffectDisposing(() async {
  void updateQuery() {
    ref.read(searchProvider.notifier).filterInput(searchController.text);
  }
  searchController.addListener(updateQuery);
  return () => searchController.removeListener(updateQuery);
});

InfiniteList(
  itemCount: searching.value ? filtered.length : customers.length,
  itemBuilder: (_, index) {
    final item = searching.value ? filtered[index] : customers[index];
    return ItemTile(item: item);
  },
)
```
