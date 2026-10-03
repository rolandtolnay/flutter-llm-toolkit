---
name: flutter-testing
description: Decide what deserves a test and write lean tests for Flutter apps built with Riverpod. Use when adding or changing tests, or when a task's verification calls for them.
---

# Flutter Testing

Tests exist to catch regressions that would ship silently and cost money, data or access. Every test is maintenance paid on each later change, so a test earns its place by guarding one distinct behaviour that no other test or compile-time check already guards. Coverage is counted in behaviours protected, not in cases, assertions or inputs exercised.

## Deciding What to Test

Start from the production code, not from the task text. A PRD, ticket or verification list names properties to prove; it is not a list of tests. Map each property onto the production conditions that realise it and write one representative case per condition. Three inputs that take the same branch are one test. Roles or environments that production treats identically are one test. Scenarios that walk the same state machine are one scenario test.

Spend tests where logic fails silently and expensively: state machines, money, auth and permissions, parsing of backend input, destructive actions, persistence, isolation between accounts and environments. Leave untested: pass-throughs, generated code, framework guarantees (Riverpod keeping previous data on refresh, adaptive widgets switching per platform), constructors, `copyWith`, trivial getters, and code the change did not touch.

A bug fix's test reproduces the bug: it fails without the fix and passes with it.

## Choosing the Layer

Test each rule once, at the lowest layer that owns it.

| The rule lives in | Test it as | Doubles |
|---|---|---|
| An entity, extension or pure function | `test()` over the function, table-driven when several inputs map to outputs | None |
| A provider or notifier (state machine, orchestration, caching, permissions) | `test()` over a `ProviderContainer` running the real provider graph | Fakes at the backend client, SDK, platform channel and storage boundary |
| A widget's rendering of provider state (loading, data, error, denied, empty) | `testWidgets()` of that widget alone, with the providers it reads overridden to the state under test | Notifier doubles returning fixed state |
| A flow across several screens | One routed journey per feature through the shared app harness | The same boundary fakes as provider tests |

Provider tests carry most of the suite. A widget test re-proving a provider's decision, or a provider test re-proving an entity's getter, is redundant. The routed journey is the slowest and most fragile kind of test, so a feature gets at most one, and it proves wiring (the right screen, the right request, nothing leaked between accounts), not every branch. On-device tests are worth their setup only when a critical flow crosses into native UI the test binding cannot drive.

## Writing the Test

- Name the behaviour the test protects, as a sentence about the user or the system: `lost processing result stays unknown and status check cannot purchase again`. No `should`, no implementation nouns, no Arrange/Act/Assert comments.
- Assert observable outcomes: the state reached, the widget shown, the request sent, the money moved. Count or list calls only for side effects that move money, credentials or external state, not for reads or initialisation.
- Expected values are literals. A test that computes its expectation with a ternary or branches on its own input mirrors the implementation; write a table of `(input, expected)` rows instead.
- Ordering comes from `Completer`s and time from `fakeAsync` or `tester.pump(duration)`, never from wall-clock delays or polling loops. Await `expectLater(future, throwsA(...))`; an unawaited `expect(future, throwsA(...))` followed by synchronous asserts checks nothing.
- Find widgets by key or semantics label, or by type when the widget is the subject; interact through the UI rather than calling a widget's callback property. `findsNothing` on copy proves nothing unless the same screen also gets a positive check.
- Platform variants only when the code under test branches on platform. Small-screen and large-text cases follow the project's scope rules and do not justify changing widgets outside the task.
- Drop rituals the framework already performs: `expect(tester.takeException(), isNull)`, a manual unmount pump, an empty `setUpAll`.
- Place the test where the production file lives (`test/<feature>/` mirrors `lib/<feature>/`), named after the unit under test. A suite that tests several features in one file is split.

## Doubles

Fake the system boundary and run everything inside it for real. The boundary is the generated backend client, the auth and analytics SDKs, platform channels, `WebViewPlatform` and storage. Hand-written fakes that record calls (`extends Fake implements ItemApi`) are the default; mocktail is for SDK types with wide interfaces. Entities, configuration and other value objects are constructed, never mocked.

Shared doubles, builders and pump helpers live in `test/support/`; a feature's own fixtures live beside its tests. Look there before writing a fake, a pump helper or an entity builder.

## Finishing

Run the affected tests; for a bug fix also show the new test failing with the fix reverted. Run the full suite once before reporting when provider or shared code changed. Report the behaviours now protected and the risks you chose not to cover.

## Where to Look

| Task touches | Read |
|---|---|
| `test/support/`, fakes, fixture builders, the app harness | `references/test_support.md` |
| Provider and state-machine tests, races, time | `references/provider_tests.md` |
| Widget tests, routed journeys, finders, waiting | `references/widget_tests.md` |
| Driving the running app for a one-off check | `references/live_verification.md` |
