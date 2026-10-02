# Logging

One global logger from `package:logging`, a listener that prints in debug and routes records to the crash reporter in release, and rules for what each level means and where logging belongs.

## Layout

- `lib/common/init_logging.dart`: the `log` instance, `initLogging()`, the `LoggingUtility` extension, the crash-reporter routing
- `lib/common/provider_failure_observer.dart` (see `app_bootstrap.md`); optional `provider_debug_observer.dart` for debug builds
- One transport logging interceptor beside the client: `lib/common/network/logging_dio_interceptor.dart` or `lib/common/data/interceptor/logging_interceptor.dart` (gRPC)
- `lib/common/extensions/ref_ext.dart`: `ref.debugPrintLifecycle()` (see `common_kit.md`)

## Logger and Levels

```dart
final log = Logger.root; // Logger.detached('AppName') when a dependency also logs to root

void initLogging() {
  log.level = kDebugMode ? Level.FINE : Level.INFO;
  log.onRecord.listen(_processLogRecord);
}

extension LoggingUtility on Logger {
  void error(Object? message, [Object? error, StackTrace? stackTrace]) => severe(message, error, stackTrace);
  void debug(Object? message, [Object? error, StackTrace? stackTrace]) => fine(message, error, stackTrace);
  void verbose(Object? message, [Object? error, StackTrace? stackTrace]) => finer(message, error, stackTrace);
}
```

`initLogging()` runs in the run-app function right after the `ProviderContainer` is built, before any provider is read. Call sites use the extension names, so the five levels read `error`, `warning`, `info`, `debug`, `verbose`.

| Call | Use for | Release |
|---|---|---|
| `log.error(msg, e, st)` | A failure that should not happen: SDK setup failed, persisted state could not be saved or restored, an unexpected state reached a flow | Reported as an exception |
| `log.warning(msg, e, st)` | A failure the app recovers from or expects: SDK call failed and the feature degrades, token refresh retried, stored value had the wrong type, URL could not be launched, unknown enum value | Reported as non-fatal |
| `log.info(msg)` | Milestones and successful mutations: auth state changed, signed out, first launch, "Account X created", deep link received, SDK initialised | Breadcrumb |
| `log.debug(msg)` | Developer detail: transport request and response, cache hits, provider lifecycle, intermediate values | Dropped (`FINE` is below `INFO`) |
| `log.verbose(msg)` | Per-event traces that drown everything else: each storage read and write, each auth step attempt | Dropped; off in debug too unless `log.level` is raised locally |

## Message Shape

```dart
log.info('Invite sent to ${dto.email}');
log.warning('Failed fetching access token: $e', e, st);
log.error('RevenueCat: failed to initialise SDK: $e', e, st);
```

- Past tense for what happened, present participle for what is starting (`'Signing out...'`).
- Include identifiers (`id`, `name`, counts), not whole entities; tokens and secrets never appear in a message. Redact or skip bodies for sensitive services.
- When an exception is at hand, interpolate `$e` for the console and pass `e, st` as arguments so the crash reporter gets the real object and stack for grouping.
- Prefix with the subsystem (`'RevenueCat: ...'`, `'[MOCK] ...'`) when the message would be ambiguous outside its file. No per-class `Logger` instances.

## Where Logging Belongs

- API classes log successful mutations at `info` (`'Order ${result.id} created'`); reads are covered by the transport interceptor.
- Notifiers log state transitions at `info` and the failures they swallow at `warning` or `error`. Errors they let propagate through `AsyncValue.guard` are not logged there: the provider failure observer reports every provider error once. Logging and rethrowing double-reports.
- Session notifiers for SDKs (see `sdk_session.md`) catch their own SDK calls and log them, `error` for setup, `warning` for identify and reset.
- Widgets log only callbacks from outside Flutter (web views, platform channels) and never from `build`.
- Isolate entry points that run before `initLogging()` (background push handlers) use `debugPrint`; nothing else does.

## Transport Logging

One interceptor per client logs at `debug`: the request with method and path, the response with status and elapsed time, and errors at `error` with the mapped status. A redacted variant logs paths only and is used for clients that carry card data or personal details.

```dart
// gRPC: ClientInterceptor.interceptUnary wraps the invoker
log.debug('🚀 ${method.path}\n$request');
log.debug('✅ ${method.path} • $elapsed\n$data');
log.error('❌ ${method.path} • $elapsed\n${e.codeName}: ${e.message}', e, s);

// Dio: a project Interceptor, placed before the error interceptor
LoggingDioInterceptor(errorLevel: Level.WARNING, shouldLogBody: (_) => false)
```

`LoggingDioInterceptor` takes `requestHeader`, `requestBody`, `responseHeader`, `shouldLogBody(response)` and per-kind levels (`requestLevel`, `responseLevel`, `errorLevel`), pretty-prints JSON bodies, and skips the verbose message for 401s since the auth interceptor handles them. Since `debug` is dropped in release, transport logs cost nothing there.

## Crash Reporter Routing

```dart
void _processLogRecord(LogRecord record) {
  _printColored(record); // dart:developer log, red/yellow/green/blue by level; stack printed for SEVERE in debug
  switch (record.level) {
    case >= Level.SEVERE:
      Sentry.captureException(record.error ?? record.message, stackTrace: record.stackTrace);
    case Level.WARNING:
      Sentry.captureMessage(record.message, level: SentryLevel.warning);
    case Level.INFO:
    case Level.FINE:
      Sentry.addBreadcrumb(record.toBreadcrumb()); // category/type from level, data carries error and stack
    case _:
  }
}
```

- Code never calls the crash reporter directly; the listener is the only caller besides the provider failure observer.
- Sentry: the DSN comes from backend config, so `SentryFlutter.init` runs in the startup gate (see `startup_gate.md`); earlier `Sentry.*` calls are no-ops, and `beforeSend` drops events outside release builds.
- Crashlytics: pass the instance into `initLogging(crashlytics)`, report only when `!kDebugMode`: `crashlytics.log(formatted)` for every record, `recordError(error ?? '$loggerName: $message', stackTrace, fatal: level >= SEVERE)` for WARNING and up. `enableCrashCollection` sets `FlutterError.onError`, an isolate error listener, and `FlutterError.demangleStackTrace` so `package:stack_trace` chains report as VM traces.

## Debug Aids

- `ProviderDebugObserver` logs `didAddProvider`, `didUpdateProvider` (previous and new value) and `didDisposeProvider` at `debug`; add it to the container's observers in debug builds only when chasing a rebuild problem.
- `ref.debugPrintLifecycle(debugName: 'itemList')` at the top of one provider's `build` traces its listeners, cancel, resume and dispose.

## Anti-Patterns (flag these)

- `print` or `debugPrint` anywhere the logger is initialised
- `log.error('$e')` without passing `e, st`: the report loses its stack and groups as a string
- Logging an error and rethrowing it, or logging inside `AsyncValue.guard` callbacks the observer already reports
- `log.error` for expected failures (no internet, cancelled request, unknown backend value): these are `warning`
- Logging whole entities, request bodies or tokens
- A `Logger('ClassName')` per class instead of the global `log`
