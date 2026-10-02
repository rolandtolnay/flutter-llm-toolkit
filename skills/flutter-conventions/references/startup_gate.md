# Startup Gate

How the splash screen initialises SDKs and config, picks the first screen, and handles first-load failure. Two providers split the work: keepAlive `AppStartup` does one-time init, and auto-dispose `StartupDestination` re-resolves the route on every splash visit, including after session expiry recreates the router.

## Layout

- `lib/startup/`: `app_startup_provider.dart`, `startup_destination_provider.dart`, `app_config_provider.dart` (the backend config fetch and `AppConfig`)
- `lib/root/`: `splash_screen.dart`, `app_update_dialog.dart`, `maintenance_view.dart`

## Startup Provider

```dart
@Riverpod(keepAlive: true)
class AppStartup extends _$AppStartup {
  bool _didSetupSentry = false;
  bool _didSetupAnalytics = false;
  @override
  Future<AppStartupState> build() async {
    final flavorConfig = ref.watch(flavorConfigProvider);
    AppConfig? config;
    final result = await AsyncValue.guard(() async {
      await ref.read(authClientProvider.future);
      if (!ref.mounted) throw StateError('Startup disposed');
      config = await ref.watch(appConfigProvider.future);
      if (!ref.mounted) throw StateError('Startup disposed');
      final startupState = AppStartupState.fromConfig(config!);
      await _setupSentry(config!);
      if (!ref.mounted) return startupState;
      if (!_didSetupAnalytics) {
        await ref.read(posthogProvider.notifier).setup(config!);
        _didSetupAnalytics = true;
      }
      return startupState;
    });
    if (!ref.mounted) return result.requireValue;
    if (result.hasError && config == null && !_didSetupSentry) {
      await AsyncValue.guard(() => _setupSentry(AppConfig.defaultFor(flavorConfig)));
      if (!ref.mounted) return result.requireValue;
    }
    return result.requireValue;
  }
  void retry() {
    if (state.isLoading) return;
    if (ref.read(authClientProvider).hasError) ref.invalidate(authClientProvider);
    final config = ref.read(appConfigProvider);
    if (config.hasError || (config.value?.underMaintenance ?? false)) ref.invalidate(appConfigProvider);
    ref.invalidateSelf();
  }

  Future<void> _setupSentry(AppConfig config) async {
    if (_didSetupSentry) return;
    await SentryFlutter.init((options) => options.dsn = config.sentryDsn);
    _didSetupSentry = true;
  }
}
// AppStartupState.fromConfig(config): requiresUpdate, underMaintenance, storeUrl
```

- The `_didSetup*` flags live on the keepAlive notifier instance, so `invalidateSelf()` re-runs `build` without re-initialising SDKs that already succeeded. `retry()` invalidates only the dependencies that failed and reuses cached successes.
- If config never arrived, crash reporting is initialised from flavor defaults so the startup failure still gets reported; that guarded call never replaces the original error.
- The backend sets `mustUpdate` from the version and bundle id the client sends; the client does no semver comparison. Config that carries SDK keys fails closed with an error and a retry. A standalone version/maintenance check may fail open and return "ok" on error.
- SDK `setup` methods catch and log their own errors, so a broken analytics SDK never blocks startup. Each SDK's session notifier is covered in `sdk_session.md`.

## Destination Provider

```dart
@riverpod
class StartupDestination extends _$StartupDestination {
  @override
  Future<AppStartupScreen> build() async {
    final startup = await ref.watch(appStartupProvider.future);
    if (!ref.mounted) throw StateError('Startup destination disposed');
    if (startup.requiresUpdate) return StartupUpdateRequired(startup.storeUrl);
    if (startup.underMaintenance) return const StartupMaintenance();
    if (ref.read(firstLaunchProvider)) return const StartupFirstLaunch();
    final auth = await ref.watch(authProvider.future);
    if (!ref.mounted) throw StateError('Startup destination disposed');
    if (!auth.isLoggedIn) return const StartupSignIn();
    final user = await ref.watch(userProvider.future);
    if (!ref.mounted) throw StateError('Startup destination disposed');
    return user?.isOnboarded ?? false ? const StartupHome() : const StartupSignIn();
  }

  void retry() {
    if (state.isLoading) return;
    if (ref.read(appStartupProvider).hasError || state.value is StartupMaintenance) {
      ref.read(appStartupProvider.notifier).retry();
    } else {
      if (ref.read(authProvider).hasError) ref.invalidate(authProvider);
      if (ref.read(userProvider).hasError) ref.invalidate(userProvider);
    }
    ref.invalidateSelf();
  }
}

sealed class AppStartupScreen { const AppStartupScreen(); }
class StartupUpdateRequired extends AppStartupScreen { const StartupUpdateRequired(this.storeUrl); final String storeUrl; }
class StartupMaintenance extends AppStartupScreen { const StartupMaintenance(); }
class StartupFirstLaunch extends AppStartupScreen { const StartupFirstLaunch(); }
class StartupSignIn extends AppStartupScreen { const StartupSignIn(); }
class StartupHome extends AppStartupScreen { const StartupHome(); }
```

- Precedence is fixed: update, maintenance, first launch, auth, onboarding, home. Update and maintenance come before auth, so a rejected app version never reaches authenticated APIs.
- A logged-in user who has not finished onboarding resolves to the auth flow, not home. Auth or user errors become the destination's error; they are never mapped to sign-in.

## Splash Screen

```dart
@RoutePage()
class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(startupDestinationProvider);
    final handled = useRef(false);
    useAsyncEffect(() {
      if (!context.mounted || handled.value || destination.isLoading) return;
      final screen = destination.value;
      if (screen == null || screen is StartupMaintenance) return;
      handled.value = true;
      switch (screen) {
        case StartupUpdateRequired(:final storeUrl): AppUpdateDialog.show(context, storeUrl: storeUrl);
        case StartupFirstLaunch(): context.router.replace(const OnboardFirstLaunchRoute());
        case StartupSignIn(): context.router.replace(const AuthRoute());
        case StartupHome(): context.router.replace(const HomeRoute());
        case StartupMaintenance(): break; // rendered below, stays retryable
      }
    }, [destination]);
    void retry() => ref.read(startupDestinationProvider.notifier).retry();
    return Scaffold(
      body: switch (destination) {
        AsyncValue(isLoading: true) => const Center(child: AppLoadingIndicator()),
        AsyncValue(:final error?) => ErrorRetryWidget(error: error, onRetry: retry),
        AsyncData(value: StartupMaintenance()) => MaintenanceView(onRetry: retry),
        _ => const Center(child: AppLoadingIndicator()),
      },
    );
  }
}
```

- Act from a keyed `useAsyncEffect` guarded by a `handled` ref. It sees a value already resolved on first build, runs outside `build`, and fires once even if the destination emits again.
- `replace` swaps out the splash. That leaves a single-route stack, because the splash is the only route when the router is created or recreated.
- Mandatory update is terminal. It is a dialog over the splash with `barrierDismissible: false`, `PopScope(canPop: false)` and no close button, and its only action opens the store URL.
- Maintenance renders inside the splash with retry, because it can clear without an app update. A first-load failure stays on the splash with `ErrorRetryWidget` (see `error_handling.md`).

## Anti-Patterns (flag these)

- SDK init inside the auto-dispose destination provider, which re-initialises SDKs on every splash visit
- Navigating from `build`, or from `ref.listen` without a once-per-visit guard, which causes a double `replace` or a missed initial value
- A dismissible update dialog, or one that routes onward after closing
- Catching auth errors in startup and returning sign-in, so a network blip logs out a valid session
