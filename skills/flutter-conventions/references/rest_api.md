# REST API Layer

Dio client, interceptors, API classes, mocks, response parsing and JSON entities for a REST backend, plus the gRPC variant of the same layering.

## Layout

- `lib/common/network/`: `dio_provider.dart`, `auth_interceptor.dart`, `locale_interceptor.dart`, `logging_dio_interceptor.dart`, `error_interceptor.dart`, `response_parsing.dart`, `exception.dart`, `api_endpoint.dart`
- `lib/<feature>/domain/`: `item_api.dart` (abstract + impl + provider), `item_entity.dart`, `item_responses.dart`, `item_requests.dart`, `mock/item_mock_api.dart`; exception types are in `error_handling.md`

## Dio Provider

```dart
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final config = ref.read(flavorConfigProvider);
  final storage = ref.read(secureStorageProvider);
  final options = BaseOptions(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  );
  final tokenDio = Dio(options); // no interceptors: refresh + retry only
  return Dio(options)
    ..interceptors.addAll([
      LocaleInterceptor(getCurrentLocale: getCurrentLocale),
      AuthInterceptor(
        getAccessToken: () => storage.read(key: StorageKeys.authToken),
        getRefreshToken: () => storage.read(key: StorageKeys.refreshToken),
        saveTokens: (access, refresh) async { /* write both keys */ },
        clearTokens: () async { /* delete both keys */ },
        tokenDio: tokenDio,
        refreshPath: '/auth/refresh',
      ),
      LoggingDioInterceptor(errorLevel: Level.WARNING, shouldLogBody: (_) => false),
      ApiErrorInterceptor(),
    ]);
}
```

Interceptor order is a requirement:

1. `LocaleInterceptor`: sets `Accept-Language` from an injected `Future<String> Function() getCurrentLocale`; a failed locale read skips the header
2. `AuthInterceptor`: bearer token and 401 recovery
3. `LoggingDioInterceptor`: the project's logging `Interceptor` (see `logging.md`); request/response/error, bodies off
4. `ApiErrorInterceptor` last: its `handler.reject` ends the error chain, so refresh and logging must already have run

- Several base URLs get one keepAlive provider each (`dio`, `dioV2`), built by a shared private `_createDio(ref, baseUrl:)`

## Auth Interceptor

`AuthInterceptor extends QueuedInterceptorsWrapper`, constructed with callbacks `getAccessToken`, `getRefreshToken`, `saveTokens(access, refresh)`, `clearTokens`, plus `tokenDio` and `refreshPath`; it never reads providers.

```dart
static const _retryHeader = 'x-retry';

@override
Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
  if (err.response?.statusCode != 401) return handler.next(err);
  if (err.requestOptions.headers[_retryHeader] == true) return handler.next(err);
  final RequestOptions retry;
  try {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) throw StateError('No refresh token');
    final res = await _tokenDio.post<Map<String, dynamic>>(_refreshPath, data: {'refreshToken': refreshToken});
    final data = res.data?['data'] as Map<String, dynamic>?;
    final access = data?['accessToken'] as String?;
    final refresh = data?['refreshToken'] as String?;
    if (access == null || refresh == null) throw StateError('Refresh response missing tokens');
    await _saveTokens(access, refresh);
    retry = err.requestOptions
      ..headers['Authorization'] = 'Bearer $access'
      ..headers[_retryHeader] = true;
  } catch (_) {
    await _clearTokens();
    return handler.next(err);
  }
  try {
    return handler.resolve(await _tokenDio.fetch<dynamic>(retry));
  } on DioException catch (replayError) {
    return handler.next(replayError);
  }
}
```

- `onRequest` adds `Authorization: Bearer <token>` unless `options.path` contains an entry of the static `_publicRoutes` whitelist (login, register, refresh)
- `QueuedInterceptorsWrapper` serialises 401 handling; this recipe refreshes for each queued 401 rather than deduplicating refreshes
- Refresh and retry go through the interceptor-free `tokenDio`; using the main Dio deadlocks the queue
- Refresh failure clears tokens and forwards the original 401. Replay failures continue through the error interceptors without clearing the refreshed tokens
- Wire `clearTokens` to the app's sign-out flow as described in `auth_session.md`; the interceptor never navigates itself

