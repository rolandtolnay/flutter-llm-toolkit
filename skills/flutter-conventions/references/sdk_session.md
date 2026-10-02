# SDK Session

KeepAlive notifiers that keep a third-party SDK's user session (analytics, support chat, purchases, push) in step with the app's signed-in user, plus typed events and remote config read from analytics feature flags.

## Layout

- `lib/startup/`: one `<sdk>_provider.dart` per SDK, `<sdk>_event.dart` for typed events, `remote_config_{api,provider,key,value}.dart`
- An SDK that serves a single feature (purchases, push) can live in that feature's `domain/` instead

## Shape

One `@Riverpod(keepAlive: true)` notifier per SDK. `build` watches the user provider and reconciles the SDK's identity with it: identify on login, reset and re-identify on identity change, reset on logout. Since `build` re-runs on every user change, nothing else calls login or logout on the SDK.

```dart
@Riverpod(keepAlive: true)
class Posthog extends _$Posthog {
  @override
  Future<PosthogState> build() async {
    final user = await ref.watch(userProvider.future);
    final distinctId = await _distinctId();

    switch (PosthogState.fromDistinctId(distinctId)) {
      case PosthogState.anonymous:
        if (user != null) await _identify(user);
      case PosthogState.identified:
        if (user == null) await _reset();
        if (user != null && user.id != distinctId) {
          await _reset();
          await _identify(user);
        }
    }
    return PosthogState.fromDistinctId(await _distinctId());
  }

  Future<void> setup(AppConfig config) async {
    try {
      final posthogConfig = ph.PostHogConfig(config.posthogApiKey)
        ..captureApplicationLifecycleEvents = true
        ..host = config.posthogHost;
      await ph.Posthog().setup(posthogConfig);
    } catch (e, st) {
      log.error('Error setting up Posthog: $e', e, st);
    }
  }

  void capture(PosthogEvent event) {
    ph.Posthog().capture(eventName: event.name, properties: event.properties);
  }

  Future<void> _identify(UserEntity user) async {
    try {
      await ph.Posthog().identify(userId: user.id, userProperties: {'email': user.email});
    } catch (e, st) {
      log.warning('Error identifying user in Posthog: $e', e, st);
    }
  }
  // _distinctId() returns '' on error; _reset() calls ph.Posthog().reset(), logging failures.
}

enum PosthogState {
  anonymous,
  identified;

  // Backend user ids carry a fixed prefix; SDK-generated anonymous ids do not.
  static PosthogState fromDistinctId(String id) =>
      id.contains('user_') ? PosthogState.identified : PosthogState.anonymous;
}
```

- SDK calls are not serialised across builds. A user change during an in-flight identify can leave the SDK on the previous identity until the next user change or launch; accept that rather than queueing reconciliation
- `capture` is fire-and-forget: callers never await analytics
- State is read back from the SDK (distinct id, logged-in attributes) rather than kept in a field, because the SDK persists identity across launches and the notifier does not.
- `setup` is separate from `build` and is called exactly once, by the startup gate, which owns the `_didSetup*` flag (see `startup_gate.md`). Keys come from backend config.
- SDK calls inside the notifier are wrapped and logged. A failing SDK degrades its own feature and never fails the session, startup, or the calling screen.
- User-provider errors propagate as the notifier's error, and the SDK keeps its last identity until the user resolves again. Do not map them to "logged out".

## Typed Actions

```dart
abstract class PosthogEvent {
  String get name;
  Map<String, Object>? get properties => null;
}

class EventAppUpdateCtaPressed extends PosthogEvent {
  @override
  String get name => 'app_update_cta_pressed';
}

extension WidgetRefEventCapture on WidgetRef {
  void captureEvent(PosthogEvent event) {
    read(posthogProvider.notifier).capture(event);
  }
}
```

- One class per event, with `snake_case` names and properties as constructor fields. Widgets call `ref.captureEvent(EventX(...))`, never the SDK. Screen views come from the SDK's navigator observer in `router.config(navigatorObservers: ...)`.
- Actions that depend on the identified user (`showMessenger()`) first `await future`, so the session is reconciled before the SDK acts. Fire-and-forget actions catch and log; actions whose outcome the UI reports (`restorePurchases()`) let the error propagate.

## Variants

- **Support chat (Intercom):** state is `signedOut` / `anonymous` / `identified`, read from `fetchLoggedInUserAttributes()`. Only onboarded users are identified, after `setUserHash(hash)` from a backend identity-verification provider; everyone else gets `loginUnidentifiedUser`. `build` also re-subscribes to `onTokenRefresh`, cancelling the subscription in `ref.onDispose`, and pushes the token once identified.
- **Purchases and push (RevenueCat, OneSignal):** the SDK cannot cheaply report identity, so the notifier tracks `String? _currentUserId` and `bool _sdkInitialized` fields and branches on initialise, switch user, or log out. These self-initialise inside `build` from `FlavorConfig` keys, and the run-app function starts them with `container.read(provider)` when the key is non-empty. RevenueCat calls `Purchases.configure` on the first login, passing that user as `appUserID`. Check `ref.mounted` after every SDK await before mutating the fields.

## Remote Config via Feature-Flag Payloads

```dart
enum RemoteConfigKey {
  termsUrl;

  String get key => switch (this) { termsUrl => 'terms_url' };
  RemoteConfigValue<dynamic> get defaultValue => switch (this) {
        termsUrl => RemoteConfigValueString('https://example.com/terms.pdf'),
      };
}

// RemoteConfigApiImpl.readValue
Future<dynamic> readValue(RemoteConfigKey key) async {
  try {
    final payload = (await _posthog.getFeatureFlagResult(key.key))?.payload;
    switch (key.defaultValue) {
      case RemoteConfigValueString():
        if (payload case final String value) return value;
        return key.defaultValue.value;
      // ... Bool, Int, Double, Json (Map) cases follow the same shape
    }
  } catch (e, st) {
    log.error('Failed to read remote config value for $key: $e', e, st);
    return key.defaultValue.value;
  }
}

@riverpod
class RemoteConfig extends _$RemoteConfig {
  @override
  dynamic build(RemoteConfigKey key) {
    ref.read(remoteConfigApiProvider).readValue(key).then((value) {
      if (ref.mounted && state != value) state = value;
    });
    return key.defaultValue.value;
  }
}
```

- `RemoteConfigValue<T>` is a sealed class (`String`, `Bool`, `Int`, `Double`, `Json` subclasses). Every key carries a typed in-app default, and a missing flag, a payload of the wrong type, or an SDK error all fall back to it.
- The provider is synchronous and returns the default immediately, then replaces it when the payload arrives, so UI never waits on or errors from remote config. Callers cast: `ref.watch(remoteConfigProvider(RemoteConfigKey.termsUrl)) as String`.
- This config is client-tunable copy and URLs. Backend-owned config (SDK keys, `mustUpdate`) comes from the backend config call in the startup gate.

## Anti-Patterns (flag these)

- Calling SDK `identify`/`logout` from auth screens or sign-out handlers instead of letting the session notifier react to the user provider
- Auto-dispose session providers, which drop identity sync as soon as no widget listens
- Invalidating the watched auth/user provider from code that runs during the session's `build`, which creates a rebuild loop that can sign the user out
- Calling the SDK directly from widgets for events, or using raw string event names
- Treating an auth/user error as logout and resetting analytics or push identity on a network blip
