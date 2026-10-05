# Widget Tests

Two kinds: a scoped test of one widget with its providers overridden to the state under test, and one routed journey per feature through the app harness. Scoped tests are the default.

## Scoped Widget Test

Pump the widget alone. The providers it reads are overridden to the state the test is about, so the test proves rendering and interaction, not the provider's decision.

```dart
testWidgets('denied access hides the list and offers retry', (tester) async {
  await pumpApp(
    tester,
    AccountAccessGate(action: AccountAction.billingRead, builder: (_) => const ItemList()),
    overrides: [
      ...accessScopeOverrides(testAccount()),
      accountAccessSnapshotProvider(testUserId, 'accounts/test').overrideWith(() => FixedAccess(actions: {})),
    ],
  );

  expect(find.byType(ItemList), findsNothing);
  expect(find.byKey(AccessGateKeys.retry), findsOneWidget);
});
```

One test per render state (loading, data, error, denied, empty) is right when each state is a different subtree. When the same widget varies by input, a table with literal expectations replaces the separate tests. A gate or builder that switches over a sealed state gets its own direct test; proving the switch only through the full app leaves the component untested on its own.

## Routed Journey

A feature's single journey runs the real router through `AppHarness` and proves wiring: the user reaches the right screen, the right request leaves with the right account, and nothing leaks across accounts. Branches inside the feature belong to provider and scoped tests.

```dart
testWidgets('switching account clears the list before the new account loads', (tester) async {
  final harness = AppHarness();
  await harness.mount(tester);
  await tester.tap(find.byKey(NavKeys.items));
  await tester.pumpAndSettle();
  expect(find.text(harness.apis.items.first.name), findsOneWidget);

  final latePage = Completer<ItemListResult>();
  harness.apis.items.pending = latePage.future;
  harness.protectedRequests.clear();
  await harness.selectAccount(tester, 'accounts/b');
  expect(find.text(harness.apis.items.first.name), findsNothing);

  latePage.complete(ItemListResult(items: [testItem(id: 'accounts/b/items/1', name: 'Item B')]));
  await tester.pumpAndSettle();
  expect(find.text('Item B'), findsOneWidget);
  expect(harness.protectedRequests, isNotEmpty);
  expect(harness.protectedRequests, everyElement(endsWith(':accounts/b')));
});
```

A journey pumps the whole app with twenty-odd overrides and is the slowest test in the suite, so a flow gets a journey only when the wiring between screens is what can break. Repeating the same interaction on three tabs that render one `const` widget is three times the cost for one proof: assert presence per tab, interact once.

## Finding Widgets

1. `find.byKey` with keys the widget owns (`static const retryKey = Key('access_gate_retry')`, or a feature `keys.dart` when a screen has several).
2. `find.bySemanticsLabel` for accessible controls that already carry a label.
3. `find.byType` when the widget is the subject of the assertion.
4. `find.text` when the copy is the subject; otherwise copy changes should not fail the test.

Interact through the UI: `tester.tap`, `tester.enterText`, `tester.drag`. Reading a widget off the tree and invoking its callback property skips the layout and gesture code the test exists to cover. `findsNothing` on text only proves something next to a positive check on the same screen, since a renamed string makes it pass for the wrong reason.

## Waiting

- `pumpAndSettle()` after an interaction, by default.
- `pump(duration)` for an animation or timer with a known duration.
- `pumpUntil(tester, () => find.byType(ItemList).evaluate().isNotEmpty)` from `test/support/` for content that arrives asynchronously, instead of a fixed number of frames.
- A toast's lifetime lives in one helper, `dismissToast(tester)`, so no test hard-codes the duration.
- Absence of an action ("no polling started") is proven through the fake's request log after `pumpEventQueue()`, not by pumping a second and looking.

## Global State

Platform singletons set for a test are restored in the same test: `WebViewPlatform.instance`, method channel handlers, `debugDefaultTargetPlatformOverride`. `addTearDown` right after the assignment keeps the restore next to the change.

## Platform and Size

`TargetPlatformVariant` only when the widget or its providers read `defaultTargetPlatform` or `Platform.is*`; the same Flutter code behaving the same on both platforms is the framework's guarantee. Viewport-specific cases use `useViewport(tester, const Size(320, 568))` and follow the project's scope rules for small screens and large text.

## Anti-Patterns (flag these)

- `expect(tester.takeException(), isNull)` at the end of a test, or `pumpWidget(const SizedBox.shrink())` as a manual unmount
- Finders on icons, `AlertDialog` then `TextButton.last`, an `AnimatedContainer` inside a checkbox, or any other tree shape
- `tester.widget<AmountInput>(...).onCurrencySelected(usd)` instead of driving the dropdown
- `await tester.pump(const Duration(seconds: 6))` to outlive a toast
- Asserting layout geometry (`badgeRect.bottom < countRect.top`) outside a layout component's own test
- A `for` over tabs or flavors that reach the same widget with the same providers
