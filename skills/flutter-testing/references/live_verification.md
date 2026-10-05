# Live Verification

Driving the running app in an emulator to see a change work, through the Marionette CLI (`marionette`) talking to the app's VM service. A live check is a spot check for this session: it proves the change works once, with real backend state, and leaves no regression protection. State machines, money and permission rules still get a provider or widget test.

## When

- The change is visible in the UI and its look or flow matters (layout, navigation, copy in context).
- The behaviour depends on backend state that is awkward to fake (a real account's history, a real invite).
- A bug report needs reproducing before a test can be written.

Name the tool in the request ("verify with Marionette"), say which screen to reach, which account to use and what the expected result is; without that the agent tends to implement first and verify last, or not at all.

## App Setup

`marionette_flutter` goes in `pubspec.yaml` and the binding replaces `WidgetsFlutterBinding` in debug builds only. Keep the versions of `marionette_flutter` and `marionette_cli` equal; the CLI does not check for a mismatch.

```dart
// lib/run_app.dart (or wherever WidgetsFlutterBinding.ensureInitialized() is called)
final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
if (kDebugMode && !isFlutterTest) {
  MarionetteBinding.ensureInitialized(
    MarionetteConfiguration(
      logCollector: LoggingLogCollector(),
      isInteractiveWidget: (type) => type == AppPrimaryButton || type == AppTextField,
    ),
  );
} else {
  WidgetsFlutterBinding.ensureInitialized();
}
```

- `kDebugMode` keeps it out of release and profile builds; the `FLUTTER_TEST` check keeps the test binding as the only binding under `flutter test`.
- `LoggingLogCollector` (package `marionette_logging`) forwards `package:logging` output to `get-logs`; without a collector the command returns nothing.
- `isInteractiveWidget` lists the app's design-system widgets so they appear in `get-interactive-elements`; only Material widgets are recognised by default. Give the widgets a live check touches a `ValueKey`, which `tap`, `enter-text` and `scroll-to` match reliably.

## CLI Setup

```bash
dart pub global activate marionette_cli
marionette help-ai   # the full command reference, written for agents
```

The CLI is the preferred way agents drive the app, from any harness, script or shell. Each command connects, runs and disconnects on its own (about 0.2s), so there is no session state to manage and several commands chain in one shell call. The `marionette_mcp` package offers the same operations as an MCP server; it is not used here.

## Session

1. Run the app in debug on the sandbox flavor: `flutter run --flavor sandbox -t lib/main_sandbox.dart --vmservice-out-file=build/vm.txt` (through the project's version manager when it has one). The file holds the `ws://127.0.0.1:<port>/ws` address; `flutter run` also prints it. Sign in with the sandbox test account the project designates for agents.
2. Name the app once so commands targeting it run as `marionette -i app <command>`: `marionette register app "$(cat build/vm.txt)"`. Names live in `~/.marionette/instances/`; `--uri <ws-uri>` works instead of `-i app` for a one-off command.
3. Run `marionette -i app get-interactive-elements` before acting on each new screen. The listing repeats every text style field; pipe it through `grep -oE '^Type: [A-Za-z]+(, (Text|Key): "[^"]*")?'` to keep type, text and key only.
4. Act by key where possible: `marionette -i app tap --key <key>`, `marionette -i app enter-text --key <key> --input <text>` (or `--focused` after tapping a field). Other actions include `scroll-to`, `swipe`, `press-key` and `press-back-button`.
5. Run `marionette -i app take-screenshots --output <path> --no-open` and read the file to confirm what the user would see; `marionette -i app get-logs` to confirm what the app did (the request fired, no exception).
6. After a code change, `marionette -i app hot-reload` keeps state and `marionette -i app hot-restart` replays from `main()`; then repeat the steps that exercised the change.
7. Run `marionette unregister app` when done.

Report what was driven and what was observed, screenshot by screenshot, and separately what the persistent tests cover. A live check that fails is a finding to fix, not a reason to skip the test.

## Limits

- Debug builds only; the binding is gated on `kDebugMode` and there is no VM service in release.
- The Flutter element tree only: native permission dialogs, system pickers and platform views are out of reach.
- Gestures are best-effort; this is not a CI or performance tool.
- Custom widgets not listed in `isInteractiveWidget` are invisible to element listing and `tap --text`, though `enter-text` by key still finds the `EditableText` beneath them.
