# Live Verification

Driving the running app in an emulator to see a change work, through the Marionette MCP server (`marionette_mcp`) talking to the app's VM service. A live check is a spot check for this session: it proves the change works once, with real backend state, and leaves no regression protection. State machines, money and permission rules still get a provider or widget test.

## When

- The change is visible in the UI and its look or flow matters (layout, navigation, copy in context).
- The behaviour depends on backend state that is awkward to fake (a real account's history, a real invite).
- A bug report needs reproducing before a test can be written.

Name the tool in the request ("verify with Marionette"), say which screen to reach, which account to use and what the expected result is; without that the agent tends to implement first and verify last, or not at all.

## App Setup

`marionette_flutter` goes in `pubspec.yaml` and the binding replaces `WidgetsFlutterBinding` in debug builds only. Keep the versions of `marionette_flutter` and `marionette_mcp` equal; `connect` refuses a mismatch.

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
- `LoggingLogCollector` (package `marionette_logging`) forwards `package:logging` output to `get_logs`; without a collector the tool returns nothing.
- `isInteractiveWidget` lists the app's design-system widgets so they appear in `get_interactive_elements`; only Material widgets are recognised by default. Give the widgets a live check touches a `ValueKey`, which `tap`, `enter_text` and `scroll_to` match reliably.

## Server Setup

```bash
dart pub global activate marionette_mcp
claude mcp add --transport stdio marionette -- marionette_mcp
```

For other clients, the generic entry is `{"mcpServers": {"marionette": {"command": "marionette_mcp", "args": []}}}`. The CLI twin (`dart pub global activate marionette_cli`, then `marionette help-ai`) offers the same operations as commands when an MCP server cannot be used; `marionette register <name> <uri>` names an app so later commands take `-i <name>`.

## Session

1. Run the app in debug on the sandbox flavor: `flutter run --flavor sandbox -t lib/main_sandbox.dart --vmservice-out-file=build/vm.txt` (through the project's version manager when it has one). The file holds the `ws://127.0.0.1:<port>/ws` address; `flutter run` also prints it. Sign in with the sandbox test account the project designates for agents.
2. `connect` with that URI. One connection at a time; a second `connect` drops the first.
3. `get_interactive_elements` before acting on each new screen, then `tap`, `enter_text`, `scroll_to`, `swipe`, `press_back_button` by key where possible.
4. `take_screenshots` to confirm what the user would see, `get_logs` to confirm what the app did (the request fired, no exception).
5. After a code change, `hot_reload` keeps state and `hot_restart` replays from `main()`; then repeat the steps that exercised the change.
6. `disconnect` when done.

Report what was driven and what was observed, screenshot by screenshot, and separately what the persistent tests cover. A live check that fails is a finding to fix, not a reason to skip the test.

## Limits

- Debug and profile builds only; there is no VM service in release.
- The Flutter element tree only: native permission dialogs, system pickers and platform views are out of reach.
- Gestures are best-effort; this is not a CI or performance tool.
- Custom widgets not listed in `isInteractiveWidget` are invisible to element listing and `tap(text:)`, though `enter_text` by key still finds the `EditableText` beneath them.
