# Test Support

The shared library under `test/support/` that tests import instead of rebuilding setup. One file per concern; a feature's own fixtures stay beside its tests.

## Layout

```
test/
  flutter_test_config.dart     // testExecutable: environment bootstrap for every test file
  support/
    container.dart             // createContainer, waitForData, waitForState
    pump.dart                  // pumpApp, pumpRouterApp, useViewport
    fixtures.dart              // entity builders through production conversion
    doubles.dart               // notifier doubles, no-op SDK wrappers
    api_fakes.dart             // recording fakes for API classes, response helpers
    app_harness.dart           // full-app fixture for routed journeys
  <feature>/
    fixtures.dart              // feature-specific builders and transport fixtures
    <unit>_test.dart           // mirrors lib/<feature>/<unit>.dart
```

## Environment

`flutter_test_config.dart` runs once per test file, so no file needs a `setUpAll` for localization, fonts or mocktail fallback values.

```dart
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  registerFallbackValue(testAccount());
  await testMain();
}
```

Fonts load only in the files that assert on text layout: `await (FontLoader('AppFont')..addFont(rootBundle.load('assets/fonts/AppFont-Regular.ttf'))).load();` in that file's `setUpAll`.

## Containers

```dart
ProviderContainer createContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(retry: (_, _) => null, overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

/// Resolves when [provider] next holds data; rethrows its error.
Future<T> waitForData<T>(ProviderContainer container, ProviderListenable<AsyncValue<T>> provider) {
  final completer = Completer<T>();
  final sub = container.listen(provider, (_, next) {
    if (completer.isCompleted) return;
    next.whenOrNull(data: completer.complete, error: completer.completeError);
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

/// Resolves when a sealed-state provider reaches [S].
Future<S> waitForState<S>(ProviderContainer container, ProviderListenable<AsyncValue<Object?>> provider) {
  final completer = Completer<S>();
  final sub = container.listen(provider, (_, next) {
    final value = next.value;
    if (value is S && !completer.isCompleted) completer.complete(value);
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}
```

`retry` is disabled so a failing provider surfaces its error immediately instead of retrying behind a loading state. Awaiting `container.read(provider.future)` is enough when the test only needs the first value; the helpers exist for state machines and refreshes.

## Pumping

```dart
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  ProviderContainer? container,
  List<Override> overrides = const [],
}) async {
  final scope = container ?? createContainer(overrides: overrides);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        assetLoader: const CodegenLoader(),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: appTheme(context),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpRouterApp(WidgetTester tester, RootStackRouter router, {ProviderContainer? container, List<Override> overrides = const []});

Future<void> useViewport(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
```

The unmount teardown runs before the container's dispose teardown, so widgets never outlive their providers. `pumpRouterApp` is the same shell around `MaterialApp.router(routerConfig: router.config())`; the app's real theme goes in both so layout assertions match production.

## Fixtures

Build entities through the production conversion so tests exercise the same mapping as the app, and give every parameter a valid default:

```dart
AccountEntity testAccount({String id = 'accounts/test', String name = 'Merchant', AccountState state = AccountState.active}) =>
    proto.Account(name: id, displayName: name, state: state.toProto()).toEntity();

ItemEntity testItem({String id = 'items/1', int amountMinor = 1000}) =>
    ItemDto.fromJson({'id': id, 'amount': amountMinor, 'currency': 'GBP'}).toEntity();
```

Parameters exist only for what tests vary. A feature's `fixtures.dart` holds builders for its own transport types and says why a fixture is shaped the way it is when that is not obvious:

```dart
/// An otherwise eligible rail isolates rejection of the unsupported type.
final bacs = proto.PaymentMethod(name: 'methods/bacs', paymentRail: 'rails/gbp', bacsDd: proto.PaymentMethod_BacsDd()).toEntity()!;
```

## Doubles

Notifier doubles extend the real notifier and return fixed state; controls and counters are public fields, which the Riverpod lint allows in test files with a one-line reason:

