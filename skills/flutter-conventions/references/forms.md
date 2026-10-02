# Forms

Form screens: hook-owned inputs, `Validator`-delegated validation, DTO submission through an action provider, listener-driven outcomes.

## Layout

- Shared: `lib/common/util/validator.dart`, `lib/common/util/use_ensure_visible_on_focus.dart`, `lib/common/widgets/container/scrollable_cta_content.dart`, `lib/common/widgets/input/` (app text inputs), `lib/common/haptic_provider.dart`
- Feature: `lib/<feature>/widgets/create_item_form.dart` with `lib/<feature>/provider/create_item_provider.dart`; the screen that hosts the form passes `onCreated`

## Action Provider

```dart
@riverpod
class CreateCustomer extends _$CreateCustomer {
  CustomerApi get _api => ref.read(customerApiProvider);

  @override
  Future<CustomerEntity?> build() async => null; // null = idle

  Future<void> createCustomer(CreateCustomerDto dto) async {
    final account = await ref.read(selectedAccountProvider.future);
    if (!ref.mounted || account == null) return;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _api.createCustomer(dto, account: account));
    if (!ref.mounted) return;

    state = result;
    ref.invalidate(customerListProvider);
  }
}
```

- One action provider per mutation: `AsyncData(non-null)` is success, `AsyncError` is failure
- The provider invalidates dependent lists; the form never refreshes them

## Validator

- `class Validator { const Validator(); ... }` holds every rule; each method returns a localized message or `null`: `String? validateEmail(String input, {bool isRequired = false})`, `String? validateCustomerName(String input)`
- Async rules return a future: `Future<String?> validatePhoneNumber(PhoneNumber phoneNumber)`; they run in the submit handler after the sync form validation
- Field `validator:` lambdas only delegate; messages come from `LocaleKeys`, e.g. `LocaleKeys.auth_error_x_cannot_be_empty.tr(args: [LocaleKeys.customer_name.tr()])`
- Injected as a widget param with a const default: `this.validator = const Validator()`

## Form Widget

```dart
class CreateCustomerForm extends HookConsumerWidget {
  const CreateCustomerForm({super.key, this.validator = const Validator(), this.onCreated});

  final Validator validator;
  final void Function(CustomerEntity)? onCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createCustomerProvider);

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final nameController = useTextEditingController();
    final emailController = useTextEditingController();
    final emailFocus = useFocusNode();
    useListenable(nameController);

    ref.listen(createCustomerProvider, (_, next) {
      next.whenOrNull(data: (customer) {
        if (customer != null) onCreated?.call(customer);
      });
    });
    ref.listenOnError(createCustomerProvider);

    Future<void> submit() async {
      if (!(formKey.currentState?.validate() ?? false)) {
        ref.feedbackError();
        return;
      }
      final dto = CreateCustomerDto(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
      );
      await ref.read(createCustomerProvider.notifier).createCustomer(dto);
    }

    final canSubmit = validator.validateCustomerName(nameController.text.trim()) == null;

    return Form(
      key: formKey,
      child: ScrollableCtaContent(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => emailFocus.requestFocus(),
              validator: (v) => validator.validateCustomerName(v?.trim() ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              focusNode: emailFocus,
              textInputAction: TextInputAction.done,
              validator: (v) => validator.validateEmail(v?.trim() ?? ''),
            ),
          ],
        ),
        cta: AppPrimaryButton(
          title: tr(LocaleKeys.customer_add),
          enabled: canSubmit,
          loading: state.isLoading,
          onPressed: submit,
        ),
      ),
    );
  }
}
```

- Hooks own every controller, focus node and the form key
- Sanitise at capture with `.trim()`; the notifier receives only the DTO
- Button loading reads the action provider's `isLoading`, never a local `useState<bool>`
- Outcomes come from `ref.listen` (success → callback or navigation) and `ref.listenOnError` (toast), not from the awaited call
- `listenOnError<T>(ProviderListenable<T> provider, {void Function(Object)? onError, bool Function(Object)? ignoreIf})` shows the toast itself; `onError` adds side effects
- Disable the CTA until valid when validity is cheap to derive from controllers (`useListenable`, or a `ValueListenableBuilder` around just the button); otherwise validate on tap
- Haptics: `ref.feedbackError()` on validation failure, from the `WidgetRef` haptics extension in `common_kit.md`

## Async Validation

```dart
final phone = phoneController.phoneNumber;
String? formattedPhone;
if (phone.phoneInput.isNotEmpty) {
  final phoneError = await validator.validatePhoneNumber(phone);
  if (!context.mounted) return;
  if (phoneError != null) {
    ref.feedbackError();
    AppToast.show(context, title: phoneError);
    return;
  }
  formattedPhone = await phone.formattedPhoneNumber();
  if (!context.mounted) return;
}
```

- Inline variant: store the result in `useValueNotifier<String?>`, return it from the field's `validator: (_) => phoneError.value`, clear it in `onChanged`, then call `formKey.currentState?.validate()`

## Layout and Focus

- `ScrollableCtaContent(body:, cta:)`: `LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight: maxHeight)` → `IntrinsicHeight` → `Column[body, Spacer(), ButtonDock(cta)]`; the CTA docks at the viewport bottom on short forms and follows long content
- When the CTA must stay visible on a long form, pin it outside the scroll view: `Column[Expanded(SingleChildScrollView(body)), ButtonDock(cta)]` in a keyboard-resizing `Scaffold`
- The app scaffold unfocuses on background tap; scroll views use `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`
- Fields that can end up under the keyboard get `useEnsureVisibleOnFocus(FocusNode focusNode, {GlobalKey? key, BuildContext? context, Duration delay = const Duration(milliseconds: 150), Duration duration = const Duration(milliseconds: 300), Curve curve = Curves.easeInOut, double alignment = 0.0})`: on focus it waits `delay` for the keyboard inset to settle, then calls `Scrollable.ensureVisible` if the target is still mounted and focused; the listener is removed in the `useEffect` cleanup

```dart
final notesFocus = useFocusNode();
final notesKey = useMemoized(GlobalKey.new); // same key on the field
useEnsureVisibleOnFocus(notesFocus, key: notesKey);
```

## Anti-Patterns (flag these)

- `final created = await notifier.create(dto); if (created != null) pop();` — outcome inferred from the awaited call
- Validation rules or hardcoded messages inline in `validator:` lambdas
- `try/catch` around the notifier call in the widget
- Untrimmed `controller.text` in the DTO
