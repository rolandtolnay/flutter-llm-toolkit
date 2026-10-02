# Multi-Step Wizards

One screen hosts every step: a sealed step type, the visible step in local `useState`, all form data in one builder notifier, and step widgets that read/write the builder and get `onNext`/`onSave` callbacks instead of pushing routes.

## Layout

- `lib/<flow>/`: `<flow>_screen.dart` (host), `<flow>_content.dart` (shell), `<flow>_step.dart` (sealed step type), one `step_<name>/` folder per step holding its widget and step-local providers
- `lib/<flow>/provider/`: `<flow>_builder_state.dart`, `<flow>_builder_provider.dart`, `<flow>_draft_provider.dart`, `<flow>_converter_provider.dart`, `<flow>_scroll_provider.dart`

## Step Type

```dart
sealed class MatchStep {
  static MatchStep fromIndex(int index) => switch (index) {
    0 => MatchStepGame(), 1 => MatchStepPlayers(), 2 => MatchStepScore(),
    _ => throw ArgumentError('Invalid step index: $index'),
  };
  int get index => switch (this) { MatchStepGame() => 0, MatchStepPlayers() => 1, MatchStepScore() => 2 };
}
class MatchStepGame extends MatchStep { MatchStepGame({this.game}); final Game? game; }
class MatchStepPlayers extends MatchStep {}
class MatchStepScore extends MatchStep { MatchStepScore({this.rematch}); final RematchBundle? rematch; }
```

- Variants carry entry arguments: a game preselected from a game page, a rematch bundle that prefills game and players

## Builder

```dart
@riverpod
class MatchBuilder extends _$MatchBuilder {
  @override
  MatchBuilderState build() {
    listenSelf((_, next) {
      if (!next.isEditing && next.hasData) ref.read(matchDraftProvider.notifier).persist(next);
    });
    return MatchBuilderState();
  }

  void setupWithMatch(Match match) => state = MatchBuilderState.fromMatch(match);
  void restoreDraft(MatchBuilderState draft) => state = draft;
  void setCurrentStepIndex(int index) => state = state.copyWith(currentStepIndex: index);
  void removePlayer(Player player) {
    final result = state.copyWith(
      playerList: state.playerList.where((e) => e != player).toList(),
      scoreList: state.scoreList.where((e) => e.playerId != player.id).toList(),
    );
    state = result.copyWith(
      winnerList: result.autoWinner ? result.autoWinnerList : result.winnerList.where((e) => e.id != player.id).toList(),
    );
  }
}
```

- State is `Equatable` and `@JsonSerializable` when drafts persist; nullable fields use `copyWith(game: () => value)`
- `currentStepIndex` is persisted for resume; `originalMatch` marks edit mode (`isEditing`) and is excluded from JSON; `hasData` gates autosave and the discard confirmation
- The builder is auto-dispose, kept alive by the screen's `ref.watch`; discard is `ref.invalidate(matchBuilderProvider)`

## Screen

```dart
ref.watch(matchBuilderProvider);
final step = useState<MatchStep>(this.step ?? MatchStepGame());
final reverse = useState(false);
final notifier = ref.read(matchBuilderProvider.notifier);
useInitAsync(() => setupWithExistingData(ref, step));
void goTo(MatchStep next, {bool back = false}) {
  step.value = next;
  reverse.value = back;
  notifier.setCurrentStepIndex(next.index);
}
final body = switch (step.value) {
  MatchStepGame() => MatchGameStep(onNext: () => goTo(MatchStepPlayers())),
  MatchStepPlayers() => MatchPlayersStep(onNext: () => goTo(MatchStepScore())),
  MatchStepScore() => MatchScoreStep(onSave: () => onSave(ref)),
};
return AppScaffold(
  resizeToAvoidBottomInset: false, // the content shell handles the keyboard
  leading: step.value.index > 0
      ? AppBackButton(onPressed: () => goTo(MatchStep.fromIndex(step.value.index - 1), back: true))
      : null,
  body: PageTransitionSwitcher( // package:animations, with SharedAxisTransition
    reverse: reverse.value,
    transitionBuilder: (child, animation, secondary) => SharedAxisTransition(
      animation: animation, secondaryAnimation: secondary, child: child,
      transitionType: SharedAxisTransitionType.horizontal, fillColor: Colors.transparent,
    ),
    child: body,
  ),
);
```

- Save: a `@riverpod Future<Match?> matchConverter(Ref ref, MatchBuilderState builder)` maps the builder to the domain input, `null` when incomplete; on success clear the draft, invalidate the builder and pop
- Close: discard immediately when `!builder.hasData`, otherwise confirm first; discard invalidates the builder, clears the draft and pops

## Content Shell

Every step renders inside `MatchContent({required Widget body, required Widget cta, bool pinCtaAboveKeyboard = true, PinnedHeader? pinnedHeader})`. Its `body` scrolls with a controller owned by a shared scroll provider, under a bottom fade and an optional pinned header shown on the provider's `showPinnedHeader`; the CTA sits below, padded by `viewInsets.bottom` when the keyboard is open, else by the bottom safe area.

## Draft Autosave

```dart
@Riverpod(keepAlive: true)
class MatchDraft extends _$MatchDraft {
  static const _maxAgeDays = 7;
  final _debouncer = Debouncer(const Duration(milliseconds: 500));

  @override
  MatchDraftState? build() {
    ref.onDispose(_debouncer.cancel);
    return _readAndValidate();
  }

  void persist(MatchBuilderState builder) {
    if (builder.isEditing || !builder.hasData) return;
    _debouncer.run(() async {
      final draft = MatchDraftState(builderState: builder, savedAt: DateTime.now());
      await _prefs.setString(_key, jsonEncode(draft.toJson()));
      state = draft;
    });
  }

  Future<void> clear() async {
    _debouncer.cancel();
    await _prefs.remove(_key);
    state = null;
  }
}
```

- `_readAndValidate` returns `null` and clears storage for missing, corrupt or older-than-`_maxAgeDays` drafts, and resets transient fields such as in-flight upload IDs

## Entry Modes

| Mode | Screen argument | Setup |
|---|---|---|
| New | none, or a step with entry args | apply step args (`setGame`, rematch prefill); with no arguments at all and a draft present, offer resume/discard |
| Edit | `match` | `setupWithMatch`; edits are never drafted |
| Resume | `draft`, or "resume" from the prompt | `restoreDraft`, then `step.value = MatchStep.fromIndex(draft.currentStepIndex)` |

- Always initialise the visible step from the persisted index; persisting it without reading it back loses the user's position

## Lighter Variant

Short one-off flows (an account onboarding, for example) keep the sealed step with `stepCount`, `useState` step and reverse flag, `PageTransitionSwitcher`, a builder notifier and a converter provider, but drop drafts, the persisted step index and the content shell.

## Anti-Patterns (flag these)

- A route per step, or steps navigating themselves instead of calling `onNext`
- One provider per step, or cross-field cleanup done in widgets instead of builder methods
- Autosaving edit mode or empty state, or writing drafts without debounce and expiry
- Leaving the draft behind after a successful save or explicit discard