```dart
// Test doubles expose recorded calls and controls to their tests.
// ignore_for_file: riverpod_lint/avoid_public_notifier_properties

class TestSelectedAccount extends SelectedAccount {
  TestSelectedAccount(this._initial);
  final AccountEntity? _initial;

  @override
  Future<AccountEntity?> build() async => _initial;

  @override
  void selectAccount(AccountEntity account) => state = AsyncData(account);
}

class SignedInAuth extends Auth {
  SignedInAuth({this.sessionId = 'session-test'});
  final String? sessionId;
  int signOutCalls = 0;

  @override
  Future<AuthState> build() async => TestAuthState(sessionId: sessionId);

  @override
  Future<void> signOut() async => signOutCalls++;
}

class DisabledHaptic extends Haptic {
  @override
  bool build() => false;
}
```

Recording API fakes implement the API class, record what was asked, and are controlled per test through fields rather than through magic input values, so the test itself shows why a call fails:

```dart
class FakeItemApi extends Fake implements ItemApi {
  final requestedAccounts = <String>[];
  Future<ItemListResult>? pending;
  Object? failWith;

  @override
  Future<ItemListResult> getItemList({required AccountEntity account, int pageSize = 10, String? pageToken}) async {
    requestedAccounts.add(account.id);
    if (failWith case final error?) throw error;
    return await (pending ?? Future.value(ItemListResult(items: [testItem()])));
  }
}
```

Boundary adapters for the transports and platforms the app uses:

- Generated gRPC client: `extends Fake implements ItemServiceClient`, returning `TestResponseFuture.value(response)` or `TestResponseFuture.error(error)`; the fake stores the last request for assertions.
- REST: a `Dio` mock stubbed per method, or a `MockAdapter` returning JSON fixtures.
- Platform channel: `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler)`, reset in `tearDown`; native-to-Dart calls are delivered with `handlePlatformMessage` through a `deliverNativeCall(method, arguments)` helper.
- Storage: in-memory implementations of secure storage and preferences behind `AppStorage memoryStorage()`.
- WebView: a `FakeWebViewPlatform` that records loaded URIs and exposes `completeTokenization(token)` or the equivalent scenario driver.

## App Harness

The fixture for routed journeys runs the real auth, startup, user, account and selection providers and the real router; only SDKs and API classes are doubles. One instance per test.

```dart
class AppHarness {
  AppHarness({this.flavor = AppFlavor.prod, bool signedIn = true, Set<String> actions = allActions});

  final apis = TestApis();          // every fake appends '<kind>:<accountId>' to protectedRequests
  final auth = MockAuthSdk();       // signed-in or signed-out; failures stubbed per test
  late final ProviderContainer container;
  late final AppRouter router;

  List<String> get protectedRequests => apis.protectedRequests;

  Future<void> mount(WidgetTester tester) async {
    container = createContainer(overrides: _overrides);
    router = TestAppRouter();
    await pumpRouterApp(tester, router, container: container);
  }

  void signInFails(String email, Object error) => auth.failures[email] = error;
}
```

The request log makes isolation claims one assertion: `expect(harness.protectedRequests, isEmpty)` after a denied account, or `expect(harness.protectedRequests, everyElement(endsWith(':accounts/b')))` after a switch. Routes a journey does not visit are stubbed in `TestAppRouter` with a `Scaffold(body: Text(route.name))` so the journey asserts arrival without pulling every screen's providers into the test.

## Anti-Patterns (flag these)

- A fake whose behaviour depends on recognising specific input values (`if (email == 'offline@example.com')`) instead of a field set by the test
- A fake that reimplements backend logic (filtering by date window, validating input) and so proves itself rather than the app
- `noSuchMethod` counters or `Mock implements` for an entity, configuration object or `AuthState` whose getters then return null
- A localization shell, `ProviderContainer` construction or entity builder copied into a test file instead of imported from `test/support/`
- A helper named like a query (`allowsAction`) used for its side effect of waiting
