# Provider Tests

Tests of notifiers and providers over a `ProviderContainer`. The real provider graph runs; only the boundary is faked. This is where state machines, money, auth and permissions are proven.

## Shape

One test protects one invariant and may walk several states to prove it. Setup comes from `test/support/`; ordering comes from `Completer`s; assertions name the state reached and the side effects that moved money.

```dart
test('lost processing result stays unknown and status check cannot purchase again', () async {
  final process = Completer<PaymentResult>();
  final sdk = FakePaymentSdk(statusResults: [PaymentStatus.processing])..processGate = process;
  final api = FakePaymentApi();
  final container = createContainer(overrides: paymentOverrides(sdk: sdk, api: api));
  await waitForState<PaymentReady>(container, paymentFlowProvider);
  final flow = container.read(paymentFlowProvider.notifier);

  final start = flow.startPayment(amountMinor: 100, currencyCode: 'GBP');
  await sdk.processStarted.future;
  process.completeError(Exception('transport lost'));
  await start;
  expect(container.read(paymentFlowProvider).value, isA<PaymentUnknown>());

  await flow.checkStatus();
  expect(container.read(paymentFlowProvider).value, isA<PaymentProcessing>());
  expect(sdk.processedSecrets, ['secret-1']);
  expect(api.creationRequests, hasLength(1));
});
```

`processedSecrets` and `creationRequests` are asserted because a second charge or a second intent costs the merchant money. `sdk.initializeCalls` would not be: initialisation count is implementation detail.

## Transition Tables

When several inputs map onto next states through one `switch` or one error mapper, the test is a table with one row per distinct production branch and literal expectations:

```dart
for (final (error, expected) in [
  (SdkError.setupRequired, isA<PaymentSetupRequired>()),
  (SdkError.releaseRequired, isA<PaymentInfrastructureError>()),
  (SdkError.serviceUnavailable, isA<PaymentReady>()),
]) {
  test('reset after $error offers $expected', () async {
    final container = createContainer(overrides: paymentOverrides(sdk: FakePaymentSdk(failWith: error)));
    await container.read(paymentFlowProvider.notifier).reset();
    expect(container.read(paymentFlowProvider).value, expected);
  });
}
```

Two errors that production maps to the same state are one row. A row whose expectation is computed (`invalid ? isNull : isA<Ready>()`) has stopped being a table.

## Races

Concurrency bugs are proven with `Completer`s that hold a boundary call open while the test changes something else, then release it. `pumpEventQueue()` flushes microtasks between steps.

```dart
test('a late page for the previous account is discarded', () async {
  final api = FakeItemApi();
  final container = createContainer(overrides: [...accessScopeOverrides(testAccount(id: 'accounts/a')), itemApiProvider.overrideWithValue(api)]);
  await waitForData(container, itemListProvider);

  final latePage = Completer<ItemListResult>();
  api.pending = latePage.future;
  final loading = container.read(itemListProvider.notifier).loadMore();
  container.read(selectedAccountProvider.notifier).selectAccount(testAccount(id: 'accounts/b'));
  await pumpEventQueue();
  latePage.complete(ItemListResult(items: [testItem(id: 'items/stale')]));
  await loading;

  expect(container.read(itemListProvider).value?.items.map((e) => e.id), isNot(contains('items/stale')));
  expect(api.requestedAccounts.last, 'accounts/b');
});
```

Errors from an awaited boundary call are asserted with `await expectLater(call, throwsA(isA<GrpcError>()))`; the state assertion follows the await.

## Time

Polling, debouncing and timeouts run under `fakeAsync`, which makes `Future.delayed` and `Timer` deterministic and lets the test advance time explicitly:

```dart
test('status polling stops at the first terminal result', () {
  fakeAsync((async) {
    final api = FakeRefundApi(states: [RefundState.pending, RefundState.pending, RefundState.succeeded]);
    final container = createContainer(overrides: [refundApiProvider.overrideWithValue(api)]);
    container.listen(refundWatchProvider('refunds/1'), (_, _) {});
    async.elapse(const Duration(seconds: 10));
    expect(api.statusCalls, 3);
    expect(container.read(refundWatchProvider('refunds/1')).value, RefundState.succeeded);
  });
});
```

A `testWidgets` body only for its fake clock, with no widget pumped, is `fakeAsync` written the long way.

## Action Providers

An action provider is tested through its method and its effects: the state it ends in, the request the fake received, and the providers it invalidated (read the dependent provider and check it refetched). The error path asserts that `state.hasError` holds the boundary error; `AsyncValue.guard` itself is not under test. Testing that `isLoading` is true mid-flight needs a `Completer` holding the call open, and is worth it only when the UI gates on that flag.

## What Belongs Elsewhere

- Entity getters and extensions: a `test()` on the function, with no container.
- API field mapping: a test of the API class with a fake client, when the mapping has logic; a pure field copy needs none.
- Rendering of a state: a scoped widget test (`widget_tests.md`).
- Riverpod's own behaviour: `retainPrevious` keeping data during refresh, auto-dispose, `AsyncLoading` before the first value.

## Anti-Patterns (flag these)

- `Future.delayed` or a `for` loop of `await Future<void>.delayed(Duration.zero)` to wait for a state
- Asserting `initializeCalls`, `statusCalls` or `calls == 1` on reads and setup
- A test that reads a provider and asserts the value its own override returned
- The same scenario proven once at provider level and again through the full app
- One test per enum value through a single `fromWire` or `switch`