## Error Interceptor

Maps every `DioException` to the typed exceptions in `error_handling.md`.

```dart
class ApiErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is SocketException || err.type == DioExceptionType.connectionError) {
      return handler.reject(NoInternetException(exception: err));
    }
    final isTimeout = const [DioExceptionType.connectionTimeout, DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout].contains(err.type);
    final isGateway = const [HttpStatus.requestTimeout, HttpStatus.badGateway,
        HttpStatus.serviceUnavailable, HttpStatus.gatewayTimeout].contains(err.response?.statusCode);
    if (isTimeout || isGateway) return handler.reject(NetworkException(exception: err));
    handler.reject(ApiException(serverMessage: _serverMessage(err.response), exception: err));
  }
}
```

- `_serverMessage` reads `{error: {message}}`, falling back to legacy `{message}` / `{error: "..."}`; `ApiException.localizedMessage` prefers it over generic copy

## API Class

```dart
abstract class ItemApi {
  Future<List<Item>> getItems();
  Future<Item> createItem(CreateItemRequest request);
}

class ItemApiImpl implements ItemApi {
  final Dio _dio;
  final ApiEndpoint _api;

  ItemApiImpl(this._dio, [this._api = const ApiEndpoint()]);

  @override
  Future<List<Item>> getItems() async {
    final response = await _dio.get<Map<String, dynamic>>(_api.items);
    return response.parseDataList(fromJson: Item.fromJson, endpoint: 'items');
  }

  @override
  Future<Item> createItem(CreateItemRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(_api.items, data: request.toJson());
    return response.parseDataSingle(fromJson: Item.fromJson, endpoint: 'createItem');
  }
}

@riverpod
ItemApi itemApi(Ref ref) {
  if (ref.read(flavorConfigProvider).isMockMode) return ItemMockApi();
  return ItemApiImpl(ref.watch(dioProvider));
}
```

- Paths come from `ApiEndpoint`, a `const` class of getters and path methods (`String item(String id) => '/items/$id'`) grouped by feature
- Bodies are request DTO `.toJson()` or inline maps; optional keys use null-aware entries: `{'email': ?email}`
- API methods never catch: interceptors type transport errors, parse helpers type contract errors
- `isMockMode` follows the project's environment policy, never build mode alone: a flavor check (`!FlavorConfig.isProd`, so a sandbox release build still runs on mocks) or an explicit dev-only opt-in flag, whichever the project defines
- Give a feature a mock only when it must run without the backend; otherwise the provider returns the impl unconditionally

## Mock API

```dart
class ItemMockApi implements ItemApi {
  @override
  Future<Item> createItem(CreateItemRequest request) async {
    await MockDataHelper.simulateNetworkDelay(); // 200-500 ms
    if (request.name == 'error') throw Exception('Mock failure'); // magic input exercises error UI
    return MockItems.defaultItem.copyWith(id: MockDataHelper.generateId(), name: request.name);
  }
  // getItems() likewise
}
```

- `MockDataHelper` statics: `simulateNetworkDelay()`, `generateId()`, `randomPastDate()`, `mockAvatar(name)`, `generateMockToken()`; fixtures live in `mock/` and vary via `copyWith`

## Response Parsing

`extension ResponseParsingEx<T> on Response<T>` in `response_parsing.dart`:

