# Navigation

auto_route setup: router config and provider, startup gating, tabs, typed params and results, where navigation calls live.

## Router

```dart
@Riverpod(keepAlive: true)
// ignore: riverpod_lint/unsupported_provider_value
AppRouter appRouter(Ref ref) {
  // A new router starts at its initial route (splash), which re-resolves the destination.
  ref.watch(tokenExpirationProvider);
  return AppRouter();
}

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.cupertino();
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: SplashRoute.page, initial: true),
    AutoRoute(page: AuthRoute.page),
    AutoRoute(
      page: RootRoute.page,
      children: [
        AutoRoute(page: HomeRoute.page, initial: true),
        AutoRoute(page: OrderRoute.page),
        AutoRoute(page: CustomerRoute.page),
        AutoRoute(page: MoreRoute.page),
      ],
    ),
    AutoRoute(page: OrderDetailRoute.page, path: '/orders/:id'),
    AutoRoute(page: CreateCustomerRoute.page, fullscreenDialog: true),
  ];
}
```

- One flat root stack; only the tab shell has `children`, so detail and flow screens push above the tab bar.
- `fullscreenDialog: true` for create/edit flows and pickers closed with an X; plain routes for drill-down.
- Feature-flagged routes are conditional entries (`if (enableX) AutoRoute(...)`) fed through the router constructor from a watched provider.
- `tokenExpirationProvider` is the keepAlive event stream `Auth.signOut()` emits on (see `auth_session.md`). Watching it is how sign-out, including the forced sign-out when no access token can be obtained, returns the app to splash.

## App Wiring

```dart
final router = ref.watch(appRouterProvider);
return ShadApp.router( // or MaterialApp.router
  routerConfig: router.config(
    navigatorObservers: () => [SentryNavigatorObserver(), PosthogObserver()],
  ),
  // theme, locale, ...
);
```

Route-level observers (Sentry, PostHog) attach here.

## Startup and Auth Gating

Auth gating lives in the splash screen's startup destination, not in `AutoRouteGuard`s. This is deliberate: one provider decides update / maintenance / first launch / auth / home from async state, and the router stays declarative. The splash leaves with `replaceAll` (or `replace`, when it is the only entry) so it never stays in the back stack, and completing sign-in likewise calls `replaceAll([const RootRoute()])` from a listener on the auth flow provider. The providers and the splash screen are in `startup_gate.md`.

## Tabs

```dart
// RootScreen (@RoutePage) build
return AutoTabsScaffold(
  homeIndex: 0,
  routes: const [HomeRoute(), OrderRoute(), CustomerRoute(), MoreRoute()],
  bottomNavigationBuilder: (_, tabsRouter) => AppBottomNavBar(
    currentTab: AppTab.values[tabsRouter.activeIndex],
    onTabSelected: (tab) => tabsRouter.setActiveIndex(AppTab.values.indexOf(tab)),
  ),
);
```

- `AppTab` enum owns icon, label and badge state, in `routes` order. The bottom bar is a plain widget taking `currentTab` + `ValueChanged<AppTab>` and knows nothing about auto_route.

## Typed Params and Results

```dart
@RoutePage()
class CreateCustomerScreen extends HookConsumerWidget {
  const CreateCustomerScreen({super.key, this.customer, this.isModal = true});
  final CustomerEntity? customer; // null = create, non-null = edit
  final bool isModal;
  // on save: context.router.pop(customer);
}
@RoutePage()
class OrderDetailScreen extends HookConsumerWidget {
  const OrderDetailScreen({super.key, @PathParam('id') required this.id});
  final String id; // passed straight into orderDetailProvider(id)
}
// caller
final customer = await context.router.push<CustomerEntity?>(CreateCustomerRoute());
if (!context.mounted) return;
if (customer != null) unawaited(context.router.push(CustomerDetailRoute(customer: customer)));
```

- Constructor args become the generated route's named args; pass entities directly for in-app flows. `push<T>` returns `Future<T?>`, filled by `context.router.pop(value)`; `null` means dismissed.
- Use `@PathParam` with a primitive id for routes that must be deep-linkable, and declare the `:id` segment in the route `path`; the screen loads by id through a family provider.
- After a mutation that should land on an existing screen, `context.router.navigate(route)` pops back to it instead of stacking a duplicate.

## Where Navigation Happens

Navigate in user-action callbacks, `ref.listen` callbacks (e.g. on a mutation reaching data), or hook effects; never in the `build` body. Check `context.mounted` after every `await` before navigating again. Screens own navigation; providers emit state or events and never hold a router reference.

## Anti-Patterns (flag these)

- `AutoRouteGuard` for login/onboarding checks: belongs in `StartupDestination`
- Pushing the splash or auth route on sign-out instead of emitting the token-expiry event
- Passing an entity through `@PathParam`, or an id-only detail route without a path segment when it must deep-link

Sources: merchant-app `lib/root/app_router.dart`, `lib/root/root_screen.dart`, `lib/root/app_bottom_nav_bar.dart`, `lib/root/application.dart`, `lib/root/splash_screen.dart`, `lib/startup/startup_destination_provider.dart`, `lib/auth/auth_screen.dart`, `lib/customer/widgets/create_customer_screen.dart`, `lib/customer/customer_screen.dart`, `lib/payment_intent/payment_detail_screen.dart`, `lib/refund/refund_review_screen.dart`; forgeblast_app `lib/common/router/app_router.dart`, `lib/application.dart`, `lib/auth/splash_screen.dart`, `lib/profile/profile_screen.dart`
