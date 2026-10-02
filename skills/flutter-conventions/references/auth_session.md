# Auth and Session

Session state from a third-party auth SDK: auth state, domain user, sign-out and token expiry, access-token cache, selected account. The concrete SDK is Clerk (`ClerkAuthState` is the listenable SDK object, `SessionToken` the cached JWT); below it is called `AuthSdk`.

## Layout

- `lib/auth/provider/`: `auth_sdk_provider.dart`, `auth_state.dart`, `auth_provider.dart`, `user_provider.dart`, `token_expiration_provider.dart`
- `lib/auth/domain/`: `auth_cache.dart`, `user_api.dart`, `user_entity.dart`
- `lib/account/provider/selected_account_provider.dart` when the product has accounts

## Auth State

```dart
class AuthState {
  const AuthState({required AuthSdk sdk}) : _sdk = sdk;
  final AuthSdk _sdk;
  bool get isLoggedIn => _sdk.user != null; // SDK session only, not backend onboarding
  String? get userId => _sdk.user?.id;
  String? get sessionId => _sdk.session?.id;
}

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  Future<AuthState> build() async {
    final sdk = await ref.watch(authSdkProvider.future);
    sdk.addListener(_onAuthStateChange);
    ref.onDispose(() => sdk.removeListener(_onAuthStateChange));
    return AuthState(sdk: sdk);
  }
  void _onAuthStateChange() => ref.invalidateSelf();
}
```

- `AuthState` is a read-only view; the SDK stays the source of truth, and every SDK change rebuilds `Auth` and its dependents. `authSdkProvider` is a keepAlive `FutureProvider` that creates the SDK with `AppStorage` as its persistor (see `storage.md`).

## Domain User

```dart
@Riverpod(keepAlive: true)
class User extends _$User {
  @override
  Future<UserEntity?> build() async {
    final userId = (await ref.watch(authProvider.future)).userId;
    if (userId == null) return null;
    return ref.read(userApiProvider).getUser(userId);
  }
}
```

Backend onboarding status lives on `UserEntity`; startup routing checks `isLoggedIn`, then `user?.isOnboarded` (see `navigation.md`). Onboarding mutations `ref.invalidate(userProvider)` on success.

## Sign-Out and Token Expiry

`TokenExpiration` is a keepAlive notifier whose `build` returns a broadcast `StreamController<DateTime>` stream (closed in `onDispose`); `didTokenExpire()` adds `DateTime.now()`.

```dart
// in Auth
Future<void> signOut() async {
  state = const AsyncValue.loading();
  await ref.read(authCacheProvider).clearAccessToken();
  try {
    final sdk = await ref.read(authSdkProvider.future);
    await sdk.signOut();
  } catch (e, st) {
    log.error('Error signing out', e, st);
    ref.invalidateSelf();
  }
  ref.read(tokenExpirationProvider.notifier).didTokenExpire();
}
```

- The router provider watches `tokenExpirationProvider`, so each event rebuilds the router at splash, which re-resolves the destination; sign-out never navigates itself. Every session end goes through `signOut()`: the user action, a failed auth step, and the request interceptor's `onShouldLogout` when no access token can be obtained.

## Access-Token Cache

An app-level cache in front of the SDK's token call. It exists to join concurrent fetches into one, retry failed fetches and check expiry; when the SDK already does all three, skip it and call the SDK directly, treating a missing token as sign-out.

```dart
class AuthCache {
  AuthCache({required AuthSdk sdk}) : _sdk = sdk;
  final AuthSdk _sdk;
  Completer<void>? _completer;
  SessionToken? _cached;
  Future<String?> accessToken({bool forceRefresh = false, int maxRetries = 3}) async {
    await _completer?.future; // join an in-flight fetch
    final cached = _cached;
    if (!forceRefresh && cached != null && cached.isNotExpired) return cached.jwt;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      await _fetchToken();
      final refreshed = _cached;
      if (refreshed != null && refreshed.isNotExpired) return refreshed.jwt;
    }
    return null; // interceptor treats null as "sign out"
  }
  Future<void> clearAccessToken() async {
    _cached = null;
    _completer = null;
  }
  Future<void> _fetchToken() async {
    final pending = _completer;
    if (pending != null) return pending.future;
    final completer = _completer = Completer<void>();
    try {
      _cached = await _sdk.sessionToken();
    } catch (e, st) {
      log.debug('Failed fetching session token', e, st);
    } finally {
      completer.complete();
      if (identical(_completer, completer)) _completer = null;
    }
  }
}

@Riverpod(keepAlive: true)
AuthCache authCache(Ref ref) => AuthCache(sdk: ref.read(authSdkProvider).requireValue);
```

- The request interceptor takes `fetchAccessToken: () => ref.read(authCacheProvider).accessToken()` and `onShouldLogout: () => ref.read(authProvider.notifier).signOut()`. `requireValue` is safe because app startup awaits SDK creation before any authenticated request.
- Sign-out ends every token request that started before it. The SDK's own sign-out does not guarantee this: a fetch already in flight still resolves with the old user's token, and a failed network sign-out leaves the SDK able to issue it again. So after every await, the cache checks that it is still in the session it started in before it stores or returns a token, and returns null otherwise. The mechanism is the app's choice; a session counter incremented by `clearAccessToken()` is the smallest. The same rule applies to a REST refresh interceptor that writes tokens to storage after an await (`rest_api.md`).

## Selected Account

```dart
const _kSelectedAccountKey = 'com.myapp.selectedAccount';
@Riverpod(keepAlive: true)
class SelectedAccount extends _$SelectedAccount {
  AppStorage get _storage => ref.read(appStorageProvider);
  @override
  Future<AccountEntity?> build() async {
    final accounts = await ref.watch(accountListProvider.future);
    if (!ref.mounted || accounts.isEmpty) return null;
    final ordered = orderAccounts(accounts);
    final fallback = ordered.firstWhereOrNull((a) => a.active) ?? ordered.first;
    final storedId = await _storage.read<String>(_kSelectedAccountKey);
    if (!ref.mounted) return null;
    if (storedId == null) return fallback;
    return accounts.firstWhereOrNull((a) => a.id == storedId) ?? fallback;
  }
  void selectAccount(AccountEntity account) {
    state = AsyncData(account);
    _storage.write(_kSelectedAccountKey, account.id);
  }
}
```

- A stale stored id (account removed, access revoked) silently falls back; no error state. Account-scoped providers `await ref.watch(selectedAccountProvider.future)` in `build`, so switching accounts reloads them.

## Variant: REST Token Auth

For a backend issuing its own access and refresh tokens:

- Tokens live in `FlutterSecureStorage` under keys centralised in a `StorageKeys` class.
- `Auth.build()` reads the access token, verifies it with the backend and returns the user; any failure deletes both tokens and returns an unauthenticated `AuthState`. Login and register write both tokens inside `AsyncValue.guard`.
- A Dio `QueuedInterceptorsWrapper` attaches the bearer token, refreshes once on 401 through a separate interceptor-free Dio, marks the retry with a header, and clears tokens when refresh fails (see `rest_api.md`).
- Wire the interceptor's clear-tokens callback to `signOut()` so the token-expiry event returns the app to splash; an interceptor that only deletes tokens leaves auth state authenticated until restart.

## Anti-Patterns (flag these)

- Storing login state in a field or storage key instead of deriving it from the SDK
- Navigating to the auth screen from `signOut()` or an interceptor
- Fetching the domain user without gating on `auth.userId`
- Storing or returning a credential after an await without checking that sign-out has not run meanwhile