| Method | Body shape | On failure |
|---|---|---|
| `parseSingle<R>({fromJson, endpoint})` | `{...}` | `ParsingException` on null body or `fromJson` throw |
| `parseWrapped<Dto, E>({fromJson, extract, endpoint})` | wrapper DTO, e.g. `{success, user}` | `ParsingException` with `expectedType: 'Dto -> E'` |
| `parseList<Dto, E>({fromJson, toEntity, endpoint})` | `[...]` | null → `[]`; bad items logged and skipped |
| `parseDataSingle<R>({fromJson, endpoint})` | `{data: {...}}` | `ParsingException` when `data` is missing or not a map |
| `parseDataList<R>({fromJson, endpoint})` | `{data: [...]}` | missing `data` → `[]`; non-list → `ParsingException`; bad items skipped |

- Every `ParsingException` carries `message`, `endpoint`, `expectedType`, `rawJson`, `innerError`; always pass `endpoint:`, it is the only request context
- List helpers trade completeness for availability: one malformed item never blanks a screen
- `parseDataSingle` calls `fromJson` outside a `try`, so a field mismatch surfaces as the raw `TypeError`

## Entities and Envelopes

```dart
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class Item extends Equatable {
  final String id;
  @JsonKey(defaultValue: '')
  final String name;
  @JsonKey(fromJson: jsonToInt)
  final int score;
  @JsonKey(unknownEnumValue: ItemStatus.unknown)
  final ItemStatus status;

  const Item({required this.id, required this.name, required this.score, required this.status});
  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
  Map<String, dynamic> toJson() => _$ItemToJson(this);

  @override
  List<Object?> get props => [id, name, score, status];
}
```

- The entity is the JSON model; REST has no separate DTO-to-entity mapper
- Tolerant converters in `common/extensions/json_parse_helpers.dart`: `jsonToInt`, `jsonToIntNullable`, `jsonToDouble`, `jsonToDoubleNullable`, `jsonSafeString`; numbers may arrive as strings or `'N/A'`, empty strings become `null`
- Client-side fields use `@JsonKey(includeFromJson: false, includeToJson: false)`
- Enums carry an `unknown` member so new backend values still parse
- Compound `data` payloads get a `@JsonSerializable` holder (`ItemsData { available, saved, current }`) parsed with `parseDataSingle`
- Request bodies are `Equatable` classes in `item_requests.dart` with `toJson()`
- Pagination is a plain generic class the API fills from `parseDataList` plus the `meta` map:

```dart
class PaginatedResponse<T> {
  final List<T> data;
  final int total, currentPage, totalPages, limit;
  const PaginatedResponse({required this.data, required this.total,
      required this.currentPage, required this.totalPages, required this.limit});
  bool get hasMore => currentPage < totalPages;
}
```

## gRPC Variant

Same three layers; the generated client replaces Dio and proto messages replace JSON.

```dart
Future<CustomerEntity> createCustomer(CreateCustomerDto dto, {required AccountEntity account}) async {
  final customer = Customer(fullName: dto.name, email: dto.email.toLowerCase());
  if (dto.address != null) customer.address = dto.address!.toProto();
  final response = await _customerClient.createCustomer(
    CreateCustomerRequest(parent: account.id, customer: customer),
  );
  return response.toEntity();
}
```

- API class is concrete and takes generated clients through its constructor (`ref.watch(customerServiceClientProvider)` in its provider); add an abstract seam only when a second implementation exists
- Proto requests are built from DTOs; responses convert via `extension CustomerDto on Customer { CustomerEntity toEntity() }` colocated with the entity, with `toProto()` extensions for the reverse
- Proto types never leave `domain/`; providers and UI see entities only
- Empty proto strings map to `null` (`email.isEmpty ? null : email`); optional messages use `hasAddress() ? address.toEntity() : null`

## Anti-Patterns (flag these)

- `ApiErrorInterceptor` anywhere but last, or token refresh sent through the intercepted Dio
- `try/catch` around Dio calls in API classes or providers to build error messages
- Hand-parsing `response.data['x'] as int` instead of a parse helper and `fromJson`
- Strict casts on fields the backend sends loosely instead of the `json_parse_helpers` converters
- Mock selection keyed on build mode instead of the project's environment policy
- Proto messages returned from an API class or held in provider state
