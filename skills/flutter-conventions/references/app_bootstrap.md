# App Bootstrap

Flavor entry points, the shared run-app function, the root `ProviderContainer`, and where logging and crash reporting start.

## Layout

- `lib/main_<flavor>.dart` per flavor, `lib/run_app.dart` (`runMainApp`), `lib/flavor_config.dart`
- `lib/common/`: `init_logging.dart` (see `logging.md`), `provider_failure_observer.dart`, `first_launch_provider.dart`; storage providers in `lib/common/storage/` (see `storage.md`)

## Flavor Entry Points

One `main_<flavor>.dart` per flavor builds a `FlavorConfig` and calls a shared `runMainApp(flavorConfig)`. Nothing else lives in `main`.

```dart
// lib/main_prod.dart; main_dev.dart and main_sandbox.dart differ only in values
void main() => runMainApp(FlavorConfig(
      flavor: AppFlavor.prod,
      backendHost: 'api.example.com',
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    ));

enum AppFlavor { prod, dev, sandbox }

class FlavorConfig {
  final AppFlavor flavor;
  final String backendHost;
  final FirebaseOptions firebaseOptions;
  FlavorConfig({required this.flavor, required this.backendHost, required this.firebaseOptions});
  bool get isProd => flavor == AppFlavor.prod;
}

@Riverpod(keepAlive: true)
FlavorConfig flavorConfig(Ref ref) => throw Exception('FlavorConfig should be overridden in main.dart');
```

- Branch on `isProd` only; every non-prod flavor is "sandbox" and behaves identically in code. An exhaustive `switch (flavor)` is fine where each flavor needs its own value (crash-reporter environment, default config).
- Variant: values may come from a `.env` file via an async `static Future<FlavorConfig> load({required AppFlavor flavor})` (flutter_dotenv) instead of literals; `main` awaits it before calling the run function.

## Run-App Order

```dart
Future<void> runMainApp(FlavorConfig flavorConfig) async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting();
  await EasyLocalization.ensureInitialized();
  try {
    await Firebase.initializeApp(options: flavorConfig.firebaseOptions);
  } catch (e) {
    debugPrint("Firebase couldn't be initialized: $e");
  }

  final container = ProviderContainer(
    observers: [ProviderFailureObserver()],
    retry: (retryCount, error) => null,
    overrides: <Override>[flavorConfigProvider.overrideWithValue(flavorConfig)],
  );
  initLogging();

  await container.read(sharedPreferencesProvider.future);
  await Future.wait([
    container.read(packageInfoProvider.future),
    container.read(pushNotificationApiProvider).initialize(),
  ]);
  if (container.read(firstLaunchProvider)) {
    log.info('First launch, clearing any stored tokens.');
    await container.read(appStorageProvider).clear(storageTypes: [StorageType.secure]);
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: EasyLocalization(
      supportedLocales: const [Locale('en', 'GB')],
      path: 'lib/generated/translations',
      assetLoader: const CodegenLoader(),
      fallbackLocale: const Locale('en', 'GB'),
      useOnlyLangCode: true,
      child: const Application(),
    ),
  ));
}
```

- Build the container manually so bootstrap can `await container.read(...)` before the first frame, then mount it with `UncontrolledProviderScope`. Firebase failure is non-fatal; drop the block when the app has no Firebase.
- `retry: (retryCount, error) => null` disables Riverpod 3 automatic retry; failures reach the UI at once and the user retries explicitly.
- Await cached preferences alone first (`SharedPreferencesWithCache`, keepAlive) because other providers read it synchronously; run independent warm-ups in one `Future.wait`.
- Only work every screen needs belongs here. SDKs that need backend config, or can fail and need a retry, belong in the startup gate (see `startup_gate.md`).
- First launch clears secure storage because the iOS keychain survives uninstall while preferences do not; otherwise a fresh install signs into the old session. `firstLaunchProvider` is a keepAlive `bool` that reads the `first_launch` pref via `requireValue`, flips it to `false`, and returns the original value, so the startup gate still sees `true` for the rest of that session.

## Provider Failure Observer

```dart
final class ProviderFailureObserver extends ProviderObserver {
  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    final providerName = context.provider.name ?? context.provider.runtimeType.toString();
    if (kDebugMode) {
      log.error('Provider [$providerName] threw $error', error, stackTrace);
      return;
    }
    Sentry.captureException(error, stackTrace: stackTrace, withScope: (s) {
      s.level = switch (error) {
        ApiException() || AuthException() => SentryLevel.warning,
        _ => SentryLevel.error,
      };
      s.setTag('providerName', providerName);
    });
  }
}
```

- Every provider error is reported once, here, tagged with the provider name; providers and widgets do not report errors themselves. Backend and auth errors are downgraded to warnings; with Crashlytics, skip expected errors via `shouldReportToCrashlytics` (see `error_handling.md`).

## Logging

`initLogging()` runs right after the container is built and before any provider is read, so every later record reaches the console and the crash reporter. With Crashlytics, initialise it after `Firebase.initializeApp`, pass the instance in, and wrap the run function in `runZonedGuarded` so uncaught errors are recorded as fatal. The logger, levels and routing are in `logging.md`.

## Anti-Patterns (flag these)

- Branching on `isDev` or a dev-only flag where `isProd` is the real distinction
- Reading `sharedPreferencesProvider.requireValue` in a provider created before bootstrap awaited it
- `ProviderScope(overrides: ...)` with a fresh container when bootstrap already built one: the awaited warm-ups are lost
