# Storage

Local key-value persistence: storage providers and bootstrap, the `AppStorage` facade, key naming, feature-owned accessors, persisted preferences.

## Providers and Bootstrap

```dart
@Riverpod(keepAlive: true)
FlutterSecureStorage flutterSecureStorage(Ref ref) => const FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

@Riverpod(keepAlive: true)
Future<SharedPreferencesWithCache> sharedPreferences(Ref ref) =>
    SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());
```

```dart
// bootstrap, before runApp
await container.read(sharedPreferencesProvider.future); // first: others requireValue it
if (container.read(firstLaunchProvider)) {
  await container.read(appStorageProvider).clear(storageTypes: [StorageType.secure]);
}
```

- `first_unlock` keeps keychain items readable for background work after the first unlock.
- Every consumer reads prefs with `ref.read(sharedPreferencesProvider).requireValue`, safe because bootstrap awaited it. The iOS keychain survives uninstall, so the first launch after install wipes secure storage to drop a previous install's session.

## AppStorage

```dart
enum StorageType {
  secure, shared;
  static StorageType forKey(String key) {
    const securelyStoredKeys = ['clerkSession', 'clerkClient'];
    return securelyStoredKeys.any(key.contains) ? secure : shared;
  }
}

typedef KeyValue = ({String key, String value});
class AppStorage implements Persistor {
  AppStorage(this._secureStorage, this._sharedPreferences);
  final FlutterSecureStorage _secureStorage;
  final SharedPreferencesWithCache _sharedPreferences;
  final _writeController = StreamController<KeyValue>.broadcast();
  Stream<KeyValue> get onKeyWritten => _writeController.stream;

  @override
  Future<T?> read<T>(String key, {StorageType? storageType}) async {
    final result = switch (storageType ?? StorageType.forKey(key)) {
      StorageType.secure => await _secureStorage.read(key: key),
      StorageType.shared => _sharedPreferences.getString(key),
    };
    if (result == null) return null;
    if (result is! T) return null; // logged
    return result as T;
  }

  @override
  Future<void> write<T>(String key, T value, {StorageType? storageType}) async {
    if (value is! String) return; // logged
    switch (storageType ?? StorageType.forKey(key)) {
      case StorageType.secure: await _secureStorage.write(key: key, value: value);
      case StorageType.shared: await _sharedPreferences.setString(key, value);
    }
    _writeController.add((key: key, value: value));
  }

  // delete(key, {storageType}) mirrors write; clear({storageTypes}) wipes whole stores
  void dispose() => _writeController.close();
}

@Riverpod(keepAlive: true)
AppStorage appStorage(Ref ref) {
  final storage = AppStorage(
    ref.watch(flutterSecureStorageProvider),
    ref.watch(sharedPreferencesProvider).requireValue,
  );
  ref.onDispose(storage.dispose);
  return storage;
}
```

- It implements the auth SDK's `Persistor` (Clerk), which is why the SDK's session keys are the ones routed to secure storage. Add a key substring to `securelyStoredKeys` to route an app secret there; everything else goes to cached prefs.
- Values are strings. Encode at the accessor: enum `.name`, ids, ISO codes, `jsonEncode` for structured state.

## Keys

- App-owned keys are `com.<app>.<name>` constants, private to the provider file that owns them (`const _kSelectedAccountKey = 'com.myapp.selectedAccount'`).
- Per-entity keys append the id: `'com.myapp.itemDefaultCurrency:${account.id}'`, built by a private function next to the accessor.
- Structured state persisted as JSON carries a version suffix (`'com.myapp.draft_v1'`); on decode failure, delete the key and start fresh.

## Feature-Owned Accessors

```dart
extension _AccountDefaultCurrencyStorage on AppStorage {
  Future<String?> readAccountDefaultCurrencyCode(AccountEntity account) =>
      read<String>(_key(account));
  Future<void> writeAccountDefaultCurrencyCode(AccountEntity account, Currency currency) =>
      write<String>(_key(account), currency.isoCode);
  String _key(AccountEntity account) => 'com.myapp.accountDefaultCurrency:${account.id}';
}
```

Typed accessors live as a private extension in the feature file that owns the data, so `AppStorage` stays generic and the key never leaks.

## Persisted Preference

```dart
@riverpod
class SavedThemeMode extends _$SavedThemeMode {
  SharedPreferencesWithCache get _prefs => ref.read(sharedPreferencesProvider).requireValue;
  static const _key = 'com.myapp.theme';
  @override
  ThemeMode build() {
    final themeMode = _prefs.getString(_key);
    if (themeMode == null) return ThemeMode.system;
    return ThemeMode.values.byName(themeMode);
  }
  void setThemeMode(ThemeMode themeMode) {
    _prefs.setString(_key, themeMode.name);
    state = themeMode;
  }
}
```

Synchronous preferences (theme, formats, first-launch flag) read the cached prefs directly so `build` stays sync; anything async or possibly secret goes through `AppStorage`. Setters write and assign `state` in the same call.

## Variant: Defensive Reads and Disposable Caches

From boardbit, for apps with typed prefs and an on-device object cache:
- A typed prefs wrapper catches wrong-type reads per getter: log, `remove(key)`, return `null`, so a type change in a later release self-heals.
- Hive boxes hold disposable caches only. A schema version int lives in prefs; `init()` deletes the box from disk when the stored version is below the code constant, and on open failure deletes the boxes and retries once. Bump the constant whenever adapters change.

```dart
const _kGameBoxVersion = 2;
if (_prefs.gameBoxVersion < _kGameBoxVersion) {
  await Hive.deleteBoxFromDisk(StorageBox.games.name);
  _prefs.gameBoxVersion = _kGameBoxVersion;
}
```

## Anti-Patterns (flag these)

- Constructing `FlutterSecureStorage` or `SharedPreferences` inside a feature instead of reading the providers
- Inline key strings repeated across files, or keys without the `com.<app>.` namespace
- Writing a non-`String` through `AppStorage.write`: it is dropped with only a log line
- Keeping data in Hive that cannot be re-fetched, which a schema bump deletes

Sources: merchant-app `lib/common/storage/app_storage.dart`, `lib/common/storage/storage_provider.dart`, `lib/root/application.dart`, `lib/run_app.dart`, `lib/common/first_launch_provider.dart`, `lib/payment_intent/provider/account_default_currency_provider.dart`, `lib/payment_intent/provider/currency_format_provider.dart`, `lib/boarding/provider/boarding_builder_provider.dart`; boardbit `lib/common/storage/app_shared_prefs.dart`, `lib/common/storage/object_storage_api.dart`
