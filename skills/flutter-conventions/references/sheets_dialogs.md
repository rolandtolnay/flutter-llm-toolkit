# Sheets and Dialogs

How bottom sheets, action sheets and confirmation dialogs are presented and how they hand results back to the caller.

## Static `show`

Every sheet widget owns its presentation through `static Future<T?> show(BuildContext context, ...)`. Callers never call `showModalBottomSheet` or `showDialog` directly, and `T` is whatever the sheet produces.

```dart
class ImageSourceSheet extends StatelessWidget {
  static Future<ImagePickerChoice?> show(BuildContext context, {bool showSampleOption = false}) {
    return showAppBottomSheet<ImagePickerChoice>(
      context: context,
      builder: (_) => ImageSourceSheet(showSampleOption: showSampleOption),
    );
  }
  // build: ListTiles whose onTap is Navigator.pop(context, ImagePickerChoice.gallery), ...
}
```

- Results leave through `Navigator.pop(context, value)` / `context.router.maybePop(value)`; a `null` result always means dismissed.
- Sheets that only perform actions return `Future<void>`.
- Feature sheets live in `lib/<feature>/widgets/`; shared ones (`app_bottom_sheet.dart`, `native_confirmation_sheet.dart`) in `lib/common/widgets/sheet/`.

## showAppBottomSheet

The single entry point for modal sheets, in `lib/common/widgets/sheet/app_bottom_sheet.dart`.

```dart
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool? showDragHandle,
}) {
  FocusScope.of(context).requestFocus(FocusNode()); // dismiss the keyboard first

  return showModalBottomSheet<T>(
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    clipBehavior: Clip.hardEdge,
    isScrollControlled: true, // content decides its height, capped by AppBottomSheet
    context: context,
    backgroundColor: context.color.background,
    isDismissible: isDismissible,
    enableDrag: isDismissible, // a non-dismissible sheet cannot be dragged away either
    showDragHandle: showDragHandle,
    builder: builder,
  );
}
```

`AppBottomSheet` is the content wrapper most sheets return from `build`:

```dart
const AppBottomSheet({
  this.title,                // centred, context.typography.headline
  required this.body,        // wrap in Expanded when it scrolls
  this.constraints,          // defaults to BoxConstraints(maxHeight: context.screenHeight * 0.8)
  this.titleGap = kGapSection,
  this.actionGap = kGapItem,
  this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
  this.overwriteActions,     // defaults to a ButtonDock with a primary "Dismiss" button that pops
});
```

Its own `AppBottomSheet.show(context, body:, title:)` covers one-off informational sheets with no dedicated widget.

## Feature-Owned Sheets Read Providers

A sheet that belongs to a feature is a `HookConsumerWidget`. Pass it the entity or id and the initial values only; it watches the providers it needs (device lists, formatting helpers, action notifiers) itself instead of receiving them through constructor arguments or callbacks.

## Draft, Edit, Apply

A filter sheet edits a local copy of the applied state and returns it only from Apply. Dismissing discards the draft; "Clear all" resets the draft, not the provider. State shape and the provider side live in `filter_sort.md`.

```dart
class ItemFilterSheet extends HookConsumerWidget {
  static Future<ItemFilterState?> show(BuildContext context, {ItemFilterState appliedFilters = const ItemFilterState()}) {
    return showAppBottomSheet<ItemFilterState?>(
      context: context,
      builder: (_) => ItemFilterSheet(appliedFilters: appliedFilters),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(appliedFilters);
    final devices = ref.watch(deviceListProvider).value ?? [];

    return AppBottomSheet(
      title: tr(LocaleKeys.filter_title),
      body: _buildChips(draft, devices), // taps set draft.value = draft.value.addingDevice(d) / removingDevice(d)
      overwriteActions: ButtonDock(
        child: Row(children: [
          Expanded(child: AppGhostButton(title: tr(LocaleKeys.filter_clear_all), onPressed: () => draft.value = const ItemFilterState())),
          const SizedBox(width: kGapItem),
          Expanded(child: AppPrimaryButton(title: tr(LocaleKeys.common_apply), onPressed: () => context.router.maybePop(draft.value))),
        ]),
      ),
    );
  }
}

// Caller
final result = await ItemFilterSheet.show(context, appliedFilters: filterState);
if (result != null) ref.read(itemFilterProvider.notifier).applyState(result);
```

## Action Sheets

Secondary actions on a detail screen (the app bar's ellipsis button) or a list tile open an action sheet that receives the entity and builds its action list from the entity's state.

- Body is an `AppBottomSheet` holding an optional `SheetTitle` and a column of `AppListButton`s; `showTitle: false` when opened from the detail screen that already shows the title.
- Actions are chosen with a `switch` on the entity state; actions valid in every state (e.g. "Get help") come last.
- Navigation actions close the sheet in the same step: `context.router.popAndPush(CreateRefundRoute(order: order))`.

Destructive actions confirm first. The confirm-then-mutate flow lives in a `WidgetRef` extension in the sheet's file, keeping `build` a plain list of buttons (`onPressed: () => ref.voidOrder(order)`):

```dart
extension RefOrderActionsExt on WidgetRef {
  Future<void> voidOrder(OrderEntity order) async {
    final confirm = await NativeConfirmationSheet.show(
      context,
      title: tr(LocaleKeys.order_void_title),
      description: tr(LocaleKeys.order_void_description),
      positiveTitle: tr(LocaleKeys.order_void_button),
      negativeTitle: tr(LocaleKeys.common_cancel),
      isPositiveDestructive: true,
    );
    if (!(confirm ?? false) || !context.mounted) return;

    await read(voidOrderProvider(order.id).notifier).voidOrder();
  }
}
```

The extension only confirms and triggers the action. The sheet's `build` watches `voidOrderProvider(order.id)` for loading, calls `ref.listenOnError` on it, and uses `ref.listenForCondition` on its non-null data to toast and pop, as in `hooks.md`.

## Dialogs

- `NativeConfirmationSheet.show(context, {String? title, String? description, required String positiveTitle, required String negativeTitle, bool isPositiveDestructive = false})` returns `Future<bool?>`: `true` positive, `false` negative, `null` dismissed. It renders `CupertinoAlertDialog` on iOS and `AlertDialog` elsewhere, so it is the choice for two-option confirmations.
- `showPopUp({required context, required content, title, defaultActionLabel, onDefaultAction, dismissible = true})` in `lib/common/util/show_popup.dart` is a single-action alert for information the user must acknowledge (e.g. a failed account deletion with a support address). It wraps `showAdaptiveDialog<bool>` + `AlertDialog.adaptive` with one `CupertinoDialogAction` on iOS or `TextButton` elsewhere, labelled `common_dismiss` by default; the action pops `true` and then calls `onDefaultAction`.
- `showPopUp(dismissible: false)` sets `barrierDismissible: false`, wraps the dialog in `PopScope(canPop: false)` and makes the action skip the pop, so `onDefaultAction` must navigate away itself.

## Anti-Patterns (flag these)

- `showModalBottomSheet` / `showDialog` called from a screen instead of the sheet's static `show`.
- A filter sheet writing to the filter provider on each chip tap, so dismissing cannot cancel.
- A feature-owned sheet receiving provider data or callbacks through its constructor that it could watch itself.
- `confirm!` on a confirmation result; dismissal returns `null`, so test `confirm ?? false`.
- Using `context` after awaiting a sheet or dialog without a `context.mounted` check.
