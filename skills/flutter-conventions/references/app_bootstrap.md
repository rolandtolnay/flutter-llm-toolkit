# App Bootstrap

Flavor entry points, the shared run-app function, the root `ProviderContainer`, and logging wired to the crash reporter.

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

```dart
final log = Logger.root;
void initLogging() {
  log.level = kDebugMode ? Level.FINE : Level.INFO;
  log.onRecord.listen(_processLogRecord);
}

void _processLogRecord(LogRecord record) {
  _printColored(record); // dart:developer log, red/yellow/green/blue by level
  switch (record.level) {
    case >= Level.SEVERE:
      Sentry.captureException(record.error ?? record.message, stackTrace: record.stackTrace);
    case Level.WARNING:
      Sentry.captureMessage(record.message, level: SentryLevel.warning);
    case Level.INFO:
    case Level.FINE:
      Sentry.addBreadcrumb(record.toBreadcrumb());
    case _:
  }
}

extension LoggingUtility on Logger {
  void error(Object? message, [Object? error, StackTrace? stackTrace]) => severe(message, error, stackTrace);
  void debug(Object? message, [Object? error, StackTrace? stackTrace]) => fine(message, error, stackTrace);
  void verbose(Object? message, [Object? error, StackTrace? stackTrace]) => finer(message, error, stackTrace);
}
```

- Code logs through the global `log` and never calls the crash reporter directly. The listener routes by severity: SEVERE becomes a reported exception, WARNING a non-fatal report, INFO/FINE breadcrumb context.
- Sentry: the DSN comes from backend config, so `SentryFlutter.init` runs in the startup gate; earlier `Sentry.*` calls are no-ops, and `beforeSend` drops events outside release builds.
- Crashlytics: init after `Firebase.initializeApp`, pass the instance into `initLogging(crashlytics)`, report only when `!kDebugMode` (`crashlytics.log` for every record, `recordError(..., fatal: level >= SEVERE)` for WARNING and up), and wrap the run function in `runZonedGuarded` to record uncaught errors as fatal. Use `Logger.detached('AppName')` when a dependency (e.g. go_router) also logs to the root logger.

## Anti-Patterns (flag these)

- Branching on `isDev` or a dev-only flag where `isProd` is the real distinction
- Reading `sharedPreferencesProvider.requireValue` in a provider created before bootstrap awaited it
- `ProviderScope(overrides: ...)` with a fresh container when bootstrap already built one: the awaited warm-ups are lost

Sources: merchant-app `lib/main_prod.dart`, `lib/main_dev.dart`, `lib/run_app.dart`, `lib/flavor_config.dart`, `lib/common/init_logging.dart`, `lib/common/provider_failure_observer.dart`, `lib/common/first_launch_provider.dart`, `lib/common/storage/storage_provider.dart`; forgeblast_app `lib/run_app.dart`, `lib/flavor_config.dart`, `lib/common/provider_failure_observer.dart`; boardbit `lib/run_app.dart`, `lib/common/data/init_logging.dart`.
